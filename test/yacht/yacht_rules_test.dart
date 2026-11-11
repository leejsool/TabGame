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

  test('초이스는 모든 눈의 합', () {
    expect(score(YachtCategory.choice, [1, 2, 3, 5, 6]), 17);
  });

  test('포카드: 같은 눈 4개 이상이면 5개의 합', () {
    expect(score(YachtCategory.fourKind, [5, 5, 5, 5, 2]), 22);
    expect(score(YachtCategory.fourKind, [5, 5, 5, 5, 5]), 25);
    expect(score(YachtCategory.fourKind, [5, 5, 5, 2, 2]), 0);
  });

  test('풀하우스: 3개 + 2개만 (같은 눈 5개는 아님)', () {
    expect(score(YachtCategory.fullHouse, [3, 3, 3, 6, 6]), 21);
    expect(score(YachtCategory.fullHouse, [3, 3, 3, 3, 6]), 0);
    expect(score(YachtCategory.fullHouse, [4, 4, 4, 4, 4]), 0);
  });

  test('스트레이트', () {
    expect(score(YachtCategory.smallStraight, [1, 2, 3, 4, 6]), 15);
    expect(score(YachtCategory.smallStraight, [3, 4, 5, 6, 6]), 15);
    expect(score(YachtCategory.smallStraight, [2, 3, 4, 5, 6]), 15);
    expect(score(YachtCategory.smallStraight, [1, 2, 3, 5, 6]), 0);
    expect(score(YachtCategory.largeStraight, [1, 2, 3, 4, 5]), 30);
    expect(score(YachtCategory.largeStraight, [2, 3, 4, 5, 6]), 30);
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
      for (final c in YachtCategory.values) {
        for (var p = 0; p < 3; p++) {
          expect(game.turn, p);
          expect(game.round, c.index + 1);
          game.applyRoll(p == 1 ? [6, 6, 6, 6, 6] : [1, 1, 2, 3, 4]);
          game.score(c);
        }
      }
      expect(game.over, isTrue);
      expect(game.canRoll, isFalse);
      expect(game.winners, [1]);
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
