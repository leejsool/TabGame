import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/core/freecell_solver.dart';
import 'package:tabgame/games/freecell/data/freecell_storage.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';
import 'package:tabgame/games/freecell/ui/freecell_table.dart';

FreecellController make(int deal, {bool auto = true}) => FreecellController(
      deal: deal,
      autoMoveEnabled: auto,
      autoDelay: const Duration(milliseconds: 1),
    );

/// 처음부터 "열 → 열(한 장)" 수가 있는 판 번호 (화면 조작 테스트용).
int dealWithColumnMove() {
  for (var d = 1; d < 200; d++) {
    final s = FcState.deal(d);
    final has = s.legalMoves().any((m) => m.from == Place.column && m.to == Place.column && m.count == 1);
    if (has) return d;
  }
  throw StateError('없음');
}

/// 자동 이동이 끝날 때까지 기다린다.
Future<void> idle(FreecellController c) async {
  for (var i = 0; i < 200 && c.busy; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 3));
  }
}

/// 풀이기의 수 순서대로 사람이 두듯이 끝까지 진행한다 (자동 이동이 먼저 둔 수는 건너뜀).
Future<void> playSolution(FreecellController c) async {
  final sol = FcSolver.solve(c.state)!;
  for (final m in sol) {
    await idle(c);
    if (c.completed) break;
    if (c.state.isLegal(m)) c.tryMove(m);
  }
  await idle(c);
}

