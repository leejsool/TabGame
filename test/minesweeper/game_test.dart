import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/minesweeper/core/mines_rules.dart';
import 'package:tabgame/games/minesweeper/data/mines_storage.dart';
import 'package:tabgame/games/minesweeper/game/mines_controller.dart';
import 'package:tabgame/games/minesweeper/ui/mines_board.dart';
import 'package:tabgame/games/minesweeper/ui/mines_menu_screen.dart';
import 'package:tabgame/games/minesweeper/ui/mines_painter.dart';
import 'package:tabgame/games/minesweeper/ui/mines_records_tab.dart';
import 'package:tabgame/games/minesweeper/ui/mines_screen.dart';

/// 초급 판에 지뢰를 직접 정해 둔 컨트롤러.
MinesController fixed(List<int> mines, {MinesLevel level = MinesLevel.beginner}) {
  final b = MinesBoard(level.rows, level.cols, mines.length)..setMines(mines);
  return MinesController(level: level, board: b);
}

Future<void> pumpScreen(WidgetTester tester, Size size, MinesController c) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MinesScreen(controller: c),
      ),
    ),
  );
  await tester.pump();
}

/// 화면에서 [cell]번 칸의 가운데.
Offset cellCenter(WidgetTester tester, MinesController c, int cell) {
  final view = find.byType(MinesBoardView);
  final layout = MinesLayout(tester.getSize(view), c.board.rows, c.board.cols);
  return tester.getTopLeft(view) + layout.rect(cell).center;
}

