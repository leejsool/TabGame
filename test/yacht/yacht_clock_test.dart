import 'dart:math';

// ignore: depend_on_referenced_packages (flutter_test가 함께 가져오는 패키지)
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';

void main() {
  test('시간이 다 되면 가장 높은 점수 칸: 같으면 점수판 위쪽 칸', () {
    final card = YachtCard();
    expect(yachtTimeoutCategory(card, [6, 6, 6, 6, 3]), YachtCategory.fourKind); // 포카드 27 = 찬스 27 → 점수판 위쪽인 포카드
    expect(yachtTimeoutCategory(card, [1, 2, 3, 4, 5]), YachtCategory.largeStraight);
    card.scores[YachtCategory.largeStraight.index] = 40;
    expect(yachtTimeoutCategory(card, [1, 2, 3, 4, 5]), YachtCategory.smallStraight);
  });

  test('시간 무제한이면 시계가 없다', () {
    fakeAsync((async) {
      final c = YachtController(mode: PlayMode.local2p, players: 2, rng: Random(1));
      c.notifyListeners();
      expect(c.secondsLeft, isNull);
      async.elapse(const Duration(minutes: 5));
      expect(c.game.turn, 0);
      expect(c.game.card.filledCount, 0);
      c.dispose();
    });
  });

  test('60초가 지나면 (안 굴렸어도) 한 번 굴리고 가장 높은 점수 칸에 저절로 적고, 다음 사람의 시계가 새로 돈다', () {
    fakeAsync((async) {
      final c = YachtController(mode: PlayMode.local2p, players: 2, rng: Random(3), turnSeconds: kYachtTurnSeconds);
      c.notifyListeners(); // (화면이 뜨면 start()가 알린다)
      expect(c.secondsLeft, 60);
      async.elapse(const Duration(seconds: 59));
      expect(c.secondsLeft, 1);
      expect(c.game.turn, 0);
      async.elapse(const Duration(seconds: 1));
      expect(c.timeUp, isTrue);
      c.roll(); // 시간이 끝난 뒤에는 누를 수 없다
      async.elapse(const Duration(seconds: 3));
      expect(c.game.turn, 1);
      final written = YachtCategory.values.where((k) => c.game.cards[0].scores[k.index] != null).toList();
      expect(written, hasLength(1));
      expect(c.lastCategory, written.single);
      expect(c.secondsLeft, greaterThan(55)); // 다음 사람의 시계가 처음부터
      expect(c.timeUp, isFalse);
      c.dispose();
    });
  });

  test('굴린 뒤 시간이 다 되면 그 주사위로 가장 높은 칸에 적는다', () {
    fakeAsync((async) {
      final c = YachtController(mode: PlayMode.local2p, players: 2, rng: Random(5), turnSeconds: 60);
      c.notifyListeners();
      c.roll();
      async.elapse(const Duration(seconds: 2));
      final dice = List<int>.of(c.game.dice);
      final want = yachtTimeoutCategory(c.game.card, dice);
      async.elapse(const Duration(seconds: 60));
      expect(c.game.turn, 1);
      expect(c.game.cards[0].scores[want.index], yachtScore(want, yachtCounts(dice)));
      c.dispose();
    });
  });

  test('제한 시간은 이어하기 보관본에 남는다', () {
    final c = YachtController(mode: PlayMode.local2p, players: 2, turnSeconds: 60);
    expect(YachtController.fromJson(c.toJson())!.turnSeconds, 60);
    expect(YachtController.fromJson(YachtController(mode: PlayMode.local2p).toJson())!.turnSeconds, isNull);
  });
}
