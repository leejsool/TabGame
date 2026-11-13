import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

void main() {
  /// 0번 자리가 [dice]를 굴린 소식을 받은 기기(1번 자리)에서 나온 알림들 (굴러서 멈출 때까지).
  Future<List<String>> rollFeedback(List<int> dice, {List<int> before = const [], bool daesung = false}) async {
    final c = YachtController(mode: PlayMode.wifi, players: 2, humanSeat: 1, advisor: advisor, rng: Random(1), daesung: daesung);
    final kinds = <String>[];
    c.onFeedback = kinds.add;
    expect(c.receive({'t': 'roll', 'd': dice, 'i': 0}), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: kYachtRollMs + 250));
    c.onFeedback = null;
    c.dispose();
    return kinds;
  }

  test('주사위 5개가 모두 같은 눈으로 멈추면 "yahtzee"(짜잔) 알림, 아니면 "land"', () async {
    expect(await rollFeedback([3, 3, 3, 3, 3]), ['roll', 'yahtzee']);
    expect(await rollFeedback([6, 6, 6, 6, 6]), ['roll', 'yahtzee']);
    expect(await rollFeedback([3, 3, 3, 3, 4]), ['roll', 'land'], reason: '포카드는 야추가 아니다');
    expect(await rollFeedback([1, 2, 3, 4, 5]), ['roll', 'land']);
  });

  test('대성One Rule: 초록 주사위의 로고(1) + 같은 눈 4개도 야추 성공 알림', () async {
    expect(await rollFeedback([1, 2, 2, 2, 2], daesung: true), ['roll', 'yahtzee'], reason: '로고는 아무 눈이나 된다');
    expect(await rollFeedback([4, 4, 4, 4, 4], daesung: true), ['roll', 'yahtzee']);
    expect(await rollFeedback([1, 2, 2, 2, 3], daesung: true), ['roll', 'land']);
    expect(await rollFeedback([2, 1, 2, 2, 2], daesung: true), ['roll', 'land'], reason: '흰 주사위의 1은 그냥 1이다');
    expect(await rollFeedback([1, 2, 2, 2, 2]), ['roll', 'land'], reason: '보통 규칙에서는 야추가 아니다');
  });

  test('점수를 적을 때는 야추여도 짜잔 소리가 나지 않는다 (점수 · 0점 알림만)', () {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(1));
    final kinds = <String>[];
    c.onFeedback = (k) {
      if (k != 'hold') kinds.add(k);
    };
    c.game.applyRoll([2, 2, 2, 2, 2]);
    c.pick = c.game.categories.last; // 찬스에 적는다 (점수는 10점)
    c.confirm();
    expect(kinds, ['score']);
  });
}
