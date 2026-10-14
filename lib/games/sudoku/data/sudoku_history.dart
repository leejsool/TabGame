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
    this.gaveUp = false,
  });

  /// 완성한 시각 (epoch ms).
  final int at;
  final Difficulty difficulty;
  final int seconds;
  final int mistakes;
  final int hints;
  final String givens;
  final String solution;

  /// 포기한 판인가 (그러면 [seconds]는 포기하기까지 걸린 시간).
  final bool gaveUp;

  SudokuPuzzle get puzzle => SudokuPuzzle.fromStrings(givens, solution, difficulty);

  Map<String, dynamic> toJson() => {
        'at': at,
        'd': difficulty.name,
        'sec': seconds,
        'mis': mistakes,
        'hint': hints,
        'g': givens,
        's': solution,
        if (gaveUp) 'gu': 1,
      };

  static SudokuRecord fromJson(Map<String, dynamic> j) => SudokuRecord(
        at: j['at'] as int,
        difficulty: Difficulty.values.byName(j['d'] as String),
        seconds: j['sec'] as int,
        mistakes: j['mis'] as int,
        hints: j['hint'] as int,
        givens: j['g'] as String,
        solution: j['s'] as String,
        gaveUp: j['gu'] == 1,
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

  /// 기록을 더한다. 같은 문제의 포기 기록은 하나만 남기고, 포기했던 문제를 완성하면 포기 기록은 지운다.
  static Future<void> add(SudokuRecord r) async {
    final list = await load();
    list.removeWhere((e) => e.gaveUp && e.givens == r.givens);
    list.insert(0, r);
    // 넘치면 오래된 완성 기록부터 지운다 (다시 도전할 수 있는 포기한 판은 되도록 남긴다)
    while (list.length > maxEntries) {
      final i = list.lastIndexWhere((e) => !e.gaveUp);
      list.removeAt(i < 0 ? list.length - 1 : i);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}
