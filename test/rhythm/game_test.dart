import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/rhythm/audio/rhythm_audio.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
import 'package:tabgame/games/rhythm/core/rhythm_judge.dart';
import 'package:tabgame/games/rhythm/game/rhythm_controller.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_menu_screen.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_art.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_screen.dart';

/// 어떤 소리가 났는지 기록만 하는 가짜 소리 장치.
class RecordingSfx implements RhythmSfx {
  final List<Sfx> played = [];
  @override
  Future<void> load() async {}
  @override
  void play(Sfx sfx) => played.add(sfx);
  @override
  Future<void> dispose() async {}
}

void main() {
  group('RhythmController', () {
    test('정답 박자에 맞게 치면 완벽 + 효과음, 끝까지 가면 종료', () {
      final sfx = RecordingSfx();
      final c = RhythmController(sfx: sfx);
      var finished = false;
      c.onFinished = () => finished = true;
      c.start();
      final mine = c.chart.playerEvents.toList();
      var t = 0.0;
      for (final e in mine) {
        while (t < e.time) {
          t += 0.016;
          c.update(t);
        }
        c.tap(e.side, e.time);
      }
      while (t < c.chart.endTime + 0.5) {
        t += 0.05;
        c.update(t);
      }
      expect(c.judge.perfect, mine.length);
      expect(c.judge.stars, 3);
      expect(finished, isTrue);
      expect(c.status, RhythmStatus.finished);
      expect(sfx.played.contains(Sfx.hitLeft), isTrue);
      expect(sfx.played.contains(Sfx.hitRight), isTrue);
      expect(sfx.played.contains(Sfx.npcLeft), isTrue);
      expect(sfx.played.contains(Sfx.allClear), isTrue);
    });

    test('아무것도 안 치면 전부 놓침 처리되고 별이 없다', () {
      final c = RhythmController(sfx: RecordingSfx());
      c.start();
      var t = 0.0;
      while (t < c.chart.endTime + 0.5) {
        t += 0.05;
        c.update(t);
      }
      expect(c.judge.miss, c.judge.total);
      expect(c.judge.stars, 0);
    });

    test('카운트다운 중의 탭은 무시한다', () {
      final c = RhythmController(sfx: RecordingSfx());
      c.start();
      c.update(0.5);
      c.tap(Side.left, 0.5);
      expect(c.judge.stray, 0);
      expect(c.judge.miss, 0);
    });

    test('입력 보정: 기기가 80ms 늦게 반응해도 보정값만큼 빼면 완벽', () {
      final c = RhythmController(sfx: RecordingSfx(), inputOffset: 0.08);
      c.start();
      final e = c.chart.playerEvents.first;
      c.update(e.time);
      c.tap(e.side, e.time + 0.08);
      expect(c.judge.perfect, 1);
    });

    test('선배의 휘두르기는 맞는 순간(박자)에 충격 단계가 된다', () {
      final c = RhythmController(sfx: RecordingSfx());
      final e = c.chart.events.firstWhere((x) => x.actor == 0);
      final before = c.swing(0, e.time - 0.1)!;
      final at = c.swing(0, e.time)!;
      final after = c.swing(0, e.time + 0.1)!;
      expect(before.progress < kImpactProgress, isTrue);
      expect(at.progress, closeTo(kImpactProgress, 1e-9));
      expect(after.progress > kImpactProgress, isTrue);
      expect(c.swing(0, e.time + 0.8), isNull);
    });

    test('선배의 2연타는 두 번째 타격도 따로 보인다', () {
      final c = RhythmController(sfx: RecordingSfx());
      final stage = c.chart.stages.indexWhere((s) => s.title.contains('2연속'));
      final hits = c.chart.events.where((e) => e.actor == 0 && e.stage == stage).toList();
      final first = hits[0];
      final second = hits[1];
      // 두 번째 타격의 맞는 순간: 두 번째 박자 기준의 충격 단계여야 한다
      final at = c.swing(0, second.time)!;
      expect(at.progress, closeTo(kImpactProgress, 1e-9));
      expect(second.time - first.time, closeTo(c.chart.beat / 2, 1e-9));
    });

    test('연속으로 쳐도 판정 글자는 최근 것 하나만 남는다', () {
      final c = RhythmController(sfx: RecordingSfx());
      c.start();
      final first = c.chart.playerEvents.first;
      c.update(first.time);
      c.tap(first.side, first.time);
      c.tap(first.side, first.time + 0.05);
      expect(c.pops.length, 1);
    });


    test('꾹 누르기 코스: 누르고 제때 떼면 끝까지 만점', () {
      final c = RhythmController(chart: RhythmChart.course(1), sfx: RecordingSfx());
      c.start();
      var t = 0.0;
      for (final e in c.chart.playerEvents) {
        while (t < e.pressTime) {
          t += 0.016;
          c.update(t);
        }
        final started = c.tap(e.side, e.pressTime);
        expect(started, e.isHold);
        if (e.isHold) {
          while (t < e.time) {
            t += 0.016;
            c.update(t);
          }
          c.release(e.time);
        }
      }
      while (t < c.chart.endTime + 0.5) {
        t += 0.05;
        c.update(t);
      }
      expect(c.judge.perfect, c.judge.total);
      expect(c.judge.stars, 3);
    });

    test('3코스: 정확히 치고 제때 떼면 끝까지 만점', () {
      final c = RhythmController(chart: RhythmChart.course(2), sfx: RecordingSfx());
      c.start();
      var t = 0.0;
      for (final e in c.chart.playerEvents) {
        while (t < e.pressTime - 0.15) {
          t += 0.016;
          c.update(t);
        }
        if (e.isSwipe) {
          // 박자 조금 전에 손을 대고(칼을 빼 든다), 박자에 맞춰 긋는다
          expect(c.beginSwipe(t), isTrue);
          expect(c.swing(3, t)!.swipe, isTrue);
          while (t < e.time) {
            t += 0.016;
            c.update(t);
          }
          c.swipe(e.side, e.time);
          continue;
        }
        while (t < e.pressTime) {
          t += 0.016;
          c.update(t);
        }
        final started = c.tap(e.side, e.pressTime);
        expect(started, e.isHold);
        if (e.isHold) {
          while (t < e.time) {
            t += 0.016;
            c.update(t);
          }
          c.release(e.time);
        }
      }
      while (t < c.chart.endTime + 0.5) {
        t += 0.05;
        c.update(t);
      }
      expect(c.judge.perfect, c.judge.total);
      expect(c.judge.stars, 3);
      expect(c.status, RhythmStatus.finished);
    });

    test('긋기: 손을 대면 칼을 빼 들고, 그으면 옆으로 휘두르며, 손만 떼면 취소된다', () {
      final c = RhythmController(chart: RhythmChart.course(2), sfx: RecordingSfx());
      c.start();
      final e = c.chart.playerEvents.first;
      expect(e.isSwipe, isTrue);
      var t = 0.0;
      // 한참 전에는 긋기를 기다리지 않는다
      while (t < e.time - 1.0) {
        t += 0.016;
        c.update(t);
      }
      expect(c.beginSwipe(t), isFalse);
      while (t < e.time - 0.2) {
        t += 0.016;
        c.update(t);
      }
      expect(c.beginSwipe(t), isTrue);
      final armed = c.swing(3, t)!;
      expect(armed.swipe, isTrue);
      expect(armed.side, e.side);
      expect(armed.sinceImpact, lessThan(0));
      // 손을 떼면(거리 부족) 자세가 풀린다
      c.cancelSwipe();
      expect(c.swing(3, t), isNull);
      // 다시 대고 그으면 그 박자가 완벽
      expect(c.beginSwipe(t), isTrue);
      c.swipe(e.side, e.time);
      final done = c.swing(3, e.time + 0.05)!;
      expect(done.swipe, isTrue);
      expect(done.sinceImpact, greaterThanOrEqualTo(0));
      expect(c.judge.perfect, 1);
      expect(c.pops.single.rating, Rating.perfect);
    });

    test('긋기 소리: 내가 그으면 방향별 쓱 소리, 선배의 긋기는 선배용 쓱 소리', () {
      final sfx = RecordingSfx();
      final c = RhythmController(chart: RhythmChart.course(2), sfx: sfx);
      c.start();
      final mine = c.chart.playerEvents.first; // 오른쪽으로 긋기
      expect(mine.side, Side.right);
      var t = 0.0;
      while (t < mine.time - 0.05) {
        t += 0.016;
        c.update(t);
      }
      expect(sfx.played, contains(Sfx.npcSwipeRight), reason: '앞사람(선배)의 긋기 소리');
      expect(sfx.played, isNot(contains(Sfx.npcRight)), reason: '긋기 박자에는 탭 소리를 쓰지 않는다');
      c.beginSwipe(t);
      expect(sfx.played, isNot(contains(Sfx.swipeRight)));
      c.swipe(Side.right, mine.time);
      expect(sfx.played, contains(Sfx.swipeRight));
      expect(sfx.played, isNot(contains(Sfx.swipeLeft)));
      c.swipe(Side.left, mine.time + 0.1);
      expect(sfx.played, contains(Sfx.swipeLeft));
    });

    test('긋기 박자가 없는 코스에서는 손을 대도 긋기를 기다리지 않는다', () {
      final c = RhythmController(sfx: RecordingSfx());
      c.start();
      final first = c.chart.playerEvents.first;
      c.update(first.time - 0.1);
      expect(c.beginSwipe(first.time - 0.1), isFalse);
    });

    test('꾹 누르는 동안 힘이 모이고, 안내 링은 떼야 할 때로 바뀐다', () {
      final c = RhythmController(chart: RhythmChart.course(1), sfx: RecordingSfx());
      c.start();
      final npc = c.chart.events.firstWhere((e) => e.actor == 0 && e.isHold);
      final mid = (npc.pressTime + npc.time) / 2;
      final sw = c.swing(0, mid)!;
      expect(sw.charge, closeTo(0.5, 0.05));
      // 플레이어
      final mine = c.chart.playerEvents.firstWhere((e) => e.isHold);
      var t = 0.0;
      while (t < mine.pressTime - 0.2) {
        t += 0.016;
        c.update(t);
      }
      final before = c.cue(t)!;
      expect(before.isHold, isTrue);
      expect(before.releasing, isFalse);
      c.tap(mine.side, mine.pressTime);
      t = mine.pressTime + 0.1;
      c.update(t);
      expect(c.cue(t)!.releasing, isTrue);
      expect(c.swing(3, t)!.charge, isNotNull);
      c.release(mine.time);
      expect(c.swing(3, mine.time + 0.05)!.charge, isNull);
    });

    test('안내 링은 단계 설정에 따라 보였다 사라진다', () {
      final c = RhythmController(sfx: RecordingSfx());
      c.start();
      final first = c.chart.playerEvents.first;
      c.update(first.time - 0.2);
      expect(c.cue(first.time - 0.2), isNotNull);
      // 마지막 단계(안내 없음)
      final last = c.chart.events.last;
      var t = first.time;
      while (t < last.time - 0.3) {
        t += 0.05;
        c.update(t);
      }
      expect(c.stage, c.chart.stages.length - 1);
      expect(c.cue(t), isNull);
    });
  });

  group('화면', () {
    Future<void> pumpApp(WidgetTester tester, Size size, Widget home) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
      ));
      await tester.pump();
    }

    testWidgets('시작 안내 → 훈련 시작 → 카운트다운, 탭해도 안전', (tester) async {
      final c = RhythmController(sfx: RecordingSfx());
      await pumpApp(tester, const Size(1000, 700), RhythmScreen(controller: c, art: RhythmArt.empty()));
      expect(find.text('훈련소 입소'), findsOneWidget);
      await tester.tap(find.text('훈련 시작!'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.status, RhythmStatus.playing);
      expect(find.text('훈련소 입소'), findsNothing);
      // 화면 양쪽 탭 (카운트다운 중이라 판정에는 영향 없음)
      await tester.tapAt(const Offset(150, 400));
      await tester.tapAt(const Offset(850, 400));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3코스 화면: 슬라임 코스 안내 → 출발 → 놓쳐도 깨지지 않는다', (tester) async {
      final c = RhythmController(chart: RhythmChart.course(2), sfx: RecordingSfx());
      await pumpApp(tester, const Size(1000, 700), RhythmScreen(course: 2, controller: c, art: RhythmArt.empty()));
      expect(find.text('마을 밖으로'), findsOneWidget);
      expect(find.text('마을 밖이다! 슬라임이 나타났다!'), findsOneWidget);
      await tester.tap(find.text('출발!'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.status, RhythmStatus.playing);
      // 곡이 흘러 첫 박자를 놓치게 둔다 (슬라임이 덤비는 장면까지 그려 본다)
      final first = c.chart.playerEvents.first;
      var t = 0.0;
      while (t < first.time + 0.3) {
        t += 0.05;
        c.update(t);
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.pops.isNotEmpty, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('옆으로 긋기: 손가락을 박자에 맞춰 가로로 끌면 판정된다 (탭으로는 안 됨)', (tester) async {
      // 빠른 곡(박자 0.15초)으로 첫 긋기가 시작 후 약 1.5초에 오게 한다
      final chart = RhythmChart.build(
        const [TutorialStage(title: '긋기', hint: '', waves: [Motif.swipeRight, Motif.swipeLeft])],
        bpm: 400,
        countIn: 1,
      );
      final c = RhythmController(chart: chart, sfx: RecordingSfx());
      await pumpApp(tester, const Size(1000, 700), RhythmScreen(controller: c, art: RhythmArt.empty()));
      await tester.tap(find.text('훈련 시작!'));
      await tester.pump(const Duration(milliseconds: 50));
      final e = chart.playerEvents.first;
      expect(e.isSwipe, isTrue);

      // 박자 조금 앞까지 실제 시간을 흘려 보낸다
      await tester.runAsync(() async {
        while (c.now < e.time - 0.12) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
          await tester.pump();
        }
      });
      final g = await tester.startGesture(const Offset(300, 500));
      await tester.pump();
      expect(c.swing(3, c.now)?.swipe, isTrue, reason: '손을 대면 칼을 빼 든다');
      expect(c.judge.judged, 0, reason: '손을 댄 것만으로는 판정하지 않는다');
      await g.moveBy(const Offset(60, 0));
      expect(c.judge.hits, 0, reason: '거리가 모자라면 아직 아니다');
      await g.moveBy(const Offset(260, 4));
      await tester.pump();
      expect(c.judge.hits, 1);
      expect(c.pops.single.rating.isHit, isTrue);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('보스전: 하트가 보이고, 박자에 맞춰 위로 밀면 막고, 가로로 밀면 못 막는다', (tester) async {
      // 빠른 곡(박자 0.15초): 첫 막기는 시작 후 약 1.5초, 두 번째는 약 2.4초
      final chart = RhythmChart.build(
        const [TutorialStage(title: '막기', hint: '', waves: [Motif.bossAttack, Motif.bossAttack])],
        bpm: 400,
        countIn: 1,
        hearts: 3,
      );
      final c = RhythmController(chart: chart, sfx: RecordingSfx());
      await pumpApp(tester, const Size(1000, 700), RhythmScreen(course: 3, controller: c, art: RhythmArt.empty()));
      expect(find.text('거대 슬라임'), findsOneWidget);
      expect(find.text('위로 쓱 = 막기'), findsOneWidget);
      await tester.tap(find.text('출발!'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3), reason: '하트 3개가 보인다');

      Future<void> waitUntil(double t) async {
        await tester.runAsync(() async {
          while (c.now < t) {
            await Future<void>.delayed(const Duration(milliseconds: 15));
            await tester.pump();
          }
        });
      }

      final g1 = chart.guards[0], g2 = chart.guards[1];
      // ① 첫 번째: 박자 조금 앞에 손을 대고(검을 든다), 위로 쓱 밀면 막는다
      await waitUntil(g1.time - 0.12);
      final up = await tester.startGesture(const Offset(300, 600));
      await tester.pump();
      expect(c.armedGuard, isTrue);
      expect(c.swing(3, c.now)?.guard, isTrue, reason: '손을 대면 검을 든다');
      await up.moveBy(const Offset(0, -30)); // 거리가 모자라면 아직
      expect(c.guardOutcome(g1), isNull);
      await up.moveBy(const Offset(10, -140));
      await tester.pump();
      expect(c.guardOutcome(g1)?.blocked, isTrue);
      expect(c.hearts, 3);
      await up.up();
      // ② 두 번째: 가로로 밀면 막지 못한다 → 하트가 깎인다
      await waitUntil(g2.time - 0.12);
      final side = await tester.startGesture(const Offset(300, 600));
      await tester.pump();
      await side.moveBy(const Offset(260, 0));
      await tester.pump();
      expect(c.guardOutcome(g2), isNull, reason: '가로 밀기는 막기가 아니다');
      await side.up();
      await waitUntil(g2.time + 0.4);
      await tester.pump();
      expect(c.guardOutcome(g2)?.blocked, isFalse);
      expect(c.hearts, 2);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('보스전: 하트를 다 잃으면 게임 오버 카드가 뜨고 기록은 남지 않는다', (tester) async {
      final chart = RhythmChart.build(
        const [TutorialStage(title: '막기', hint: '', waves: [Motif.bossAttack, Motif.bossAttack, Motif.bossAttack])],
        bpm: 400,
        countIn: 1,
        hearts: 3,
      );
      final c = RhythmController(chart: chart, sfx: RecordingSfx());
      await pumpApp(tester, const Size(1000, 700), RhythmScreen(course: 3, controller: c, art: RhythmArt.empty()));
      await tester.tap(find.text('출발!'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        while (c.status == RhythmStatus.playing) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.gameOver, isTrue);
      expect(c.hearts, 0);
      expect(find.text('게임 오버'), findsOneWidget);
      expect(find.text('합격!'), findsNothing);
      expect(find.text('다시 도전!'), findsOneWidget);
      // 다시 도전하면 하트가 되돌아온다
      await tester.tap(find.text('다시 도전!'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.hearts, 3);
      expect(c.gameOver, isFalse);
      expect(find.text('게임 오버'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('세로 화면에서도 깨지지 않는다', (tester) async {
      final c = RhythmController(sfx: RecordingSfx());
      await pumpApp(tester, const Size(600, 1000), RhythmScreen(controller: c, autoStart: true, art: RhythmArt.empty()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.status, RhythmStatus.playing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('메뉴가 열리고 박자 보정 버튼이 있다', (tester) async {
      await pumpApp(tester, const Size(1000, 700), const RhythmMenuScreen());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('리듬 검사단'), findsWidgets);
      expect(find.text('훈련소 입소'), findsOneWidget);
      expect(find.textContaining('박자 보정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
