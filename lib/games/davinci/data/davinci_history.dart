import '../../../core/json_history.dart';

import '../core/davinci_ai.dart';

/// 끝난 다빈치 코드 한 판의 결과.
class DvRecord {
  const DvRecord({
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

  /// 이긴 자리.
  final int winner;

  /// 이 기기에서 내가 앉았던 자리.
  final int human;
  final int turns;

  /// CPU 대결일 때의 난이도.
  final DvLevel? level;

  /// 기권으로 끝난 판인가.
  final bool resigned;

  bool get humanWon => winner == human;

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

  static DvRecord fromJson(Map<String, dynamic> j) => DvRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        players: j['p'] as int,
        winner: j['w'] as int,
        human: j['h'] as int,
        turns: j['t'] as int,
        level: j['lv'] == null ? null : DvLevel.values.byName(j['lv'] as String),
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class DvHistory {
  DvHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<DvRecord>(
    key: 'davinci.history',
    fromJson: DvRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(DvRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<DvRecord>> load() => _store.load();

  static Future<void> add(DvRecord r) => _store.add(r);
}
