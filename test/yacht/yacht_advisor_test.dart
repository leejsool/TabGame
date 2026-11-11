import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_dice.dart';
import 'package:tabgame/games/yacht/core/yacht_fraction.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/ui/yacht_explain_popup.dart';

/// [open] 칸만 비어 있는 점수판 (나머지는 0점으로 채움).
YachtCard cardWithOpen(List<YachtCategory> open) {
  final card = YachtCard();
  for (final c in YachtCategory.values) {
    if (!open.contains(c)) card.scores[c.index] = 0;
  }
  return card;
}

void main() {
  final t = YachtDiceTables.instance;
  final values = YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync());
  final advisor = YachtAdvisor(values);

  group('주사위 경우의 수', () {
    test('남기는 경우 462가지, 굴린 결과 252가지', () {
      expect(t.counts.length, 462);
      expect(t.rolls.length, 252);
    });

    test('어떤 주사위를 남기든 결과 확률의 합은 1', () {
      for (var k = 0; k < YachtDiceTables.keepCount; k++) {
        var sum = 0.0;
        for (var i = t.outStart[k]; i < t.outStart[k + 1]; i++) {
          sum += t.outP[i];
        }
        expect(sum, closeTo(1, 1e-12));
      }
    });

    test('한 번에 야추가 나올 확률은 6/7776', () {
      var p = 0.0;
      for (var i = t.outStart[t.empty]; i < t.outStart[t.empty + 1]; i++) {
        if (t.score[t.outTo[i] * kYachtSlots + YachtCategory.yacht.index] > 0) p += t.outP[i];
      }
      expect(p, closeTo(6 / 7776, 1e-12));
    });
  });

  test('분수: 자동으로 약분되고, 더하고 곱해도 정확하다', () {
    expect(YachtFrac(10, 36).toString(), '5/18');
    expect(YachtFrac(0, 7776), YachtFrac.zero);
    expect(YachtFrac(7776, 7776), YachtFrac.one);
    expect(YachtFrac(7776, 7776).toString(), '1');
    expect((YachtFrac(1, 36) + YachtFrac(60, 1296) + YachtFrac(25, 1296)).toString(), '121/1296');
    expect((YachtFrac(1, 6) * YachtFrac(5, 6)).toString(), '5/36');
    expect(YachtFrac(121, 1296).value, closeTo(0.09336, 1e-5));
  });

  test('에이스~식스 확률: 그 눈이 아닌 주사위만 다시 굴려 몇 개가 될지', () {
    // 하나도 없고 한 번 굴리면 5개를 굴려 각각 1/6
    final fresh = yachtUpperOdds(0, 1);
    expect(fresh[0], closeTo(pow(5 / 6, 5), 1e-12));
    expect(fresh[5], closeTo(pow(1 / 6, 5), 1e-12));
    expect(fresh.reduce((a, b) => a + b), closeTo(1, 1e-12));
    // 2개 있고 한 번 굴리면 3개를 굴린다: 늘어나지 않을 확률 125/216
    final two = yachtUpperOdds(2, 1);
    expect(two[0] + two[1], 0, reason: '이미 나온 눈은 줄지 않는다');
    expect(two[2], closeTo(125 / 216, 1e-12));
    expect(two[5], closeTo(1 / 216, 1e-12));
    // 못 굴리면 지금 그대로
    expect(yachtUpperOdds(3, 0)[3], 1);
    // 두 번 굴리면 한 번일 때보다 3개 이상 나올 확률이 높다
    double atLeast3(List<double> o) => o[3] + o[4] + o[5];
    expect(atLeast3(yachtUpperOdds(1, 2)), greaterThan(atLeast3(yachtUpperOdds(1, 1))));
    // 평균 개수 = 지금 + 굴릴 주사위마다 1/6씩 두 번 (1개 있을 때 4개 굴리고 1번 더)
    double mean(List<double> o) => [for (var k = 0; k <= 5; k++) o[k] * k].reduce((a, b) => a + b);
    expect(mean(yachtUpperOdds(1, 1)), closeTo(1 + 4 / 6, 1e-12));
    expect(mean(yachtUpperOdds(0, 2)), closeTo(5 / 6 + (5 - 5 / 6) / 6, 1e-9));
    // 정확한 분수: 2개 있고 한 번 굴리면 늘어나지 않을 확률 125/216, 한 번에 3개가 다 나올 확률 1/216
    final exact = yachtUpperOddsFrac(2, 1);
    expect(exact[2].toString(), '125/216');
    expect(exact[5].toString(), '1/216');
    expect(exact.fold(YachtFrac.zero, (a, b) => a + b), YachtFrac.one);
    expect(yachtUpperOddsFrac(0, 2).fold(YachtFrac.zero, (a, b) => a + b), YachtFrac.one);
    expect(yachtUpperOddsFrac(1, 2)[1].toString(), '390625/1679616', reason: '두 번 다 4개를 굴려 하나도 안 늘 확률 (625/1296)의 제곱');
  });

  group('분수 설명: 경우의 수 세기', () {
    test('1 세 개 + 2, 3에서 한 번 더 굴려 포카드: 36가지 중 11가지 (11/36), 못 만드는 건 25가지', () {
      final bd = advisor.breakdown(YachtCategory.fourKind, [1, 1, 1, 2, 3], 1)!;
      expect(bd.keptValues, [1, 1, 1]);
      expect(bd.rolled, 2);
      final done = bd.groups.firstWhere((g) => g.done);
      final fail = bd.groups.firstWhere((g) => !g.done);
      expect(done.prob.toString(), '11/36');
      expect(fail.prob.toString(), '25/36');
      final yes = advisor.outcomesOf(YachtCategory.fourKind, bd, done);
      final no = advisor.outcomesOf(YachtCategory.fourKind, bd, fail);
      expect(yes.length, 11);
      expect(no.length, 25);
      expect(yes.every((t) => t.contains(1)), isTrue, reason: '1이 하나라도 나오면 포카드');
      expect(no.every((t) => !t.contains(1)), isTrue);
      expect({...yes.map((t) => t.join()), ...no.map((t) => t.join())}.length, 36, reason: '서로 겹치지 않고 36가지를 모두 덮는다');
      // 줄 글: A가 1이면 B는 1~6 (6가지), A가 2~6이면 B는 1 (1가지씩)
      expect(yachtCaseLines(yes, 2), [
        'A가 1일 때, B가 1~6 → 6가지',
        'A가 2일 때, B가 1 → 1가지',
        'A가 3일 때, B가 1 → 1가지',
        'A가 4일 때, B가 1 → 1가지',
        'A가 5일 때, B가 1 → 1가지',
        'A가 6일 때, B가 1 → 1가지',
      ]);
    });

    test('묶음마다 세어 낸 경우의 수가 곧 분자다 (모든 모양 칸 · 여러 주사위)', () {
      for (final cat in YachtCategory.values.where((c) => c.isPattern)) {
        for (final dice in [
          [1, 2, 3, 4, 6],
          [2, 2, 5, 5, 6],
          [6, 6, 6, 6, 1],
          [1, 1, 2, 5, 6],
        ]) {
          for (final left in [1, 2]) {
            final bd = advisor.breakdown(cat, dice, left)!;
            var total = 1;
            for (var i = 0; i < bd.rolled; i++) {
              total *= 6;
            }
            for (final g in bd.groups) {
              final n = advisor.outcomesOf(cat, bd, g).length;
              expect(YachtFrac(n, total), g.prob, reason: '${cat.label} $dice $left번');
            }
          }
        }
      }
    });
  });

  group('모양 확률의 풀이', () {
    test('3 세 개를 고정하고 2번 더 굴려 야추: 1/36 + 5/108 + 25/1296 = 121/1296', () {
      final bd = advisor.breakdown(YachtCategory.yacht, [3, 1, 3, 6, 3], 2)!;
      expect(bd.keep, [0, 0, 3, 0, 0, 0]);
      expect(bd.rolled, 2);
      expect(bd.total.toString(), '121/1296');
      final done = bd.groups.where((g) => g.done).single;
      expect(done.prob.toString(), '1/36');
      expect(done.next, YachtFrac.one);
      final later = bd.later;
      // 하나만 3 (10/36 = 5/18) → 다음에 1/6 / 둘 다 아님 (25/36) → 다음에 1/36
      expect([for (final g in later) '${g.prob} x ${g.next} = ${g.gain}'], ['5/18 x 1/6 = 5/108', '25/36 x 1/36 = 25/1296']);
      // 묶음의 확률을 다 더하면 1
      expect(bd.groups.fold(YachtFrac.zero, (a, g) => a + g.prob), YachtFrac.one);
    });

    test('풀이의 합계는 힌트가 보여 주는 완성 확률과 같다 (모든 모양 칸 · 굴림 1~2번 · 여러 주사위)', () {
      final samples = [
        [1, 2, 3, 4, 6],
        [2, 2, 5, 5, 6],
        [6, 6, 6, 6, 1],
        [3, 3, 3, 4, 4],
        [1, 1, 2, 5, 6],
      ];
      for (final cat in YachtCategory.values.where((c) => c.isPattern)) {
        for (final dice in samples) {
          for (final left in [1, 2]) {
            final bd = advisor.breakdown(cat, dice, left)!;
            final chance = advisor.outlook(cat, dice, left).chance!;
            expect(bd.total.value, closeTo(chance, 1e-9), reason: '${cat.label} $dice $left번');
            expect(bd.groups.fold(YachtFrac.zero, (a, g) => a + g.prob), YachtFrac.one, reason: '${cat.label} $dice');
          }
        }
      }
    });

    test('이미 완성이면 풀이는 1 하나, 굴릴 수 없으면 풀이가 없다', () {
      final bd = advisor.breakdown(YachtCategory.yacht, [5, 5, 5, 5, 5], 2)!;
      expect(bd.rolled, 0);
      expect(bd.total, YachtFrac.one);
      expect(advisor.breakdown(YachtCategory.yacht, [5, 5, 5, 5, 5], 0), isNull);
      expect(advisor.breakdown(YachtCategory.ones, [1, 1, 1, 1, 1], 2), isNull, reason: '숫자 칸은 모양이 없다');
    });

    test('굴림이 한 번 남았으면 한 번에 완성될 확률 하나뿐이다 (포카드 4개에서 1/6 + ...)', () {
      final bd = advisor.breakdown(YachtCategory.yacht, [1, 1, 1, 1, 2], 1)!;
      expect(bd.total.toString(), '1/6');
      expect(bd.later, isEmpty);
    });
  });

  group('족보 확률', () {
    test('3번 안에 야추가 나올 확률은 약 4.60%', () {
      expect(advisor.chanceFromStart(YachtCategory.yacht), closeTo(0.046029, 1e-6));
    });

    test('같은 눈 4개에서 한 번 더 굴리면 야추 확률 1/6', () {
      final o = advisor.outlook(YachtCategory.yacht, [1, 1, 1, 1, 2], 1);
      expect(o.chance, closeTo(1 / 6, 1e-12));
      expect(o.keep, [4, 0, 0, 0, 0, 0]);
    });

    test('같은 눈 3개에서 두 번 굴리면 야추 확률 121/1296', () {
      final o = advisor.outlook(YachtCategory.yacht, [1, 1, 1, 2, 3], 2);
      expect(o.chance, closeTo(121 / 1296, 1e-12));
      expect(o.keep, [3, 0, 0, 0, 0, 0]);
    });

    test('1-2-3-4에서 한 번 굴리면 라지 스트레이트 확률 1/6, 2-3-4-5면 1/3', () {
      expect(advisor.outlook(YachtCategory.largeStraight, [1, 2, 3, 4, 4], 1).chance,
          closeTo(1 / 6, 1e-12));
      expect(advisor.outlook(YachtCategory.largeStraight, [2, 3, 4, 5, 5], 1).chance,
          closeTo(1 / 3, 1e-12));
    });

    test('투페어에서 한 번 굴리면 풀하우스 확률 1/3', () {
      expect(advisor.outlook(YachtCategory.fullHouse, [2, 2, 5, 5, 6], 1).chance,
          closeTo(1 / 3, 1e-12));
    });

    test('더 못 굴리면 확률은 0 아니면 1', () {
      expect(advisor.outlook(YachtCategory.fullHouse, [2, 2, 5, 5, 5], 0).chance, 1);
      expect(advisor.outlook(YachtCategory.fullHouse, [2, 2, 5, 5, 6], 0).chance, 0);
    });

    test('모양이 없는 칸은 확률 대신 점수의 평균만', () {
      final o = advisor.outlook(YachtCategory.sixes, [6, 6, 1, 2, 3], 1);
      expect(o.chance, isNull);
      expect(o.expected, closeTo(12 + 3 * 6 / 6, 1e-12)); // 3개를 굴려 평균 0.5개씩 6
      expect(o.keep, [0, 0, 0, 0, 0, 2]);
      expect(advisor.expectedFromStart(YachtCategory.choice), greaterThan(17.5));
    });
  });

  group('기대 점수 표', () {
    test('저장된 표는 끝판(빈 칸 2개 이하)을 새로 계산한 값과 같다', () {
      final fresh = buildYachtValues(minFilled: 11);
      for (var mask = 0; mask < 1 << kYachtSlots; mask++) {
        var filled = 0;
        for (var i = 0; i < kYachtSlots; i++) {
          filled += (mask >> i) & 1;
        }
        if (filled < 11) continue;
        for (var u = 0; u < 64; u++) {
          expect(values.at(mask, u), closeTo(fresh[mask * 64 + u], 0.006),
              reason: 'mask $mask, upper $u');
        }
      }
    });

    test('야추 칸만 남았으면 기대 점수 = 50 x 야추 확률', () {
      final mask = cardWithOpen([YachtCategory.yacht]).filledMask;
      expect(values.at(mask, 0), closeTo(50 * 0.046029, 0.006));
    });

    test('처음부터 가장 좋게 하면 평균 약 218.9점 (쓰리카드 없이)', () {
      // 쓰리카드를 안 쓰는 판은 12번 비트가 처음부터 켜진 상태
      expect(values.at(YachtCard().filledMask, 0), closeTo(218.87, 0.05));
    });

    test('쓰리카드 칸이 있으면 칸이 하나 더 있는 만큼 평균 점수가 높다', () {
      expect(values.at(YachtCard(threeKind: true).filledMask, 0), greaterThan(values.at(YachtCard().filledMask, 0) + 10));
    });

    test('쓰리카드 칸만 남았으면 바로 적고, 굴림이 남으면 같은 눈을 남긴다', () {
      final card = YachtCard(threeKind: true);
      for (final c in YachtCategory.values) {
        if (c != YachtCategory.threeKind) card.scores[c.index] = 0;
      }
      final now = advisor.advise(card: card, dice: [4, 4, 4, 1, 6], rerollsLeft: 0);
      expect(now.bestCategory, YachtCategory.threeKind);
      expect(now.stopValue, 19);
      expect(advisor.outlook(YachtCategory.threeKind, [4, 4, 1, 2, 6], 1).chance, isNotNull);
    });

    test('전체를 새로 계산해도 저장된 표와 같다', () {
      final fresh = buildYachtValues();
      for (var i = 0; i < YachtValues.length; i++) {
        expect(values.at(i ~/ 64, i % 64), closeTo(fresh[i], 0.006));
      }
    }, tags: 'slow');
  });

  group('추천', () {
    test('야추가 나왔고 야추 칸이 비었으면 바로 적는다', () {
      final a = advisor.advise(card: YachtCard(), dice: [4, 4, 4, 4, 4], rerollsLeft: 2);
      expect(a.shouldRoll, isFalse);
      expect(a.bestCategory, YachtCategory.yacht);
      expect(a.scoreNow[YachtCategory.yacht.index], 50);
    });

    test('야추 칸만 남았으면 같은 눈을 남기고 굴린다', () {
      final card = cardWithOpen([YachtCategory.yacht]);
      final a = advisor.advise(card: card, dice: [1, 3, 3, 3, 6], rerollsLeft: 2);
      expect(a.shouldRoll, isTrue);
      expect(a.keep, [0, 0, 3, 0, 0, 0]);
      expect(a.rollValue, closeTo(50 * 121 / 1296, 1e-9));
      expect(a.stopValue, 0);
      expect(a.valueNow.where((v) => v != null).length, 1);
    });

    test('더 못 굴리면 가장 좋은 칸만 알려 준다', () {
      final card = cardWithOpen([YachtCategory.choice, YachtCategory.ones]);
      final a = advisor.advise(card: card, dice: [6, 6, 5, 5, 6], rerollsLeft: 0);
      expect(a.shouldRoll, isFalse);
      expect(a.keep, isNull);
      expect(a.bestCategory, YachtCategory.choice);
    });

    test('보너스가 걸려 있으면 그 값을 계산에 넣는다', () {
      // 6 칸만 남았고 지금까지 1~5 칸 합이 45 → 6이 3개 이상이면 보너스 35점.
      final card = cardWithOpen([YachtCategory.sixes]);
      card.scores
        ..[0] = 3
        ..[1] = 6
        ..[2] = 9
        ..[3] = 12
        ..[4] = 15;
      final a = advisor.advise(card: card, dice: [6, 6, 6, 1, 2], rerollsLeft: 0);
      expect(a.stopValue, 18 + 35);
      final b = advisor.advise(card: card, dice: [6, 6, 3, 1, 2], rerollsLeft: 0);
      expect(b.stopValue, 12);
    });
  });

  test('남길 주사위 고르기: 지금 잡고 있는 주사위를 먼저 쓴다', () {
    expect(yachtHoldsFor([3, 1, 3, 3, 6], [0, 0, 2, 0, 0, 0]), [true, false, true, false, false]);
    expect(
      yachtHoldsFor([3, 1, 3, 3, 6], [0, 0, 2, 0, 0, 0],
          prefer: [false, false, false, true, false]),
      [true, false, false, true, false],
    );
  });
}
