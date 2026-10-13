import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
import 'package:tabgame/games/rhythm/core/rhythm_judge.dart';

void main() {
  group('RhythmChart', () {
    final chart = RhythmChart.tutorial(bpm: 120); // 한 박 0.5초

    test('물결은 선배1 → 선배2 → 선배3 → 나 순서로 한 박씩 이어진다', () {
      final first = chart.events.where((e) => e.wave == 0).toList();
      expect(first.map((e) => e.actor), [0, 1, 2, 3]);
      for (var i = 0; i < 4; i++) {
        expect(first[i].time, closeTo((4 + i) * 0.5, 1e-9));
      }
    });

    test('2연속은 반 박 간격으로 같은 쪽을 두 번 친다', () {
      final stage = chart.stages.indexWhere((s) => s.title.contains('2연속'));
      final mine = chart.playerEvents.where((e) => e.stage == stage && e.wave == chart.events.firstWhere((x) => x.stage == stage).wave).toList();
      expect(mine.length, 2);
      expect(mine[1].time - mine[0].time, closeTo(0.25, 1e-9));
      expect(mine[0].side, mine[1].side);
    });

    test('이벤트는 시간 순이고 단계는 순서대로 진행된다', () {
      for (var i = 1; i < chart.events.length; i++) {
        expect(chart.events[i].time >= chart.events[i - 1].time, isTrue);
      }
      expect(chart.stageStarts.length, chart.stages.length);
      expect(chart.stageAt(0), 0);
      expect(chart.stageAt(chart.endTime), chart.stages.length - 1);
    });


    test('꾹 누르기 코스: 누르는 시각이 한 박 앞서고, 물결은 5박 간격', () {
      final c = RhythmChart.course(1);
      final holds = c.events.where((e) => e.isHold).toList();
      expect(holds, isNotEmpty);
      for (final e in holds) {
        expect(e.time - e.pressTime, closeTo(c.beat, 1e-9));
      }
      // 첫 물결(꾹 누르기)에서 선배1 → 선배2 → 선배3 → 나 순서로 한 박씩 늦게 시작한다
      final w0 = c.events.where((e) => e.wave == 0).toList()..sort((a, b) => a.actor.compareTo(b.actor));
      for (var i = 1; i < 4; i++) {
        expect(w0[i].pressTime - w0[i - 1].pressTime, closeTo(c.beat, 1e-9));
      }
      final w1 = c.events.firstWhere((e) => e.wave == 1 && e.actor == 0);
      expect(w1.pressTime - w0[0].pressTime, closeTo(5 * c.beat, 1e-9));
    });

    test('코스 목록: 둘째 코스는 꾹 누르기를 포함한다', () {
      expect(RhythmCourse.all.length, greaterThanOrEqualTo(2));
      expect(RhythmChart.course(0).events.any((e) => e.isHold), isFalse);
      expect(RhythmChart.course(1).playerEvents.any((e) => e.isHold), isTrue);
    });

    test('3코스(마을 밖으로): 슬라임 4단계, 옆으로 긋기를 처음 배우고 앞 기술과 섞는다', () {
      final course = RhythmCourse.all[2];
      expect(course.foe, Foe.slime);
      expect(course.stages.length, 4);
      expect(course.bpm, greaterThanOrEqualTo(RhythmCourse.all[1].bpm));
      // 첫 단계는 긋기만, 마지막 단계만 안내가 없다
      expect(course.stages.first.waves.every((w) => w.swipe), isTrue);
      expect(course.stages.map((s) => s.cue), [true, true, true, false]);
      // 갈수록 길어진다
      final lens = course.stages.map((s) => s.waves.length).toList();
      for (var i = 1; i < lens.length; i++) {
        expect(lens[i], greaterThanOrEqualTo(lens[i - 1]));
      }
      final c = RhythmChart.course(2);
      final mine = c.playerEvents.toList();
      expect(mine.any((e) => e.isSwipe && e.side == Side.left), isTrue);
      expect(mine.any((e) => e.isSwipe && e.side == Side.right), isTrue);
      expect(mine.any((e) => e.isHold), isTrue);
      expect(mine.any((e) => !e.isSwipe && !e.isHold), isTrue);
      // 앞의 코스에는 긋기가 없다
      expect(RhythmChart.course(1).events.any((e) => e.isSwipe), isFalse);
      // 선배들도 같은 박자에 긋는다 (물결 하나 = 네 명이 한 박씩)
      final w0 = c.events.where((e) => e.wave == 0).toList();
      expect(w0.every((e) => e.isSwipe), isTrue);
      expect(RhythmCourse.all.map((c) => c.title).take(3), ['훈련소 입소', '꾹 눌러 모으기', '마을 밖으로']);
      expect(RhythmCourse.all.length, 4);
    });

    test('코스별 배경과 검: 1·2코스는 훈련장 + 목검, 3·4코스는 숲길 + 철검', () {
      final all = RhythmCourse.all;
      expect(all.map((c) => c.background), ['bg', 'bg', 'bg_forest', 'bg_forest']);
      expect(all.map((c) => c.ironSword), [false, false, true, true]);
    });

    test('튜토리얼에는 왼쪽·오른쪽·2연속이 모두 들어 있다', () {
      final mine = chart.playerEvents.toList();
      expect(mine.any((e) => e.side == Side.left), isTrue);
      expect(mine.any((e) => e.side == Side.right), isTrue);
      final byWave = <int, int>{};
      for (final e in mine) {
        byWave[e.wave] = (byWave[e.wave] ?? 0) + 1;
      }
      expect(byWave.values.any((n) => n == 2), isTrue);
    });
  });

  group('RhythmJudge 옆으로 긋기', () {
    ChartEvent sw(double t, Side s) => ChartEvent(time: t, actor: 3, side: s, stage: 0, wave: 0, isSwipe: true);

    test('방향이 맞고 박자에 맞게 그으면 완벽 — 탭보다 판정 폭이 넓다', () {
      final j = RhythmJudge([sw(1.0, Side.right), sw(2.0, Side.left), sw(3.0, Side.right)]);
      expect(j.swipe(1.03, Side.right).rating, Rating.perfect);
      // 탭이라면 좋아요(0.07초 초과)지만 긋기는 0.09초까지 완벽
      expect(j.swipe(2.085, Side.left).rating, Rating.perfect);
      expect(j.swipe(3.17, Side.right).rating, Rating.good);
      expect(j.total, 3);
      expect(j.hits, 3);
    });

    test('방향이 반대면 반대쪽(놓침)', () {
      final j = RhythmJudge([sw(1.0, Side.right)]);
      final r = j.swipe(1.0, Side.left);
      expect(r.rating, Rating.wrongSide);
      expect(j.miss, 1);
      expect(j.combo, 0);
    });

    test('긋기 박자는 탭으로 칠 수 없고, 탭 박자는 긋기로 칠 수 없다', () {
      final tapEv = ChartEvent(time: 1.0, actor: 3, side: Side.left, stage: 0, wave: 0);
      final j = RhythmJudge([sw(2.0, Side.right), tapEv]);
      expect(j.tap(2.0, Side.right).rating, Rating.stray);
      expect(j.swipe(1.0, Side.left).rating, Rating.stray);
      expect(j.tap(1.0, Side.left).rating, Rating.perfect);
      expect(j.swipe(2.0, Side.right).rating, Rating.perfect);
    });

    test('아무도 안 그으면 박자가 지나서 놓침 처리된다 (판정 폭 여유만큼 더 기다린다)', () {
      final j = RhythmJudge([sw(1.0, Side.right)]);
      expect(j.expire(1.0 + 0.2 + 0.01), isEmpty);
      expect(j.expire(1.0 + 0.2 * 1.3 + 0.01).length, 1);
      expect(j.miss, 1);
    });

    test('nextPending은 긋기도 안내 대상으로 돌려준다', () {
      final j = RhythmJudge([sw(1.0, Side.left)]);
      expect(j.nextPending(0.5)!.isSwipe, isTrue);
    });
  });

  group('RhythmJudge', () {
    ChartEvent ev(double t, [Side s = Side.left]) =>
        ChartEvent(time: t, actor: 3, side: s, stage: 0, wave: 0);

    test('정확히 맞으면 완벽, 조금 빗나가면 좋아요', () {
      final j = RhythmJudge([ev(1.0), ev(2.0)]);
      expect(j.tap(1.02, Side.left).rating, Rating.perfect);
      expect(j.tap(2.1, Side.left).rating, Rating.good);
      expect(j.combo, 2);
      expect(j.hits, 2);
    });

    test('반대쪽을 치면 그 박자는 실패하고 콤보가 끊긴다', () {
      final j = RhythmJudge([ev(1.0)]);
      final r = j.tap(1.0, Side.right);
      expect(r.rating, Rating.wrongSide);
      expect(j.miss, 1);
      expect(j.combo, 0);
    });

    test('박자와 한참 먼 탭은 stray, 안 친 박자는 expire로 놓침 처리', () {
      final j = RhythmJudge([ev(1.0)]);
      expect(j.tap(5.0, Side.left).rating, Rating.stray);
      expect(j.expire(1.1), isEmpty); // 아직 칠 수 있는 시간
      final missed = j.expire(1.5);
      expect(missed.length, 1);
      expect(j.miss, 1);
      expect(j.expire(9), isEmpty); // 두 번 세지 않는다
    });

    test('2연속은 각 탭이 가까운 박자에 하나씩 짝지어진다', () {
      final j = RhythmJudge([ev(1.0), ev(1.25)]);
      expect(j.tap(1.01, Side.left).event!.time, 1.0);
      expect(j.tap(1.26, Side.left).event!.time, 1.25);
      expect(j.perfect, 2);
    });

    test('2연타: 첫 박자를 조금 늦게 쳐도 첫 박자로 판정한다', () {
      final j = RhythmJudge([ev(1.0), ev(1.3)]);
      final r1 = j.tap(1.12, Side.left);
      expect(r1.event!.time, 1.0);
      expect(r1.rating, Rating.good);
      final r2 = j.tap(1.4, Side.left);
      expect(r2.event!.time, 1.3);
      expect(j.miss, 0);
    });

    test('2연타: 첫 박자를 아주 늦게(둘째 박자에 훨씬 가깝게) 치면 첫 박자는 놓침, 둘째로 판정', () {
      final j = RhythmJudge([ev(1.0), ev(1.3)]);
      final r = j.tap(1.2, Side.left); // 첫 박자 +0.2, 둘째 박자 -0.1
      expect(r.event!.time, 1.3);
      expect(j.miss, 1);
    });


    ChartEvent hold(double press, double release, [Side s = Side.left]) =>
        ChartEvent(time: release, pressTime: press, actor: 3, side: s, stage: 0, wave: 0);

    test('꾹 누르기: 제때 누르고 제때 떼면 완벽', () {
      final j = RhythmJudge([hold(1.0, 1.6)]);
      expect(j.tap(1.02, Side.left).rating, Rating.holdStart);
      expect(j.holdingEvent, isNotNull);
      final r = j.release(1.61)!;
      expect(r.rating, Rating.perfect);
      expect(j.holdingEvent, isNull);
      expect(j.perfect, 1);
    });

    test('꾹 누르기: 너무 일찍 떼면 놓침', () {
      final j = RhythmJudge([hold(1.0, 1.6)]);
      j.tap(1.0, Side.left);
      final r = j.release(1.2)!;
      expect(r.rating, Rating.miss);
      expect(j.miss, 1);
    });

    test('꾹 누르기: 계속 누르고만 있으면 놓침 처리, 누르기를 놓쳐도 놓침', () {
      final j = RhythmJudge([hold(1.0, 1.6), hold(3.0, 3.6)]);
      j.tap(1.0, Side.left);
      expect(j.expire(1.7), isEmpty); // 아직 뗄 수 있는 시간
      expect(j.expire(2.0).length, 1); // 너무 오래 누름
      expect(j.holdingEvent, isNull);
      expect(j.expire(3.5).length, 1); // 두 번째는 누르지도 않음
      expect(j.miss, 2);
    });

    test('꾹 누르기: 반대쪽을 누르면 바로 실패, 떼도 아무 일 없음', () {
      final j = RhythmJudge([hold(1.0, 1.6)]);
      expect(j.tap(1.0, Side.right).rating, Rating.wrongSide);
      expect(j.release(1.6), isNull);
    });

    test('탭만 있는 곡에서 손을 떼도 아무 일 없다', () {
      final j = RhythmJudge([ev(1.0)]);
      j.tap(1.0, Side.left);
      expect(j.release(1.1), isNull);
    });

    test('별 개수는 정확도로 정해진다', () {
      final j = RhythmJudge([ev(1), ev(2), ev(3), ev(4)]);
      for (final t in [1.0, 2.0, 3.0, 4.0]) {
        j.tap(t, Side.left);
      }
      expect(j.accuracy, 1.0);
      expect(j.stars, 3);
      final k = RhythmJudge([ev(1), ev(2), ev(3), ev(4)]);
      k.tap(1.0, Side.left);
      k.expire(10);
      expect(k.stars, 0);
    });
  });
}
