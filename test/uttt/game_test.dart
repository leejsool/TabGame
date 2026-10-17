import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/uttt/core/uttt_ai.dart';
import 'package:tabgame/games/uttt/core/uttt_rules.dart';
import 'package:tabgame/games/uttt/data/uttt_history.dart';
import 'package:tabgame/games/uttt/game/uttt_controller.dart';
import 'package:tabgame/games/uttt/ui/uttt_board.dart';
import 'package:tabgame/games/uttt/ui/uttt_records_tab.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_setup_screen.dart';

Future<UtttController> pumpScreen(
  WidgetTester tester,
  Size size, {
  PlayMode mode = PlayMode.local2p,
  int human = kX,
  UttLevel level = UttLevel.easy,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  final c = UtttController(mode: mode, humanSide: human, level: level);
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: UtttScreen(controller: c),
      ),
    ),
  );
  await tester.pump();
  return c;
}

/// 판 위의 칸 중심 좌표.
Offset cellPos(WidgetTester tester, int move) {
  final box = find.byType(UtttBoard);
  final size = tester.getSize(box);
  final side = size.width < size.height ? size.width : size.height;
  final layout = UtttLayout(side);
  final origin = tester.getTopLeft(find.descendant(of: find.byType(UtttBoard), matching: find.byType(CustomPaint)).first);
  return origin + layout.cellRect(move ~/ 9, move % 9).center;
}

Future<void> waitForCpu(WidgetTester tester, UtttController c) async {
  for (var i = 0; i < 20 && c.thinking; i++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('컨트롤러', () {
    test('2인: 수를 두면 차례가 바뀌고, 규칙에 어긋난 수는 거절한다', () {
      final c = UtttController(mode: PlayMode.local2p);
      expect(c.play(4 * 9 + 2), isTrue); // 가운데 판 오른쪽 위 칸 → 다음은 오른쪽 위 판
      expect(c.state.next, 2);
      expect(c.play(4 * 9 + 3), isFalse); // 엉뚱한 판
      expect(c.play(2 * 9 + 0), isTrue);
      expect(c.moveCount, 2);
      c.dispose();
    });

    test('2인: 되돌리기는 한 수씩', () {
      final c = UtttController(mode: PlayMode.local2p);
      c.play(0);
      c.play(1);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.moveCount, 1);
      c.undo();
      expect(c.moveCount, 0);
      expect(c.canUndo, isFalse);
      c.dispose();
    });

    test('판을 차지하면 lastCaptured가 알려준다', () {
      final c = UtttController(mode: PlayMode.local2p);
      // O가 0번 판의 3,4,5칸(가운데 줄)을 모두 차지한다.
      for (final m in [0, 3, 27, 4, 36, 5]) {
        expect(c.play(m), isTrue, reason: 'move $m');
      }
      expect(c.state.boardOwner(0), 2);
      expect(c.lastCaptured, 0);
      c.dispose();
    });

    test('새 판은 시작하는 쪽이 바뀐다', () {
      final c = UtttController(mode: PlayMode.local2p);
      c.play(0);
      c.restart();
      expect(c.moveCount, 0);
      expect(c.state.turn, kO);
      c.dispose();
    });
  });

  group('화면', () {
    for (final size in const [Size(360, 740), Size(800, 1280), Size(1280, 800), Size(640, 360)]) {
      testWidgets('넘치지 않고 그려진다 $size', (tester) async {
        final c = await pumpScreen(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.text('궁극 틱택토'), findsOneWidget);
        expect(find.textContaining('차례'), findsWidgets);
        c.play(40);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('칸을 누르면 수가 두어지고 안내가 바뀐다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      await tester.tapAt(cellPos(tester, 4 * 9 + 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.moveCount, 1);
      expect(c.state.next, 2);
      expect(find.textContaining('오른쪽 위 판'), findsOneWidget);
      // 엉뚱한 판의 칸은 무시된다
      await tester.tapAt(cellPos(tester, 5 * 9 + 5));
      await tester.pump();
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('되돌리기·새 판 버튼', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      await tester.tapAt(cellPos(tester, 40));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      expect(c.moveCount, 0);
      await tester.tapAt(cellPos(tester, 40));
      await tester.pump(const Duration(milliseconds: 400));
      // 하던 판이 있으면 새 판을 시작하기 전에 묻는다 (취소하면 하던 판 그대로)
      await tester.tap(find.text('새 판'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('새 판을 시작할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.moveCount, 1);
      await tester.tap(find.text('새 판'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('새 판')));
      await tester.pump();
      expect(c.moveCount, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CPU 대결: 내가 O면 CPU가 먼저 두고, 내 차례에 둘 수 있다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280),
          mode: PlayMode.vsCpu, human: kO, level: UttLevel.easy);
      expect(c.thinking, isTrue);
      await waitForCpu(tester, c);
      expect(c.moveCount, 1);
      expect(c.state.turn, kO);
      final move = c.state.legalMoves().first;
      await tester.tapAt(cellPos(tester, move));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.moveCount, 2);
      await waitForCpu(tester, c);
      expect(c.moveCount, 3);
      // 되돌리면 내 수와 CPU 응답이 함께 사라진다
      c.undo();
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('규칙 창이 뜬다', (tester) async {
      await pumpScreen(tester, const Size(360, 740));
      await tester.tap(find.byTooltip('규칙'));
      await tester.pump(const Duration(milliseconds: 400)); // 판의 반짝임은 끝나지 않으므로 settle 불가
      expect(find.text('궁극 틱택토 규칙'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('설정/기록', () {
    testWidgets('설정 화면: 선택하고 시작하면 대결 화면으로 간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const UtttSetupScreen()),
        ),
      );
      expect(find.text('내 표시'), findsOneWidget);
      await tester.tap(find.text('어려움'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('궁극 틱택토'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    test('기록 저장·불러오기', () async {
      SharedPreferences.setMockInitialValues({});
      await UtttHistory.add(const UtttRecord(at: 1, vsCpu: true, winner: kX, moves: 31, level: UttLevel.hard, human: kX));
      await UtttHistory.add(const UtttRecord(at: 2, vsCpu: false, winner: null, moves: 60));
      final list = await UtttHistory.load();
      expect(list.length, 2);
      expect(list.first.at, 2);
      expect(list.first.isDraw, isTrue);
      expect(list.last.humanWon, isTrue);
      expect(list.last.level, UttLevel.hard);
    });

    testWidgets('기록 탭이 전적을 보여준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await UtttHistory.add(UtttRecord(
            at: DateTime.now().millisecondsSinceEpoch,
            vsCpu: true,
            winner: kO,
            moves: 40,
            level: UttLevel.normal,
            human: kX));
      });
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: UtttRecordsTab()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('0승 1패 0무'), findsOneWidget);
      expect(find.textContaining('졌어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
