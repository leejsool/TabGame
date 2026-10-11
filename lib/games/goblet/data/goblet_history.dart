import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';

/// 끝난 고블렛 한 판의 결과.
class GobbletRecord {
  const GobbletRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    this.level,
    this.human,
    this.byReveal = false,
  });

  final int at;
  final bool vsCpu;

  /// 이긴 팀. null이면 무승부.
  final Team? winner;
  final int moves;

  /// CPU 대결일 때: 난이도와 내 팀.
  final CpuLevel? level;
  final Team? human;

  /// 말을 들어 올리는 바람에 상대 줄이 드러나서 결정된 경우.
  final bool byReveal;

  bool get isDraw => winner == null;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu && winner != null ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner?.name,
        'm': moves,
        'lv': level?.name,
        'h': human?.name,
        'rv': byReveal,
      };

  static GobbletRecord fromJson(Map<String, dynamic> j) => GobbletRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: j['w'] == null ? null : Team.values.byName(j['w'] as String),
        moves: j['m'] as int,
        level: j['lv'] == null ? null : CpuLevel.values.byName(j['lv'] as String),
        human: j['h'] == null ? null : Team.values.byName(j['h'] as String),
        byReveal: j['rv'] as bool? ?? false,
      );
}

class GobbletHistory {
  GobbletHistory._();

  static const _key = 'goblet.history';
  static const maxEntries = 200;

  /// 최신 순.
  static Future<List<GobbletRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) GobbletRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> add(GobbletRecord r) async {
    final list = await load();
    list.insert(0, r);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}