void main() {
  group('컨트롤러', () {
    test('첫 칸은 늘 안전하고 시작을 알린다', () {
      final rng = Random(3);
      for (var t = 0; t < 40; t++) {
        final c = MinesController(level: MinesLevel.intermediate, rng: rng);
        var starts = 0;
        c.onStarted = () => starts++;
        final first = rng.nextInt(c.board.size);
        c.tap(first);
        expect(c.status == MinesStatus.playing || c.status == MinesStatus.won, isTrue);
        expect(c.board.mine[first], isFalse);
        expect(starts, 1);
        c.tap((first + 1) % c.board.size); // 두 번째 탭은 시작을 다시 알리지 않는다
        expect(starts, 1);
        c.dispose();
      }
    });

    test('시작 전에는 깃발을 꽂을 수 없다', () {
      final c = MinesController(level: MinesLevel.beginner);
      c.longPress(0);
      expect(c.board.flagCount, 0);
      c.dispose();
    });

    test('깃발 모드에서는 탭이 깃발, 깃발 칸은 열리지 않는다', () {
      final c = fixed([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      c.toggleFlagMode();
      c.tap(40);
      expect(c.board.marks[40], CellMark.flagged);
      expect(c.minesLeft, 9);
      c.toggleFlagMode();
      c.tap(40); // 깃발 칸은 열기로 열리지 않는다
      expect(c.board.marks[40], CellMark.flagged);
      c.longPress(40);
      expect(c.board.marks[40], CellMark.hidden);
      c.dispose();
    });

    test('지뢰를 밟으면 지고, 이후에는 입력을 받지 않는다', () {
      final c = fixed([40]);
      var lost = 0;
      c.onLost = () => lost++;
      c.tap(40);
      expect(c.status, MinesStatus.lost);
      expect(lost, 1);
      expect(c.canAct, isFalse);
      c.tap(0);
      expect(c.board.marks[0], CellMark.hidden);
      c.dispose();
    });

    test('모두 열면 이기고 지뢰에 깃발이 모두 꽂힌다', () {
      final c = fixed([80]);
      var won = 0;
      c.onWon = () => won++;
      c.tap(0); // 구석에서 열면 연쇄로 거의 다 열린다
      expect(c.status, MinesStatus.won);
      expect(won, 1);
      expect(c.board.marks[80], CellMark.flagged);
      expect(c.minesLeft, 0);
      c.dispose();
    });

    test('숫자 칸 탭(코드)', () {
      final c = fixed([0]);
      c.tap(40); // 연쇄로 대부분 열린다
      expect(c.board.marks[1], CellMark.revealed); // 칸 1은 숫자 1
      c.longPress(0);
      expect(c.board.marks[0], CellMark.flagged);
      c.tap(1); // 깃발 수 == 숫자 → 이웃을 한꺼번에 연다 (이미 열려 있어도 오류 없이)
      expect(c.status, MinesStatus.won);
      c.dispose();
    });

    test('저장했다가 불러오면 같은 판', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      c.tap(0);
      expect(c.status, MinesStatus.playing);
      c.longPress(36);
      c.elapsed.value = 61;
      final r = MinesController.fromJson(c.toJson());
      expect(r.level, c.level);
      expect(r.board.mine, c.board.mine);
      expect(r.board.marks, c.board.marks);
      expect(r.board.revealedCount, c.board.revealedCount);
      expect(r.board.flagCount, 1);
      expect(r.elapsed.value, 61);
      expect(r.status, MinesStatus.playing);
      c.dispose();
      r.dispose();
    });

    test('새 판은 처음 상태', () {
      final c = fixed([40]);
      c.tap(0);
      c.restart();
      expect(c.status, MinesStatus.ready);
      expect(c.board.minesPlaced, isFalse);
      expect(c.board.revealedCount, 0);
      c.dispose();
    });

    test('힌트: 시작 전엔 안내, 진행 중엔 안내 문구', () {
      final c = MinesController(level: MinesLevel.beginner);
      c.requestHint();
      expect(c.hint, isNull);
      expect(c.hintMessage, contains('첫 칸'));
      c.tap(40);
      c.requestHint();
      expect(c.hintMessage, isNotNull);
      c.dispose();
    });
  });

  group('화면', () {
    for (final size in const [Size(360, 740), Size(800, 1280), Size(1280, 800), Size(640, 360)]) {
      for (final level in MinesLevel.values) {
        testWidgets('넘치지 않고 그려진다 $size ${level.label}', (tester) async {
          final c = MinesController(level: level, rng: Random(5));
          await pumpScreen(tester, size, c);
          expect(tester.takeException(), isNull);
          expect(find.text('지뢰찾기'), findsOneWidget);
          await tester.tapAt(cellCenter(tester, c, c.board.size ~/ 2));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          expect(c.status == MinesStatus.playing || c.status == MinesStatus.won, isTrue);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('칸을 누르면 열리고, 길게 누르면 깃발이 꽂힌다', (tester) async {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      await pumpScreen(tester, const Size(800, 1280), c);
      await tester.tapAt(cellCenter(tester, c, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.board.marks[0], CellMark.revealed);
      expect(c.status, MinesStatus.playing);
      // 지뢰가 있는 칸에 깃발
      await tester.longPressAt(cellCenter(tester, c, 36));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.board.marks[36], CellMark.flagged);
      expect(tester.widget<Text>(find.byKey(const ValueKey('mines-left'))).data, '8');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('지뢰를 밟으면 터지는 연출 뒤 결과 창이 뜬다', (tester) async {
      final c = fixed([40]);
      await pumpScreen(tester, const Size(800, 1280), c);
      await tester.tapAt(cellCenter(tester, c, 40));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.status, MinesStatus.lost);
      await tester.pump(const Duration(milliseconds: 3200));
      expect(find.text('펑! 💥'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('다시 하기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.status, MinesStatus.ready);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('이기면 기록이 남고 클리어 창이 뜬다', (tester) async {
      final c = fixed([80]);
      await pumpScreen(tester, const Size(800, 1280), c);
      await tester.tapAt(cellCenter(tester, c, 0));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.status, MinesStatus.won);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.text('클리어! 🎉'), findsOneWidget);
      final list = await tester.runAsync(MinesStorage.loadHistory);
      expect(list!.length, 1);
      expect(list.first.level, MinesLevel.beginner);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('깃발 모드 버튼과 힌트 버튼', (tester) async {
      final c = fixed([0, 80]);
      await pumpScreen(tester, const Size(800, 1280), c);
      await tester.tap(find.text('깃발'));
      await tester.pump();
      expect(c.flagMode, isTrue);
      await tester.tap(find.text('열기'));
      await tester.pump();
      expect(c.flagMode, isFalse);
      await tester.tap(find.text('힌트'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.hintMessage, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('메뉴/기록', () {
    testWidgets('메뉴에 세 난이도가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const MinesMenuScreen()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      for (final l in MinesLevel.values) {
        expect(find.text(l.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    test('기록 저장: 난이도별 최고 기록', () async {
      SharedPreferences.setMockInitialValues({});
      await MinesStorage.recordStart(MinesLevel.beginner);
      await MinesStorage.recordStart(MinesLevel.beginner);
      final a = await MinesStorage.recordWin(const MinesRecord(at: 1, level: MinesLevel.beginner, seconds: 80));
      final b = await MinesStorage.recordWin(const MinesRecord(at: 2, level: MinesLevel.beginner, seconds: 95));
      final c = await MinesStorage.recordWin(const MinesRecord(at: 3, level: MinesLevel.expert, seconds: 400));
      expect((a, b, c), (true, false, true));
      final s = await MinesStorage.stats(MinesLevel.beginner);
      expect((s.starts, s.wins, s.bestSeconds), (2, 2, 80));
      expect((await MinesStorage.loadHistory()).map((r) => r.seconds), [400, 95, 80]);
    });

    testWidgets('기록 탭이 클리어한 판을 보여준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await MinesStorage.recordWin(MinesRecord(
            at: DateTime.now().millisecondsSinceEpoch, level: MinesLevel.intermediate, seconds: 123));
      });
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: MinesRecordsTab()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.textContaining('중급 · 02:03'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
