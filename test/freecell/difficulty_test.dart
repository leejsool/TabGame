import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/core/freecell_difficulty.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/core/freecell_solver.dart';
import 'package:tabgame/games/freecell/ui/freecell_menu_screen.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('난이도 표 (가짜 데이터)', () {
    // 점수 = 번호에 비례해서 올라가는 표 (1번이 가장 쉽고 32000번이 가장 어렵다)
    FcDifficultyTable synthetic({List<int> unsolved = const []}) {
      final b = Uint8List(kMaxDeal);
      for (var i = 0; i < kMaxDeal; i++) {
        b[i] = 60 + (i * 150 ~/ kMaxDeal); // 60 ~ 209
      }
      for (final d in unsolved) {
        b[d - 1] = 255;
      }
      return FcDifficultyTable(b);
    }

    test('점수가 낮을수록 쉽고, 난이도 비율은 대략 35/40/20/5%', () {
      final t = synthetic();
      expect(t.levelOf(1), FcLevel.easy);
      expect(t.levelOf(kMaxDeal), FcLevel.expert);
      final total = t.count(FcLevel.easy) + t.count(FcLevel.medium) + t.count(FcLevel.hard) + t.count(FcLevel.expert);
      expect(total, kMaxDeal - 1); // 풀 수 없는 11982 한 판만 빠진다
      double share(FcLevel l) => t.count(l) / total;
      expect(share(FcLevel.easy), closeTo(0.35, 0.03));
      expect(share(FcLevel.medium), closeTo(0.40, 0.03));
      expect(share(FcLevel.hard), closeTo(0.20, 0.03));
      expect(share(FcLevel.expert), closeTo(0.05, 0.02));
      // 점수가 올라가면 난이도는 내려가지 않는다
      var prev = FcLevel.easy.index;
      for (var d = 1; d <= kMaxDeal; d++) {
        if (d == kUnsolvableDeal) continue;
        final cur = t.levelOf(d).index;
        expect(cur, greaterThanOrEqualTo(prev));
        prev = cur;
      }
    });

    test('못 푼 판(255)은 전문가로 보되 무작위로는 뽑지 않는다', () {
      final t = synthetic(unsolved: [139, 5000]);
      expect(t.levelOf(139), FcLevel.expert);
      expect(t.levelOf(5000), FcLevel.expert);
      final rng = Random(1);
      for (var i = 0; i < 5000; i++) {
        final d = t.randomDeal(FcLevel.expert, rng);
        expect(d, isNot(139));
        expect(d, isNot(5000));
        expect(d, isNot(kUnsolvableDeal));
      }
    });

    test('난이도별 무작위 판은 그 난이도에 속한다', () {
      final t = synthetic();
      final rng = Random(2);
      for (final l in FcLevel.values) {
        for (var i = 0; i < 500; i++) {
          final d = t.randomDeal(l, rng);
          expect(d, inInclusiveRange(1, kMaxDeal));
          expect(t.levelOf(d), l);
        }
      }
    });
  });

  group('난이도 표 (실제 파일)', () {
    test('파일 크기·분포가 맞다', () async {
      final t = await FcDifficultyTable.load();
      expect(t.scores.length, kMaxDeal);
      for (final l in FcLevel.values) {
        expect(t.count(l), greaterThan(500), reason: '${l.label}: ${t.count(l)}판');
      }
      // 풀 수 없는 판 표시
      expect(t.scores[kUnsolvableDeal - 1], 255);
      // 같은 번호는 늘 같은 난이도
      expect(t.levelOf(617), t.levelOf(617));
    });

    test('난이도가 높을수록 풀이기가 실제로 더 많이 헤맨다 (표본 검증)', () async {
      final t = await FcDifficultyTable.load();
      final rng = Random(5);
      double avgExpanded(FcLevel l) {
        var sum = 0;
        const n = 25;
        for (var i = 0; i < n; i++) {
          final d = t.randomDeal(l, rng);
          sum += FcSolver.rate(FcState.deal(d)).expanded;
        }
        return sum / n;
      }

      final easy = avgExpanded(FcLevel.easy);
      final medium = avgExpanded(FcLevel.medium);
      final hard = avgExpanded(FcLevel.hard);
      // ignore: avoid_print
      print('평균 펼친 상태 수 — 쉬움 ${easy.round()}, 보통 ${medium.round()}, 어려움 ${hard.round()}');
      expect(easy, lessThan(medium));
      expect(medium, lessThan(hard));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('메뉴', () {
    testWidgets('난이도를 고르면 저장되고, 그 난이도의 판으로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const FreecellMenuScreen()));
      await settle(tester, rounds: 5);
      expect(find.text('난이도'), findsOneWidget);
      for (final label in ['무작위', '쉬움', '보통', '어려움', '전문가']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      expect(find.text('새 게임'), findsOneWidget); // 무작위일 때

      await tester.tap(find.widgetWithText(ChoiceChip, '어려움'));
      await settle(tester, rounds: 2);
      expect(find.text('새 게임 · 어려움'), findsOneWidget);
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString('freecell.level'), 'hard');

      await tester.tap(find.text('새 게임 · 어려움'));
      await settle(tester, rounds: 6);
      final screen = tester.widget<FreecellScreen>(find.byType(FreecellScreen));
      final table = FcDifficultyTable.instance!;
      expect(table.levelOf(screen.deal), FcLevel.hard);
      // 게임 화면 제목에 난이도가 보인다
      expect(find.text('어려움'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('번호를 입력하면 그 판의 난이도를 알려준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const FreecellMenuScreen()));
      await settle(tester, rounds: 5);
      final table = (await tester.runAsync(FcDifficultyTable.load))!;
      await tester.enterText(find.byType(TextField), '617');
      await tester.pump();
      expect(find.text('#617 · ${table.levelOf(617).label} 난이도'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '99999');
      await tester.pump();
      expect(find.textContaining('난이도'), findsWidgets); // 섹션 제목 등. 입력 미리보기는 없다
      expect(find.text('#99999 · 보통 난이도'), findsNothing);
    });

    testWidgets('폰 세로에서도 난이도 표시가 상단 바를 넘치게 하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(home: FreecellScreen(deal: 617)),
      ));
      await settle(tester, rounds: 5);
      final table = FcDifficultyTable.instance!;
      expect(find.text(table.levelOf(617).label), findsOneWidget); // 상단의 난이도 표시
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('마지막에 고른 난이도가 다음에 열 때도 남아 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'freecell.level': 'expert'});
      await tester.pumpWidget(await appWith(const FreecellMenuScreen()));
      await settle(tester, rounds: 5);
      expect(find.text('새 게임 · 전문가'), findsOneWidget);
    });
  });
}
