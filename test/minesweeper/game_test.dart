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

    test('소리 알림: 칸 열기는 reveal, 깃발은 flag, 물음표는 question0~2, 깃발·물음표를 뗄 때는 unmark', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      final kinds = <String>[];
      c.onFeedback = kinds.add;
      c.tap(0); // 시작 칸 열기
      expect(kinds.last, 'reveal');
      c.flag(72); // 깃발 꽂기
      expect(kinds.last, 'flag');
      c.flag(72); // 깃발 뽑기
      expect(kinds.last, 'unmark');
      c.question(72); // 물음표 달기
      expect(kinds.last, matches(RegExp(r'^question[012]$')));
      c.question(72); // 물음표 떼기
      expect(kinds.last, 'unmark');
      c.flag(72);
      c.question(72); // 깃발 칸에 물음표 (깃발은 뽑히고 물음표가 달린다)
      expect(kinds.last, matches(RegExp(r'^question[012]$')));
    });

    test('시작 전에는 깃발을 꽂을 수 없다', () {
      final c = MinesController(level: MinesLevel.beginner);
      c.flag(0);
      expect(c.board.flagCount, 0);
      c.dispose();
    });

    test('깃발 칸은 열기로 열리지 않고, 깃발 토글로 뽑을 수 있다', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      c.tap(0); // 시작
      c.flag(72);
      expect(c.board.marks[72], CellMark.flagged);
      expect(c.minesLeft, 8);
      c.tap(72); // 깃발 칸은 열기로 열리지 않는다
      expect(c.board.marks[72], CellMark.flagged);
      c.flag(72);
      expect(c.board.marks[72], CellMark.hidden);
      c.dispose();
    });

    test('물음표: 시작 전에는 달 수 없고, 달아도 지뢰 수·열기에 영향이 없다', () {
      final c = MinesController(level: MinesLevel.beginner);
      c.question(0);
      expect(c.board.marks[0], CellMark.hidden);
      c.dispose();

      final p = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      p.tap(0);
      p.question(72);
      expect(p.board.marks[72], CellMark.question);
      expect(p.minesLeft, 9); // 깃발이 아니라서 줄지 않는다
      p.tap(72); // 물음표 칸은 눌러서 열 수 있다
      expect(p.board.marks[72], CellMark.revealed);
      p.dispose();
    });

    test('깃발 칸에서 물음표로, 물음표 칸에서 깃발로 바꾸면 지뢰 수가 맞는다', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]);
      c.tap(0);
      c.flag(72);
      expect(c.minesLeft, 8);
      c.question(72); // 깃발 → 물음표
      expect(c.board.marks[72], CellMark.question);
      expect(c.minesLeft, 9);
      c.flag(72); // 물음표 → 깃발
      expect(c.board.marks[72], CellMark.flagged);
      expect(c.minesLeft, 8);
      c.tap(72); // 깃발 칸은 열리지 않는다
      expect(c.board.marks[72], CellMark.flagged);
      c.dispose();
    });

    test('물음표가 저장했다 불러와도 남는다', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]);
      c.tap(0);
      c.question(36);
      c.flag(37);
      final r = MinesController.fromJson(c.toJson());
      expect(r.board.marks[36], CellMark.question);
      expect(r.board.marks[37], CellMark.flagged);
      expect(r.board.flagCount, 1);
      c.dispose();
      r.dispose();
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
      c.flag(0);
      expect(c.board.marks[0], CellMark.flagged);
      c.tap(1); // 깃발 수 == 숫자 → 이웃을 한꺼번에 연다 (이미 열려 있어도 오류 없이)
      expect(c.status, MinesStatus.won);
      c.dispose();
    });

    test('저장했다가 불러오면 같은 판', () {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      c.tap(0);
      expect(c.status, MinesStatus.playing);
      c.flag(36);
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

    testWidgets('톡 치면 열기, 꾹 눌러 원형 메뉴: 위=열기 / 오른쪽 아래=깃발 / 왼쪽 아래=물음표 / 가운데=취소', (tester) async {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]); // 가운데 줄이 지뢰 벽: 위쪽만 열린다
      await pumpScreen(tester, const Size(800, 1280), c);

      Future<void> press(int cell, {Offset drag = Offset.zero, int holdMs = 0}) async {
        final g = await tester.startGesture(cellCenter(tester, c, cell));
        if (holdMs > 0) await tester.pump(Duration(milliseconds: holdMs));
        if (drag != Offset.zero) {
          await g.moveBy(drag ~/ 2);
          await g.moveBy(drag - drag ~/ 2);
        }
        await g.up();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await press(0); // 톡 치기 = 열기
      expect(c.board.marks[0], CellMark.revealed);
      expect(c.status, MinesStatus.playing);

      // 오른쪽 아래(깃발): 지뢰가 있는 칸
      await press(36, drag: const Offset(60, 30), holdMs: 300);
      expect(c.board.marks[36], CellMark.flagged);
      expect(tester.widget<Text>(find.byKey(const ValueKey('mines-left'))).data, '8');
      await press(36, drag: const Offset(90, 0)); // 바로 오른쪽도 깃발 조각: 한 번 더 하면 뽑힌다
      expect(c.board.marks[36], CellMark.hidden);

      // 왼쪽 아래(물음표): 남은 지뢰 수는 그대로
      await press(37, drag: const Offset(-60, 30), holdMs: 300);
      expect(c.board.marks[37], CellMark.question);
      expect(tester.widget<Text>(find.byKey(const ValueKey('mines-left'))).data, '9');
      await press(37, drag: const Offset(-90, 0));
      expect(c.board.marks[37], CellMark.hidden);

      // 가운데에서 떼면 취소 (메뉴가 뜬 뒤): 열리지도 표시되지도 않는다
      await press(72, holdMs: 500);
      expect(c.board.marks[72], CellMark.hidden);
      await press(72, drag: const Offset(10, 6), holdMs: 500);
      expect(c.board.marks[72], CellMark.hidden);

      // 깃발 칸은 열기 조각으로 열리지 않는다
      await press(36, drag: const Offset(60, 30), holdMs: 300);
      expect(c.board.marks[36], CellMark.flagged);
      await press(36, drag: const Offset(0, -80), holdMs: 300);
      expect(c.board.marks[36], CellMark.flagged);
      expect(c.status, MinesStatus.playing);

      // 위쪽으로 밀면 열기 (남은 칸이 다 열려서 이긴다)
      await press(72, drag: const Offset(0, -80), holdMs: 300);
      expect(c.board.marks[72], CellMark.revealed);
      expect(c.status, MinesStatus.won);
      // 클리어 연출과 결과 창이 끝나도록 기다린다
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 3200));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('두 손가락으로 누르면 칸이 열리지 않는다 (확대/이동용)', (tester) async {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]);
      await pumpScreen(tester, const Size(800, 1280), c);
      final g1 = await tester.startGesture(cellCenter(tester, c, 0), pointer: 1);
      final g2 = await tester.startGesture(cellCenter(tester, c, 3), pointer: 2);
      await g1.up();
      await g2.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.board.marks[0], CellMark.hidden);
      expect(c.board.marks[3], CellMark.hidden);
      expect(c.board.revealedCount, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('확대했을 때 이미 열린 칸을 잡고 끌면 화면이 움직이고(칸은 눌리지 않고), 닫힌 칸을 끌면 움직이지 않는다', (tester) async {
      final c = fixed([36, 37, 38, 39, 40, 41, 42, 43, 44]);
      await pumpScreen(tester, const Size(800, 1280), c);
      await tester.tapAt(cellCenter(tester, c, 0)); // 위쪽이 열린다
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.board.marks[0], CellMark.revealed);
      final zoom = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
      Offset t() => Offset(zoom.value.entry(0, 3), zoom.value.entry(1, 3));
      zoom.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0); // 2배 확대 (왼쪽 위 기준)
      await tester.pump();
      final view = tester.getTopLeft(find.byType(MinesBoardView));
      Offset onScreen(int cell) => view + (cellCenter(tester, c, cell) - view) * 2;

      // 열린 칸을 잡고 왼쪽 위로 끌기
      final flaggedBefore = c.board.flagCount;
      final g = await tester.startGesture(onScreen(10));
      await g.moveBy(const Offset(-30, -20));
      await g.moveBy(const Offset(-50, -40));
      await g.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(t().dx, closeTo(-80, 1));
      expect(t().dy, closeTo(-60, 1));
      expect(c.board.flagCount, flaggedBefore);

      // 판 가장자리 밖으로는 안 나간다
      final g2 = await tester.startGesture(onScreen(10));
      await g2.moveBy(const Offset(-3000, -3000));
      await g2.up();
      await tester.pump();
      final area = tester.getSize(find.byType(MinesBoardView));
      expect(t().dx, closeTo(-area.width, 1));
      expect(t().dy, closeTo(-area.height, 1));

      // 닫힌 칸(깃발·열기 메뉴용)을 끌면 화면은 그대로
      zoom.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      await tester.pump();
      final g3 = await tester.startGesture(onScreen(72));
      await g3.moveBy(const Offset(-60, -40));
      await g3.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(t(), Offset.zero);
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

    testWidgets('아래에는 힌트·새 판 버튼만 있다 (열기/깃발 모드 버튼은 없다)', (tester) async {
      final c = fixed([0, 80]);
      await pumpScreen(tester, const Size(800, 1280), c);
      expect(find.text('깃발'), findsNothing);
      expect(find.text('열기'), findsNothing);
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
