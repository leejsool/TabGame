import '../../../core/json_history.dart';

import '../core/quoridor_ai.dart';

/// 끝난 쿼리도 한 판의 결과.
class QuoridorRecord {
  const QuoridorRecord({
    required this.at,
    required this.vsCpu,
    required this.players,
    required this.winner,
    required this.moves,
    this.human,
    this.level,
    this.resigned = false,
    this.online = false,
  });

  final int at;

  /// CPU와 한 판인가.
  final bool vsCpu;

  /// 같은 Wi‑Fi의 다른 기기와 한 판인가.
  final bool online;

  /// 판에 앉은 사람 수 (2 또는 4, CPU 포함).
  final int players;

  /// 이긴 자리 (0~3).
  final int winner;
  final int moves;

  /// CPU 대결·Wi‑Fi 대결일 때 이 기기에서 내가 맡은 자리.
  final int? human;

  /// CPU 대결일 때의 난이도.
  final QLevel? level;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  /// CPU 대결·Wi‑Fi 대결에서 내가 이겼는가 (한 기기로 한 판이면 null).
  bool? get humanWon => human == null ? null : winner == human;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'p': players,
        'w': winner,
        'm': moves,
        'h': human,
        'lv': level?.name,
        if (resigned) 'rs': 1,
        if (online) 'net': 1,
      };

  static QuoridorRecord fromJson(Map<String, dynamic> j) => QuoridorRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        players: j['p'] as int,
        winner: j['w'] as int,
        moves: j['m'] as int,
        human: j['h'] as int?,
        level: j['lv'] == null ? null : QLevel.values.byName(j['lv'] as String),
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class QuoridorHistory {
  QuoridorHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<QuoridorRecord>(
    key: 'quoridor.history',
    fromJson: QuoridorRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(QuoridorRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<QuoridorRecord>> load() => _store.load();

  static Future<void> add(QuoridorRecord r) => _store.add(r);
}
