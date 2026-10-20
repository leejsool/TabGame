import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/snake/core/snake_ai.dart';
import 'package:tabgame/games/snake/core/snake_body.dart';
import 'package:tabgame/games/snake/core/snake_world.dart';
import 'package:tabgame/games/snake/game/snake_controller.dart';

void main() {
  SnakeWorld fresh({int seed = 1}) {
    final w = SnakeWorld(rng: Random(seed));
    w.addSeat(0, '나');
    w.setUp();
    return w;
  }

  void run(SnakeWorld w, double seconds, {void Function()? each}) {
    final n = (seconds * 60).round();
    for (var i = 0; i < n; i++) {
      each?.call();
      w.step(1 / 60);
    }
  }

  test('처음에는 나를 빼고 모두 CPU로 30마리, 먹이가 깔린다', () {
    final w = fresh();
    expect(w.snakes.length, SnakeRules.population);
    expect(w.snakes.where((s) => s.human).length, 1);
    expect(w.food.length, greaterThanOrEqualTo(SnakeRules.foodTarget));
    // 솜씨가 고루 섞인다
    final skills = [for (final s in w.snakes) if (!s.human) s.brain!.skill];
    for (final k in CpuSkill.values) {
      expect(skills.where((x) => x == k).length, greaterThanOrEqualTo(9));
    }
    // 성격도 솜씨마다 고루 섞인다 (공격형·보통형·신중형)
    for (final k in CpuSkill.values) {
      final moods = [for (final s in w.snakes) if (!s.human && s.brain!.skill == k) s.brain!.mood];
      expect(moods.toSet(), CpuMood.values.toSet());
    }
  });

  test('사람 뱀 점수가 높으면 멍청한 CPU가 똑똑한 CPU로 바뀌고, 3000점부터 떼 사냥 단계가 된다', () {
    final w = fresh();
    final me = w.snakeOfSeat(0)!;
    me.mass = 4200;
    run(w, 20, each: () => w.steer(0, me.angle + 0.02, false));
    expect(w.cpuLevel, greaterThanOrEqualTo(CpuBrain.packLevel));
    final skills = [for (final s in w.snakes) if (!s.human) s.brain!.skill];
    expect(skills.where((k) => k == CpuSkill.dumb), isEmpty);
    expect(skills.where((k) => k == CpuSkill.smart).length, greaterThan(skills.length ~/ 2));
  });

  test('먹이를 먹으면 길어지고 아주 서서히 굵어진다', () {
    expect(SnakeRules.lengthOf(100), greaterThan(SnakeRules.lengthOf(10) * 3));
    expect(SnakeRules.radiusOf(100) / SnakeRules.radiusOf(10), lessThan(1.4));
    final w = SnakeWorld(rng: Random(2), foodTarget: 0);
    final me = w.addSeat(0, '나');
    me.layStraight(1000, 1000, 0);
    w.steer(0, 0, false);
    for (var i = 0; i < 10; i++) {
      w.addFood(1030.0 + i * 12, 1000, 2, 0);
    }
    run(w, 1.5, each: () => w.steer(0, 0, false));
    expect(me.mass, closeTo(SnakeRules.startMass + 20, 0.01));
  });

  test('벽에 박으면 죽는다', () {
    final w = SnakeWorld(rng: Random(3), foodTarget: 0);
    final me = w.addSeat(0, '나');
    me.layStraight(w.field - 60, 2500, 0);
    SnakeDeath? died;
    w.onDeath = (d) => died = d;
    run(w, 1, each: () => w.steer(0, 0, false));
    expect(died?.seat, 0);
    expect(died?.killer, -1);
    expect(w.snakeOfSeat(0), isNull);
    expect(w.food, isNotEmpty, reason: '죽은 뱀은 먹이로 흩어진다');
  });

  test('다른 뱀 몸에 머리를 박으면 죽고, 박힌 뱀이 처치를 얻는다', () {
    final w = SnakeWorld(rng: Random(4), foodTarget: 0, population: 2);
    final me = w.addSeat(0, '나');
    final wall = w.addSeat(1, '벽뱀');
    wall.mass = 200;
    wall.layStraight(1500, 1000, pi / 2); // 세로로 길게 누운 몸
    me.layStraight(1200, 900, 0);
    run(w, 2.5, each: () {
      w.steer(0, 0, false);
      w.steer(1, pi / 2, false);
    });
    expect(w.snakeOfSeat(0), isNull);
    expect(wall.kills, 1);
  });

  test('사람이 들어와 30명이 넘으면 죽은 CPU는 다시 태어나지 않는다', () {
    final w = fresh(seed: 5);
    w.addSeat(1, '친구');
    expect(w.headcount, 31);
    final cpu = w.snakes.firstWhere((s) => !s.human);
    cpu.x = -100; // 벽 밖으로
    run(w, 6);
    expect(w.headcount, lessThanOrEqualTo(SnakeRules.population + 1));
    // 수가 30 아래로 내려가면 다시 채운다
    w.removeSeat(1);
    run(w, 8);
    expect(w.headcount, greaterThanOrEqualTo(SnakeRules.population - 2), reason: '다른 CPU가 죽고 다시 태어나기를 기다리는 중일 수 있다');
  });

  test('CPU끼리 1분씩 돌려도 망가지지 않고, 똑똑한 CPU가 멍청한 CPU보다 덜 죽는다', () {
    final deaths = {for (final k in CpuSkill.values) k: 0};
    for (final seed in [6, 11, 12]) {
      final w = fresh(seed: seed);
      final skillOf = <int, CpuSkill>{};
      w.onDeath = (d) {
        final k = skillOf[d.id];
        if (k != null) deaths[k] = deaths[k]! + 1;
      };
      run(w, 60, each: () {
        for (final s in w.snakes) {
          if (!s.human) skillOf[s.id] = s.brain!.skill;
        }
        final me = w.snakeOfSeat(0);
        if (me != null) w.steer(0, me.angle + 0.02, false); // 나는 천천히 빙글빙글
        w.respawnSeat(0);
      });
      expect(w.snakes.length, greaterThan(20));
    }
    expect(deaths[CpuSkill.smart]!, lessThan(deaths[CpuSkill.dumb]!));
  }, tags: 'slow');

  test('똑똑한 CPU는 가까운 사람 뱀을 가로막거나 둘러싸려 하고, 오래 둘러싸면 실수를 한다', () {
    final w = SnakeWorld(rng: Random(7), foodTarget: 200, population: 2);
    final me = w.addSeat(0, '나');
    me.layStraight(2500, 2500, 0);
    final cpu = WorldSnake(id: 999, name: '똑똑이', color: 1, brain: CpuBrain(CpuSkill.smart, Random(8))..debugReadyToHunt());
    cpu.mass = 400;
    cpu.layStraight(2500, 2200, 0);
    w.snakes.add(cpu);
    w.byId[cpu.id] = cpu;
    final seen = <CpuPlan>{};
    run(w, 25, each: () {
      final m = w.respawnSeat(0); // (내가 부딪혀 죽어도 바로 다시 태어나 표적이 된다)
      if (m != null) w.steer(0, m.angle + 0.03, false);
      if (w.byId.containsKey(999)) seen.add(cpu.brain!.plan);
    });
    expect(seen.contains(CpuPlan.coil) || seen.contains(CpuPlan.cut), isTrue, reason: 'seen $seen alive ${w.byId.containsKey(999)} t ${w.time}');
    if (seen.contains(CpuPlan.coil)) expect(seen, contains(CpuPlan.blunder));
  });

  test('내가 1등이 되는 순간에 한 번 "1등" 알림이 나고, 근처 뱀이 죽으면 위치를 알려 준다', () {
    final c = SnakeController.host(nick: '나', rng: Random(9));
    final kinds = <String>[];
    var deaths = 0;
    c.onFeedback = kinds.add;
    c.onOtherDeath = (_, _) => deaths++;
    for (var i = 0; i < 30; i++) {
      c.frame(1 / 60);
    }
    c.world!.snakeOfSeat(0)!.mass = 5000; // 갑자기 커져서 1등
    for (var i = 0; i < 60; i++) {
      c.frame(1 / 60);
    }
    expect(kinds.where((k) => k == 'first').length, 1);
    c.world!.snakes.firstWhere((s) => !s.human).x = -100;
    c.frame(1 / 60);
    expect(deaths, greaterThanOrEqualTo(1));
    c.dispose();
  });

  test('오래 놀아도 먹이가 벽 근처에만 몰리지 않는다 (안 먹힌 먹이는 치우고 드문 곳에 새로 깐다)', () {
    final w = fresh(seed: 10);
    final edgeOf = <double>[];
    run(w, 180, each: () {
      w.respawnSeat(0);
      final me = w.snakeOfSeat(0);
      if (me != null) w.steer(0, me.angle + 0.02, false);
    });
    var center = 0, edge = 0;
    for (final f in w.food.values) {
      final d = min(min(f.x, f.y), min(w.field - f.x, w.field - f.y));
      edgeOf.add(d);
      if (f.x > 1000 && f.x < 4000 && f.y > 1000 && f.y < 4000) center++;
      if (d < 500) edge++;
    }
    // 두 구역의 넓이는 같다 (가운데 3000×3000 = 벽에서 500 안쪽 띠)
    expect(center, greaterThan(edge * 0.6), reason: '가운데 $center, 벽 근처 $edge');
    expect(w.food.length, lessThan(SnakeRules.foodCap));
  }, tags: 'slow');

  test('공격형 보통 CPU는 가로막기를 하고, 신중형 똑똑한 CPU는 사냥을 하지 않는다', () {
    List<CpuPlan> plans(CpuSkill skill, CpuMood mood) {
      final w = SnakeWorld(rng: Random(11), foodTarget: 200, population: 2);
      w.addSeat(0, '나').layStraight(2500, 2500, 0);
      final cpu = WorldSnake(id: 999, name: 'CPU', color: 1, brain: CpuBrain(skill, Random(12), mood: mood)..debugReadyToHunt());
      cpu.mass = 60;
      cpu.layStraight(2500, 2250, 0);
      w.snakes.add(cpu);
      w.byId[cpu.id] = cpu;
      final seen = <CpuPlan>[];
      run(w, 8, each: () {
        final m = w.respawnSeat(0);
        if (m != null) w.steer(0, m.angle + 0.03, false);
        if (w.byId.containsKey(999)) seen.add(cpu.brain!.plan);
      });
      return seen;
    }

    expect(plans(CpuSkill.normal, CpuMood.aggressive), contains(CpuPlan.cut));
    expect(plans(CpuSkill.smart, CpuMood.cautious).toSet(), {CpuPlan.roam});
    expect(plans(CpuSkill.normal, CpuMood.balanced).toSet(), {CpuPlan.roam});
  });

  test('사람이 1등인 채로 500점을 넘을 때마다 CPU 단계가 오르고, CPU가 1등이면 천천히 내려간다', () {
    final w = fresh(seed: 13);
    final me = w.snakeOfSeat(0)!;
    w.step(1 / 60);
    expect(w.cpuLevel, 0);
    me.mass = 1100;
    run(w, 1, each: () => w.steer(0, (w.snakeOfSeat(0)?.angle ?? 0) + 0.02, false));
    expect(w.cpuLevel, 2);
    // Wi‑Fi 손님이 1등이어도 똑같다
    final friend = w.addSeat(1, '친구');
    friend.mass = 3000;
    run(w, 1, each: () => w.steer(1, friend.angle + 0.02, false));
    expect(w.cpuLevel, 6);
    // 사람들이 사라지고 CPU가 1등이면 15초마다 하나씩 내려간다
    w.removeSeat(1);
    w.removeSeat(0);
    run(w, 16);
    expect(w.cpuLevel, 5);
  });
}
