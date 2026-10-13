import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/ui/board_widget.dart';
import 'package:tabgame/games/sudoku/ui/game_screen.dart';

Future<SudokuGame> pumpGame(WidgetTester tester, Size size, {int seed = 5}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  final game = SudokuGame(
    puzzle: PuzzleGenerator.generate(Difficulty.medium, rng: Random(seed)),
  );
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SudokuGameScreen(game: game),
      ),
    ),
  );
  await tester.pump();
  return game;
}

/// 보드 위의 칸 [cell] 중앙 좌표.
Offset cellCenter(WidgetTester tester, int cell) {
  final box = tester.getRect(find.byType(SudokuBoard));
  final size = min(box.width, box.height);
  final cs = size / 9;
  return box.topLeft + Offset((cell % 9 + 0.5) * cs, (cell ~/ 9 + 0.5) * cs);
}

Future<void> closeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  const sizes = {
    '폰 세로': Size(360, 640),
    '폰 세로(긴 화면)': Size(412, 915),
    '태블릿 세로': Size(800, 1280),
    '태블릿 가로': Size(1280, 800),
    '작은 가로': Size(800, 500),
  };

  sizes.forEach((name, size) {
    testWidgets('$name($size): 넘침 없이 그려진다 (힌트·메모 포함)', (tester) async {
      final game = await pumpGame(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(SudokuBoard), findsOneWidget);

      game.autoNotes();
      game.requestHint();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(game.hint, isNotNull);
      expect(find.byType(SudokuBoard), findsOneWidget);

      game.toggleQuick();
      game.dismissHint();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });
  });

  sizes.forEach((name, size) {
    testWidgets('$name: 보드의 81칸 어디를 눌러도 선택된다 (맨 아래 줄 포함)', (tester) async {
      final game = await pumpGame(tester, size);
      final dead = <int>[];
      for (var cell = 0; cell < 81; cell++) {
        game.select(-1);
        final g = await tester.startGesture(cellCenter(tester, cell));
        await g.up();
        await tester.pump();
        if (game.selected != cell) dead.add(cell);
      }
      expect(dead, isEmpty, reason: '반응 없는 칸');
      await closeScreen(tester);
    });
  });

  testWidgets('칸을 누르고 숫자를 누르면 입력된다 (고전 방식)', (tester) async {
    final game = await pumpGame(tester, const Size(800, 1280));
    final cell = game.values.indexOf(0);
    final answer = game.puzzle.solution[cell];
    await tester.tapAt(cellCenter(tester, cell));
    await tester.pump();
    expect(game.selected, cell);
    await tester.tap(find.byKey(ValueKey('pad-$answer')));
    await tester.pump();
    expect(game.values[cell], answer);
    expect(game.mistakes, 0);
    await closeScreen(tester);
  });

  testWidgets('번개 토글: 숫자를 먼저 고르고 칸을 누르면 입력된다', (tester) async {
    final game = await pumpGame(tester, const Size(800, 1280));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(game.quickMode, isTrue);

    final cell = game.values.indexOf(0);
    final answer = game.puzzle.solution[cell];
    await tester.tap(find.byKey(ValueKey('pad-$answer')));
    await tester.pump();
    expect(game.quickDigit, answer);
    expect(game.values[cell], 0);

    await tester.tapAt(cellCenter(tester, cell));
    await tester.pump();
    expect(game.values[cell], answer);
    await closeScreen(tester);
  });

  testWidgets('틀린 숫자 3번이면 선택 대화상자가 뜬다', (tester) async {
    final game = await pumpGame(tester, const Size(800, 1280));
    final empties = [for (var i = 0; i < 81; i++) if (game.values[i] == 0) i];
    for (var k = 0; k < 3; k++) {
      final c = empties[k];
      final s = game.puzzle.solution[c];
      game.select(c);
      game.padDigit(s == 9 ? 1 : s + 1);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('실수 3번!'), findsOneWidget);
    expect(find.text('처음부터 다시하기'), findsOneWidget);
    expect(find.text('그래도 계속하기'), findsOneWidget);
    expect(find.text('다른 판으로 시작'), findsOneWidget);

    await tester.tap(find.text('처음부터 다시하기'));
    await tester.pumpAndSettle();
    expect(game.mistakes, 0);
    expect(game.values, game.puzzle.givens);
    await closeScreen(tester);
  });

  testWidgets('힌트를 계속 적용하면 완성되고 완성 대화상자가 뜬다', (tester) async {
    final game = await pumpGame(tester, const Size(800, 1280));
    var guard = 0;
    var sawBanner = false;
    while (!game.completed && guard++ < 400) {
      if (game.autoCompleting) {
        // 남은 칸을 자동으로 채우는 동안 안내 문구가 보인다
        await tester.pump(const Duration(milliseconds: 300));
        sawBanner = sawBanner || find.text('✨ 남은 칸을 자동으로 채워요').evaluate().isNotEmpty;
        continue;
      }
      game.requestHint();
      game.applyHint();
    }
    expect(game.completed, isTrue);
    expect(sawBanner, isTrue, reason: '자동 완성 안내가 떠야 한다');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('완성! 🎉'), findsOneWidget);
    await closeScreen(tester);
  });
}
