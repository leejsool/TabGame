import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'freecell_rules.dart';

/// 프리셀 난이도. 판마다 풀이기가 "풀이를 찾기까지 얼마나 헤맸는지"로 미리 매겨 둔 점수에서 나뉜다
/// (tool/rate_freecell_deals.dart 로 만든 assets/freecell_difficulty.bin).
enum FcLevel {
  easy('쉬움', '풀이가 뚜렷해서 차근차근 하면 풀려요'),
  medium('보통', '조금 생각해야 풀리는 판이에요'),
  hard('어려움', '프리셀과 빈 열을 아껴 써야 풀려요'),
  expert('전문가', '여러 수를 내다봐야 하는 까다로운 판이에요');

  const FcLevel(this.label, this.description);

  final String label;
  final String description;
}

/// 판 번호(1~32000) → 난이도.
class FcDifficultyTable {
  /// [scores]의 (번호-1)번째 바이트가 그 판의 점수 (255 = 풀이기가 못 푼 판).
  FcDifficultyTable(this.scores) {
    assert(scores.length == kMaxDeal);
    final solved = <int>[
      for (var i = 0; i < scores.length; i++)
        if (scores[i] < 255) scores[i],
    ]..sort();
    // 풀린 판 기준으로: 아래 35% 쉬움, 35~75% 보통, 75~95% 어려움, 위 5% 전문가
    int at(double p) => solved[min(solved.length - 1, (solved.length * p).floor())];
    _easyMax = at(0.35);
    _mediumMax = at(0.75);
    _hardMax = at(0.95);
    for (var d = 1; d <= kMaxDeal; d++) {
      if (d == kUnsolvableDeal || scores[d - 1] >= 255) continue; // 못 푼 판은 무작위로 뽑지 않는다
      _byLevel[levelOf(d).index].add(d);
    }
  }

  final Uint8List scores;
  late final int _easyMax, _mediumMax, _hardMax;
  final List<List<int>> _byLevel = List.generate(FcLevel.values.length, (_) => <int>[]);

  static FcDifficultyTable? _instance;

  /// 이미 읽어 둔 표 (아직이면 null).
  static FcDifficultyTable? get instance => _instance;

  /// 앱에 들어 있는 난이도 표를 읽는다 (한 번만 읽고 재사용).
  static Future<FcDifficultyTable> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/freecell_difficulty.bin');
    return _instance = FcDifficultyTable(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  FcLevel levelOf(int deal) {
    final s = scores[deal - 1];
    if (s >= 255 || s > _hardMax) return FcLevel.expert;
    if (s > _mediumMax) return FcLevel.hard;
    if (s > _easyMax) return FcLevel.medium;
    return FcLevel.easy;
  }

  /// 이 난이도의 판 개수.
  int count(FcLevel level) => _byLevel[level.index].length;

  /// 이 난이도의 무작위 판 번호.
  int randomDeal(FcLevel level, [Random? rng]) {
    final list = _byLevel[level.index];
    return list[(rng ?? Random()).nextInt(list.length)];
  }
}
