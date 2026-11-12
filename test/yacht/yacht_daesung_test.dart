import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/core/yacht_cpu.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_dice.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_values.dart';
import 'package:tabgame/games/yacht/core/yacht_game.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';

void main() {
  // 주사위 눈 목록의 0번이 대성One (1이면 로고 = 만능)
  int s(YachtCategory c, List<int> dice) => daesungScore(c, dice);

  group('대성One Rule 점수', () {
    test('원즈: 1의 합, 1 네 개 + 대성One이면 70점', () {
      expect(s(YachtCategory.ones, [3, 1, 1, 2, 5]), 2);
      expect(s(YachtCategory.ones, [1, 1, 1, 2, 5]), 3, reason: '로고는 1로 쳐서 하나 더');
      expect(s(YachtCategory.ones, [1, 1, 1, 1, 1]), kDaesungOnes);
      expect(s(YachtCategory.ones, [4, 1, 1, 1, 1]), 4, reason: '대성One이 로고가 아니면 70이 아니다');
    });

    test('숫자 칸 · 찬스에서 로고는 가장 좋은 눈', () {
      expect(s(YachtCategory.sixes, [1, 6, 6, 2, 3]), 18);
      expect(s(YachtCategory.choice, [1, 2, 3, 4, 5]), 20, reason: '로고 = 6');
      expect(s(YachtCategory.choice, [5, 2, 3, 4, 5]), 19);
    });

    test('풀하우스는 눈 5개의 합, 라지 스트레이트 30, 야추 50 (로고로 채울 수 있다)', () {
      expect(s(YachtCategory.fullHouse, [3, 3, 3, 5, 5]), 19);
      expect(s(YachtCategory.fullHouse, [1, 6, 6, 5, 5]), 28, reason: '로고 = 6 → 6 6 6 5 5');
      expect(s(YachtCategory.fullHouse, [2, 2, 2, 2, 5]), 0);
      expect(s(YachtCategory.largeStraight, [1, 2, 3, 4, 5]), 30, reason: '로고 = 1 또는 6');
      expect(s(YachtCategory.largeStraight, [1, 3, 4, 5, 6]), 30, reason: '로고 = 2');
      expect(s(YachtCategory.largeStraight, [1, 2, 4, 5, 6]), 30);
      expect(s(YachtCategory.largeStraight, [2, 2, 4, 5, 6]), 0);
      expect(s(YachtCategory.yacht, [1, 4, 4, 4, 4]), 50);
      expect(s(YachtCategory.yacht, [4, 4, 4, 4, 4]), 50);
      expect(s(YachtCategory.yacht, [3, 4, 4, 4, 4]), 0);
      expect(s(YachtCategory.fourKind, [4, 4, 4, 4, 4]), 0, reason: '포카드 칸은 없다');
    });

    test('점수판: 10칸, 보너스 55점 → +40, 야추 보너스 없음, 이름 "원즈"', () {
      final card = YachtCard(daesung: true, threeKind: true);
      expect(card.threeKind, isFalse);
      expect(card.categories, hasLength(10));
      expect(card.categories, isNot(contains(YachtCategory.fourKind)));
      expect(card.categories, isNot(contains(YachtCategory.smallStraight)));
      expect(card.labelOf(YachtCategory.ones), '원즈');
      card.scores[YachtCategory.sixes.index] = 30;
      card.scores[YachtCategory.fives.index] = 20;
      expect(card.bonus, 0);
      card.scores[YachtCategory.fours.index] = 8;
      expect(card.bonus, kDaesungBonus);
      card.yahtzeeBonuses = 2;
      expect(card.yahtzeeBonusTotal, 0);
    });

    test('판: 야추를 또 굴려도 +100이 없고, 보관했다가 되살려도 대성One Rule이다', () {
      final g = YachtGame(playerCount: 2, daesung: true);
      g.applyRoll([1, 3, 3, 3, 3]);
      g.score(YachtCategory.yacht);
      expect(g.cards[0].scores[YachtCategory.yacht.index], 50);
      final back = YachtGame.fromJson(g.toJson());
      expect(back.daesung, isTrue);
      expect(back.cards[0].daesung, isTrue);
      expect(back.rounds, 10);
    });
  });

  group('대성One Rule 확률', () {
    final t = YachtDaesungTables.instance;

    test('경우의 수: 굴린 결과 126 x 6 = 756가지, 어떤 걸 남겨도 확률의 합은 1', () {
      expect(t.rolls, hasLength(756));
      for (var k = 0; k < t.keeps; k++) {
        var p = 0.0;
        for (var i = t.outStart[k]; i < t.outStart[k + 1]; i++) {
          p += t.outP[i];
        }
        if (t.outStart[k + 1] > t.outStart[k]) expect(p, closeTo(1, 1e-9), reason: '남긴 것 $k');
      }
    });

    final advisor = YachtDaesungAdvisor(YachtDaesungValues.fromBytes(File('assets/yacht/values_ds.bin').readAsBytesSync()));

    test('만능 주사위 덕분에 야추가 기본 규칙(4.6%)보다 잘 나온다', () {
      final p = advisor.chanceFromStart(YachtCategory.yacht);
      expect(p, greaterThan(0.06));
      expect(p, lessThan(0.2));
    });

    test('남길 주사위 → 잡을 주사위: 대성One은 0번 자리', () {
      final card = YachtCard(daesung: true);
      final a = advisor.advise(card: card, dice: [1, 6, 6, 2, 3], rerollsLeft: 2);
      final holds = advisor.holdsFor([1, 6, 6, 2, 3], a.keep ?? [0, 0, 0, 0, 0, 0, 1]);
      expect(holds[0], isTrue, reason: '로고(만능)는 남긴다');
    });

    test('CPU(어려움)끼리 끝까지 두면 판이 끝나고 평균 점수가 그럴듯하다', () {
      final rng = Random(7);
      var sum = 0;
      const games = 12;
      for (var n = 0; n < games; n++) {
        final g = YachtGame(playerCount: 1, daesung: true);
        while (!g.over) {
          g.roll(rng);
          while (true) {
            final m = YachtCpu.choose(advisor, g, YachtLevel.hard, rng);
            if (m.category != null) {
              g.score(m.category!);
              break;
            }
            g.setHolds(m.holds!);
            g.roll(rng);
          }
        }
        expect(g.cards[0].filledCount, 10);
        sum += g.cards[0].total;
      }
      final avg = sum / games;
      expect(avg, greaterThan(140), reason: '평균 $avg');
      expect(avg, lessThan(260), reason: '평균 $avg');
    });
  });
}
