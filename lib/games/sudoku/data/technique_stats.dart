import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 심화 기술 하나의 연습 기록.
class TechniqueStat {
  const TechniqueStat({this.count = 0, this.foundCount = 0, this.foundSeconds = 0});

  /// 연습을 마친 횟수 (정답 보기로 끝낸 것까지).
  final int count;

  /// 정답 보기 없이 스스로 찾은 횟수와, 그때 걸린 시간의 합(초).
  final int foundCount;
  final int foundSeconds;

  /// 스스로 찾는 데 걸린 평균 시간(초). 스스로 찾은 적이 없으면 null.
  int? get averageSeconds => foundCount == 0 ? null : (foundSeconds / foundCount).round();

  Map<String, dynamic> toJson() => {'n': count, 'f': foundCount, 's': foundSeconds};

  factory TechniqueStat.fromJson(Map<String, dynamic> j) => TechniqueStat(
        count: (j['n'] as num?)?.toInt() ?? 0,
        foundCount: (j['f'] as num?)?.toInt() ?? 0,
        foundSeconds: (j['s'] as num?)?.toInt() ?? 0,
      );
}

/// 기술별 연습 횟수·평균 시간 (기기에 저장).
class TechniqueStats {
  TechniqueStats._();

  static const _key = 'sudokuTechniqueStats';

  static Future<Map<String, TechniqueStat>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: TechniqueStat.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  /// 연습 한 번을 기록한다. [found]이면 정답 보기 없이 스스로 찾았다.
  static Future<void> record(String id, {required int seconds, required bool found}) async {
    final all = await load();
    final old = all[id] ?? const TechniqueStat();
    all[id] = TechniqueStat(
      count: old.count + 1,
      foundCount: old.foundCount + (found ? 1 : 0),
      foundSeconds: old.foundSeconds + (found ? seconds : 0),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}));
  }
}

/// "1분 5초", "42초" 처럼 읽기 쉬운 시간.
String spokenTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '$s초';
  return s == 0 ? '$m분' : '$m분 $s초';
}
