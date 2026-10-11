import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/solitaire/core/solitaire_rules.dart';
import 'package:tabgame/games/solitaire/data/solitaire_storage.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_menu_screen.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_records_tab.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_screen.dart';

String dump(SolState s) => [
      s.tableau.map((t) => t.join(',')).join('|'),
      s.up.join(','),
      s.stock.join(','),
      s.waste.join(','),
      s.found.join(','),
      s.fan,
    ].join(' / ');

/// 처음 상태에서 열끼리 옮길 수 있는 판 번호를 찾는다.
int dealWithColumnMove() {
  for (var d = 1; d < 500; d++) {
    final s = SolState.deal(d);
    if (s.legalMoves().any((m) => m.kind == SolKind.colToCol)) return d;
  }
  throw StateError('no deal');
}

Future<SolitaireController> pumpScreen(
  WidgetTester tester,
  Size size, {
  int deal = 1,
  int draw = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  final c = SolitaireController(deal: deal, draw: draw, autoDelay: Duration.zero);
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SolitaireScreen(controller: c),
      ),
    ),
  );
  await tester.pump();
  return c;
}

Finder cardFinder(int card) => find.byKey(ValueKey('card-$card'));

void main() {
  group('컨트롤러', () {
    test('뽑기·되돌리기: 되돌리면 정확히 이전 상태', () {
      final c = SolitaireController(deal: 7, draw: 3);
      final before = dump(c.state);
      expect(c.drawFromStock(), isTrue);
      expect(c.state.waste.length, 3);
      expect(c.moveCount, 1);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(dump(c.state), before);
      expect(c.canUndo, isFalse);
      c.dispose();
    });

    test('합법이 아닌 수는 거절하고, 일시정지 중에는 둘 수 없다', () {
      final c = SolitaireController(deal: 1);
      expect(c.tryMove(const SolMove(SolKind.colToFound, from: 3)), isFalse);
      c.setPaused(true);
      expect(c.drawFromStock(), isFalse);
      c.setPaused(false);
      expect(c.drawFromStock(), isTrue);
      c.dispose();
    });

    test('저장했다가 불러오면 같은 판·같은 수·같은 시간', () {
      final c = SolitaireController(deal: dealWithColumnMove(), draw: 3, autoMoveEnabled: false);
      c.tryMove(c.state.legalMoves().firstWhere((m) => m.kind == SolKind.colToCol));
      c.drawFromStock();
      c.drawFromStock();
      c.elapsed.value = 95;
      final restored = SolitaireController.fromJson(c.toJson(), autoMove: false);
      expect(dump(restored.state), dump(c.state));
      expect(restored.moveCount, c.moveCount);
      expect(restored.elapsed.value, 95);
      expect(restored.draw, 3);
      c.dispose();
      restored.dispose();
    });

    test('처음부터: 같은 번호의 처음 모습으로', () {
      final c = SolitaireController(deal: 12);
      final first = dump(c.state);
      c.drawFromStock();
      c.elapsed.value = 40;
      c.restart();
      expect(dump(c.state), first);
      expect(c.moveCount, 0);
      expect(c.elapsed.value, 0);
      c.dispose();
    });

    test('남은 카드가 전부 앞면이면 자동으로 끝까지 올리고 완성한다', () async {
      final c = SolitaireController(deal: 1, autoDelay: Duration.zero);
      c.state = SolState(
        List.generate(7, (i) => i == 0 ? [12 * 4 + 2, 12 * 4 + 3] : <int>[]),
        [2, 0, 0, 0, 0, 0, 0],
        [],
        [],
        [13, 13, 12, 12], // 하트·스페이드는 Q까지 완성, K 둘이 남음
        0,
      );
      var done = false;
      c.onCompleted = () => done = true;
      c.start();
      for (var i = 0; i < 50 && !done; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(done, isTrue);
      expect(c.completed, isTrue);
      expect(c.state.isWon, isTrue);
      c.dispose();
    });

    test('손해 없는 카드는 사용자가 한 수 둔 뒤 자동으로 완성 칸에 올라간다', () async {
      final c = SolitaireController(deal: 1, autoDelay: Duration.zero);
      // 클로버 A가 버린 카드 맨 위, 열에는 다른 카드. 더미에서 뽑는 수를 두면 자동으로 올라간다.
      c.state = SolState(
        [
          [30],
          [31],
          [],
          [],
          [],
          [],
          [],
        ],
        [1, 1, 0, 0, 0, 0, 0],
        [0 * 4 + 0, 40], // 끝에서부터 뽑으니 40이 먼저 나온다... 클로버 A는 그 다음
        [],
        [0, 0, 0, 0],
        0,
      );
      c.drawFromStock(); // 40
      expect(c.state.waste, [40]);
      c.drawFromStock(); // 클로버 A → 자동으로 올라감
      for (var i = 0; i < 20 && c.state.found[0] == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(c.state.found[0], 1);
      expect(c.state.waste, [40]);
      expect(c.moveCount, 2); // 자동 이동은 세지 않는다
      c.undo(); // 사용자의 수와 자동으로 올라간 수가 함께 되돌아간다
      expect(c.state.found[0], 0);
      expect(c.state.waste, [40]);
      expect(c.state.stock, [0]);
      c.dispose();
    });

    test('탭 이동: 완성 칸 > 열', () {
      final c = SolitaireController(deal: 1, autoMoveEnabled: false);
      c.state = SolState(
        [
          [4 * 4 + 1, 0 * 4 + 0], // 열 0: 다이아 5, 클로버 A (위)
          [5 * 4 + 0], // 열 1: 클로버 6
          [],
          [],
          [],
          [],
          [],
        ],
        [2, 1, 0, 0, 0, 0, 0],
        [],
        [],
        [0, 0, 0, 0],
        0,
      );
      expect(c.smartMoveColumn(0, 1), isTrue); // 클로버 A → 완성 칸
      expect(c.state.found[0], 1);
      expect(c.smartMoveColumn(0, 1), isTrue); // 다이아 5 → 클로버 6 위
      expect(c.state.tableau[1], [5 * 4 + 0, 4 * 4 + 1]);
      c.dispose();
    });
  });

  group('화면', () {
    for (final size in const [Size(360, 740), Size(800, 1280), Size(1280, 800), Size(640, 360)]) {
      testWidgets('넘치지 않고 그려진다 $size', (tester) async {
        final c = await pumpScreen(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('솔리테어'), findsOneWidget);
        c.drawFromStock();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('더미를 누르면 카드를 뽑는다 (3장 뽑기)', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280), draw: 3);
      expect(c.state.waste, isEmpty);
      await tester.tap(cardFinder(c.state.stock.last));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.state.waste.length, 3);
      expect(c.state.stock.length, 21);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('카드를 끌어서 다른 열에 놓는다', (tester) async {
      final deal = dealWithColumnMove();
      final c = await pumpScreen(tester, const Size(800, 1280), deal: deal);
      final move = c.state.legalMoves().firstWhere((m) => m.kind == SolKind.colToCol);
      final card = c.state.tableau[move.from].last;
      final target = c.state.tableau[move.to].last;
      final from = tester.getCenter(cardFinder(card));
      final to = tester.getCenter(cardFinder(target)) + const Offset(0, 40);
      await tester.dragFrom(from, to - from);
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.state.tableau[move.to].last, card);
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('규칙에 맞지 않는 곳에 놓으면 제자리로 돌아간다', (tester) async {
      final deal = dealWithColumnMove();
      final c = await pumpScreen(tester, const Size(800, 1280), deal: deal);
      final move = c.state.legalMoves().firstWhere((m) => m.kind == SolKind.colToCol);
      final card = c.state.tableau[move.from].last;
      final before = dump(c.state);
      final from = tester.getCenter(cardFinder(card));
      await tester.dragFrom(from, const Offset(0, -20)); // 열 위쪽 줄 근처 (완성 칸 아님)
      await tester.pump(const Duration(milliseconds: 400));
      expect(dump(c.state), before);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('힌트·되돌리기·규칙 버튼', (tester) async {
      final c = await pumpScreen(tester, const Size(800, 1280));
      await tester.tap(find.text('힌트'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.hint, isNotNull);
      c.drawFromStock();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('되돌리기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.moveCount, 0);
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('규칙 보기'));
      await tester.pumpAndSettle();
      expect(find.text('솔리테어 규칙'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('메뉴/기록', () {
    testWidgets('메뉴: 뽑는 방식 고르기', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const SolitaireMenuScreen()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.text('새 게임 · 1장 뽑기'), findsOneWidget);
      await tester.tap(find.text('3장 뽑기').first);
      await tester.pump();
      expect(find.text('새 게임 · 3장 뽑기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('기록 저장: 뽑기 장수별로 따로 센다', () async {
      SharedPreferences.setMockInitialValues({});
      await SolitaireStorage.recordStart(1);
      await SolitaireStorage.recordStart(3);
      await SolitaireStorage.recordStart(3);
      final best1 = await SolitaireStorage.recordWin(
          const SolitaireRecord(at: 1, deal: 5, draw: 1, seconds: 300, moves: 120));
      final best3 = await SolitaireStorage.recordWin(
          const SolitaireRecord(at: 2, deal: 6, draw: 3, seconds: 500, moves: 150));
      final worse1 = await SolitaireStorage.recordWin(
          const SolitaireRecord(at: 3, deal: 7, draw: 1, seconds: 400, moves: 130));
      expect(best1, isTrue);
      expect(best3, isTrue); // 3장 뽑기에서는 첫 기록
      expect(worse1, isFalse);
      final s1 = await SolitaireStorage.stats(1);
      final s3 = await SolitaireStorage.stats(3);
      expect((s1.starts, s1.wins, s1.bestSeconds), (1, 2, 300));
      expect((s3.starts, s3.wins, s3.bestMoves), (2, 1, 150));
      final list = await SolitaireStorage.loadHistory();
      expect(list.map((r) => r.deal), [7, 6, 5]);
    });

    testWidgets('기록 탭이 완성한 판을 보여준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await SolitaireStorage.recordWin(SolitaireRecord(
            at: DateTime.now().millisecondsSinceEpoch, deal: 617, draw: 3, seconds: 245, moves: 99));
      });
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: SolitaireRecordsTab()),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.textContaining('#617'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
