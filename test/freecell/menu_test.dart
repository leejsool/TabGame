import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/data/freecell_storage.dart';
import 'package:tabgame/games/freecell/freecell_entry.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_menu_screen.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';
import 'package:tabgame/records/records_screen.dart';

Future<Widget> appWith(Widget home) async {
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  test('무작위 판 번호는 1~32000이고 풀 수 없는 번호는 나오지 않는다', () {
    for (var i = 0; i < 20000; i++) {
      final n = randomDeal();
      expect(n, inInclusiveRange(1, kMaxDeal));
      expect(n, isNot(kUnsolvableDeal));
    }
  });

  group('메뉴', () {
    testWidgets('번호를 넣어 시작한다 / 잘못된 번호는 안내한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const FreecellMenuScreen()));
      await settle(tester, rounds: 3);
      expect(find.text('새 게임'), findsOneWidget);

      // 범위 밖
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('시작'));
      await tester.pump();
      expect(find.textContaining('1부터 32000 사이'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '32001');
      await tester.tap(find.text('시작'));
      await tester.pump();
      expect(find.textContaining('1부터 32000 사이'), findsOneWidget);
      // 풀 수 없는 판
      await tester.enterText(find.byType(TextField), '11982');
      await tester.tap(find.text('시작'));
      await tester.pump();
      expect(find.textContaining('풀 수 없는 판이라'), findsOneWidget);
      expect(find.byType(FreecellScreen), findsNothing);

      // 정상 번호
      await tester.enterText(find.byType(TextField), '617');
      await tester.tap(find.text('시작'));
      await settle(tester, rounds: 4);
      expect(find.byType(FreecellScreen), findsOneWidget);
      expect(find.text('프리셀 #617'), findsOneWidget);
      final s = await tester.runAsync(FreecellStorage.stats);
      expect(s!.starts, 1); // 도전 횟수가 올랐다
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('이어하던 판이 있으면 이어하기 카드가 보이고, 눌러서 이어한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // 몇 수 둔 판을 만들어 저장 형식으로 넣는다
      final c = FreecellController(deal: 42, autoMoveEnabled: false);
      final moves = c.state.legalMoves(forSolver: true);
      c.tryMove(moves.first);
      c.elapsed.value = 75;
      final json = jsonEncode(c.toJson());
      final before = c.state.key;
      c.dispose();
      SharedPreferences.setMockInitialValues({'freecell.save': json});

      await tester.pumpWidget(await appWith(const FreecellMenuScreen()));
      await settle(tester, rounds: 3);
      expect(find.text('이어하기'), findsOneWidget);
      expect(find.textContaining('#42'), findsOneWidget);
      expect(find.textContaining('1수'), findsOneWidget);
      expect(find.textContaining('01:15'), findsOneWidget);

      await tester.tap(find.text('이어하기'));
      await settle(tester, rounds: 4);
      final screen = tester.widget<FreecellScreen>(find.byType(FreecellScreen));
      expect(screen.saved!['deal'], 42);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(before, isNotEmpty);
    });
  });

  group('기록 보드', () {
    testWidgets('프리셀 탭: 요약과 목록이 보이고 "다시 하기"는 같은 번호로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'freecell.history': jsonEncode([
          const FreecellRecord(at: 1760000000000, deal: 617, seconds: 305, moves: 88).toJson(),
        ]),
        'freecell.wins': 2,
        'freecell.starts': 5,
        'freecell.bestTime': 290,
        'freecell.bestMoves': 80,
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'freecell')));
      await settle(tester, rounds: 5);
      expect(find.text('2판'), findsOneWidget);
      expect(find.textContaining('승률 40%'), findsOneWidget);
      expect(find.text('04:50'), findsOneWidget); // 최단 시간
      expect(find.text('80수'), findsOneWidget); // 최소 이동
      expect(find.text('#617 · 05:05'), findsOneWidget);

      await tester.tap(find.text('다시 하기'));
      await settle(tester, rounds: 5);
      expect(find.byType(FreecellScreen), findsOneWidget);
      expect(find.text('프리셀 #617'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('이어하던 판이 있으면 덮어쓸지 먼저 묻는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = FreecellController(deal: 9, autoMoveEnabled: false);
      c.tryMove(c.state.legalMoves(forSolver: true).first);
      final json = jsonEncode(c.toJson());
      c.dispose();
      SharedPreferences.setMockInitialValues({
        'freecell.save': json,
        'freecell.history': jsonEncode([
          const FreecellRecord(at: 1760000000000, deal: 617, seconds: 305, moves: 88).toJson(),
        ]),
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'freecell')));
      await settle(tester, rounds: 5);
      await tester.tap(find.text('다시 하기'));
      await settle(tester, rounds: 4);
      expect(find.text('이어하던 판이 있어요'), findsOneWidget);
      expect(find.byType(FreecellScreen), findsNothing);
      await tester.tap(find.text('취소'));
      await settle(tester, rounds: 3);
      expect(find.byType(FreecellScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('기록이 없으면 안내가 보이고, 기록 화면에서 다른 게임으로 바꿀 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'freecell')));
      await settle(tester, rounds: 4);
      expect(find.textContaining('아직 완성한 판이 없어요'), findsOneWidget);
      expect(find.text('프리셀'), findsOneWidget); // 지금 보는 게임 이름
      // 고르개를 열면 다른 게임들이 보인다
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await settle(tester, rounds: 6);
      expect(find.text('스도쿠'), findsOneWidget);
      expect(find.text('직소퍼즐'), findsOneWidget);
      expect(find.text('고블렛'), findsOneWidget);
    });
  });
}
