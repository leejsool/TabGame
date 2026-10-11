import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/goblet/core/goblet_ai.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_stage.dart';

/// 컨트롤러로 한 수 둔다. place: from = -1.
bool mv(GobbletController c, int from, int to, int size) {
  final id = from < 0 ? c.reserveFront(c.turn, size) : c.topAt(from);
  if (id == null) return false;
  c.select(id);
  return c.dropPiece(id, to);
}

Future<GobbletController> pumpScreen(
  WidgetTester tester,
  Size size, {
  PlayMode mode = PlayMode.local2p,
  Team human = Team.red,
  CpuLevel level = CpuLevel.easy,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  final c = GobbletController(mode: mode, humanTeam: human, level: level);
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: GobbletScreen(controller: c),
      ),
    ),
  );
  await tester.pump();
  return c;
}

StageMetrics metricsOf(WidgetTester tester) =>
    StageMetrics.compute(tester.getSize(find.byType(GobbletStage)));

Offset stageOrigin(WidgetTester tester) => tester.getTopLeft(find.byType(GobbletStage));

Offset cellPos(WidgetTester tester, int cell) =>
    stageOrigin(tester) + metricsOf(tester).boardPieceCenter(cell);

Finder pieceFinder(PieceId id) => find.byKey(ValueKey('piece-$id'));

