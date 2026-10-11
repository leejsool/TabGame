import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/generator.dart';

/// 완성한 스도쿠 한 판의 기록. 문제를 통째로 담고 있어서 같은 판을 다시 풀 수 있다.
class SudokuRecord {
  const SudokuRecord({
    required this.at,
    required this.difficulty,
    required this.seconds,
    required this.mistakes,
    required this.hints,
    required this.givens,
    required this.solution,
  });

  /// 완성한 시각 (epoch ms).
  final int at;
  final Difficulty difficulty;
  final int seconds;
  final int mistakes;
  final int hints;
  final String givens;
  final String solution;

  SudokuPuzzle get puzzle => SudokuPuzzle.fromStrings(givens, solution, difficulty);

  Map<String, dynamic> toJson() => {
        'at': at,
        'd': difficulty.name,
        'sec': seconds,
        'mis': mistakes,
        'hint': hints,
        'g': givens,
        's': solution,
      };

  static SudokuRecord fromJson(Map<String, dynamic> j) => SudokuRecord(
        at: j['at'] as int,
        difficulty: Difficulty.values.byName(j['d'] as String),
        seconds: j['sec'] as int,
        mistakes: j['mis'] as int,
        hints: j['hint'] as int,
        givens: j['g'] as String,
        solution: j['s'] as String,
      );
}

class SudokuHistory {
  SudokuHistory._();

  static const _key = 'sudoku.history';

  /// 최근 이만큼만 보관한다.
  static const maxEntries = 100;

  /// 최신 순.
  static Future<List<SudokuRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) SudokuRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> add(SudokuRecord r) async {
    final list = await load();
    list.insert(0, r);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}
