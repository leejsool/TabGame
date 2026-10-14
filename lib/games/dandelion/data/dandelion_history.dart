import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';

/// 끝난 민들레 한 판의 결과.
class DandelionRecord {
  const DandelionRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    required this.empties,
    this.level,
    this.human,
    this.resigned = false,
  });

  final int at;
  final bool vsCpu;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  final Role winner;

  /// 둔 수 (꽃 심기 + 바람).
  final int moves;

  /// 끝났을 때 남은 빈칸.
  final int empties;

  /// CPU 대결일 때: 난이도와 내가 맡은 쪽.
  final DandLevel? level;
  final Role? human;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner.index,
        'm': moves,
        'e': empties,
        'lv': level?.name,
        'h': human?.index,
        if (resigned) 'rs': 1,
      };

  static DandelionRecord fromJson(Map<String, dynamic> j) => DandelionRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: Role.values[j['w'] as int],
        moves: j['m'] as int,
        empties: j['e'] as int,
        level: j['lv'] == null ? null : DandLevel.values.byName(j['lv'] as String),
        human: j['h'] == null ? null : Role.values[j['h'] as int],
        resigned: j['rs'] == 1,
      );
}

class DandelionHistory {
  DandelionHistory._();

  static const _key = 'dandelion.history';
  static const maxEntries = 200;

  /// 최신 순.
  static Future<List<DandelionRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) DandelionRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> add(DandelionRecord r) async {
    final list = await load();
    list.insert(0, r);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}
