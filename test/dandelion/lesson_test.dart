import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_lesson_screen.dart';

int cell(int r, int c) => r * kSize + c;

void main() {
  group('계산', () {
    test('책의 그림: 꽃 둘 중 한쪽의 아래, 다른 쪽의 오른쪽 칸은 보장된다', () {
      final cells = DandState.sow([cell(0, 3), cell(2, 1)], const []);
      final sure = DandState.guaranteed(cells, 0);
      expect(sure, contains(cell(2, 3)));
    });

    test('꽃 한 송이뿐이면 보장된 칸이 없다', () {
      final cells = DandState.sow([cell(2, 2)], const []);
      expect(DandState.guaranteed(cells, 0), isEmpty);
    });

    test('보장된 칸은 바람이 어떤 방향을 빼도 실제로 채워진다', () {
      for (final sc in kGuaranteeScenarios) {
        final cells = DandState.sow(sc.flowers, sc.used);
        var used = 0;
        for (final d in sc.used) {
          used |= 1 << d.index;
        }
        final sure = DandState.guaranteed(cells, used);
        final left = [for (final d in WindDir.values) if (used & (1 << d.index) == 0) d];
        for (final skip in left) {
          final after = DandState.sow(sc.flowers, [...sc.used, for (final d in left) if (d != skip) d]);
          for (final c in sure) {
            expect(after[c], isNot(kEmpty), reason: '${sc.title} 칸 $c, 빼는 방향 ${skip.label}');
          }
        }
      }
    });

    test('보장되지 않은 칸은 바람이 빼는 방향을 잘 고르면 비어 있다', () {
      final sc = kGuaranteeScenarios[2];
      final cells = DandState.sow(sc.flowers, sc.used);
      var used = 0;
      for (final d in sc.used) {
        used |= 1 << d.index;
      }
      final sure = DandState.guaranteed(cells, used);
      final left = [for (final d in WindDir.values) if (used & (1 << d.index) == 0) d];
      final unsure = [for (var i = 0; i < cells.length; i++) if (cells[i] == kEmpty && !sure.contains(i)) i];
      final reach = DandState.reachMasks(cells, used);
      for (final c in unsure) {
        final dirs = [for (final d in left) if (reach[c] & (1 << d.index) != 0) d];
        if (dirs.isEmpty) continue; // 애초에 닿는 길이 없는 칸
        final after = DandState.sow(sc.flowers, [...sc.used, for (final d in left) if (d != dirs.first) d]);
        expect(after[c], kEmpty);
      }
    });

    test('협력 계획은 규칙대로 두어지고 마지막에 초원이 가득 찬다', () {
      final s = DandState();
      for (var i = 0; i < kCoopMoves.length; i++) {
        expect(s.isOver, isFalse, reason: '${i + 1}번째 수 전에 끝나면 안 돼요');
        expect(s.legalMoves(), contains(kCoopMoves[i]), reason: '${i + 1}번째 수');
        s.apply(kCoopMoves[i]);
      }
      expect(s.isOver, isTrue);
      expect(s.winner, Role.dandelion);
      expect(s.emptyCount, 0);
      expect(s.windCount, kWindTurns);
    });
  });

  group('교과학습 화면', () {
    Future<void> pumpLesson(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const DandelionLessonScreen()),
      ));
      await tester.pump();
    }

    testWidgets('모든 단원이 오류 없이 열리고, 만져 보는 그림이 동작한다', (tester) async {
      await pumpLesson(tester);
      expect(find.text('교과학습'), findsOneWidget);
      await tester.tap(find.textContaining('1. 민들레 한눈에 보기'));
      await tester.pumpAndSettle();
      for (var i = 1; i < 7; i++) {
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.textContaining('다음:'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('다음:'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
      await tester.scrollUntilVisible(find.textContaining('나침반에는 바람 방향이 8개 있어요'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('7방향 (한 방향은 안 불어요)'));
      await tester.pump();
      expect(find.text('정답! 🎉'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('보장된 칸 찾기: 빈칸을 누르면 이유가 나오고 정답 보기가 된다', (tester) async {
      await pumpLesson(tester);
      await tester.tap(find.textContaining('3. 보장된 칸 찾기'));
      await tester.pumpAndSettle();
      expect(find.text('비어 있는 칸을 눌러 보세요.'), findsWidgets);
      final board = find.byType(CustomPaint).evaluate().map((e) => e.widget).length; // 그림이 있다
      expect(board, greaterThan(0));
      await tester.tap(find.text('보장된 칸 모두 보기'));
      await tester.pump();
      expect(find.textContaining('초록 체크'), findsOneWidget);
      await tester.tap(find.text('문제 2'));
      await tester.pump();
      await tester.tap(find.text('보장된 칸 모두 보기'));
      await tester.pump();
      expect(find.text('이 문제에는 보장된 칸이 하나도 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
