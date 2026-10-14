import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/generator.dart';
import '../game/sudoku_game.dart';

class SudokuStats {
  const SudokuStats({this.wins = 0, this.bestSeconds});

  final int wins;
  final int? bestSeconds;
}

/// 진행 중인 판과 기록을 기기에 저장한다.
class SudokuStorage {
  SudokuStorage._();

  static const _saveKey = 'sudoku.save';

  /// 지금 화면에서 하고 있는 판. 새 판으로 바뀐 뒤 이전 화면이 늦게 정리되면서
  /// 새 판의 저장본을 덮어쓰는 일을 막는다.
  static SudokuGame? _active;

  static void setActive(SudokuGame game) => _active = game;

  static Future<void> save(SudokuGame game) async {
    if (!identical(game, _active) || game.completed || game.gaveUp) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(game.toJson()));
  }

  static Future<SudokuGame?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      return SudokuGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_saveKey);
      return null;
    }
  }

  static Future<void> clearSave(SudokuGame game) async {
    if (!identical(game, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  static Future<SudokuStats> stats(Difficulty d) async {
    final prefs = await SharedPreferences.getInstance();
    return SudokuStats(
      wins: prefs.getInt('sudoku.${d.name}.wins') ?? 0,
      bestSeconds: prefs.getInt('sudoku.${d.name}.best'),
    );
  }

  /// 완성 기록. 최고 기록(최단 시간)이면 true.
  static Future<bool> recordWin(Difficulty d, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final wins = (prefs.getInt('sudoku.${d.name}.wins') ?? 0) + 1;
    await prefs.setInt('sudoku.${d.name}.wins', wins);
    final best = prefs.getInt('sudoku.${d.name}.best');
    if (best == null || seconds < best) {
      await prefs.setInt('sudoku.${d.name}.best', seconds);
      return true;
    }
    return false;
  }
}
