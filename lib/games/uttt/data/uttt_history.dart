import '../../../core/json_history.dart';

import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';

/// 끝난 궁극 틱택토 한 판의 결과.
class UtttRecord {
  const UtttRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    this.level,
    this.human,
    this.resigned = false,
    this.online = false,
  });

  final int at;
  final bool vsCpu;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  /// 이긴 쪽 (kX / kO). null이면 무승부.
  final int? winner;
  final int moves;

  /// CPU 대결일 때: 난이도. CPU 대결·Wi‑Fi 대결일 때: 내가 맡은 쪽.
  final UttLevel? level;
  final int? human;

  /// 같은 Wi‑Fi의 다른 기기와 한 판인가 ([human]은 이 기기가 맡은 쪽).
  final bool online;

  bool get isDraw => winner == null;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu && winner != null ? winner == human : null;

  /// Wi‑Fi 대결에서 내가 이겼는가 (무승부면 null).
  bool? get onlineWon => online && winner != null ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner,
        'm': moves,
        'lv': level?.name,
        'h': human,
        if (resigned) 'rs': 1,
        if (online) 'net': 1,
      };

  static UtttRecord fromJson(Map<String, dynamic> j) => UtttRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: j['w'] as int?,
        moves: j['m'] as int,
        level: j['lv'] == null ? null : UttLevel.values.byName(j['lv'] as String),
        human: j['h'] as int?,
        resigned: j['rs'] == 1,
        online: j['net'] == 1,
      );
}

class UtttHistory {
  UtttHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<UtttRecord>(
    key: 'uttt.history',
    fromJson: UtttRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(UtttRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<UtttRecord>> load() => _store.load();

  static Future<void> add(UtttRecord r) => _store.add(r);
}

/// 결과를 사람이 읽는 이름으로.
String sideLabel(int side) => side == kX ? 'X' : 'O';
