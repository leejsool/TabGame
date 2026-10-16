import '../../../core/json_history.dart';

import '../core/rummikub_ai.dart';

/// 끝난 루미큐브 한 판의 결과.
class RkRecord {
  const RkRecord({
    required this.at,
    required this.vsCpu,
    required this.players,
    required this.winner,
    required this.human,
    required this.turns,
    this.level,
    this.resigned = false,
    this.online = false,
  });

  final int at;

  /// CPU와 한 판인가 (아니면 같은 Wi‑Fi의 사람과 한 판).
  final bool vsCpu;
  final bool online;

  /// 판에 앉은 사람 수 (CPU 포함).
  final int players;

  /// 이긴 자리 (null이면 무승부).
  final int? winner;

  /// 이 기기에서 내가 앉았던 자리.
  final int human;
  final int turns;

  /// CPU 대결일 때의 난이도.
  final RkLevel? level;

  /// 내가 기권했거나 상대가 기권해서 끝난 판인가.
  final bool resigned;

  /// 내가 이겼는가 (무승부면 null).
  bool? get humanWon => winner == null ? null : winner == human;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'p': players,
        'w': winner,
        'h': human,
        't': turns,
        'lv': level?.name,
        if (resigned) 'rs': 1,
        if (online) 'net': 1,
      };

  static RkRecord fromJson(Map<String, dynamic> j) => RkRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        players: j['p'] as int,
        winner: j['w'] as int?,
        human: j['h'] as int,
        turns: j['t'] as int,
        level: j['lv'] == null ? null : RkLevel.values.byName(j['lv'] as String),
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class RkHistory {
  RkHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<RkRecord>(
    key: 'rummikub.history',
    fromJson: RkRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(RkRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<RkRecord>> load() => _store.load();

  static Future<void> add(RkRecord r) => _store.add(r);
}
