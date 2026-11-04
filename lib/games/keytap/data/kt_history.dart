import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/json_history.dart';

/// 건반 톡톡 한 판의 기록.
class KtRecord {
  const KtRecord({required this.kind, required this.song, required this.score, this.stars = 0, this.rank = 0, this.players = 1, required this.at});

  /// 'song' · 'endless' · 'race'
  final String kind;

  /// 곡 id (무한이면 빈 문자열).
  final String song;
  final int score;

  /// 곡 완주의 별 (0~3).
  final int stars;

  /// 경주의 등수 (1부터). 혼자 하기면 0.
  final int rank;
  final int players;
  final DateTime at;

  Map<String, dynamic> toJson() => {'k': kind, 's': song, 'sc': score, 'st': stars, 'r': rank, 'p': players, 'at': at.millisecondsSinceEpoch};

  factory KtRecord.fromJson(Map<String, dynamic> j) => KtRecord(
        kind: j['k'] as String,
        song: j['s'] as String? ?? '',
        score: j['sc'] as int,
        stars: j['st'] as int? ?? 0,
        rank: j['r'] as int? ?? 0,
        players: j['p'] as int? ?? 1,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );
}

/// 곡 하나(또는 무한)의 최고 기록.
class KtBest {
  const KtBest({this.stars = 0, this.score = 0});
  final int stars, score;
}

class KtHistory {
  KtHistory._();

  static final JsonHistoryStore<KtRecord> _store = JsonHistoryStore<KtRecord>(
    key: 'keytap.history',
    fromJson: KtRecord.fromJson,
    toJson: (r) => r.toJson(),
  );

  static const _bestKey = 'keytap.best';

  static Future<List<KtRecord>> load() => _store.load();

  /// 곡 id(무한은 'endless') → 최고 기록. 기록 목록이 넘쳐 옛 판이 지워져도 최고 기록은 남는다.
  static Future<Map<String, KtBest>> bests() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_bestKey) ?? '{}') as Map<String, dynamic>;
      return {
        for (final e in raw.entries)
          if (e.value is List && (e.value as List).length == 2) e.key: KtBest(stars: (e.value as List)[0] as int, score: (e.value as List)[1] as int),
      };
    } catch (_) {
      return {};
    }
  }

  /// 판을 남긴다. 혼자 하기면 최고 기록도 고친다. 새 최고 점수면 true.
  static Future<bool> add(KtRecord r) async {
    await _store.add(r);
    if (r.kind == 'race') return false;
    final key = r.kind == 'endless' ? 'endless' : r.song;
    final all = await bests();
    final old = all[key] ?? const KtBest();
    final better = r.score > old.score;
    all[key] = KtBest(stars: r.stars > old.stars ? r.stars : old.stars, score: better ? r.score : old.score);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bestKey, jsonEncode({for (final e in all.entries) e.key: [e.value.stars, e.value.score]}));
    return better && old.score > 0;
  }
}
