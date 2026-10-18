import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/sudoku/core/grid.dart';
import 'package:tabgame/games/sudoku/core/solver.dart';
import 'package:tabgame/games/sudoku/core/techniques.dart';
import 'package:tabgame/games/sudoku/tutorial/basic_lesson.dart';
import 'package:tabgame/games/sudoku/tutorial/basic_lesson_screen.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/tutorial/practice_menu_screen.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_examples.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_info.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_lesson_screen.dart';
import 'package:tabgame/games/sudoku/ui/board_widget.dart';
import 'package:tabgame/tutorial/tutorial_progress.dart';

import '../support/preview_kit.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('기본 규칙 튜토리얼 판', () {
    test('정답이 하나뿐이고, 싱글만으로 풀린다', () {
      final p = basicPuzzle();
      expect(BacktrackSolver.countSolutions(p.givens), 1);
      expect(BacktrackSolver.solve(p.givens), p.solution);
      expect(HumanSolver.grade(p.givens, maxLevel: 1).solved, isTrue);
    });

    test('단계마다 고른 칸이 설명대로의 칸이다', () {
      final p = basicPuzzle();
      List<int> emptiesIn(List<int> v, List<int> unit) => [
            for (final c in unit)
              if (v[c] == 0) c,
          ];
      final v = List<int>.of(p.givens);
      // 맨 아래 행에는 빈 칸이 하나뿐
      expect(emptiesIn(v, unitCells[rowOf[kLessonRowCell]]), [kLessonRowCell]);
      expect(p.solution[kLessonRowCell], 9);
      v[kLessonRowCell] = p.solution[kLessonRowCell];
      // 아래쪽 가운데 박스에도 빈 칸이 하나뿐
      expect(emptiesIn(v, unitCells[18 + boxOf[kLessonBoxCell]]), [kLessonBoxCell]);
      expect(p.solution[kLessonBoxCell], 9);
      v[kLessonBoxCell] = p.solution[kLessonBoxCell];
      // 가운데 칸은 후보가 하나뿐
      final g = CandidateGrid.fromValues(v);
      expect(digitsOf(g.cand[kLessonCrossCell]), [1]);
      v[kLessonCrossCell] = p.solution[kLessonCrossCell];
      // 메모 연습 칸은 후보 3·9
      final g2 = CandidateGrid.fromValues(v);
      expect(digitsOf(g2.cand[kLessonNoteCell]), [3, 9]);
    });
  });

  group('심화 기술 예제', () {
    test('모든 기술에 예제가 있다', () {
      for (final info in kTechniqueInfos) {
        expect(kTechniqueExamples[info.technique], isNotEmpty, reason: info.label);
      }
    });

    for (final info in kTechniqueInfos) {
      test('${info.label}: 다음으로 쉬운 단계가 그 기술이고, 정답은 지우지 않는다', () {
        final examples = kTechniqueExamples[info.technique]!;
        for (final ex in examples) {
          final values = ex.valueList;
          expect(values.length, 81);
          expect(BacktrackSolver.countSolutions(values), 1, reason: '정답이 하나여야 해요');
          final solution = BacktrackSolver.solve(values)!;
          final g = CandidateGrid.fromValues(values, eliminated: ex.elimList);
          // 이미 지운 후보가 정답을 건드리면 안 된다
          for (var i = 0; i < 81; i++) {
            if (values[i] == 0) {
              expect(g.cand[i] & bit(solution[i]), isNot(0), reason: '칸 $i의 정답 후보');
            }
          }
          final step = StepFinder.next(g, maxLevel: 9);
          expect(step, isNotNull);
          expect(step!.technique, info.technique);
          if (info.placeOne) {
            expect(step.isPlacement, isTrue);
            expect(solution[step.placeCell], step.placeDigit);
          } else if (!info.fill) {
            // 후보 지우기 단계: 지우는 후보는 정답이 아니어야 하고, 실제로 지울 게 있어야 한다
            expect(step.eliminations, isNotEmpty);
            step.eliminations.forEach((cell, mask) {
              expect(mask & bit(solution[cell]), 0);
              expect(g.cand[cell] & mask, isNot(0));
            });
          }
        }
      });
    }
  });

  // 여러 기기 크기와 큰 글자 설정에서도 끝까지 진행되고, 그동안 화면이 넘치지 않는다.
  for (final (name, size, scale) in const [
    ('태블릿 세로', Size(450, 900), 1.0),
    ('폰 세로', Size(360, 740), 1.0),
    ('작은 폰 + 큰 글자', Size(360, 640), 1.4),
    ('폰 가로', Size(800, 360), 1.0),
    ('태블릿 가로', Size(1280, 800), 1.0),
  ]) {
    testWidgets('기본 규칙 튜토리얼을 끝까지 진행할 수 있다 ($name)', (tester) async {
      await playBasicLesson(tester, size, scale);
    });
  }

  techniqueLessonTests();
}

