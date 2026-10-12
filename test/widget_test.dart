import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tabgame/app.dart';
import 'package:tabgame/core/settings.dart';

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
    expect(find.text('얼티밋 틱택토'), findsOneWidget);
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
    await tester.ensureVisible(find.text('얼티밋 틱택토'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('얼티밋 틱택토'));
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

    await tester.tap(find.text('얼티밋 틱택토'));
    await tester.pumpAndSettle();
    expect(find.text('CPU와 대결'), findsOneWidget);

    await tester.tap(find.text('CPU와 대결'));
    await tester.pumpAndSettle();
    expect(find.text('내 표시'), findsOneWidget);
    expect(find.text('CPU 난이도'), findsOneWidget);
  });

  testWidgets('아직 만들지 않은 게임은 준비 중 화면으로 간다', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final settings = await Settings.load();
    await tester.pumpWidget(TabGameApp(settings: settings));

    await tester.ensureVisible(find.text('핀볼'));
    await tester.tap(find.text('핀볼'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 만드는 중'), findsOneWidget);
  });
}
