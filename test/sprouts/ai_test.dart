import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_ai.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';

void main() {
  test('어려움 CPU는 이른 판에 제자리 고리만 긋지 않는다 (고리 안을 막는 같은 수로 늘 지던 문제)', () {
    // 2026-10-18 제보: 어려움 CPU가 먼저 두면 늘 목숨 3인 점에서 제자리 고리를 그었고, 사람이 고리 안을 막는 수로 받으면 반드시 졌다.
    for (final n in [4, 5, 6]) {
      for (final seed in [1, 2, 3]) {
        final b = SproutsBoard.initial(n, Random(seed));
        final m = chooseMove(b, SproutsLevel.hard, Random(seed));
        expect(m, isNotNull);
        expect(m!.s == m.e, isFalse, reason: '점 $n개 seed=$seed 첫 수가 제자리 고리예요');
      }
    }
  });

  test('어려움 CPU는 늘 같은 수만 두지 않는다 (같은 방법으로 계속 이길 수 없게)', () {
    final b = SproutsBoard.initial(6, Random(7));
    final picks = <String>{};
    for (var seed = 0; seed < 6; seed++) {
      final m = chooseMove(b, SproutsLevel.hard, Random(seed))!;
      picks.add('${m.s}-${m.e}');
    }
    expect(picks.length, greaterThan(1));
  });
}
