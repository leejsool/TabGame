// 간단한 봇으로 한 판을 돌려서 난이도(초당 점수, 공 놓치는 횟수)를 가늠하는 도구. 평소에는 느슨한 확인만 한다.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/pinball/core/pinball_run.dart';

/// 공이 플리퍼 높이에 오면 가까운 쪽 플리퍼를 올리는 반응형 봇.
void botFrame(PinballRun r) {
  var left = false, right = false;
  for (final b in r.engine.balls) {
    if (b.waiting) continue;
    if (b.y > 1110 && b.y < 1300 && b.vy > -150) {
      if (b.x < 308) {
        left = true;
      } else {
        right = true;
      }
    }
  }
  r.setFlipper(true, left);
  r.setFlipper(false, right);
  if (r.engine.hasWaitingBall) r.launch(0.9);
}

({int round, int score, int drains, int bestCombo, double secs}) play(int seed, {bool pick = true}) {
  final r = PinballRun(seed: seed);
  var drains = 0;
  r.onFeedback = (k) {
    if (k == 'drain') drains++;
  };
  var t = 0.0;
  while (r.phase != RunPhase.over && t < 600) {
    if (r.phase == RunPhase.choosing) {
      // 가장 비싼 걸 살 수 있으면 사고, 공짜는 첫 번째
      if (pick) {
        for (var i = 0; i < r.paidOffers.length; i++) {
          if (r.canBuy(r.paidOffers[i]) && r.score - r.paidOffers[i].price > PinballRun.gainFor(r.round) * 0.2) r.buy(i);
        }
      }
      if (r.freeOffers.isEmpty) {
        r.continueWithoutPick();
      } else {
        r.pickFree(0);
      }
    }
    botFrame(r);
    r.update(1 / 60);
    t += 1 / 60;
  }
  return (round: r.round, score: r.score, drains: drains, bestCombo: r.bestCombo, secs: t);
}

void main() {
  test('봇 시뮬레이션 (난이도 가늠)', () {
    final rounds = <int>[];
    for (var s = 1; s <= 8; s++) {
      final res = play(s);
      // ignore: avoid_print
      print('seed $s: 라운드 ${res.round}, 점수 ${res.score}, 놓침 ${res.drains}, 최고콤보 ${res.bestCombo}, ${res.secs.toStringAsFixed(0)}초');
      rounds.add(res.round);
    }
    // ignore: avoid_print
    print('평균 라운드 ${(rounds.reduce((a, b) => a + b) / rounds.length).toStringAsFixed(1)} / 최대 ${rounds.reduce(max)}');
    expect(rounds.every((r) => r >= 1), isTrue);
  });
}