Future<void> playBasicLesson(WidgetTester tester, Size size, double textScale) async {
  {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SudokuBasicLessonScreen(firstTime: true),
      ),
    );
    await tester.pump();
    final game = tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;
    final steps = basicSteps();

    Future<void> next() async {
      await tester.tap(find.text('다음'));
      await tester.pump();
    }

    // 읽기만 하는 다섯 장
    for (var i = 0; i < 5; i++) {
      expect(find.text(steps[i].title), findsOneWidget);
      await next();
    }

    // 칸 선택: 목표를 이루기 전에는 넘어갈 수 없다
    expect(find.text('칸을 눌러 보세요'), findsOneWidget);
    expect(find.text('직접 해 보세요'), findsOneWidget);
    expect(find.text('다음'), findsNothing);
    game.strokeDown(kLessonRowCell);
    game.strokeEnd();
    await tester.pump();
    await next();

    // 숫자 넣기 ①: 틀린 숫자는 이유를 알려 주고 곧 지워진다
    expect(find.text('숫자를 넣어 보세요 (1)'), findsOneWidget);
    game.padDigit(5);
    await tester.pump();
    expect(game.values[kLessonRowCell], 5);
    expect(find.textContaining('같은 행에 이미 있어서'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(game.values[kLessonRowCell], 0);
    expect(game.mistakes, 0);
    game.padDigit(9);
    await tester.pump();
    expect(find.textContaining('정답이에요'), findsOneWidget);
    await next();

    // 숫자 넣기 ②
    expect(find.text('숫자를 넣어 보세요 (2)'), findsOneWidget);
    game.padDigit(9);
    await tester.pump();
    await next();

    // 행·열·박스
    expect(find.text('행·열·박스를 함께 봐요'), findsOneWidget);
    await tester.tap(find.text('도와줘요'));
    await tester.pump();
    expect(find.textContaining('이 숫자들을 뺀 나머지'), findsOneWidget);
    game.padDigit(1);
    await tester.pump();
    await next();

    // 일부러 틀리기 → 지우기
    expect(find.text('일부러 틀려 볼까요?'), findsOneWidget);
    final wrongCell = game.selected;
    game.padDigit(game.puzzle.solution[wrongCell] % 9 + 1);
    await tester.pump();
    expect(game.isWrong(wrongCell), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(game.isWrong(wrongCell), isTrue, reason: '이 단계에서는 틀린 칸을 자동으로 지우지 않아요');
    expect(game.mistakes, 1);
    await next();
    expect(find.text('지우기와 취소'), findsOneWidget);
    game.erase();
    await tester.pump();
    await next();

    // 메모
    expect(find.text('메모로 후보를 적어요'), findsOneWidget);
    expect(game.mistakes, 0);
    game.toggleNotes();
    game.padDigit(3);
    await tester.pump();
    expect(find.text('직접 해 보세요'), findsOneWidget);
    game.padDigit(9);
    await tester.pump();
    await next();

    // 빠른 메모
    expect(find.text('빠른 메모'), findsWidgets);
    game.autoNotes();
    await tester.pump();
    await next();

    // 힌트
    expect(find.text('막힐 땐 힌트'), findsOneWidget);
    game.requestHint();
    await tester.pump();
    expect(game.hint, isNotNull);
    game.applyHint();
    await tester.pump();
    await next();

    // 알아두면 좋은 기능 → 마지막 장
    await next();
    expect(find.text('기본 규칙 끝!'), findsOneWidget);
    expect(find.text('스도쿠 시작하기'), findsOneWidget);
    expect(find.text('심화 기술 연습하기'), findsOneWidget);
    await tester.tap(find.text('스도쿠 시작하기'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await TutorialProgress.doneLessons(), contains('sudoku_basic'));
    expect(tester.takeException(), isNull);
  }
}

// ── 심화 기술 연습 화면 ──

Future<SudokuGame> _openLesson(WidgetTester tester, int index) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: SudokuTechniqueLessonScreen(index: index)));
  await tester.pump();
  return tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;
}

