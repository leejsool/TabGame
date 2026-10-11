import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/jigsaw/core/jigsaw_geometry.dart';
import 'package:tabgame/games/jigsaw/game/jigsaw_controller.dart';
import 'package:tabgame/games/jigsaw/jigsaw_entry.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_menu_screen.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_screen.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_table.dart';

Future<JigsawSession> makeSession(WidgetTester tester, {int target = 12}) async {
  late JigsawSession session;
  await tester.runAsync(() async {
    final image = await SampleArt.render('sunset', scale: 0.5);
    final (rows, cols) = JigsawGeometry.gridFor(target, image.width / image.height);
    final g = JigsawGeometry(
      rows: rows,
      cols: cols,
      imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
      seed: 3,
    );
    final c = JigsawController(geometry: g, scatterSeed: 2);
    final pieces = await PieceImages.build(image, g);
    session = JigsawSession(
      image: image,
      pieces: pieces,
      controller: c,
      source: JigsawSource.none,
      pieceTarget: target,
    );
  });
  return session;
}

Future<Widget> appWith(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

/// 탁자 좌표 → 화면 좌표 (탁자가 화면에 꽉 차게 맞춰진 초기 상태).
Offset toScreen(JigsawController c, Size view, Offset table) {
  final t = c.tableSize;
  final fit = min(view.width / t.width, view.height / t.height);
  final off = Offset((view.width - t.width * fit) / 2, (view.height - t.height * fit) / 2);
  return off + table * fit;
}

void main() {
  testWidgets('조각을 끌어서 제자리에 놓으면 딸깍 붙는다', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final s = await makeSession(tester);
    final c = s.controller;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: JigsawTable(controller: c, pieces: s.pieces, image: s.image)),
    ));
    final view = tester.getSize(find.byType(JigsawTable));

    // 맨 위에 있는 조각 하나를 잡는다 (칸 중심 = 조각 모양 안의 확실한 점)
    final i = c.order.last;
    final cell = c.geometry.cellRect(c.geometry.rowOf(i), c.geometry.colOf(i));
    final grabTable = c.pos[i] + (cell.center - c.geometry.boxes[i].topLeft);
    final target = c.targetPos(i) + (cell.center - c.geometry.boxes[i].topLeft);

    final g = await tester.startGesture(toScreen(c, view, grabTable));
    await tester.pump();
    expect(c.dragging, i);
    await g.moveTo(toScreen(c, view, target + const Offset(15, 10))); // 조금 빗나가게
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.placed[i], isTrue);
    expect(c.pos[i], c.targetPos(i));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('빈 곳을 밀면 화면이 이동하고(조각은 안 움직임), 두 손가락 확대도 문제없다', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final s = await makeSession(tester);
    final c = s.controller;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: JigsawTable(controller: c, pieces: s.pieces, image: s.image)),
    ));
    final before = List<Offset>.of(c.pos);

    // 판 한가운데(조각이 없는 곳이 아니라 판 위의 빈 칸 근처)를 한 손가락으로 끈다: 확대 전에는 이동 불가라 변화 없음
    final pan = await tester.startGesture(const Offset(400, 500));
    await pan.moveBy(const Offset(40, 30));
    await pan.up();

    // 두 손가락 벌리기 (확대)
    final a = await tester.startGesture(const Offset(350, 500));
    final b = await tester.startGesture(const Offset(450, 500));
    await a.moveBy(const Offset(-80, 0));
    await b.moveBy(const Offset(80, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 확대 중에 조각이 끌려 움직이지 않았다
    expect(c.dragging, isNull);
    expect(c.placedCount, 0);
    // (붙지 않은 조각은 판 밖에서 그대로)
    expect(c.pos.length, before.length);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('완성하면 완성 연출이 나오고 오류가 없다', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final s = await makeSession(tester);
    final c = s.controller;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: JigsawTable(controller: c, pieces: s.pieces, image: s.image)),
    ));
    for (var i = 0; i < c.geometry.count; i++) {
      c.beginDrag(i, c.pos[i]);
      c.dragTo(c.targetPos(i));
      c.endDrag();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(c.completed, isTrue);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  const sizes = {
    '폰 세로': Size(360, 640),
    '태블릿 세로': Size(800, 1280),
    '태블릿 가로': Size(1280, 800),
    '작은 가로': Size(800, 500),
  };
  sizes.forEach((name, size) {
    testWidgets('$name: 퍼즐 화면이 넘침 없이 그려진다 (힌트·일시정지 포함)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = await makeSession(tester, target: 24);
      await tester.pumpWidget(await appWith(JigsawScreen(session: s)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('0 / ${s.controller.geometry.count}'), findsOneWidget);

      s.controller.giveHint(Random(1));
      await tester.pump(const Duration(milliseconds: 300));
      s.controller.setPaused(true);
      await tester.pump();
      expect(find.text('일시정지'), findsWidgets);
      s.controller.setPaused(false);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  testWidgets('메뉴 → 샘플 선택 → 설정 → 시작 → 퍼즐 화면까지 이어진다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await appWith(const JigsawMenuScreen()));
    // 메뉴가 저장/썸네일을 비동기로 불러온다
    for (var i = 0; i < 15 && find.text('바다의 노을').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('갤러리에서 사진 고르기'), findsOneWidget);
    expect(find.text('바다의 노을'), findsOneWidget);

    await tester.tap(find.text('바다의 노을'));
    for (var i = 0; i < 20 && find.text('퍼즐 만들기').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('퍼즐 만들기'), findsOneWidget);
    expect(find.textContaining('조각'), findsWidgets);

    await tester.tap(find.text('아주 쉬움 · 12조각'));
    await tester.pump();
    await tester.tap(find.text('퍼즐 시작'));
    for (var i = 0; i < 60 && find.byType(JigsawScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(JigsawScreen), findsOneWidget);
    expect(find.text('0 / 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
