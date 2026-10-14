import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/date_format.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/goblet/core/goblet_ai.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/data/goblet_history.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/jigsaw/data/jigsaw_history.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_screen.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/data/sudoku_history.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/ui/game_screen.dart';
import 'package:tabgame/records/records_screen.dart';

Future<Widget> appWith(Widget home) async {
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

SudokuRecord sudokuRecord({int seconds = 245, int at = 1760000000000, int seed = 1}) {
  final p = PuzzleGenerator.generate(Difficulty.easy, rng: Random(seed));
  return SudokuRecord(
    at: at,
    difficulty: Difficulty.easy,
    seconds: seconds,
    mistakes: 1,
    hints: 2,
    givens: p.givensString,
    solution: p.solutionString,
  );
}

/// 비동기 작업(저장소·그림 그리기)이 끝날 때까지 기다리며 화면을 갱신한다.
Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 기록 화면에서 위쪽 게임 고르개를 눌러 [name] 게임으로 바꾼다.
Future<void> switchRecordsTo(WidgetTester tester, String name) async {
  await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
  await settle(tester, rounds: 6);
  await tester.tap(find.text(name).last);
  await settle(tester, rounds: 6);
}

void main() {
  group('날짜 표시', () {
    test('올해는 연도를 생략하고, 다른 해는 연도를 붙인다', () {
      final now = DateTime(2026, 10, 11);
      expect(formatDate(DateTime(2026, 10, 11, 16, 4).millisecondsSinceEpoch, now: now), '10월 11일 16:04');
      expect(formatDate(DateTime(2025, 1, 3, 9, 5).millisecondsSinceEpoch, now: now), '2025년 1월 3일 09:05');
    });
  });

  group('기록 저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('스도쿠: 최신 순으로 쌓이고 100개까지만 보관한다', () async {
      expect(await SudokuHistory.load(), isEmpty);
      for (var i = 0; i < 105; i++) {
        await SudokuHistory.add(sudokuRecord(seconds: i, at: i));
      }
      final list = await SudokuHistory.load();
      expect(list.length, SudokuHistory.maxEntries);
      expect(list.first.seconds, 104); // 가장 최근이 맨 위
      expect(list.last.seconds, 5);
      // 문제가 통째로 저장되어 있어서 같은 판을 만들 수 있다
      final r = list.first;
      expect(r.puzzle.givensString, r.givens);
      expect(r.puzzle.solutionString, r.solution);
    });

    test('직소퍼즐: 30개까지만 보관한다', () async {
      for (var i = 0; i < 33; i++) {
        await JigsawHistory.add(JigsawRecord(
          at: i,
          target: 24,
          pieces: 24,
          seconds: i,
          source: const JigsawSource('sample', 'sunset'),
        ));
      }
      final list = await JigsawHistory.load();
      expect(list.length, JigsawHistory.maxEntries);
      expect(list.first.seconds, 32);
      expect(list.first.canReplay, isTrue);
      expect(
        const JigsawRecord(at: 0, target: 12, pieces: 12, seconds: 1, source: JigsawSource.none)
            .canReplay,
        isFalse,
      );
    });

    test('고블렛: 결과 해석 (CPU 대전 승패, 무승부)', () async {
      await GobbletHistory.add(const GobbletRecord(
        at: 1, vsCpu: true, winner: Team.blue, moves: 9, level: CpuLevel.hard, human: Team.blue));
      await GobbletHistory.add(const GobbletRecord(
        at: 2, vsCpu: true, winner: Team.red, moves: 7, level: CpuLevel.hard, human: Team.blue));
      await GobbletHistory.add(const GobbletRecord(at: 3, vsCpu: false, winner: null, moves: 30));
      final list = await GobbletHistory.load();
      expect(list.map((r) => r.at), [3, 2, 1]);
      expect(list[2].humanWon, isTrue);
      expect(list[1].humanWon, isFalse);
      expect(list[0].isDraw, isTrue);
      expect(list[0].humanWon, isNull);
      expect(list[1].level, CpuLevel.hard);
    });
  });

  group('기록 보드 화면', () {
    testWidgets('게임이 많아도 이름이 잘리지 않는다: 위에 이름이 통째로 보이고, 누르면 모든 게임이 목록으로 나온다', (tester) async {
      addTearDown(tester.view.reset);
      for (final size in const [Size(360, 740), Size(800, 1280)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const SizedBox()); // 앞 크기에서 바뀐 화면 상태가 남지 않게
        await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'ultimate_tictactoe')));
        await settle(tester, rounds: 3);
        // 긴 이름도 통째로 보인다
        expect(find.text('궁극 틱택토'), findsOneWidget);
        // 눌러서 목록을 열면 모든 게임이 보이고, 고르면 그 게임으로 바뀐다
        await tester.tap(find.text('궁극 틱택토'));
        await settle(tester, rounds: 6);
        for (final name in ['스도쿠', '프리셀', '지뢰찾기', '솔리테어', '직소퍼즐', '겟 컬러', '궁극 틱택토', '고블렛', '콩나물', '민들레']) {
          expect(find.text(name), findsWidgets, reason: name);
        }
        await tester.tap(find.text('민들레').last);
        await settle(tester, rounds: 6);
        expect(find.text('민들레'), findsOneWidget); // 위에 고른 게임 이름
        expect(find.text('10/10'), findsOneWidget);
        // 옆 화살표로 이웃 게임으로
        await tester.tap(find.byTooltip('다음 게임'));
        await settle(tester, rounds: 6);
        expect(find.text('스도쿠'), findsOneWidget);
        expect(find.text('1/10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('스도쿠: 요약과 목록이 보이고, "다시 풀기"는 같은 판을 연다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rec = sudokuRecord();
      SharedPreferences.setMockInitialValues({
        'sudoku.history': jsonEncode([rec.toJson()]),
        'sudoku.easy.wins': 3,
        'sudoku.easy.best': 200,
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'sudoku')));
      await settle(tester, rounds: 4);

      expect(find.text('내 기록'), findsOneWidget);
      expect(find.text('03:20'), findsOneWidget); // 쉬움 최고 기록 (200초)
      expect(find.textContaining('완성 3번'), findsOneWidget);
      expect(find.text('쉬움 · 04:05'), findsOneWidget);
      expect(find.textContaining('실수 1 · 힌트 2'), findsOneWidget);
      // 다른 난이도로 거르면 목록이 비어 안내가 나온다
      await tester.tap(find.widgetWithText(ChoiceChip, '어려움'));
      await tester.pump();
      expect(find.text('쉬움 · 04:05'), findsNothing);
      expect(find.text('이 난이도로 완성한 판이 아직 없어요.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
      await tester.pump();

      await tester.tap(find.text('다시 풀기'));
      await settle(tester, rounds: 4);
      final screen = tester.widget<SudokuGameScreen>(find.byType(SudokuGameScreen));
      expect(screen.game.puzzle.givensString, rec.givens);
      expect(screen.game.puzzle.solutionString, rec.solution);
      expect(screen.game.mistakes, 0); // 처음부터
      expect(screen.game.values, screen.game.puzzle.givens);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('스도쿠: 이어하던 판이 있으면 덮어쓸지 먼저 묻는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rec = sudokuRecord();
      final inProgress = SudokuGame(puzzle: PuzzleGenerator.generate(Difficulty.medium, rng: Random(5)));
      SharedPreferences.setMockInitialValues({
        'sudoku.history': jsonEncode([rec.toJson()]),
        'sudoku.save': jsonEncode(inProgress.toJson()),
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'sudoku')));
      await settle(tester, rounds: 4);
      await tester.tap(find.text('다시 풀기'));
      await settle(tester, rounds: 3);
      expect(find.text('이어하던 판이 있어요'), findsOneWidget);
      expect(find.byType(SudokuGameScreen), findsNothing);
      // 취소하면 아무 일도 없다
      await tester.tap(find.text('취소'));
      await settle(tester, rounds: 3);
      expect(find.byType(SudokuGameScreen), findsNothing);
      // 새로 시작을 고르면 시작한다
      await tester.tap(find.text('다시 풀기'));
      await settle(tester, rounds: 3);
      await tester.tap(find.text('새로 시작'));
      await settle(tester, rounds: 4);
      expect(find.byType(SudokuGameScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('직소퍼즐: 조각 수별 요약과 목록이 보이고, "다시 하기"는 같은 그림·조각 수로 시작한다',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const rec = JigsawRecord(
        at: 1760000000000,
        target: 24,
        pieces: 24,
        seconds: 312,
        source: JigsawSource('sample', 'sunset'),
      );
      SharedPreferences.setMockInitialValues({
        'jigsaw.history': jsonEncode([rec.toJson()]),
        'jigsaw.best.24': 300,
        'jigsaw.wins.24': 2,
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'jigsaw')));
      await settle(tester, rounds: 6);

      expect(find.text('05:00'), findsOneWidget); // 24조각 최고 기록
      expect(find.text('24조각 · 05:12'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);

      await tester.tap(find.text('다시 하기'));
      for (var i = 0; i < 60 && find.byType(JigsawScreen).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final screen = tester.widget<JigsawScreen>(find.byType(JigsawScreen));
      expect(screen.session.pieceTarget, 24);
      expect(screen.session.source.ref, 'sunset');
      expect(screen.session.controller.geometry.count, 24);
      expect(screen.session.controller.placedCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('직소퍼즐: 그림이 남아 있지 않은 기록은 다시 할 수 없다고 알려준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const rec = JigsawRecord(
        at: 1760000000000,
        target: 12,
        pieces: 12,
        seconds: 90,
        source: JigsawSource('file', '/없는/경로/사진.jpg'),
      );
      SharedPreferences.setMockInitialValues({
        'jigsaw.history': jsonEncode([rec.toJson()]),
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'jigsaw')));
      await settle(tester, rounds: 5);
      await tester.tap(find.text('다시 하기'));
      await settle(tester, rounds: 8);
      expect(find.textContaining('그림 파일을 찾을 수 없어서'), findsOneWidget);
      expect(find.byType(JigsawScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('고블렛: CPU 전적과 2인 요약, 최근 결과가 보인다 (다시 하기는 없다)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const records = [
        GobbletRecord(at: 4, vsCpu: false, winner: null, moves: 40),
        GobbletRecord(at: 3, vsCpu: false, winner: Team.red, moves: 11),
        GobbletRecord(at: 2, vsCpu: true, winner: Team.red, moves: 8, level: CpuLevel.normal, human: Team.blue),
        GobbletRecord(at: 1, vsCpu: true, winner: Team.blue, moves: 9, level: CpuLevel.normal, human: Team.blue),
      ];
      SharedPreferences.setMockInitialValues({
        'goblet.history': jsonEncode([for (final r in records) r.toJson()]),
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'goblet_gobblers')));
      await settle(tester, rounds: 4);

      expect(find.text('1승 1패 0무'), findsOneWidget); // CPU 보통
      expect(find.text('아직 기록이 없어요'), findsNWidgets(2)); // CPU 쉬움·어려움
      expect(find.text('총 판 수'), findsOneWidget);
      expect(find.text('이겼어요 · CPU 보통'), findsOneWidget);
      expect(find.text('졌어요 · CPU 보통'), findsOneWidget);
      expect(find.text('빨강팀 승리'), findsOneWidget);
      expect(find.text('무승부'), findsWidgets);
      expect(find.text('다시 하기'), findsNothing);
      expect(find.text('다시 풀기'), findsNothing);
    });

    testWidgets('예전에 완성한 기록(요약만 있는 경우)은 이유를 설명해 준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'sudoku.hard.wins': 1, 'sudoku.hard.best': 591});
      await tester.pumpWidget(await appWith(const RecordsScreen()));
      await settle(tester, rounds: 4);
      expect(find.text('09:51'), findsOneWidget);
      expect(find.textContaining('판 목록 기능이 생기기 전에'), findsOneWidget);
    });

    testWidgets('기록이 없으면 안내 문구가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const RecordsScreen()));
      await settle(tester, rounds: 4);
      expect(find.textContaining('아직 완성한 판이 없어요'), findsOneWidget);
      await switchRecordsTo(tester, '고블렛');
      expect(find.textContaining('아직 끝낸 판이 없어요'), findsOneWidget);
    });

    const sizes = {
      '폰 세로': Size(360, 640),
      '태블릿 가로': Size(1280, 800),
      '작은 가로': Size(800, 500),
    };
    sizes.forEach((name, size) {
      testWidgets('$name: 기록 화면이 넘치지 않는다 (세 탭 모두)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({
          'sudoku.history': jsonEncode([sudokuRecord().toJson()]),
          'jigsaw.history': jsonEncode([
            const JigsawRecord(
              at: 1760000000000, target: 48, pieces: 48, seconds: 3725,
              source: JigsawSource('sample', 'garden'),
            ).toJson(),
          ]),
          'goblet.history': jsonEncode([
            const GobbletRecord(
              at: 1760000000000, vsCpu: true, winner: Team.blue, moves: 14,
              level: CpuLevel.hard, human: Team.blue, byReveal: true,
            ).toJson(),
          ]),
        });
        await tester.pumpWidget(await appWith(const RecordsScreen()));
        await settle(tester, rounds: 4);
        expect(tester.takeException(), isNull);
        await switchRecordsTo(tester, '직소퍼즐');
        expect(tester.takeException(), isNull);
        await switchRecordsTo(tester, '고블렛');
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('판이 끝나면 기록이 남는다', () {
    testWidgets('스도쿠: 완성하면 문제·시간·실수·힌트가 기록된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final game = SudokuGame(
        puzzle: PuzzleGenerator.generate(Difficulty.easy, rng: Random(9)),
        autoStep: const Duration(milliseconds: 5),
      );
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(home: SudokuGameScreen(game: game)),
      ));
      game.elapsed.value = 123;
      var guard = 0;
      while (!game.completed && guard++ < 400) {
        if (game.autoCompleting) {
          await tester.pump(const Duration(milliseconds: 20));
          continue;
        }
        game.requestHint();
        game.applyHint();
      }
      expect(game.completed, isTrue);
      await settle(tester, rounds: 4);
      final list = await tester.runAsync(SudokuHistory.load);
      expect(list!.length, 1);
      expect(list.first.seconds, 123);
      expect(list.first.difficulty, Difficulty.easy);
      expect(list.first.givens, game.puzzle.givensString);
      expect(list.first.hints, greaterThan(0));
      // 완성 화면이 뜨기까지의 대기 시간을 지나 보낸 뒤 정리한다
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('고블렛: 승부가 나면 한 번만 기록된다 (CPU 대전은 내 입장의 결과)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final c = GobbletController(mode: PlayMode.local2p);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(home: GobbletScreen(controller: c)),
      ));
      void mv(int from, int to, int size) {
        final id = from < 0 ? c.reserveFront(c.turn, size)! : c.topAt(from)!;
        c.select(id);
        c.dropPiece(id, to);
      }

      mv(-1, 0, 3);
      mv(-1, 3, 3);
      mv(-1, 1, 3);
      mv(-1, 4, 3);
      mv(-1, 2, 2); // 빨강 승리
      expect(c.isOver, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // 화면이 그려지는 동안 알림이 더 와도 한 번만 기록된다
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester, rounds: 3);
      final list = await tester.runAsync(GobbletHistory.load);
      expect(list!.length, 1);
      expect(list.first.winner, Team.red);
      expect(list.first.vsCpu, isFalse);
      expect(list.first.moves, 5);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
