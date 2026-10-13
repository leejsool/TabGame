import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/audio/rhythm_audio.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
import 'package:tabgame/games/rhythm/core/rhythm_judge.dart';
import 'package:tabgame/games/rhythm/game/rhythm_controller.dart';

class FakeSfx implements RhythmSfx {
  final List<Sfx> played = [];
  @override
  Future<void> load() async {}
  @override
  void play(Sfx sfx) => played.add(sfx);
  @override
  Future<void> dispose() async {}
}

/// 4코스(보스) 곡을 처음부터 끝까지 플레이한다. [skipGuards]에 든 번호(0부터)의 막기는 일부러 안 막는다.
Future<RhythmController> play({Set<int> skipGuards = const {}, FakeSfx? sfx}) async {
  final c = RhythmController(chart: RhythmChart.course(3), sfx: sfx ?? FakeSfx());
  c.start();
  var t = 0.0;
  void advance(double to) {
    while (t < to && c.status == RhythmStatus.playing) {
      t += 0.016;
      c.update(t);
    }
  }

  var guardIndex = 0;
  for (final e in c.chart.playerEvents) {
    if (c.status != RhythmStatus.playing) break;
    if (e.isGuard) {
      final skip = skipGuards.contains(guardIndex++);
      advance(e.time - 0.15);
      if (!skip && c.status == RhythmStatus.playing) {
        expect(c.beginSwipe(t), isTrue);
        expect(c.armedGuard, isTrue);
        advance(e.time);
        c.guard(e.time);
      }
      continue;
    }
    advance(e.pressTime - 0.15);
    if (e.isSwipe) {
      c.beginSwipe(t);
      advance(e.time);
      c.swipe(e.side, e.time);
      continue;
    }
    advance(e.pressTime);
    final started = c.tap(e.side, e.pressTime);
    if (started) {
      advance(e.time);
      c.release(e.time);
    }
  }
  advance(c.chart.endTime + 0.6);
  return c;
}