void techniqueLessonTests() {
  for (var i = 0; i < kTechniqueInfos.length; i++) {
    final info = kTechniqueInfos[i];
    testWidgets('${info.label} 연습을 끝까지 할 수 있다', (tester) async {
      var game = await _openLesson(tester, i);
      // 개념 → 직접 해 보기
      expect(find.text(info.label), findsWidgets);
      expect(find.text('직접 해 보기'), findsOneWidget);
      expect(game.hint, isNotNull, reason: '예제 패턴이 판에 표시돼야 해요');
      await tester.tap(find.text('직접 해 보기'));
      await tester.pump();
      expect(game.hint, isNull);
      expect(game.notesMode, !info.fill && !info.placeOne);

      if (info.fill) {
        // 싱글: 힌트 사다리로 칸을 알아내 3개를 채운다
        for (var n = 0; n < 3; n++) {
          final g = CandidateGrid.fromValues(game.values, eliminated: game.hintElims);
          final s = StepFinder.next(g, maxLevel: 1)!;
          game.select(s.placeCell);
          game.padDigit(s.placeDigit);
          await tester.pump();
        }
      } else if (info.placeOne) {
        // 정답 한 칸 찾기 (BUG+1)
        final g = CandidateGrid.fromValues(game.values, eliminated: game.hintElims);
        final s = StepFinder.next(g, maxLevel: 9)!;
        game.select(s.placeCell);
        game.padDigit(s.placeDigit);
        await tester.pump();
      } else {
        // 후보 지우기: 정답이 아닌 후보를 지운다
        final g = CandidateGrid.fromValues(game.values, eliminated: game.hintElims);
        final s = StepFinder.next(g, maxLevel: 9)!;
        s.eliminations.forEach((cell, mask) {
          game.select(cell);
          for (final d in digitsOf(mask)) {
            game.padDigit(d);
          }
        });
        await tester.pump();
      }
      expect(find.text('잘했어요! 🎉'), findsOneWidget);
      expect(await TutorialProgress.doneLessons(), contains(info.id));
      game = tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;
    });
  }

  testWidgets('정답 후보를 지우면 되돌려 놓는다', (tester) async {
    final game = await _openLesson(tester, 4); // 네이키드 페어
    await tester.tap(find.text('직접 해 보기'));
    await tester.pump();
    var cell = -1;
    for (var i = 0; i < 81; i++) {
      if (game.values[i] == 0) {
        cell = i;
        break;
      }
    }
    final d = game.puzzle.solution[cell];
    game.select(cell);
    game.padDigit(d);
    await tester.pump();
    expect(game.notes[cell] & bit(d), isNot(0));
    expect(find.textContaining('지우면 안 돼요'), findsOneWidget);
  });

  testWidgets('힌트 사다리: 힌트 → 더 알려줘요 → 정답대로 해 줘요', (tester) async {
    final game = await _openLesson(tester, 2); // 포인팅
    await tester.tap(find.text('직접 해 보기'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '힌트'));
    await tester.pump();
    expect(game.hint?.visualOnly, isTrue);
    expect(game.hint!.removeMask, isEmpty, reason: '1단계에서는 지울 후보를 아직 가려요');
    await tester.tap(find.text('더 알려줘요'));
    await tester.pump();
    expect(game.hint!.removeMask, isNotEmpty);
    await tester.tap(find.text('정답대로 해 줘요'));
    await tester.pump();
    expect(find.text('잘했어요! 🎉'), findsOneWidget);
  });

  testWidgets('다음 기술로 넘어가고, 다른 예제로 한 번 더 할 수 있다', (tester) async {
    final game = await _openLesson(tester, 2);
    await tester.tap(find.text('직접 해 보기'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '힌트'));
    await tester.pump();
    await tester.tap(find.text('더 알려줘요'));
    await tester.pump();
    await tester.tap(find.text('정답대로 해 줘요'));
    await tester.pump();
    final before = game.puzzle.givensString;
    await tester.tap(find.text('다른 예제로 한 번 더'));
    await tester.pump();
    final after = tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;
    expect(after.puzzle.givensString, isNot(before));
    // 다른 예제는 정답(패턴·지울 후보) 표시 없이 바로 직접 해 보기로 시작한다
    expect(after.hint, isNull);
    expect(find.text('직접 해 보기'), findsOneWidget); // (설명 단계의 단추가 아니라 연습 카드의 제목)
    expect(find.widgetWithText(FilledButton, '직접 해 보기'), findsNothing);
    expect(find.textContaining('지워야 할 후보가'), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('연습 목록에 모든 기술이 보이고, 마친 기술에는 체크가 붙는다', (tester) async {
    tester.view.physicalSize = const Size(900, 9000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await TutorialProgress.markLessonDone('sudoku_xWing');
    await tester.pumpWidget(const MaterialApp(home: SudokuPracticeMenuScreen()));
    await tester.pumpAndSettle();
    for (final info in kTechniqueInfos) {
      expect(find.text(info.label), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('1 / ${kTechniqueInfos.length} 완료', findRichText: true), findsNothing);
    expect(find.textContaining('(1 / ${kTechniqueInfos.length} 완료)'), findsOneWidget);
  });
}
