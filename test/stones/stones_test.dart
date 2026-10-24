import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/stones/core/stones_rules.dart';
import 'package:tabgame/games/stones/ui/stones_board.dart';
import 'package:tabgame/games/stones/ui/stones_lesson_31.dart';
import 'package:tabgame/games/stones/ui/stones_lesson_screen.dart';
import 'package:tabgame/games/stones/ui/stones_menu.dart';
import 'package:tabgame/games/stones/ui/stones_screen.dart';

void main() {
  group('규칙', () {
    test('처음 판의 빈칸 수는 10, 8, 6이고 갑의 이기는 첫 수는 3행 흰 돌을 7칸으로', () {
      final s = kStartBoard.start();
      expect(s.gaps, [10, 8, 6]);
      expect(s.winningMoves(), [const StoneMove(2, 6)]);
    });

    test('문제 (1): 1행 흰 돌 4칸 → 6칸, 또는 3행 흰 돌 3칸 → 1칸 (뒤로 물러나기)', () {
      final s = kPuzzles[0].start();
      expect(s.gaps, [3, 1, 0]);
      expect(s.winningMoves().toSet(), {const StoneMove(0, 5), const StoneMove(2, 0)});
    });

    test('문제 (2): 2행 검은 돌 → 9칸, 또는 3행 검은 돌 → 12칸 (뒤로 물러나기)', () {
      final s = kPuzzles[1].start();
      expect(s.turn, Side.black);
      expect(s.winningMoves().toSet(), {const StoneMove(1, 8), const StoneMove(2, 11)});
    });

    test('문제 (3): 1행 검은 돌 12칸 → 9칸만 이긴다', () {
      final s = kPuzzles[2].start();
      expect(s.winningMoves(), [const StoneMove(0, 8)]);
    });

    test('돌을 건너뛸 수 없다', () {
      final s = StonesState([2, 0, 0], [5, 11, 11]);
      expect(s.targets(0), [0, 1, 3, 4]);
      expect(s.targets(0, Side.black), [3, 4, 6, 7, 8, 9, 10, 11]);
    });

    test('모두 붙어 벽에 닿으면 흰 돌은 움직일 수 없다', () {
      final s = StonesState([0, 0, 0], [1, 1, 1]);
      expect(s.isOver, isTrue);
      expect(s.winner, Side.black);
    });

    test('빈칸이 0, 0, 0이면 승부가 정해지고, 남은 수를 두면 차례였던 쪽이 진다', () {
      for (final turn in Side.values) {
        final s = StonesState([3, 5, 9], [4, 6, 10], turn: turn);
        expect(s.isDecided, isTrue);
        final moves = s.finishMoves();
        expect(moves.length, lessThanOrEqualTo(6));
        for (final m in moves) {
          s.apply(m);
        }
        expect(s.isOver, isTrue);
        expect(s.winner, turn.other);
      }
      expect(kStartBoard.start().isDecided, isFalse);
    });

    test('2진법 자리마다 1의 개수: 10, 8, 6 → 8 자리 2개, 4 자리 1개, 2 자리 2개, 1 자리 0개', () {
      expect(kStartBoard.start().bitCounts, [2, 1, 2, 0]);
    });

    test('31 게임: 컴퓨터는 열쇠 수(4로 나눈 나머지 2)에 닿을 수 있으면 거기서 멈춘다', () {
      final rng = Random(0);
      expect(cpu31(0, rng), 2);
      expect(cpu31(27, rng), 30);
      expect(cpu31(23, rng), 26);
      expect(cpu31(30, rng), 31);
    });

    test('컴퓨터끼리 두면 이기는 쪽(처음 판의 갑)이 끝내 이긴다', () {
      for (var seed = 0; seed < 30; seed++) {
        final rng = Random(seed);
        final s = kStartBoard.start();
        var n = 0;
        while (!s.isOver) {
          s.apply(s.cpuMove(rng));
          n++;
          expect(n, lessThan(500));
        }
        expect(s.winner, Side.white);
      }
    });
  });

  group('화면', () {
    testWidgets('빈칸이 0, 0, 0이 되면 남은 수를 자동으로 둬서 끝낸다', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const p = StonesPuzzle(title: '시험', question: '', white: [1, 1, 1], black: [3, 2, 2], turn: Side.white);
      await tester.pumpWidget(const MaterialApp(home: StonesScreen(mode: PlayMode.local2p, puzzle: p)));
      // 1행 흰 돌을 2칸으로 → 0, 0, 0 (을 차례) → 을이 지고 갑이 이긴다
      final board = tester.getRect(find.descendant(of: find.byType(StonesBoard), matching: find.byType(CustomPaint)).first);
      final cell = board.height / 4;
      await tester.tapAt(board.topLeft + Offset(cell * 2.5, cell * 1.5));
      await tester.pump();
      expect(find.textContaining('자동으로 둬요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('갑의 승리!'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('교과학습 단원들이 모두 열린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: StonesLessonScreen()));
      await tester.tap(find.textContaining('1. 님(Nim) 게임이란?'));
      await tester.pumpAndSettle();
      for (var i = 1; i < 7; i++) {
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.textContaining('다음:'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('다음:'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
      expect(tester.takeException(), isNull);
    });


    testWidgets('메뉴에서 문제 (1)을 열어 정답을 두면 "정답!"이 뜬다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: StonesMenuScreen(mode: PlayMode.local2p)));
      await tester.tap(find.text('문제 (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(StonesScreen), findsOneWidget);
      // 1행 6칸을 누른다 (판 위치에서 칸 좌표를 계산)
      final board = tester.getRect(find.descendant(of: find.byType(StonesBoard), matching: find.byType(CustomPaint)).first);
      final cell = board.height / 4;
      await tester.tapAt(board.topLeft + Offset(cell * 6.5, cell * 1.5));
      await tester.pump();
      expect(find.text('정답! 이기는 수예요'), findsOneWidget);
      // 무르면 문제 처음으로 돌아간다
      await tester.tap(find.text('무르기'));
      await tester.pump();
      expect(find.text('정답! 이기는 수예요'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('돌을 끌어서 놓아도 옮겨지고, 갈 수 없는 칸에 놓으면 그대로다', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: StonesScreen(mode: PlayMode.local2p, puzzle: kPuzzles[0])));
      final board = tester.getRect(find.descendant(of: find.byType(StonesBoard), matching: find.byType(CustomPaint)).first);
      final cell = board.height / 4;
      Offset at(int row, int col) => board.topLeft + Offset(cell * (col + 1.5), cell * (row + 1.5));
      // 1행 흰 돌(4칸)을 검은 돌(8칸) 너머로 끌면 놓이지 않는다
      await tester.dragFrom(at(0, 3), at(0, 9) - at(0, 3));
      await tester.pump();
      expect(find.text('정답! 이기는 수예요'), findsNothing);
      // 6칸에 놓으면 정답
      final g = await tester.startGesture(at(0, 3));
      // (한 번에 한 칸씩 크게 움직여도 처음 댄 돌을 잡는다)
      for (var k = 1; k <= 2; k++) {
        await g.moveTo(Offset.lerp(at(0, 3), at(0, 5), k / 2)!);
        await tester.pump();
      }
      await g.up();
      await tester.pump();
      expect(find.text('정답! 이기는 수예요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CPU와 할 때 컴퓨터가 자기 차례에 둔다', (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: StonesScreen(mode: PlayMode.vsCpu, puzzle: kStartBoard, cpuSide: Side.white, seed: 1)));
      expect(find.textContaining('생각하고 있어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('나 을(검은 돌) 차례'), findsOneWidget);
      final undo = tester.widget<ButtonStyleButton>(find.ancestor(of: find.text('무르기'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(undo.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
