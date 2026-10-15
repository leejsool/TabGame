import '../../../core/json_history.dart';

import '../core/sprouts_ai.dart';

/// 끝난 콩나물 한 판의 결과.
class SproutsRecord {
  const SproutsRecord({
    required this.at,
    required this.vsCpu,
    required this.winner,
    required this.moves,
    required this.dots,
    this.level,
    this.human,
    this.resigned = false,
  });

  final int at;
  final bool vsCpu;

  /// 이긴 플레이어 (0 = 먼저 시작한 쪽, 1 = 나중).
  final int winner;
  final int moves;

  /// 처음 점의 수.
  final int dots;

  /// CPU 대결일 때: 난이도와 내가 맡은 쪽 (0 = 먼저).
  final SproutsLevel? level;
  final int? human;

  /// 진 쪽이 기권해서 끝난 판인가.
  final bool resigned;

  /// CPU 대결에서 내가 이겼는가 (CPU 대결이 아니면 null).
  bool? get humanWon => vsCpu ? winner == human : null;

  Map<String, dynamic> toJson() => {
        'at': at,
        'cpu': vsCpu,
        'w': winner,
        'm': moves,
        'n': dots,
        'lv': level?.name,
        'h': human,
        if (resigned) 'rs': 1,
      };

  static SproutsRecord fromJson(Map<String, dynamic> j) => SproutsRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        winner: j['w'] as int,
        moves: j['m'] as int,
        dots: j['n'] as int,
        level: j['lv'] == null ? null : SproutsLevel.values.byName(j['lv'] as String),
        human: j['h'] as int?,
        resigned: j['rs'] == 1,
      );
}

class SproutsHistory {
  SproutsHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<SproutsRecord>(
    key: 'sprouts.history',
    fromJson: SproutsRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(SproutsRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<SproutsRecord>> load() => _store.load();

  static Future<void> add(SproutsRecord r) => _store.add(r);
}