Future<void> closeScreen(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// 말이 움직이는 애니메이션이 끝날 때까지 기다린다. (pump 한 번은 애니메이션을 시작만 시킨다)
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// CPU가 수를 둘 때까지 기다린다. (대기 시간은 테스트 시계로, 계산은 실제 시간으로 흐른다)
Future<void> waitForCpu(WidgetTester tester, GobbletController c) async {
  for (var i = 0; i < 20 && c.thinking; i++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('컨트롤러', () {
    test('말을 놓으면 위치·차례가 바뀌고, 덮인 말은 아래에 쌓인다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      expect(c.turn, Team.red);
      expect(mv(c, -1, 4, 1), isTrue); // 빨강 작은 말 → 가운데
      expect(c.turn, Team.blue);
      expect(mv(c, -1, 4, 2), isTrue); // 파랑 중간 말이 덮는다
      final stack = c.stackAt(4);
      expect(stack.length, 2);
      expect(teamOfPiece(stack.first), Team.red);
      expect(teamOfPiece(stack.last), Team.blue);
      expect(c.isCovered(stack.first), isTrue);
      expect(c.isSelectable(stack.first), isFalse);
    });

    test('규칙에 안 맞는 수는 거부된다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 4, 3); // 빨강 큰 말
      expect(mv(c, -1, 4, 2), isFalse); // 작은 말로 큰 말을 덮을 수 없다
      expect(c.turn, Team.blue);
      // 상대(빨강) 말은 파랑 차례에 집을 수 없다
      final redBig = c.topAt(4)!;
      expect(c.isSelectable(redBig), isFalse);
    });

    test('같은 크기 말 2개는 번호 순서대로 나온다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      final first = c.reserveFront(Team.red, 2)!;
      mv(c, -1, 0, 2);
      expect(c.loc[first], 0);
      final second = c.reserveFront(Team.red, 2)!;
      expect(second, isNot(first));
      expect(c.reserveRank(second), 0);
    });

    test('줄을 만들면 승리한다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 0, 3); // 빨강
      mv(c, -1, 3, 3); // 파랑
      mv(c, -1, 1, 3); // 빨강
      mv(c, -1, 4, 3); // 파랑
      mv(c, -1, 2, 2); // 빨강 → [0,1,2]
      expect(c.isOver, isTrue);
      expect(c.result!.winner, Team.red);
      expect(c.result!.line, [0, 1, 2]);
      expect(c.humanCanAct, isFalse);
    });

    test('말을 들어 올려 상대 줄이 드러나면 상대가 이긴다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 0, 2); // 빨강
      mv(c, -1, 0, 3); // 파랑이 덮음 (파랑 큰 말 아래 빨강 중간)
      mv(c, -1, 4, 1); // 빨강
      mv(c, -1, 1, 3); // 파랑 → 파랑 큰 말이 0, 1
      mv(c, -1, 5, 1); // 빨강
      mv(c, 1, 8, 3); // 파랑이 큰 말을 옮김
      mv(c, -1, 1, 2); // 빨강
      expect(c.isOver, isFalse);
    });

    test('같은 모양이 3번 반복되면 무승부', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 0, 1); // 빨강
      mv(c, -1, 8, 1); // 파랑
      for (var i = 0; i < 2; i++) {
        mv(c, 0, 1, 1);
        mv(c, 8, 7, 1);
        mv(c, 1, 0, 1);
        mv(c, 7, 8, 1);
      }
      expect(c.result?.kind, ResultKind.draw);
    });

    test('되돌리기 (2인): 한 수씩', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 4, 3);
      mv(c, -1, 0, 1);
      c.undo();
      expect(c.turn, Team.blue);
      expect(c.loc.where((l) => l >= 0).length, 1);
      c.undo();
      expect(c.turn, Team.red);
      expect(c.loc.every((l) => l == -1), isTrue);
      expect(c.canUndo, isFalse);
    });

    test('새 판은 선공을 번갈아 하고 모든 말이 대기로 돌아간다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      mv(c, -1, 4, 3);
      c.restart();
      expect(c.turn, Team.blue);
      expect(c.loc.every((l) => l == -1), isTrue);
      expect(c.result, isNull);
    });
  });

  group('화면', () {
    const sizes = {
      '폰 세로': Size(360, 640),
      '태블릿 세로': Size(800, 1280),
      '태블릿 가로': Size(1280, 800),
      '작은 가로': Size(800, 500),
    };
    sizes.forEach((name, size) {
      testWidgets('$name: 넘침 없이 그려지고 말 12개가 보인다', (tester) async {
        final c = await pumpScreen(tester, size);
        expect(tester.takeException(), isNull);
        for (var id = 0; id < 12; id++) {
          expect(pieceFinder(id), findsOneWidget);
        }
        mv(c, -1, 4, 3);
        mv(c, -1, 4, 1); // 불가: 거부됨
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await closeScreen(tester);
      });
    });

    testWidgets('말을 누르고 칸을 누르면 옮겨진다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      final id = c.reserveFront(Team.red, 3)!;
      await tester.tap(pieceFinder(id));
      await tester.pump();
      expect(c.selected, id);
      expect(c.targets.length, 9);

      await tester.tapAt(cellPos(tester, 4));
      await settle(tester);
      expect(c.loc[id], 4);
      expect(c.turn, Team.blue);
      await closeScreen(tester);
    });

    testWidgets('말을 끌어서 칸에 놓으면 옮겨지고, 안 되는 칸에 놓으면 제자리로 돌아간다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      // 빨강 큰 말을 가운데에 둔다
      mv(c, -1, 4, 3);
      await settle(tester);
      // 파랑 중간 말을 끌어서 큰 말 위(불가)에 놓기
      final blueMid = c.reserveFront(Team.blue, 2)!;
      final start = tester.getCenter(pieceFinder(blueMid));
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(cellPos(tester, 4));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await settle(tester);
      expect(c.loc[blueMid], -1);
      expect(c.turn, Team.blue);

      // 빈 칸(칸 0)에는 놓을 수 있다
      final g2 = await tester.startGesture(tester.getCenter(pieceFinder(blueMid)));
      await g2.moveTo(cellPos(tester, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await g2.up();
      await settle(tester);
      expect(c.loc[blueMid], 0);
      expect(c.turn, Team.red);
      await closeScreen(tester);
    });

    testWidgets('승리하면 결과 대화상자가 뜬다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      mv(c, -1, 0, 3);
      mv(c, -1, 3, 3);
      mv(c, -1, 1, 3);
      mv(c, -1, 4, 3);
      mv(c, -1, 2, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.textContaining('빨강팀 승리'), findsWidgets);
      expect(find.text('한 판 더'), findsOneWidget);
      await tester.tap(find.text('한 판 더'));
      await settle(tester);
      expect(c.result, isNull);
      await closeScreen(tester);
    });

    testWidgets('CPU 대전: 내가 두면 CPU가 응답하고, 되돌리기는 내 수까지 되돌린다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280), mode: PlayMode.vsCpu);
      expect(c.humanCanAct, isTrue);
      mv(c, -1, 4, 2);
      expect(c.thinking, isTrue);
      expect(c.humanCanAct, isFalse);
      // 생각하는 동안에는 말을 집을 수 없다
      expect(c.isSelectable(c.reserveFront(Team.red, 3)!), isFalse);

      await waitForCpu(tester, c);
      expect(c.thinking, isFalse);
      expect(c.turn, Team.red);
      expect(c.loc.where((l) => l >= 0).length, 2);

      c.undo();
      expect(c.loc.every((l) => l == -1), isTrue);
      expect(c.turn, Team.red);
      await closeScreen(tester);
    });

    testWidgets('CPU 대전: 파랑을 고르면 CPU(빨강)가 먼저 둔다', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280),
          mode: PlayMode.vsCpu, human: Team.blue);
      await tester.pump(); // start() 호출
      expect(c.thinking, isTrue);
      await waitForCpu(tester, c);
      expect(c.loc.where((l) => l >= 0).length, 1);
      expect(c.turn, Team.blue);
      expect(c.humanCanAct, isTrue);
      await closeScreen(tester);
    });
  });
}