void main() {
  group('4코스 곡', () {
    final course = RhythmCourse.all[3];
    final chart = RhythmChart.course(3);

    test('큰 빨간 슬라임(보스) 코스: 하트 3개, 4단계, 단계 2·3·4에 막기가 한 번씩 (총 3번)', () {
      expect(course.foe, Foe.bossSlime);
      expect(course.hearts, 3);
      expect(chart.hearts, 3);
      expect(course.stages.length, 4);
      final guards = chart.guards;
      expect(guards.length, 3);
      expect(guards.map((g) => g.stage), [1, 2, 3]);
      expect(chart.hasGuards, isTrue);
      expect(RhythmChart.course(2).hasGuards, isFalse);
      expect(RhythmChart.course(2).hearts, 0);
    });

    test('막기 박자: 물결의 네 번째 박(내 차례)이고, 그 물결에는 선배들의 동작이 없다', () {
      for (final g in chart.guards) {
        final wave = chart.events.where((e) => e.wave == g.wave).toList();
        expect(wave.length, 1, reason: '막기 물결에는 막기 박자 하나뿐');
        final waveStart = g.time - 3 * chart.beat;
        // 바로 앞 물결(선배들)의 마지막 박은 막기 시작 전에 끝나 있다
        final before = chart.events.where((e) => e.time < g.time && !e.isGuard);
        if (before.isNotEmpty) expect(before.map((e) => e.time).reduce((a, b) => a > b ? a : b), lessThan(waveStart + 1e-9));
        expect(g.isPlayer, isTrue);
        expect(g.isGuard, isTrue);
      }
      // 이벤트는 시간 순
      for (var i = 1; i < chart.events.length; i++) {
        expect(chart.events[i].time >= chart.events[i - 1].time, isTrue);
      }
    });

    test('막기 직전·직후에도 박자 간격(물결은 4박)이 지켜진다', () {
      final g = chart.guards.first;
      final next = chart.events.firstWhere((e) => e.time > g.time);
      // 다음 물결의 첫 박은 막기 물결 시작(= 덮치기 3박 전)에서 4박 뒤
      expect(next.time - (g.time - 3 * chart.beat), closeTo(4 * chart.beat, 1e-9));
    });
  });

  group('판정: 막기', () {
    ChartEvent guardEv(double t) => ChartEvent(time: t, actor: 3, side: Side.left, stage: 0, wave: 0, isGuard: true);
    ChartEvent tapEv(double t) => ChartEvent(time: t, actor: 3, side: Side.left, stage: 0, wave: 1);

    test('박자에 맞게 위로 밀면 완벽, 판정 폭은 탭보다 넓다(×1.3)', () {
      final j = RhythmJudge([guardEv(1.0), guardEv(2.0), guardEv(3.0)]);
      expect(j.guard(1.02).rating, Rating.perfect);
      expect(j.guard(2.085).rating, Rating.perfect);
      expect(j.guard(3.17).rating, Rating.good);
      expect(j.hits, 3);
    });

    test('박자에서 한참 벗어난 밀기는 stray, 아무도 안 밀면 놓침(판정 폭 여유까지 기다린다)', () {
      final j = RhythmJudge([guardEv(1.0)]);
      expect(j.guard(0.2).rating, Rating.stray);
      expect(j.expire(1.0 + 0.2 + 0.01), isEmpty);
      final missed = j.expire(1.0 + 0.2 * 1.3 + 0.01);
      expect(missed.length, 1);
      expect(missed.single.event!.isGuard, isTrue);
    });

    test('막기 박자는 탭·옆으로 긋기로는 못 막고, 막기는 탭 박자를 못 친다', () {
      final j = RhythmJudge([guardEv(2.0), tapEv(1.0)]);
      expect(j.tap(2.0, Side.left).rating, Rating.stray);
      expect(j.swipe(2.0, Side.right).rating, Rating.stray);
      expect(j.guard(1.0).rating, Rating.stray);
      expect(j.tap(1.0, Side.left).rating, Rating.perfect);
      expect(j.guard(2.0).rating, Rating.perfect);
    });
  });

  group('컨트롤러: 하트와 게임 오버', () {
    test('전부 막으면 하트 3개 그대로, 정상 종료, 3성', () async {
      final c = await play();
      expect(c.hearts, 3);
      expect(c.gameOver, isFalse);
      expect(c.status, RhythmStatus.finished);
      expect(c.judge.perfect, c.judge.total);
      expect(c.judge.stars, 3);
      for (final g in c.chart.guards) {
        expect(c.guardOutcome(g)!.blocked, isTrue);
      }
    });

    test('한 번 못 막으면 하트 2개, 두 번이면 1개 — 게임은 끝까지 간다', () async {
      var c = await play(skipGuards: {1});
      expect(c.hearts, 2);
      expect(c.gameOver, isFalse);
      expect(c.status, RhythmStatus.finished);
      expect(c.guardOutcome(c.chart.guards[1])!.blocked, isFalse);
      c = await play(skipGuards: {0, 2});
      expect(c.hearts, 1);
      expect(c.gameOver, isFalse);
    });

    test('세 번 모두 못 막으면 하트 0, 그 순간 바로 게임 오버 (점수·별과 상관없이)', () async {
      final sfx = FakeSfx();
      final c = await play(skipGuards: {0, 1, 2}, sfx: sfx);
      expect(c.hearts, 0);
      expect(c.gameOver, isTrue);
      expect(c.status, RhythmStatus.finished);
      // 다른 박자는 전부 완벽하게 쳤는데도 실패다: 별 개수는 의미가 없다
      expect(c.judge.stars, greaterThanOrEqualTo(2));
      // 마지막(세 번째) 공격의 놓침이 확정되는 시점에 끝난다 — 곡이 끝나기 전
      final third = c.chart.guards.last;
      expect(c.heartLostAt, greaterThan(third.time));
      expect(c.heartLostAt, lessThan(third.time + 0.5));
      expect(c.chart.endTime, greaterThan(c.heartLostAt), reason: '남은 곡이 있어도 바로 끝낸다');
      expect(sfx.played, isNot(contains(Sfx.allClear)), reason: '게임 오버에는 완전 클리어 팡파르가 울리지 않는다');
    });

    test('게임 오버가 나면 이후 입력·시간은 무시되고, 다시 하면 하트가 3개로 돌아온다', () async {
      final c = await play(skipGuards: {0, 1, 2});
      expect(c.gameOver, isTrue);
      final before = c.judge.total;
      c.update(c.heartLostAt + 5);
      c.guard(c.heartLostAt + 5);
      expect(c.hearts, 0);
      expect(c.judge.total, before);
      c.restart();
      expect(c.hearts, 3);
      expect(c.gameOver, isFalse);
      expect(c.status, RhythmStatus.ready);
      expect(c.guardOutcome(c.chart.guards.first), isNull);
    });

    test('하트가 없는 코스에서는 놓쳐도 하트·게임 오버가 없다', () {
      final c = RhythmController(chart: RhythmChart.course(2), sfx: FakeSfx());
      expect(c.hasHearts, isFalse);
      c.start();
      for (var t = 0.0; t < c.chart.endTime + 1; t += 0.05) {
        c.update(t);
      }
      expect(c.gameOver, isFalse);
      expect(c.status, RhythmStatus.finished);
    });

    test('막기 중 입력: 손을 대면 검을 드는 자세, 위로 밀면 막는 자세를 잠깐 유지', () {
      final c = RhythmController(chart: RhythmChart.course(3), sfx: FakeSfx());
      c.start();
      final g = c.chart.guards.first;
      var t = 0.0;
      while (t < g.time - 1.0) {
        t += 0.016;
        c.update(t);
      }
      expect(c.beginSwipe(t), isFalse, reason: '한참 전에는 막기를 기다리지 않는다');
      while (t < g.time - 0.2) {
        t += 0.016;
        c.update(t);
      }
      expect(c.beginSwipe(t), isTrue);
      expect(c.armedGuard, isTrue);
      expect(c.swing(3, t)!.guard, isTrue);
      // 손만 떼면(위로 안 밀면) 자세가 풀린다
      c.cancelSwipe();
      expect(c.swing(3, t), isNull);
      expect(c.armedGuard, isFalse);
      c.beginSwipe(t);
      c.guard(g.time);
      expect(c.guardOutcome(g)!.blocked, isTrue);
      final pose = c.swing(3, g.time + 0.1)!;
      expect(pose.guard, isTrue);
      expect(c.swing(3, g.time + 0.8), isNull, reason: '자세는 잠깐만 유지');
      expect(c.pops.single.guard, isTrue);
      expect(c.pops.single.rating.isHit, isTrue);
    });
  });

  group('컨트롤러: 보스 동작', () {
    test('힘 모으기 → 덮치기 → (막으면) 튕겨 나감 / (못 막으면) 내리찍음 → 가만히', () async {
      final c = RhythmController(chart: RhythmChart.course(3), sfx: FakeSfx());
      c.start();
      final g = c.chart.guards.first;
      final b = c.chart.beat;
      expect(c.bossState(g.time - 3 * b - 0.5).phase, BossPhase.idle);
      expect(c.bossState(g.time - 3 * b + 0.01).phase, BossPhase.windup);
      final mid = c.bossState(g.time - 1.5 * b);
      expect(mid.phase, BossPhase.windup);
      expect(mid.progress, inInclusiveRange(0.3, 0.8));
      expect(c.bossState(g.time - 0.05).phase, BossPhase.lunge);
      // 아직 결과가 없으면(막을 수 있는 동안) 내리찍는 모습
      expect(c.bossState(g.time + 0.05).phase, BossPhase.slam);
      expect(c.bossState(g.time + 3).phase, BossPhase.idle);
      // 막은 뒤에는 튕겨 나간다
      var t = 0.0;
      while (t < g.time - 0.2) {
        t += 0.016;
        c.update(t);
      }
      c.beginSwipe(t);
      c.guard(g.time);
      expect(c.bossState(g.time + 0.1).phase, BossPhase.blocked);
      expect(c.bossState(g.time + 2).phase, BossPhase.idle);
    });
  });
}
