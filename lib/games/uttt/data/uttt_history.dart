import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';

/// 끝난 얼티밋 틱택토 한 판의 결과.
class UtttRecord {
  const UtttRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    this.level,
    this.human,
  });

  final int at;
  final bool vsCpu;

  /// 이긴 쪽 (kX / kO). null이면 무승부.
  final int? winner;
  final int moves;

  /// CPU 대결일 때: 난이도와 내가 맡은 쪽.
  final UttLevel? level;
  final int? human;

  bool get isDraw => winner == null;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu && winner != null ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner,
        'm': moves,
        'lv': level?.name,
        'h': human,
      };

  static UtttRecord fromJson(Map<String, dynamic> j) => UtttRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: j['w'] as int?,
        moves: j['m'] as int,
        level: j['lv'] == null ? null : UttLevel.values.byName(j['lv'] as String),
        human: j['h'] as int?,
      );
}

class UtttHistory {
  UtttHistory._();

  static const _key = 'uttt.history';
  static const maxEntries = 200;

  /// 최신 순.
  static Future<List<UtttRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) UtttRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> add(UtttRecord r) async {
    final list = await load();
    list.insert(0, r);
    if (list.length > maxEntries) list.removeRange(maxEntries, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
  }
}

/// 결과를 사람이 읽는 이름으로.
String sideLabel(int side) => side == kX ? 'X' : 'O';
