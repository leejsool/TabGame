import '../../../core/json_history.dart';

/// 핀볼 도전 한 번(끝날 때까지)의 기록.
class PinballRecord {
  const PinballRecord({required this.round, required this.score, required this.bestCombo, required this.upgrades, required this.names, required this.at});

  /// 끝난 라운드 (여기서 시간이 다 됐다 = 이 라운드 직전까지 깼다).
  final int round;
  final int score;
  final int bestCombo;
  final int upgrades;

  /// 고른 업그레이드 이름들 (기록에서 보여 준다).
  final List<String> names;
  final DateTime at;

  Map<String, dynamic> toJson() => {'round': round, 'score': score, 'combo': bestCombo, 'up': upgrades, 'names': names, 'at': at.millisecondsSinceEpoch};

  factory PinballRecord.fromJson(Map<String, dynamic> j) => PinballRecord(
        round: j['round'] as int,
        score: j['score'] as int,
        bestCombo: j['combo'] as int? ?? 0,
        upgrades: j['up'] as int? ?? 0,
        names: [for (final n in (j['names'] as List? ?? const [])) n as String],
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );
}

class PinballHistory {
  PinballHistory._();

  static final JsonHistoryStore<PinballRecord> _store = JsonHistoryStore<PinballRecord>(
    key: 'pinball.history',
    fromJson: PinballRecord.fromJson,
    toJson: (r) => r.toJson(),
  );

  static Future<List<PinballRecord>> load() => _store.load();

  static Future<void> add(PinballRecord r) => _store.add(r);
}
