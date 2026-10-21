import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/pinball/core/pinball_engine.dart';
import 'package:tabgame/games/pinball/core/pinball_run.dart';
import 'package:tabgame/games/pinball/core/pinball_table.dart';
import 'package:tabgame/games/pinball/core/pinball_upgrades.dart';

void main() {
  group('물리', () {
    test('통로에 놓인 공은 바닥에서 가만히 기다린다', () {
      final e = PinballEngine(PinballTable.standard());
      e.spawnWaitingBall();
      e.advance(0.04);
      for (var i = 0; i < 100; i++) {
        e.advance(0.016);
      }
      final b = e.balls.single;
      expect(b.waiting, isTrue);
      expect(b.y, closeTo(kLaneFloorY - kBallR, 3));
      expect(b.x, closeTo(kLaneX, 1));
    });

    test('세게 쏘면 천장을 돌아 판 안으로 들어온다', () {
      final e = PinballEngine(PinballTable.standard());
      e.spawnWaitingBall();
      e.launch(1.0);
      var inField = false;
      for (var i = 0; i < 60 * 6 && e.balls.isNotEmpty; i++) {
        e.advance(1 / 60);
        final b = e.balls.isEmpty ? null : e.balls.first;
        if (b != null && b.x < kLaneInnerX - 30 && b.y < 900) inField = true;
        e.events.clear();
      }
      expect(inField, isTrue);
    });

    test('약하게 쏘면 천장에 못 닿고 통로로 되돌아온다', () {
      final e = PinballEngine(PinballTable.standard());
      e.spawnWaitingBall();
      e.launch(0.0);
      for (var i = 0; i < 60 * 5; i++) {
        e.advance(1 / 60);
      }
      final b = e.balls.single;
      expect(b.x, greaterThan(kLaneInnerX));
    });

    test('약하게 쏴서 돌아온 공은 다시 쏠 수 있는 공이 된다', () {
      final e = PinballEngine(PinballTable.standard());
      e.spawnWaitingBall();
      e.launch(0.0);
      for (var i = 0; i < 60 * 6; i++) {
        e.advance(1 / 60);
      }
      expect(e.hasWaitingBall, isTrue);
    });

    test('판에서 통로 쪽으로 날아온 공은 문에 막혀 통로로 못 들어간다', () {
      final e = PinballEngine(PinballTable.standard());
      e.balls.add(Ball(540, 230)
        ..waiting = false
        ..vx = 900
        ..vy = 100);
      for (var i = 0; i < 90; i++) {
        e.advance(1 / 60);
        if (e.balls.isEmpty) break;
        expect(e.balls.first.x, lessThan(kLaneInnerX), reason: '공이 문을 지나 통로로 들어갔어요');
      }
    });

    test('아무것도 안 하면 공은 결국 떨어진다 (판 밖으로 안 새고 막히지도 않는다)', () {
      final e = PinballEngine(PinballTable.standard());
      e.spawnWaitingBall();
      e.launch(1.0);
      var drained = false;
      for (var i = 0; i < 60 * 60 && !drained; i++) {
        e.advance(1 / 60);
        drained = e.events.any((x) => x.kind == HitKind.drain);
        e.events.clear();
        for (final b in e.balls) {
          expect(b.x, inInclusiveRange(0, kTableW), reason: '공이 옆으로 샜어요');
          expect(b.y, greaterThan(-50), reason: '공이 천장을 뚫었어요');
        }
      }
      expect(drained, isTrue);
    });

    test('플리퍼를 올리면 위에 놓인 공이 튕겨 오른다', () {
      final e = PinballEngine(PinballTable.standard());
      // 쉬는 왼쪽 플리퍼의 축 근처에 공을 얹고 바로 올린다.
      e.balls.add(Ball(225, 1200)..waiting = false);
      e.setFlipper(true, true);
      var top = 1200.0;
      for (var i = 0; i < 60; i++) {
        e.advance(1 / 60);
        if (e.balls.isEmpty) break;
        top = top < e.balls.first.y ? top : e.balls.first.y;
      }
      expect(top, lessThan(1120), reason: '플리퍼가 공을 쳐 올려야 해요');
    });

    test('쉬는 플리퍼 위의 공은 비탈을 굴러 가운데로 빠진다', () {
      final e = PinballEngine(PinballTable.standard());
      e.balls.add(Ball(245, 1190)..waiting = false);
      var drained = false;
      for (var i = 0; i < 120 && !drained; i++) {
        e.advance(1 / 60);
        drained = e.events.any((x) => x.kind == HitKind.drain);
      }
      expect(drained, isTrue);
    });

    test('범퍼는 공을 세게 밀어낸다', () {
      final e = PinballEngine(PinballTable.standard());
      e.balls.add(Ball(238, 430)
        ..waiting = false
        ..vy = -900);
      var hit = false;
      for (var i = 0; i < 30; i++) {
        e.advance(1 / 60);
        hit = hit || e.events.any((x) => x.kind == HitKind.bumper);
      }
      expect(hit, isTrue);
    });

    test('가운데 표적 세 개를 다 맞히면 묶음 보너스가 나고 다시 선다', () {
      final e = PinballEngine(PinballTable.standard());
      var bank = -1;
      for (final t in e.table.targets.where((t) => t.bank == 0)) {
        e.balls
          ..clear()
          ..add(Ball(t.x, t.y + 30)
            ..waiting = false
            ..vy = -300);
        for (var i = 0; i < 20; i++) {
          e.advance(1 / 60);
          for (final ev in e.events) {
            if (ev.kind == HitKind.bank) bank = ev.index;
          }
          e.events.clear();
        }
      }
      expect(bank, 0);
      for (var i = 0; i < 90; i++) {
        e.advance(1 / 60);
      }
      expect(e.targetDown.every((d) => !d), isTrue);
    });

    test('롤오버 레인을 네 개 다 지나가면 모두 켜졌다는 소식이 나온다', () {
      final e = PinballEngine(PinballTable.standard());
      var lanes = 0;
      var done = false;
      for (final s in e.table.sensors.where((s) => s.kind == SensorKind.lane)) {
        e.balls
          ..clear()
          ..add(Ball(s.x, s.y + 40)
            ..waiting = false
            ..vy = -400);
        for (var i = 0; i < 30; i++) {
          e.advance(1 / 60);
          for (final ev in e.events) {
            if (ev.kind == HitKind.lane) lanes++;
            if (ev.kind == HitKind.lanesDone) done = true;
          }
          e.events.clear();
        }
      }
      expect(lanes, 4);
      expect(done, isTrue);
    });

    test('블랙홀에 공이 빨려 들어갔다가 다시 나온다', () {
      final e = PinballEngine(PinballTable.standard(), rng: Random(3));
      final c = e.table.saucer;
      e.balls.add(Ball(c.x, c.y + 40)
        ..waiting = false
        ..vy = -700);
      var captured = false;
      for (var i = 0; i < 40 && !captured; i++) {
        e.advance(1 / 60);
        captured = e.events.any((x) => x.kind == HitKind.saucer);
        e.events.clear();
      }
      expect(captured, isTrue);
      expect(e.held, isNotNull);
      expect(e.ballsInPlay, 1, reason: '잡힌 공도 판에 남은 공으로 세어요');
      for (var i = 0; i < 90 && e.held != null; i++) {
        e.advance(1 / 60);
        e.events.clear();
      }
      expect(e.held, isNull);
      expect(e.ballsInPlay, 1, reason: '나온 공은 그대로 한 개');
    });

    test('불이 켜진 블랙홀에서는 공이 세 개가 되어 나온다', () {
      final e = PinballEngine(PinballTable.standard(), rng: Random(5))..saucerLit = true;
      final c = e.table.saucer;
      e.balls.add(Ball(c.x, c.y + 40)
        ..waiting = false
        ..vy = -700);
      var multi = false;
      for (var i = 0; i < 60 * 4 && !multi; i++) {
        e.advance(1 / 60);
        multi = e.events.any((x) => x.kind == HitKind.multiball);
        e.events.clear();
      }
      expect(multi, isTrue);
      // 나오는 순간: 지금 나온 공 + 곧 나올 공 둘 = 세 개 (아직 안 빠졌다)
      expect(e.ballsInPlay, 3);
      expect(e.saucerLit, isFalse);
    });

    test('스피너는 공이 지나가면 돌고 돌 때마다 소식이 난다', () {
      final e = PinballEngine(PinballTable.standard());
      final sp = e.table.spinners.first;
      e.balls.add(Ball(sp.x, sp.y + 60)
        ..waiting = false
        ..vy = -900);
      var spins = 0;
      for (var i = 0; i < 90; i++) {
        e.advance(1 / 60);
        spins += e.events.where((x) => x.kind == HitKind.spin).length;
        e.events.clear();
      }
      expect(spins, greaterThanOrEqualTo(2));
    });

    test('아웃레인에 들어간 공은 그대로 빠진다', () {
      final e = PinballEngine(PinballTable.standard());
      e.balls.add(Ball(48, 700)..waiting = false);
      var drained = false;
      for (var i = 0; i < 120 && !drained; i++) {
        e.advance(1 / 60);
        drained = e.events.any((x) => x.kind == HitKind.drain);
      }
      expect(drained, isTrue);
    });

    test('슬링샷은 판 안쪽에서 맞은 공만 튕겨 낸다', () {
      final e = PinballEngine(PinballTable.standard());
      // 왼쪽 슬링샷 (113,1095)-(192,1163) 의 안쪽(오른쪽 위)에서 떨어뜨린다
      e.balls.add(Ball(165, 1100)..waiting = false);
      var kicked = false;
      for (var i = 0; i < 40 && !kicked; i++) {
        e.advance(1 / 60);
        kicked = e.events.any((x) => x.kind == HitKind.sling);
      }
      expect(kicked, isTrue);
    });
  });

  group('규칙', () {
    test('라운드 목표는 앞 라운드 몫을 합친 값이고 점점 가팔라진다', () {
      expect(PinballRun.targetFor(1), PinballRun.gainFor(1));
      expect(PinballRun.targetFor(2), PinballRun.gainFor(1) + PinballRun.gainFor(2));
      expect(PinballRun.gainFor(5), greaterThan(PinballRun.gainFor(4)));
    });

    test('3·2·1이 끝나야 시간이 흐른다', () {
      final r = PinballRun(seed: 1);
      expect(r.phase, RunPhase.countdown);
      final t0 = r.timeLeft;
      r.update(2.0);
      expect(r.timeLeft, t0);
      r.update(1.5);
      expect(r.phase, RunPhase.playing);
      r.update(1.0);
      expect(r.timeLeft, lessThan(t0));
    });

    test('시간이 다 되면 끝난다', () {
      final r = PinballRun(seed: 1)..update(3.1);
      for (var i = 0; i < 60 * 50 && r.phase == RunPhase.playing; i++) {
        r.update(1 / 60);
      }
      expect(r.phase, RunPhase.over);
    });

    test('목표 점수에 닿으면 멈추고 카드가 뜨고, 고르면 다음 라운드 카운트다운', () {
      final r = PinballRun(seed: 7)..update(3.1);
      r.score = r.targetScore;
      r.update(0.016);
      expect(r.phase, RunPhase.choosing);
      expect(r.freeOffers.length, 3);
      expect(r.freeOffers.map((o) => o.upgrade.id).toSet().length, 3);
      expect(r.paidOffers, isNotEmpty);
      final t = r.timeLeft;
      r.update(1.0); // 멈춰 있다
      expect(r.timeLeft, t);

      r.pickFree(0);
      expect(r.round, 2);
      expect(r.phase, RunPhase.countdown);
      expect(r.targetScore, PinballRun.targetFor(2));
      expect(r.timeLeft, greaterThan(PinballRun.timeFor(2) - 0.1));
      expect(r.upgradeCount, 1);
    });

    test('유료 카드는 점수를 쓰고, 모자라면 못 산다', () {
      final r = PinballRun(seed: 7)..update(3.1);
      r.score = r.targetScore;
      r.update(0.016);
      final o = r.paidOffers.first;
      final before = r.score;
      r.score = o.price - 1;
      expect(r.buy(0), isFalse);
      r.score = before;
      expect(r.buy(0), isTrue);
      expect(r.score, before - o.price);
      expect(o.bought, isTrue);
      expect(r.buy(0), isFalse, reason: '같은 카드를 또 살 수 없어요');
      expect(r.phase, RunPhase.choosing, reason: '사도 창은 그대로예요');
    });

    test('공을 놓치면 시간이 깎이고 새 공이 통로에 놓인다', () {
      final r = PinballRun(seed: 3)..update(3.1);
      r.engine.balls.clear();
      r.engine.balls.add(Ball(280, kDrainY - 2)
        ..waiting = false
        ..vy = 600);
      final t0 = r.timeLeft;
      r.update(0.05);
      expect(r.timeLeft, lessThan(t0 - 4));
      expect(r.engine.hasWaitingBall, isTrue);
    });

    test('보호막은 떨어지는 공을 한 번 살려 준다', () {
      final r = PinballRun(seed: 3)..update(3.1);
      r.engine.shields = 1;
      r.engine.balls.clear();
      r.engine.balls.add(Ball(308, 1295)
        ..waiting = false
        ..vy = 600);
      r.update(0.05);
      expect(r.engine.shields, 0);
      expect(r.engine.balls.single.vy, lessThan(0));
    });

    test('공짜 카드를 다 모아서 고를 게 없으면 그냥 다음 라운드로 간다', () {
      final r = PinballRun(seed: 7)..update(3.1);
      for (final u in kUpgrades.where((u) => !u.consumable)) {
        r.stacks[u.id] = u.max;
      }
      r.score = r.targetScore;
      r.update(0.016);
      expect(r.phase, RunPhase.choosing);
      expect(r.freeOffers, isEmpty);
      expect(r.paidOffers, isNotEmpty, reason: '시간 팩은 늘 살 수 있어요');
      r.continueWithoutPick();
      expect(r.round, 2);
      expect(r.phase, RunPhase.countdown);
    });

    test('업그레이드가 수치에 반영된다', () {
      final m = PinballMods({'flip_len': 2, 'gold': 1, 'coupon': 1});
      expect(m.flipLen, closeTo(1.2, 1e-9));
      expect(m.scoreMul, closeTo(1.15, 1e-9));
      expect(m.price, closeTo(0.85, 1e-9));
      for (final u in kUpgrades) {
        expect(upgradeById(u.id), u);
      }
    });

    test('콤보가 쌓이면 점수 배수가 오르고 가만히 있으면 사라진다', () {
      final r = PinballRun(seed: 1)..update(3.1);
      for (var i = 0; i < 9; i++) {
        r.engine.events.add(const HitEvent(HitKind.bumper, 272, 300));
      }
      r.update(0.001);
      expect(r.combo, 9);
      expect(r.multiplier, greaterThan(1.5));
      r.update(3.0);
      expect(r.combo, 0);
    });
  });
}
