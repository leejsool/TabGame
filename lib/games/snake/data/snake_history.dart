import '../../../core/json_history.dart';

/// 내 뱀 한 마리(태어나서 죽을 때까지)의 기록.
class SnakeRecord {
  const SnakeRecord({
    required this.score,
    required this.bestRank,
    required this.kills,
    required this.seconds,
    required this.people,
    required this.at,
  });

  /// 죽을 때의 크기 (점수).
  final int score;

  /// 살아 있는 동안 올라간 가장 높은 순위.
  final int bestRank;

  /// 내 몸에 부딪혀 죽은 뱀 수.
  final int kills;
  final int seconds;

  /// 그때 함께 있던 사람 수 (나 포함).
  final int people;
  final DateTime at;

  Map<String, dynamic> toJson() => {'score': score, 'rank': bestRank, 'kills': kills, 'sec': seconds, 'people': people, 'at': at.millisecondsSinceEpoch};

  factory SnakeRecord.fromJson(Map<String, dynamic> j) => SnakeRecord(
        score: j['score'] as int,
        bestRank: j['rank'] as int,
        kills: j['kills'] as int,
        seconds: j['sec'] as int,
        people: j['people'] as int? ?? 1,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );
}

class SnakeHistory {
  SnakeHistory._();

  static final JsonHistoryStore<SnakeRecord> _store = JsonHistoryStore<SnakeRecord>(
    key: 'snake.history',
    fromJson: SnakeRecord.fromJson,
    toJson: (r) => r.toJson(),
  );

  static Future<List<SnakeRecord>> load() => _store.load();

  static Future<void> add(SnakeRecord r) => _store.add(r);
}
