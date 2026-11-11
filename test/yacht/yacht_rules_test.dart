import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/core/yacht_game.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';

int score(YachtCategory c, List<int> dice) => yachtScore(c, yachtCounts(dice));

void main() {
  test('1~6 칸은 그 눈의 합', () {
    expect(score(YachtCategory.ones, [1, 1, 3, 4, 1]), 3);
    expect(score(YachtCategory.sixes, [6, 6, 6, 6, 2]), 24);
    expect(score(YachtCategory.fours, [1, 2, 3, 5, 6]), 0);
  });

  test('찬스는 모든 눈의 합', () {
    expect(score(YachtCategory.choice, [1, 2, 3, 5, 6]), 17);
  });

  test('쓰리카드: 같은 눈 3개 이상이면 5개의 합', () {
    expect(score(YachtCategory.threeKind, [4, 4, 4, 1, 6]), 19);
    expect(score(YachtCategory.threeKind, [4, 4, 4, 4, 6]), 22);
    expect(score(YachtCategory.threeKind, [4, 4, 4, 4, 4]), 20);
    expect(score(YachtCategory.threeKind, [4, 4, 1, 1, 6]), 0);
  });

  test('점수판 줄 순서는 진짜 야추 점수표대로이고, 칸 번호는 그대로다', () {
    expect(YachtCategory.sheetOrder.length, kYachtSlots);
    expect(YachtCategory.sheetOrder.toSet().length, kYachtSlots);
    expect(YachtCategory.sheetOrder.sublist(6).map((c) => c.label), ['쓰리카드', '포카드', '풀하우스', '스몰 스트레이트', '라지 스트레이트', '야추', '찬스']);
    expect(YachtCategory.choice.index, 6, reason: '저장된 판 · 확률 표와 맞물리는 번호');
    expect(YachtCategory.threeKind.index, 12);
  });

  test('포카드: 같은 눈 4개 이상이면 5개의 합', () {
    expect(score(YachtCategory.fourKind, [5, 5, 5, 5, 2]), 22);
    expect(score(YachtCategory.fourKind, [5, 5, 5, 5, 5]), 25);
    expect(score(YachtCategory.fourKind, [5, 5, 5, 2, 2]), 0);
  });

  test('풀하우스: 3개 + 2개만 (같은 눈 5개는 아님) → 25점', () {
    expect(score(YachtCategory.fullHouse, [3, 3, 3, 6, 6]), 25);
    expect(score(YachtCategory.fullHouse, [1, 1, 1, 2, 2]), 25);
    expect(score(YachtCategory.fullHouse, [3, 3, 3, 3, 6]), 0);
    expect(score(YachtCategory.fullHouse, [4, 4, 4, 4, 4]), 0);
  });

  test('스트레이트: 스몰 30점, 라지 40점', () {
    expect(score(YachtCategory.smallStraight, [1, 2, 3, 4, 6]), 30);
    expect(score(YachtCategory.smallStraight, [3, 4, 5, 6, 6]), 30);
    expect(score(YachtCategory.smallStraight, [2, 3, 4, 5, 6]), 30);
    expect(score(YachtCategory.smallStraight, [1, 2, 3, 5, 6]), 0);
    expect(score(YachtCategory.largeStraight, [1, 2, 3, 4, 5]), 40);
    expect(score(YachtCategory.largeStraight, [2, 3, 4, 5, 6]), 40);
    expect(score(YachtCategory.largeStraight, [1, 2, 3, 4, 6]), 0);
  });

  test('야추: 같은 눈 5개면 50점', () {
    expect(score(YachtCategory.yacht, [2, 2, 2, 2, 2]), 50);
    expect(score(YachtCategory.yacht, [2, 2, 2, 2, 3]), 0);
  });

  test('점수판: 1~6 칸 합이 63 이상이면 보너스 35점', () {
    final card = YachtCard();
    for (var i = 0; i < 6; i++) {
      card.scores[i] = (i + 1) * 3; // 눈마다 3개씩 = 63
    }
    expect(card.upperSum, 63);
    expect(card.bonus, 35);
    expect(card.total, 98);
    card.scores[0] = 2;
    expect(card.bonus, 0);
    expect(card.total, 62);
  });

  group('야추 보너스', () {
    test('야추 칸에 50점을 적은 뒤 야추를 또 굴려 적으면 100점씩', () {
      final game = YachtGame(playerCount: 1);
      game.applyRoll([3, 3, 3, 3, 3]);
      game.score(YachtCategory.yacht);
      expect(game.card.yahtzeeBonuses, 0, reason: '처음 야추는 보너스가 아니라 50점');
      game.applyRoll([4, 4, 4, 4, 4]);
      game.score(YachtCategory.fours);
      expect(game.card.yahtzeeBonuses, 1);
      expect(game.card.scores[YachtCategory.fours.index], 20);
      game.applyRoll([6, 6, 6, 6, 6]);
      game.score(YachtCategory.choice);
      expect(game.card.yahtzeeBonuses, 2);
      expect(game.card.yahtzeeBonusTotal, 200);
      expect(game.card.total, 50 + 20 + 30 + 200);
      game.applyRoll([1, 2, 3, 4, 6]);
      game.score(YachtCategory.sixes);
      expect(game.card.yahtzeeBonuses, 2, reason: '야추가 아니면 보너스 없음');
    });

    test('야추 칸에 0점을 적었으면 보너스는 없다', () {
      final game = YachtGame(playerCount: 1);
      game.applyRoll([1, 2, 3, 4, 6]);
      game.score(YachtCategory.yacht);
      game.applyRoll([5, 5, 5, 5, 5]);
      game.score(YachtCategory.fives);
      expect(game.card.yahtzeeBonuses, 0);
      expect(game.card.total, 25);
    });

    test('저장했다가 되살려도 보너스가 그대로', () {
      final game = YachtGame(playerCount: 2);
      game.applyRoll([2, 2, 2, 2, 2]);
      game.score(YachtCategory.yacht);
      game.applyRoll([1, 2, 3, 4, 6]);
      game.score(YachtCategory.sixes);
      game.applyRoll([4, 4, 4, 4, 4]);
      game.score(YachtCategory.fours);
      final back = YachtGame.fromJson(game.toJson());
      expect(back.cards[0].yahtzeeBonuses, 1);
      expect(back.cards[0].total, game.cards[0].total);
      expect(back.toJson(), game.toJson());
    });
  });

  group('한 판 진행', () {
    test('굴리기 3번, 잡은 주사위는 그대로, 적으면 다음 사람', () {
      final game = YachtGame(playerCount: 2);
      final rng = Random(7);
      expect(game.canScore(YachtCategory.choice), isFalse, reason: '굴리기 전에는 못 적는다');
      game.roll(rng);
      final first = List<int>.of(game.dice);
      game.toggleHold(0);
      game.toggleHold(3);
      game.roll(rng);
      expect(game.dice[0], first[0]);
      expect(game.dice[3], first[3]);
      game.roll(rng);
      expect(game.canRoll, isFalse);
      expect(() => game.roll(rng), throwsStateError);
      final sum = game.dice.reduce((a, b) => a + b);
      expect(game.score(YachtCategory.choice), sum);
      expect(game.turn, 1);
      expect(game.rollsUsed, 0);
      expect(game.held.contains(true), isFalse);
      expect(game.cards[0].total, sum);
    });

    test('같은 칸에 두 번 못 적는다', () {
      final game = YachtGame(playerCount: 1);
      game.applyRoll([1, 2, 3, 4, 5]);
      game.score(YachtCategory.largeStraight);
      game.applyRoll([1, 2, 3, 4, 5]);
      expect(game.canScore(YachtCategory.largeStraight), isFalse);
      expect(() => game.score(YachtCategory.largeStraight), throwsStateError);
    });

    test('12라운드가 지나면 끝나고 최고 점수가 이긴다', () {
      final game = YachtGame(playerCount: 3);
      expect(game.rounds, 12);
      expect(game.categories.length, 12);
      expect(game.categories.contains(YachtCategory.threeKind), isFalse);
      expect(game.canScore(YachtCategory.threeKind), isFalse, reason: '옵션을 안 켜면 쓰리카드 칸은 닫혀 있다');
      var round = 0;
      for (final c in game.categories) {
        round++;
        for (var p = 0; p < 3; p++) {
          expect(game.turn, p);
          expect(game.round, round);
          game.applyRoll(p == 1 ? [6, 6, 6, 6, 6] : [1, 1, 2, 3, 4]);
          game.score(c);
        }
      }
      expect(game.over, isTrue);
      expect(game.canRoll, isFalse);
      expect(game.winners, [1]);
    });

    test('쓰리카드를 켜면 13라운드가 지나야 끝난다', () {
      final game = YachtGame(playerCount: 2, threeKind: true);
      expect(game.rounds, 13);
      expect(game.categories.length, 13);
      for (final c in game.categories) {
        expect(game.over, isFalse);
        for (var p = 0; p < 2; p++) {
          game.applyRoll(p == 0 ? [6, 6, 6, 6, 6] : [1, 1, 2, 3, 4]);
          expect(game.canScore(c), isTrue);
          game.score(c);
        }
      }
      expect(game.over, isTrue);
      expect(game.winners, [0]);
      expect(game.cards[0].scores[YachtCategory.threeKind.index], 30);
    });

    test('안 쓰는 쓰리카드 칸은 "이미 찬 칸"으로 센다 (확률 표의 규칙)', () {
      expect(YachtCard().filledMask, 1 << YachtCategory.threeKind.index);
      expect(YachtCard(threeKind: true).filledMask, 0);
      expect(YachtCard().full, isFalse);
      final card = YachtCard();
      for (final c in card.categories) {
        card.scores[c.index] = 0;
      }
      expect(card.full, isTrue);
      expect(card.filledMask, (1 << kYachtSlots) - 1);
    });

    test('쓰리카드가 없던 옛 보관본(12칸)도 읽는다', () {
      final old = {
        'cards': [
          [3, null, null, null, null, null, 17, null, null, null, null, null],
          [null, null, null, null, null, null, null, null, null, null, null, null],
        ],
        'turn': 1,
        'rolls': 0,
        'dice': [0, 0, 0, 0, 0],
        'held': [false, false, false, false, false],
      };
      final game = YachtGame.fromJson(old);
      expect(game.threeKind, isFalse);
      expect(game.cards[0].scores.length, kYachtSlots);
      expect(game.cards[0].scores[YachtCategory.choice.index], 17);
      expect(game.cards[0].filledCount, 2);
      expect(game.round, 1);
    });

    test('쓰리카드 옵션도 저장했다가 되살려도 그대로', () {
      final game = YachtGame(playerCount: 2, threeKind: true);
      game.applyRoll([2, 2, 2, 6, 6]);
      game.score(YachtCategory.threeKind);
      final back = YachtGame.fromJson(game.toJson());
      expect(back.threeKind, isTrue);
      expect(back.cards[0].scores[YachtCategory.threeKind.index], 18);
      expect(back.toJson(), game.toJson());
    });

    test('저장했다가 되살려도 그대로', () {
      final game = YachtGame(playerCount: 2);
      game.applyRoll([2, 2, 5, 6, 6]);
      game.score(YachtCategory.twos);
      game.applyRoll([1, 3, 3, 4, 6]);
      game.toggleHold(1);
      game.toggleHold(2);
      final back = YachtGame.fromJson(game.toJson());
      expect(back.toJson(), game.toJson());
      expect(back.turn, 1);
      expect(back.cards[0].scores[YachtCategory.twos.index], 4);
      expect(back.held, [false, true, true, false, false]);
    });
  });
}
