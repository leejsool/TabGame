import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/rhythm/audio/rhythm_audio.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
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
