import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

void main() {
  /// [dice]를 굴린 것으로 하고 [cat]에 적어, 그때 나온 알림들을 돌려준다.
  List<String> scoreWith(YachtController c, List<int> dice, YachtCategory cat) {
    final kinds = <String>[];
    c.onFeedback = (k) {
      if (k != 'hold') kinds.add(k); // (칸을 고르는 소리는 빼고)
    };
    c.game.applyRoll(dice);
    c.choose(cat);
    c.confirm();
    c.onFeedback = null;
    return kinds;
  }

  test('야추 칸에 50점을 적으면 "yahtzee"(짜잔) 알림, 보통 점수는 "score", 0점은 "zero"', () {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(1));
    expect(scoreWith(c, [2, 2, 2, 2, 2], YachtCategory.yacht), ['yahtzee']);
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.choice), ['score']);
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.fours), ['score']);
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.yacht), ['zero'], reason: '다른 사람이 야추 칸에 0점을 적는 건 성공이 아니다');
  });

  test('야추 칸에 50점을 적은 뒤 또 야추를 굴려 적으면 (보너스 100점) 다시 "yahtzee" 알림', () {
    final c = YachtController(mode: PlayMode.local2p, players: 1 + 1, advisor: advisor, rng: Random(1));
    expect(scoreWith(c, [3, 3, 3, 3, 3], YachtCategory.yacht), ['yahtzee']); // 0번 자리
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.ones), ['score']); // 1번 자리
    expect(scoreWith(c, [5, 5, 5, 5, 5], YachtCategory.fives), ['yahtzee']); // 0번 자리: 보너스
    expect(c.game.cards[0].yahtzeeBonuses, 1);
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.twos), ['score']);
    expect(scoreWith(c, [1, 2, 3, 4, 6], YachtCategory.sixes), ['score'], reason: '야추가 아니면 보너스도 없다');
  });
}
