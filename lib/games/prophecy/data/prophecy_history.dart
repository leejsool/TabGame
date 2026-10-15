import '../../../core/json_history.dart';

import '../core/prophecy_ai.dart';

/// 끝난 예언 한 판의 결과.
class ProphRecord {
  const ProphRecord({
    required this.at,
    required this.vsCpu,
    required this.rows,
    required this.cols,
    required this.score0,
    required this.score1,
    required this.winner,
    required this.moves,
    this.level,
    this.human,
    this.resigned = false,
    this.online = false,
  });

  final int at;
  final bool vsCpu;
  final int rows, cols;

  /// 먼저 쓴 쪽(0)과 나중에 쓴 쪽(1)의 점수. 기권한 판은 그때까지의 점수가 아니라 0이다.
  final int score0, score1;

  /// 이긴 쪽 (0 / 1). null이면 무승부.
  final int? winner;
  final int moves;

  /// CPU 대결일 때: 난이도. CPU 대결·Wi‑Fi 대결일 때: 내가 맡은 쪽 (0 = 먼저 쓰기, 1 = 나중에 쓰기).
  final ProphLevel? level;
  final int? human;

  /// 같은 Wi‑Fi의 다른 기기와 한 판인가 ([human]은 이 기기가 맡은 쪽).
  final bool online;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  bool get isDraw => winner == null;

  /// CPU 대결에서 내가 이겼는가 (무승부면 null, CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu && winner != null ? winner == human : null;

  /// Wi‑Fi 대결에서 내가 이겼는가 (무승부면 null).
  bool? get onlineWon => online && winner != null ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'r': rows,
        'c': cols,
        's0': score0,
        's1': score1,
        'w': winner,
        'm': moves,
        'lv': level?.name,
        'h': human,
        if (resigned) 'rs': 1,
        if (online) 'net': 1,
      };

  static ProphRecord fromJson(Map<String, dynamic> j) => ProphRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        rows: j['r'] as int,
        cols: j['c'] as int,
        score0: j['s0'] as int,
        score1: j['s1'] as int,
        winner: j['w'] as int?,
        moves: j['m'] as int,
        level: j['lv'] == null ? null : ProphLevel.values.byName(j['lv'] as String),
        human: j['h'] as int?,
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class ProphHistory {
  ProphHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<ProphRecord>(
    key: 'prophecy.history',
    fromJson: ProphRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(ProphRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<ProphRecord>> load() => _store.load();

  static Future<void> add(ProphRecord r) => _store.add(r);
}
