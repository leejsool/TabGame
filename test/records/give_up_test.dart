import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/data/freecell_storage.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_records_tab.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/data/goblet_history.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/jigsaw/data/jigsaw_history.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/minesweeper/core/mines_rules.dart';
import 'package:tabgame/games/minesweeper/data/mines_storage.dart';
import 'package:tabgame/games/minesweeper/game/mines_controller.dart';
import 'package:tabgame/games/minesweeper/ui/mines_records_tab.dart';
import 'package:tabgame/games/solitaire/data/solitaire_storage.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/data/sudoku_history.dart';
import 'package:tabgame/games/uttt/core/uttt_ai.dart';
import 'package:tabgame/games/uttt/data/uttt_history.dart';
import 'package:tabgame/games/uttt/game/uttt_controller.dart';

Future<Widget> appWith(Widget home) async {
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('스도쿠', () {
    SudokuRecord rec(int at, String givens, {bool gaveUp = false}) => SudokuRecord(
          at: at,
          difficulty: Difficulty.easy,
          seconds: 60,
          mistakes: 1,
          hints: 0,
          givens: givens,
          solution: givens,
          gaveUp: gaveUp,
        );

    test('포기 기록은 같은 문제당 하나만 남고, 그 문제를 완성하면 사라진다', () async {
      final a = '1' * 81, b = '2' * 81;
      await SudokuHistory.add(rec(1, a, gaveUp: true));
      await SudokuHistory.add(rec(2, b, gaveUp: true));
      await SudokuHistory.add(rec(3, a, gaveUp: true)); // 같은 문제를 또 포기
      var h = await SudokuHistory.load();
      expect(h.map((e) => e.at), [3, 2]);
      expect(h.every((e) => e.gaveUp), isTrue);

      await SudokuHistory.add(rec(4, a)); // 포기했던 문제를 완성
      h = await SudokuHistory.load();
      expect(h.map((e) => e.at), [4, 2]);
      expect(h.first.gaveUp, isFalse);
      expect(h.last.gaveUp, isTrue);
    });

    test('기록이 넘치면 완성 기록부터 지우고 포기한 판은 남긴다', () async {
      await SudokuHistory.add(rec(0, '0' * 81, gaveUp: true));
      for (var i = 1; i <= SudokuHistory.maxEntries + 5; i++) {
        await SudokuHistory.add(rec(i, '${i % 9 + 1}' * 81));
      }
      final h = await SudokuHistory.load();
      expect(h.length, SudokuHistory.maxEntries);
      expect(h.any((e) => e.gaveUp && e.at == 0), isTrue);
    });
  });

  group('프리셀', () {
    test('한 수도 두지 않았으면 포기할 수 없고, 포기하면 손댈 수 없다', () {
      final c = FreecellController(deal: 2, autoMoveEnabled: false);
      expect(c.giveUp(), isFalse);
      final move = c.state.legalMoves().first;
      expect(c.tryMove(move), isTrue);
      expect(c.giveUp(), isTrue);
      expect(c.gaveUp, isTrue);
      expect(c.canAct, isFalse);
      expect(c.canUndo, isFalse);
      final t = c.elapsed.value;
      c.tick();
      expect(c.elapsed.value, t);
      expect(c.giveUp(), isFalse);
      c.restart();
      expect(c.gaveUp, isFalse);
      c.dispose();
    });

    test('포기 기록: 같은 번호는 하나만, 완성하면 사라지고, 최고 기록에 들지 않는다', () async {
      FreecellRecord r(int at, int deal, {bool gu = false}) =>
          FreecellRecord(at: at, deal: deal, seconds: 50, moves: 9, gaveUp: gu);
      await FreecellStorage.recordGiveUp(r(1, 11, gu: true));
      await FreecellStorage.recordGiveUp(r(2, 22, gu: true));
      await FreecellStorage.recordGiveUp(r(3, 11, gu: true));
      var h = await FreecellStorage.loadHistory();
      expect(h.map((e) => e.deal), [11, 22]);
      expect((await FreecellStorage.stats()).wins, 0);
      expect((await FreecellStorage.stats()).bestSeconds, isNull);

      await FreecellStorage.recordWin(r(4, 11));
      h = await FreecellStorage.loadHistory();
      expect(h.map((e) => '${e.deal}${e.gaveUp ? 'g' : ''}'), ['11', '22g']);
      expect((await FreecellStorage.stats()).wins, 1);
    });

    test('포기한 판은 이어하기로 저장되지 않는다', () async {
      final c = FreecellController(deal: 2, autoMoveEnabled: false);
      FreecellStorage.setActive(c);
      c.tryMove(c.state.legalMoves().first);
      c.giveUp();
      await FreecellStorage.save(c);
      expect(await FreecellStorage.loadSaved(), isNull);
      c.dispose();
    });

    testWidgets('기록 탭: 포기한 판 목록에 다시 도전 단추가 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await FreecellStorage.recordGiveUp(
          const FreecellRecord(at: 1760000000000, deal: 777, seconds: 95, moves: 12, gaveUp: true));
      await tester.pumpWidget(await appWith(const Scaffold(body: FreecellRecordsTab())));
      await settle(tester);
      expect(find.text('포기한 판'), findsOneWidget);
      expect(find.text('#777'), findsOneWidget);
      expect(find.text('포기'), findsOneWidget);
      expect(find.text('다시 도전'), findsOneWidget);
      expect(find.textContaining('아직 완성한 판이 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('솔리테어', () {
    test('포기: 한 수 둔 뒤에만, 포기하면 손댈 수 없다', () {
      final c = SolitaireController(deal: 1, autoMoveEnabled: false);
      expect(c.giveUp(), isFalse);
      expect(c.drawFromStock(), isTrue);
      expect(c.giveUp(), isTrue);
      expect(c.canAct, isFalse);
      expect(c.drawFromStock(), isFalse);
      c.dispose();
    });

    test('포기 기록은 같은 번호·같은 뽑기 장수당 하나만 남는다', () async {
      SolitaireRecord r(int at, int deal, int draw, {bool gu = true}) =>
          SolitaireRecord(at: at, deal: deal, draw: draw, seconds: 40, moves: 5, gaveUp: gu);
      await SolitaireStorage.recordGiveUp(r(1, 5, 1));
      await SolitaireStorage.recordGiveUp(r(2, 5, 3)); // 뽑기 장수가 다르면 다른 판
      await SolitaireStorage.recordGiveUp(r(3, 5, 1));
      var h = await SolitaireStorage.loadHistory();
      expect(h.map((e) => '${e.deal}/${e.draw}'), ['5/1', '5/3']);
      await SolitaireStorage.recordWin(r(4, 5, 3, gu: false));
      h = await SolitaireStorage.loadHistory();
      expect(h.map((e) => '${e.deal}/${e.draw}/${e.gaveUp}'), ['5/3/false', '5/1/true']);
      expect((await SolitaireStorage.stats(3)).wins, 1);
      expect((await SolitaireStorage.stats(1)).wins, 0);
    });
  });

  group('지뢰찾기', () {
    test('고정 배치로 다시 도전하면 첫 칸과 이웃은 안전하고 지뢰 수는 그대로다', () {
      const level = MinesLevel.beginner;
      // 일부러 한가운데(40) 주변에 지뢰를 모아 둔다
      final preset = [30, 31, 32, 39, 41, 48, 49, 50, 0, 80];
      final c = MinesController(level: level, presetMines: preset, rng: Random(1));
      expect(c.status, MinesStatus.ready);
      c.tap(40);
      expect(c.status, MinesStatus.playing);
      expect(c.board.mine[40], isFalse);
      for (final n in c.board.neighbors(40)) {
        expect(c.board.mine[n], isFalse);
      }
      expect(c.mineCells.length, preset.length);
      // 안전한 구역 밖에 있던 지뢰(0, 80)는 그대로
      expect(c.board.mine[0] && c.board.mine[80], isTrue);
      expect(c.retryOf, preset);
    });

    test('포기: 칸을 연 뒤에만, 포기하면 손댈 수 없고 저장되지 않는다', () async {
      final c = MinesController(level: MinesLevel.beginner, rng: Random(3));
      expect(c.giveUp(), isFalse);
      MinesStorage.setActive(c);
      c.tap(40);
      expect(c.giveUp(), isTrue);
      expect(c.gaveUp, isTrue);
      expect(c.canAct, isFalse);
      final t = c.elapsed.value;
      c.tick();
      expect(c.elapsed.value, t);
      await MinesStorage.save(c);
      expect(await MinesStorage.loadSaved(), isNull);
      c.restart();
      expect(c.gaveUp, isFalse);
      expect(c.retryOf, isNull);
      c.dispose();
    });

    test('포기 기록은 같은 배치당 하나만, 다시 도전해 클리어하면 사라진다', () async {
      final a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      MinesRecord gave(int at, List<int> m) =>
          MinesRecord(at: at, level: MinesLevel.beginner, seconds: 70, gaveUp: true, mines: m, opened: 12);
      await MinesStorage.recordGiveUp(gave(1, a));
      await MinesStorage.recordGiveUp(gave(2, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]));
      await MinesStorage.recordGiveUp(gave(3, a.reversed.toList())); // 같은 배치(순서만 다름)
      var h = await MinesStorage.loadHistory();
      expect(h.map((e) => e.at), [3, 2]);
      expect(h.first.mines, a.reversed.toList());
      expect(h.first.opened, 12);

      await MinesStorage.recordWin(MinesRecord(at: 4, level: MinesLevel.beginner, seconds: 80, mines: a));
      h = await MinesStorage.loadHistory();
      expect(h.map((e) => '${e.at}${e.gaveUp ? 'g' : ''}'), ['4', '2g']);
      expect((await MinesStorage.stats(MinesLevel.beginner)).wins, 1);
    });

    testWidgets('기록 탭: 포기한 판에서 다시 도전하면 같은 배치로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await MinesStorage.recordGiveUp(MinesRecord(
        at: 1760000000000,
        level: MinesLevel.beginner,
        seconds: 61,
        gaveUp: true,
        mines: const [0, 8, 72, 80, 20, 21, 22, 60, 61, 62],
        opened: 33,
      ));
      await tester.pumpWidget(await appWith(const Scaffold(body: MinesRecordsTab())));
      await settle(tester);
      expect(find.text('포기한 판'), findsOneWidget);
      expect(find.textContaining('33/71칸'), findsOneWidget);
      expect(find.text('다시 도전'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('직소퍼즐', () {
    test('포기 기록은 같은 그림·조각 수당 하나만, 완성하면 사라진다', () async {
      const src = JigsawSource('sample', 'sunset');
      JigsawRecord r(int at, {int target = 24, bool gu = true, JigsawSource source = src}) => JigsawRecord(
            at: at,
            target: target,
            pieces: target,
            seconds: 100,
            source: source,
            gaveUp: gu,
            placed: 7,
          );
      await JigsawHistory.add(r(1));
      await JigsawHistory.add(r(2, target: 48)); // 조각 수가 다르면 다른 판
      await JigsawHistory.add(r(3));
      var h = await JigsawHistory.load();
      expect(h.map((e) => '${e.at}/${e.target}'), ['3/24', '2/48']);
      expect(h.first.placed, 7);
      await JigsawHistory.add(r(4, gu: false));
      h = await JigsawHistory.load();
      expect(h.map((e) => '${e.at}${e.gaveUp ? 'g' : ''}'), ['4', '2g']);
    });
  });

  group('기권 (궁극 틱택토 / 고블렛)', () {
    test('틱택토: 한 수 둔 뒤에만 기권할 수 있고, CPU 대결은 사람이, 둘이서는 지금 차례인 쪽이 기권한다', () {
      final c = UtttController(mode: PlayMode.local2p);
      expect(c.canResign, isFalse);
      final first = c.state.legalMoves().first;
      c.play(first);
      expect(c.canResign, isTrue);
      expect(c.resigningSide, c.state.turn);
      expect(c.resign(), isTrue);
      c.dispose();

      final cpu = UtttController(mode: PlayMode.vsCpu, humanSide: 1);
      expect(cpu.resigningSide, 1);
      cpu.dispose();
    });

    test('틱택토 기록: 기권은 저장되고 졌다고 센다', () async {
      await UtttHistory.add(UtttRecord(
        at: 1,
        vsCpu: true,
        winner: 1,
        moves: 5,
        level: UttLevel.easy,
        human: 0,
        resigned: true,
      ));
      final h = await UtttHistory.load();
      expect(h.single.resigned, isTrue);
      expect(h.single.humanWon, isFalse);
    });

    test('고블렛: 기권하면 상대가 이긴 채로 끝나고, 한 수 두기 전에는 기권할 수 없다', () {
      final c = GobbletController(mode: PlayMode.local2p);
      expect(c.canResign, isFalse);
      final id = c.reserveFront(c.turn, 1)!;
      c.select(id);
      expect(c.dropPiece(id, 4), isTrue);
      expect(c.canResign, isTrue);
      final who = c.resigningTeam;
      expect(who, c.turn);
      expect(c.resign(), isTrue);
      expect(c.isOver, isTrue);
      expect(c.result!.winner, who.other);
      expect(c.result!.resigned, isTrue);
      expect(c.canResign, isFalse);
      c.dispose();
    });

    test('고블렛 기록: 기권 표시가 저장된다', () async {
      await GobbletHistory.add(GobbletRecord(
        at: 1,
        vsCpu: false,
        winner: Team.blue,
        moves: 4,
        resigned: true,
      ));
      expect((await GobbletHistory.load()).single.resigned, isTrue);
    });
  });
}