void main() {
  group('컨트롤러', () {
    test('풀이대로 두면 끝까지 풀리고 완성 알림이 한 번 온다', () async {
      final c = make(2);
      var done = 0;
      c.onCompleted = () => done++;
      await playSolution(c);
      expect(c.completed, isTrue);
      expect(c.state.isWon, isTrue);
      expect(done, 1);
      expect(c.canUndo, isFalse); // 끝난 판은 되돌릴 수 없다
      expect(c.moveCount, greaterThan(10));
      c.dispose();
    });

    test('합법이 아닌 수는 거부되고 아무것도 바뀌지 않는다', () {
      final c = make(1, auto: false);
      final before = c.state.key;
      expect(c.tryMove(const FcMove(Place.column, 0, Place.column, 0)), isFalse);
      expect(c.tryMove(const FcMove(Place.cell, 0, Place.column, 1)), isFalse); // 빈 프리셀
      expect(c.state.key, before);
      expect(c.moveCount, 0);
      c.dispose();
    });

    test('되돌리기: 사용자의 수와 그 뒤에 자동으로 올라간 수를 함께 되돌린다', () async {
      // 자동 올리기가 반드시 일어나는 상황을 찾는다: 풀이 중 자동으로 올라간 수가 따라오는 첫 수
      FreecellController? c;
      for (var deal = 1; deal < 60 && c == null; deal++) {
        final probe = make(deal);
        final sol = FcSolver.solve(probe.state)!;
        for (var i = 0; i < sol.length; i++) {
          final p = make(deal);
          for (var k = 0; k < i; k++) {
            await idle(p);
            if (p.state.isLegal(sol[k])) p.tryMove(sol[k]);
          }
          await idle(p);
          if (!p.state.isLegal(sol[i])) {
            p.dispose();
            continue;
          }
          final keyBefore = p.state.key;
          final movesBefore = p.moveCount;
          p.tryMove(sol[i]);
          await idle(p);
          if (p.state.foundationTotal > FcState.deal(deal).foundationTotal &&
              p.moveCount == movesBefore + 1 &&
              p.state.foundationTotal > 0) {
            // 자동 이동이 일어났는지: 사용자의 수 하나에 비해 완성 칸이 늘어났다
            p.undo();
            if (p.state.key == keyBefore && p.moveCount == movesBefore) {
              c = p;
              break;
            }
          }
          p.dispose();
        }
        probe.dispose();
      }
      expect(c, isNotNull, reason: '자동 올리기가 따라오는 수를 찾지 못함');
      c!.dispose();
    });

    test('되돌리기를 끝까지 하면 처음 판으로 돌아간다', () async {
      final c = make(7, auto: false);
      final start = FcState.deal(7).key;
      var n = 0;
      for (final m in c.state.legalMoves(forSolver: true).take(1)) {
        c.tryMove(m);
        n++;
      }
      for (var i = 0; i < 6; i++) {
        final moves = c.state.legalMoves(forSolver: true);
        if (moves.isEmpty) break;
        c.tryMove(moves.first);
        n++;
      }
      expect(c.moveCount, n);
      while (c.canUndo) {
        c.undo();
      }
      expect(c.state.key, start);
      expect(c.moveCount, 0);
      c.dispose();
    });

    test('다시 시작하면 같은 번호의 처음 판이 된다', () {
      final c = make(11, auto: false);
      c.tryMove(c.state.legalMoves(forSolver: true).first);
      c.elapsed.value = 99;
      c.restart();
      expect(c.state.key, FcState.deal(11).key);
      expect(c.elapsed.value, 0);
      expect(c.moveCount, 0);
      c.dispose();
    });

    test('저장했다가 복원하면 같은 상태·수·시간', () async {
      final c = make(5);
      for (var i = 0; i < 8; i++) {
        await idle(c);
        final moves = c.state.legalMoves(forSolver: true);
        if (moves.isEmpty) break;
        c.tryMove(moves.first);
      }
      await idle(c);
      c.elapsed.value = 321;
      final r = FreecellController.fromJson(c.toJson());
      expect(r.deal, 5);
      expect(r.state.key, c.state.key);
      expect(r.moveCount, c.moveCount);
      expect(r.elapsed.value, 321);
      // 복원한 판에서도 되돌리기가 된다
      final before = r.state.key;
      r.undo();
      expect(r.state.key == before, isFalse);
      r.dispose();
      c.dispose();
    });

    test('자동 올리기를 끄면 안전한 카드도 저절로 올라가지 않는다', () async {
      // 1번 판을 풀이대로 진행하다가 처음으로 안전한 올리기가 가능한 상태를 찾는다
      final c = make(1, auto: false);
      final sol = FcSolver.solve(c.state)!;
      var sawSafe = false;
      for (final m in sol) {
        if (c.state.safeAutoMove() != null) {
          sawSafe = true;
          final total = c.state.foundationTotal;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(c.state.foundationTotal, total, reason: '자동 올리기 꺼짐인데 올라갔다');
          break;
        }
        if (c.state.isLegal(m)) c.tryMove(m);
        if (c.state.canFinishAutomatically) break;
      }
      expect(sawSafe, isTrue);
      c.dispose();
    });

    test('남은 카드가 모두 풀려 있으면 자동으로 끝까지 올린다 (자동 올리기 꺼짐이어도)', () async {
      final c = make(3, auto: false);
      // 모든 열을 내림차순으로 정리된 상태로 만든다: 완성 칸 직전 상태
      c.state = FcState(
        [
          [12 * 4 + 0, 11 * 4 + 0, 10 * 4 + 0, 9 * 4 + 0, 8 * 4 + 0, 7 * 4 + 0, 6 * 4 + 0, 5 * 4 + 0, 4 * 4 + 0, 3 * 4 + 0, 2 * 4 + 0, 1 * 4 + 0, 0 * 4 + 0],
          [for (var r = 12; r >= 0; r--) r * 4 + 1],
          [for (var r = 12; r >= 0; r--) r * 4 + 2],
          [for (var r = 12; r >= 0; r--) r * 4 + 3],
          [],
          [],
          [],
          [],
        ],
        [-1, -1, -1, -1],
        [0, 0, 0, 0],
      );
      var done = 0;
      c.onCompleted = () => done++;
      c.start();
      for (var i = 0; i < 400 && !c.completed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      expect(c.completed, isTrue);
      expect(c.state.isWon, isTrue);
      expect(done, 1);
      c.dispose();
    });

    test('막다른 상태를 알아챈다', () async {
      final c = make(1, auto: false);
      // 프리셀이 꽉 차고, 놓을 수 있는 곳이 하나도 없는 상태
      c.state = FcState(
        [
          [4 * 4 + 0, 2 * 4 + 1], [4 * 4 + 1, 2 * 4 + 0], [4 * 4 + 2, 2 * 4 + 3], [4 * 4 + 3, 2 * 4 + 2],
          [6 * 4 + 0, 8 * 4 + 1], [6 * 4 + 1, 8 * 4 + 0], [6 * 4 + 2, 8 * 4 + 3], [6 * 4 + 3, 8 * 4 + 2],
        ],
        [12 * 4 + 0, 12 * 4 + 1, 12 * 4 + 2, 12 * 4 + 3],
        [0, 0, 0, 0],
      );
      var stuck = 0;
      c.onNoMoves = () => stuck++;
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.state.legalMoves(), isEmpty);
      expect(c.noMoves, isTrue);
      expect(stuck, 1);
      c.dispose();
    });

    test('탭 이동: 완성 칸 > 이어 붙이는 열 > 빈 열, 갈 곳이 없으면 아무 일도 없다', () {
      final c = make(1, auto: false);
      // 자동 완성 상태(모든 열이 내림차순)가 되지 않도록 5번째 열에 "작은 카드 위에 큰 카드"를 둔다
      c.state = FcState(
        [
          [1 * 4 + 2], // 2H (하트 2)
          [0 * 4 + 2], // AH → 완성 칸이 우선
          [2 * 4 + 0], // 3C (검정 3)
          [3 * 4 + 2], // 4H → 3C 위에는 못 올림(같은 계급 차이 아님)이지만 5S 위에는 올릴 수 있다
          [4 * 4 + 3], // 5S
          [1 * 4 + 1, 4 * 4 + 1], // 2D 위에 5D: 풀리지 않은 열
          [],
          [],
        ],
        [-1, -1, -1, -1],
        [0, 0, 0, 0],
      );
      expect(c.state.canFinishAutomatically, isFalse);
      // AH: 완성 칸으로
      expect(c.smartMove(Place.column, 1, 1), isTrue);
      expect(c.state.found[2], 1);
      // 2H: 이제 완성 칸이 우선 (A 다음)
      expect(c.smartMove(Place.column, 0, 1), isTrue);
      expect(c.state.found[2], 2);
      // 4H: 완성 칸은 안 되고 (3H 아직), 5S 위로 이어 붙인다 (빈 열보다 우선)
      expect(c.smartMove(Place.column, 3, 1), isTrue);
      expect(c.state.columns[4].last, 3 * 4 + 2);
      // 갈 곳이 없는 카드: 5D (4열 5S... 위에는 검정 6만 올릴 수 있다) → 빈 열로 간다
      expect(c.smartMove(Place.column, 5, 1), isTrue);
      expect(c.state.columns.where((col) => col.isEmpty).length, lessThan(5));
      c.dispose();
    });

    test('집을 수 있는 카드: 이어진 줄의 시작부터 맨 위까지', () {
      final c = make(1, auto: false);
      c.state = FcState(
        [
          [12 * 4 + 3, 5 * 4 + 1, 4 * 4 + 3, 3 * 4 + 2], // KS 6D 5S 4H → 6D,5S,4H 가 줄
          [], [], [], [], [], [], [],
        ],
        [-1, -1, -1, -1],
        [0, 0, 0, 0],
      );
      expect(c.grabCount(0, 3 * 4 + 2), 1); // 4H
      expect(c.grabCount(0, 4 * 4 + 3), 2); // 5S부터 2장
      expect(c.grabCount(0, 5 * 4 + 1), 3); // 6D부터 3장
      expect(c.grabCount(0, 12 * 4 + 3), isNull); // KS는 줄이 이어지지 않아 못 집음
      c.dispose();
    });

    test('힌트: 풀이를 찾아 첫 수를 알려주고, 그대로 두면 다음 힌트는 바로 나온다', () async {
      final c = make(2, auto: false);
      await c.requestHint();
      expect(c.hint, isNotNull);
      expect(c.hint!.fromSolver, isTrue);
      expect(c.state.isLegal(c.hint!.move), isTrue);
      final first = c.hint!.move;
      c.tryMove(first);
      expect(c.hint, isNull); // 수를 두면 힌트가 사라진다
      // 계획이 이어져 있어서 다음 힌트가 바로 나온다 (isolate 없이)
      await c.requestHint();
      expect(c.hint, isNotNull);
      expect(c.state.isLegal(c.hint!.move), isTrue);
      c.dispose();
    });
  });

  group('저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('기록: 최고 기록 갱신과 목록(최신 순, 100개 제한)', () async {
      expect(await FreecellStorage.loadHistory(), isEmpty);
      final b1 = await FreecellStorage.recordWin(const FreecellRecord(at: 1, deal: 10, seconds: 300, moves: 90));
      expect(b1, isTrue); // 첫 기록은 최고 기록
      final b2 = await FreecellStorage.recordWin(const FreecellRecord(at: 2, deal: 11, seconds: 400, moves: 120));
      expect(b2, isFalse);
      final b3 = await FreecellStorage.recordWin(const FreecellRecord(at: 3, deal: 12, seconds: 280, moves: 130));
      expect(b3, isTrue); // 시간 갱신
      final s = await FreecellStorage.stats();
      expect(s.wins, 3);
      expect(s.bestSeconds, 280);
      expect(s.bestMoves, 90);
      final h = await FreecellStorage.loadHistory();
      expect(h.map((r) => r.deal), [12, 11, 10]);
      for (var i = 0; i < 110; i++) {
        await FreecellStorage.recordWin(FreecellRecord(at: i, deal: i + 1, seconds: 999, moves: 999));
      }
      expect((await FreecellStorage.loadHistory()).length, FreecellStorage.maxHistory);
    });

    test('도전 횟수와 승률', () async {
      await FreecellStorage.recordStart();
      await FreecellStorage.recordStart();
      await FreecellStorage.recordWin(const FreecellRecord(at: 1, deal: 1, seconds: 10, moves: 10));
      final s = await FreecellStorage.stats();
      expect(s.starts, 2);
      expect(s.wins, 1);
      expect(s.winRate, 0.5);
    });
  });

  group('화면', () {
    Future<Widget> app(FreecellController c) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      return SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: FreecellScreen(controller: c)),
      );
    }

    const sizes = {
      '폰 세로': Size(360, 640),
      '태블릿 세로': Size(800, 1280),
      '태블릿 가로': Size(1280, 800),
      '작은 가로': Size(800, 500),
    };
    sizes.forEach((name, size) {
      testWidgets('$name: 넘침 없이 그려지고 카드 52장이 보인다', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final c = make(617, auto: false);
        await tester.pumpWidget(await app(c));
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (var card = 0; card < 52; card++) {
          expect(find.byKey(ValueKey('card-$card')), findsOneWidget);
        }
        // 폰 가로 화면은 도구가 좌우 줄로 가서 판 번호만 보인다
        final phoneLandscape = size.shortestSide < 600 && size.width > size.height;
        expect(find.text(phoneLandscape ? '#617' : '프리셀 #617'), findsOneWidget);
        expect(find.text('힌트'), findsOneWidget);
        // 일시정지·힌트 표시 상태도 넘치지 않는다
        c.setPaused(true);
        await tester.pump();
        expect(find.text('일시정지'), findsWidgets);
        c.setPaused(false);
        c.hint = FcHint(c.state.legalMoves(forSolver: true).first);
        c.notifyListeners();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('카드를 끌어서 놓을 수 있는 열에 놓으면 이동한다 (실제 터치)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(dealWithColumnMove(), auto: false);
      await tester.pumpWidget(await app(c));
      await tester.pump();

      // 놓을 수 있는 열→열 수 하나를 고른다 (한 장짜리)
      final move = c.state.legalMoves().firstWhere(
            (m) => m.from == Place.column && m.to == Place.column && m.count == 1,
          );
      final card = c.state.columns[move.fromIndex].last;
      final destTop = c.state.columns[move.toIndex].last;
      final cardFinder = find.byKey(ValueKey('card-$card'));
      final destFinder = find.byKey(ValueKey('card-$destTop'));
      final start = tester.getCenter(cardFinder);
      final end = tester.getCenter(destFinder) + const Offset(0, 30); // 도착 열 맨 위 카드 근처
      final g = await tester.startGesture(start);
      await g.moveTo(start + const Offset(0, 20));
      await g.moveTo(end);
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.state.columns[move.toIndex].last, card);
      expect(c.moveCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('대충 옆으로 치우쳐 놓아도 가장 가까운 놓을 수 있는 열로 들어간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(dealWithColumnMove(), auto: false);
      await tester.pumpWidget(await app(c));
      await tester.pump();

      final move = c.state.legalMoves().firstWhere(
            (m) => m.from == Place.column && m.to == Place.column && m.count == 1,
          );
      final targets = c.targetsFor(Place.column, move.fromIndex, 1).where((t) => t.to == Place.column);
      bool legal(int col) => targets.any((t) => t.toIndex == col);
      // 옆 열이 놓을 수 있는 자리가 아닌 쪽으로 치우쳐서 놓는다
      final dir = (move.toIndex < 7 && !legal(move.toIndex + 1)) ? 1.0 : -1.0;
      expect(dir > 0 || (move.toIndex > 0 && !legal(move.toIndex - 1)), isTrue, reason: '치우칠 쪽이 필요');

      final card = c.state.columns[move.fromIndex].last;
      final destTop = c.state.columns[move.toIndex].last;
      final cardW = tester.getSize(find.byKey(ValueKey('card-$card'))).width;
      final start = tester.getCenter(find.byKey(ValueKey('card-$card')));
      // 도착 열 중심에서 카드 폭의 0.8배나 옆으로 벗어난 곳에 놓는다 (예전 판정으로는 옆 열이라 실패)
      final end = tester.getCenter(find.byKey(ValueKey('card-$destTop'))) + Offset(dir * cardW * 0.8, 30);
      final g = await tester.startGesture(start);
      await g.moveTo(start + const Offset(0, 20));
      await g.moveTo(end);
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.state.columns[move.toIndex].last, card);
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('놓을 수 없는 곳에 놓으면 제자리로 돌아간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(1, auto: false);
      await tester.pumpWidget(await app(c));
      await tester.pump();
      final card = c.state.columns[0].last;
      final before = c.state.key;
      final start = tester.getCenter(find.byKey(ValueKey('card-$card')));
      final g = await tester.startGesture(start);
      await g.moveTo(start + const Offset(0, 40));
      await g.moveTo(tester.getTopLeft(find.byType(FreecellTable)) + const Offset(400, 900)); // 아무것도 없는 곳
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.state.key, before);
      expect(c.moveCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('카드를 탭하면 알아서 갈 수 있는 곳으로 간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(dealWithColumnMove(), auto: false);
      await tester.pumpWidget(await app(c));
      await tester.pump();
      // 탭하면 이동할 수 있는 열의 맨 위 카드를 찾는다
      int? tapCard;
      for (var i = 0; i < 8 && tapCard == null; i++) {
        final n = c.grabCount(i, c.state.columns[i].last);
        if (n == null) continue;
        final hasTarget = c.targetsFor(Place.column, i, 1).any((m) => m.to != Place.cell);
        if (hasTarget) tapCard = c.state.columns[i].last;
      }
      expect(tapCard, isNotNull);
      await tester.tap(find.byKey(ValueKey('card-$tapCard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('완성하면 기록이 쌓이고 완성 대화상자가 뜬다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final c = make(2);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(home: FreecellScreen(controller: c)),
      ));
      // 풀이대로 두면서 화면을 갱신한다
      final sol = FcSolver.solve(c.state)!;
      for (final m in sol) {
        for (var i = 0; i < 100 && c.busy; i++) {
          await tester.pump(const Duration(milliseconds: 5));
        }
        if (c.completed) break;
        if (c.state.isLegal(m)) c.tryMove(m);
        await tester.pump(const Duration(milliseconds: 5));
      }
      for (var i = 0; i < 200 && !c.completed; i++) {
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(c.completed, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      final list = await tester.runAsync(FreecellStorage.loadHistory);
      expect(list!.length, 1);
      expect(list.first.deal, 2);
      await tester.pump(const Duration(milliseconds: 14500));
      expect(find.text('완성! 🎉'), findsOneWidget);
      expect(find.textContaining('#2'), findsWidgets); // 번호와 난이도가 함께 보인다
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
