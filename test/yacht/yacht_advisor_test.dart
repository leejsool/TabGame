import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_dice.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';

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
        if (t.score[t.outTo[i] * 12 + YachtCategory.yacht.index] > 0) p += t.outP[i];
      }
      expect(p, closeTo(6 / 7776, 1e-12));
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
      final fresh = buildYachtValues(minFilled: 10);
      for (var mask = 0; mask < 4096; mask++) {
        var filled = 0;
        for (var i = 0; i < 12; i++) {
          filled += (mask >> i) & 1;
        }
        if (filled < 10) continue;
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

    test('처음부터 가장 좋게 하면 평균 약 191.8점', () {
      expect(values.at(0, 0), closeTo(191.77, 0.05));
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
