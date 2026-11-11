// 야추 CPU: 난이도에 따라 "다시 굴리기(남길 주사위)"나 "적을 칸"을 고른다. 화면 없이 쓰는 순수 Dart.
import 'dart:math';

import 'yacht_advisor.dart';
import 'yacht_game.dart';
import 'yacht_rules.dart';

/// CPU 난이도.
enum YachtLevel {
  easy('쉬움', '눈앞의 점수만 보고 골라요'),
  normal('보통', '계산을 하지만 가끔 눈앞의 점수에 끌려요'),
  hard('어려움', '언제나 확률을 계산해 가장 좋은 선택을 해요');

  const YachtLevel(this.label, this.description);
  final String label;
  final String description;
}

/// CPU의 결정 하나: [holds]를 잡고 다시 굴리거나, [category]에 적는다.
class YachtMove {
  const YachtMove.roll(List<bool> this.holds) : category = null;
  const YachtMove.score(YachtCategory this.category) : holds = null;

  final List<bool>? holds;
  final YachtCategory? category;
}

class YachtCpu {
  YachtCpu._();

  /// 보통 난이도가 눈앞의 점수에 끌리는 비율.
  static const double normalSlip = 0.3;

  /// 지금 차례([YachtGame.turn])의 결정. 주사위를 한 번은 굴린 뒤여야 한다.
  static YachtMove choose(YachtAdvisor advisor, YachtGame game, YachtLevel level, Random rng) {
    assert(game.rollsUsed > 0 && !game.over);
    final greedy = level == YachtLevel.easy || (level == YachtLevel.normal && rng.nextDouble() < normalSlip);
    return greedy ? _greedy(advisor, game) : _best(advisor, game);
  }

  /// 끝났을 때 점수의 평균이 가장 커지는 선택.
  static YachtMove _best(YachtAdvisor advisor, YachtGame game) {
    final a = advisor.advise(card: game.card, dice: game.dice, rerollsLeft: game.rollsLeft);
    final keep = a.keep;
    if (keep != null) return YachtMove.roll(yachtHoldsFor(game.dice, keep, prefer: game.held));
    return YachtMove.score(a.bestCategory);
  }

  /// 눈앞의 점수만 본다: 한 칸의 점수가 가장 커 보이는 쪽을 노리고, 지금 점수가 가장 큰 칸에 적는다.
  static YachtMove _greedy(YachtAdvisor advisor, YachtGame game) {
    final open = [
      for (final c in YachtCategory.values)
        if (game.card.isOpen(c)) c,
    ];
    if (game.rollsLeft > 0) {
      YachtOutlook? aim;
      for (final c in open) {
        final o = advisor.outlook(c, game.dice, game.rollsLeft);
        if (aim == null || o.expected > aim.expected) aim = o;
      }
      final kept = aim!.keep.fold(0, (a, b) => a + b);
      if (kept < kYachtDice) return YachtMove.roll(yachtHoldsFor(game.dice, aim.keep, prefer: game.held));
    }
    final counts = yachtCounts(game.dice);
    var pick = open.first;
    for (final c in open.skip(1)) {
      final s = yachtScore(c, counts), best = yachtScore(pick, counts);
      // 점수가 같으면 (0점끼리 포함) 덜 아까운 칸을 쓴다
      if (s > best || (s == best && advisor.expectedFromStart(c) < advisor.expectedFromStart(pick))) pick = c;
    }
    return YachtMove.score(pick);
  }
}
