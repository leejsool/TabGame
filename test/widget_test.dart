import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tabgame/app.dart';
import 'package:tabgame/core/dev_unlock.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/game_registry.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('허브에 게임 목록이 보이고, 필터가 동작한다', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));

    expect(find.text('스도쿠'), findsOneWidget);
    expect(find.text('고블렛 고블러스'), findsOneWidget);

    await tester.tap(find.byTooltip('함께'));
    await tester.pumpAndSettle();
    expect(find.text('스도쿠'), findsNothing);
    expect(find.text('궁극 틱택토'), findsOneWidget);
  });

  testWidgets('폰 세로·작은 화면에서도 허브가 넘치지 않는다', (tester) async {
    final settings = await Settings.load();
    for (final size in const [Size(360, 640), Size(800, 500), Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(TabGameApp(settings: settings));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
      // 끝까지 스크롤해도 넘침이 없어야 한다
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size (스크롤 후)');
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('아주 낮은 화면에서도 모드 선택창이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(533, 333);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));
    await tester.tap(find.byTooltip('함께')); // 화면이 낮아 "함께 놀기" 카드만 보이게 한다
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('궁극 틱택토'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('궁극 틱택토'));
    await tester.pumpAndSettle();
    expect(find.text('CPU와 대결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2인 게임은 모드 선택 후 설정 화면으로 간다', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));

    await tester.tap(find.text('궁극 틱택토'));
    await tester.pumpAndSettle();
    expect(find.text('CPU와 대결'), findsOneWidget);

    await tester.tap(find.text('CPU와 대결'));
    await tester.pumpAndSettle();
    // 처음 여는 게임이라 게임 방법 안내가 먼저 나오고, 건너뛸 수 있다 (자세한 건 tutorial/first_run_test.dart)
    expect(find.text('궁극 틱택토 게임 방법'), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('내 표시'), findsOneWidget);
    expect(find.text('CPU 난이도'), findsOneWidget);
  });

  testWidgets('다듬는 중인 게임(핀볼·리듬 검사단)은 허브 카드에 beta 표시가 붙는다', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));

    await tester.ensureVisible(find.text('핀볼'));
    expect(find.text('beta'), findsWidgets);
    expect(allGames.where((g) => g.beta).map((g) => g.id), containsAll(['pinball', 'rhythm_swords']));
  });

  testWidgets('정식 앱에서 핀볼은 닫혀 있고, 카드를 10번 연달아 누르면 열린다', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    DevUnlock.reset();
    addTearDown(DevUnlock.reset);

    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));
    final pinball = allGames.firstWhere((g) => g.id == 'pinball');
    expect(pinball.locked, isTrue);

    await tester.ensureVisible(find.text('핀볼'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.text('핀볼'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('아직 만들고 있는 게임이에요'), findsOneWidget);
    expect(find.text('도전 시작'), findsNothing);

    await tester.tap(find.text('핀볼'));
    await tester.pumpAndSettle();
    expect(pinball.locked, isFalse);
    expect(find.text('건너뛰기'), findsOneWidget, reason: '열리면 처음엔 게임 방법이 먼저 나와요');
  });

  test('닫힌 카드는 쉬엄쉬엄 누르면 처음부터 다시 센다', () {
    DevUnlock.reset();
    addTearDown(DevUnlock.reset);
    final t0 = DateTime(2026);
    for (var i = 0; i < 9; i++) {
      expect(DevUnlock.tap('x', now: t0.add(Duration(milliseconds: 300 * i))), isFalse);
    }
    // 한참 쉬었다가 누르면 다시 1번째
    final late = t0.add(const Duration(seconds: 10));
    for (var i = 0; i < 9; i++) {
      expect(DevUnlock.tap('x', now: late.add(Duration(milliseconds: 300 * i))), isFalse);
    }
    expect(DevUnlock.tap('x', now: late.add(const Duration(milliseconds: 2700))), isTrue);
  });
}
