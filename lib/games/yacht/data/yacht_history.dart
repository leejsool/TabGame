import '../../../core/json_history.dart';
import '../core/yacht_cpu.dart';

/// 끝난 야추 한 판의 결과.
class YachtRecord {
  const YachtRecord({required this.at, required this.vsCpu, required this.scores, this.level});

  final int at;

  /// CPU와 한 판인가 (그러면 0번 자리가 나다).
  final bool vsCpu;

  /// 자리별 최종 점수.
  final List<int> scores;

  /// CPU 대결일 때의 난이도.
  final YachtLevel? level;

  int get players => scores.length;
  int get best => scores.reduce((a, b) => a > b ? a : b);

  /// 가장 높은 점수를 받은 자리(들).
  List<int> get winners => [
        for (var i = 0; i < scores.length; i++)
          if (scores[i] == best) i,
      ];

  /// CPU 대결에서 내가 이겼는가 (공동 1등이면 null = 무승부).
  bool? get humanWon => !winners.contains(0) ? false : (winners.length == 1 ? true : null);

  Map<String, dynamic> toJson() => {'at': at, 'cpu': vsCpu, 's': scores, 'lv': level?.name};

  static YachtRecord fromJson(Map<String, dynamic> j) => YachtRecord(
        at: j['at'] as int,
        vsCpu: j['cpu'] as bool,
        scores: (j['s'] as List).cast<int>(),
        level: j['lv'] == null ? null : YachtLevel.values.byName(j['lv'] as String),
      );
}

class YachtHistory {
  YachtHistory._();

  static const maxEntries = 200;

  static const _store = JsonHistoryStore<YachtRecord>(
    key: 'yacht.history',
    fromJson: YachtRecord.fromJson,
    toJson: _toJson,
    maxEntries: maxEntries,
  );

  static Map<String, dynamic> _toJson(YachtRecord r) => r.toJson();

  /// 최신 순.
  static Future<List<YachtRecord>> load() => _store.load();

  static Future<void> add(YachtRecord r) => _store.add(r);
}
