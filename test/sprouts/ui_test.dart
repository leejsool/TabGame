import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/sprouts/core/sprouts_ai.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/data/sprouts_history.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_board_view.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_records_tab.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_setup_screen.dart';

Future<Widget> app(Widget home, {Key? key}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return RepaintBoundary(
    key: key,
    child: SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
    ),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 판 좌표 → 화면 좌표 (SproutsBoardView 안에서 늘려 그리는 방식과 같다).
Offset toScreen(WidgetTester tester, P p) {
  final rect = tester.getRect(find.byType(SproutsBoardView));
  final b = tester.widget<SproutsBoardView>(find.byType(SproutsBoardView)).controller.board.bounds;
  final scale = min(rect.width / b.width, rect.height / b.height);
  final dx = (rect.width - b.width * scale) / 2;
  final dy = (rect.height - b.height * scale) / 2;
  return rect.topLeft + Offset(dx + (p.x - b.x0) * scale, dy + (p.y - b.y0) * scale);
}

Future<void> dragStroke(WidgetTester tester, List<P> pts) async {
  final g = await tester.startGesture(toScreen(tester, pts.first));
  for (final p in pts.skip(1)) {
    await g.moveTo(toScreen(tester, p));
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final dir = Platform.environment['SPROUTS_PREVIEW_DIR'];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  });

  for (final (name, size) in const [
    ('폰 세로', Size(360, 740)),
    ('태블릿 세로', Size(800, 1280)),
    ('태블릿 가로', Size(1280, 800)),
    ('작은 가로', Size(740, 360)),
  ]) {
    testWidgets('화면이 넘침 없이 그려진다 ($name)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, rng: Random(1));
      await tester.pumpWidget(await app(SproutsScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.text('콩나물'), findsOneWidget);
      expect(find.byType(SproutsBoardView), findsOneWidget);
      expect(find.textContaining('플레이어 1 차례'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('손가락으로 점에서 점으로 그으면 수가 두어지고, 점이 아닌 곳에서 시작하면 안내가 나온다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 3, rng: Random(5));
    await tester.pumpWidget(await app(SproutsScreen(controller: c)));
    await settle(tester, rounds: 2);

    // 빈 곳을 누르면 "점에서 시작해 주세요"
    final far = c.board.dots.every((d) => d.pos.dist(const P(200, 230)) > 60) ? const P(200, 230) : const P(380, 440);
    await tester.tapAt(toScreen(tester, far));
    await tester.pump();
    expect(find.textContaining('점에서 시작'), findsOneWidget);
    expect(c.moveCount, 0);

    final m = findMoves(c.board).firstWhere((m) => !m.isLoop);
    await dragStroke(tester, m.path);
    expect(c.moveCount, 1);
    expect(c.turn, 1);
    expect(c.board.dots.length, 4);
    expect(find.textContaining('플레이어 2 차례'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('다른 선을 가로지르는 선은 거절되고 이유가 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, rng: Random(8));
    final first = findMoves(c.board).firstWhere((m) => !m.isLoop);
    c.tryStroke(first.path);
    await tester.pumpWidget(await app(SproutsScreen(controller: c)));
    await settle(tester, rounds: 2);
    // 방금 그은 선의 한가운데를 지나가는 직선 (다른 점에서 출발해 그 선을 가로질러 끝점으로)
    final other = [for (var i = 0; i < c.board.dots.length; i++) i]
        .firstWhere((i) => i != first.s && i != first.e && c.board.dots[i].lives > 0);
    final a = c.board.dots[other].pos;
    final mid = first.path[first.path.length ~/ 2];
    final b = c.board.dots[first.e].pos;
    List<P> seg(P p, P q) => [for (var i = 0; i <= 30; i++) P(p.x + (q.x - p.x) * i / 30, p.y + (q.y - p.y) * i / 30)];
    await dragStroke(tester, [...seg(a, mid), ...seg(mid, b)]);
    expect(c.moveCount, 1); // 거절됨
    expect(c.message, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('자리가 좁아서 안 될 선도 기존 점을 살짝 밀어서 그을 수 있다 (밀리는 동안 화면이 깨지지 않는다)', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final board = SproutsBoard([
      Dot(const P(100, 200), 3),
      Dot(const P(300, 200), 3),
      Dot(const P(200, 214), 3), // 곧은 선이 15 거리로 지나간다
      Dot(const P(60, 380), 3),
    ], []);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, board: board);
    await tester.pumpWidget(await app(SproutsScreen(controller: c)));
    await settle(tester, rounds: 2);
    final before = c.board.dots[2].pos;
    await dragStroke(tester, [for (var i = 0; i <= 40; i++) P(100 + 200 * i / 40, 200)]);
    expect(c.moveCount, 1);
    expect(c.message, isNull);
    expect(c.morphFrom, isNotNull);
    expect(c.board.dots[2].pos.dist(before), greaterThan(3));
    await tester.pump(const Duration(milliseconds: 250)); // 옮겨 가는 중
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('힌트 → 그대로 그으면 수가 두어지고, 되돌리기·기권 단추가 동작한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 3, rng: Random(6));
    await tester.pumpWidget(await app(SproutsScreen(controller: c)));
    await settle(tester, rounds: 2);

    await tester.tap(find.text('힌트'));
    await tester.pump();
    expect(c.hintPath, isNotNull);
    await dragStroke(tester, c.hintPath!);
    expect(c.moveCount, 1);

    await tester.tap(find.text('되돌리기'));
    await tester.pump();
    expect(c.moveCount, 0);

    // 한 수 두고 기권
    await dragStroke(tester, findMoves(c.board).first.path);
    expect(c.moveCount, 1);
    await tester.tap(find.text('기권'));
    await tester.pumpAndSettle();
    expect(find.text('이 판을 기권할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '기권'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('기권했어요'), findsOneWidget);
    // 끝났다는 안내는 창이 아니라 아래 막대로: 그림을 가리지 않는다
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('한 판 더'), findsOneWidget);
    expect(find.text('메뉴로'), findsOneWidget);
    final h = await tester.runAsync(SproutsHistory.load);
    expect(h!.single.resigned, isTrue);
    expect(h.single.winner, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('설정 화면: 점의 수를 고르고 시작하면 그 수의 점으로 판이 열린다 (CPU 대결은 난이도·먼저/나중도)', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app(const SproutsSetupScreen(mode: PlayMode.vsCpu)));
    await settle(tester, rounds: 2);
    expect(find.text('CPU 난이도'), findsOneWidget);
    expect(find.text('튜토리얼 보기'), findsOneWidget);
    await tester.tap(find.text('4개'));
    await tester.pump();
    expect(find.textContaining('안에 끝나요'), findsNothing); // 수 제한 안내는 교과학습에서만
    await tester.tap(find.text('나중에 시작'));
    await tester.tap(find.text('쉬움'));
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final screen = tester.widget<SproutsScreen>(find.byType(SproutsScreen));
    expect(screen.dotCount, 4);
    expect(screen.humanSide, 1);
    expect(screen.level, SproutsLevel.easy);
    // 나중에 시작이라 CPU가 먼저 둔다: 끝나기를 기다렸다가 닫는다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('기록 탭: 전적과 기권 표시가 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await SproutsHistory.add(
        const SproutsRecord(at: 1760000000000, vsCpu: true, winner: 0, moves: 7, dots: 3, level: SproutsLevel.normal, human: 0));
    await SproutsHistory.add(const SproutsRecord(
        at: 1760000100000, vsCpu: true, winner: 1, moves: 4, dots: 3, level: SproutsLevel.normal, human: 0, resigned: true));
    await SproutsHistory.add(const SproutsRecord(at: 1760000200000, vsCpu: false, winner: 1, moves: 6, dots: 2));
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: const MaterialApp(home: Scaffold(body: SproutsRecordsTab())),
    ));
    await settle(tester);
    expect(find.text('1승 1패'), findsOneWidget);
    expect(find.text('기권했어요 · CPU 보통'), findsOneWidget);
    expect(find.text('포기'), findsOneWidget);
    expect(find.byTooltip('다시 도전'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그림 미리보기 이미지 만들기', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rng = Random(3);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, rng: rng);
    for (var i = 0; i < 4; i++) {
      final ms = findMoves(c.board);
      if (ms.isEmpty) break;
      c.tryStroke(ms[rng.nextInt(ms.length)].path);
    }
    c.showHint();
    final key = GlobalKey();
    await tester.pumpWidget(await app(SproutsScreen(controller: c), key: key));
    await settle(tester, rounds: 8);
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/sprouts_play.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  }, skip: dir == null);

  testWidgets('빽빽한 판 미리보기 이미지 만들기 (판이 넓어져 화면이 멀어진 모습)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rng = Random(2);
    final c = SproutsController(mode: PlayMode.local2p, dotCount: 8, rng: rng);
    var guard = 0;
    while (c.board.bounds.scale < 1.3 && guard++ < 40) {
      final ms = findMoves(c.board);
      if (ms.isEmpty) break;
      c.tryStroke(ms[rng.nextInt(ms.length)].path);
    }
    final key = GlobalKey();
    await tester.pumpWidget(await app(SproutsScreen(controller: c), key: key));
    await settle(tester, rounds: 10);
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/sprouts_big.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('판 범위: ${c.board.bounds}, 배율 ${c.board.bounds.scale.toStringAsFixed(2)}');
    await tester.pumpWidget(const SizedBox());
  }, skip: dir == null);
}
