import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_art.dart';
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

    test('문제 세 개 모두 찾을 보장된 칸이 있다', () {
      for (final sc in kGuaranteeScenarios) {
        final cells = DandState.sow(sc.flowers, sc.used);
        var used = 0;
        for (final d in sc.used) {
          used |= 1 << d.index;
        }
        expect(DandState.guaranteed(cells, used), isNotEmpty, reason: sc.title);
      }
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

    testWidgets('보장된 칸 찾기: 틀린 칸은 이유가 나오고, 세 문제를 다 찾으면 축하해 준다', (tester) async {
      await pumpLesson(tester);
      tester.view.physicalSize = const Size(430, 2400); // 문제 그림이 한 화면에 다 들어오게
      await tester.tap(find.textContaining('3. 보장된 칸 찾기'));
      await tester.pumpAndSettle();
      expect(find.text('보장된 칸을 눌러 보세요.'), findsWidgets);
      expect(find.byKey(const ValueKey('guarantee-done')), findsNothing);

      Future<void> tapCell(int cell) async {
        final meadow = find.byType(CustomPaint).evaluate().map((e) => e.renderObject).whereType<RenderBox>().firstWhere((r) => r.size.width == 280);
        final layout = DandLayout(meadow.size.width);
        await tester.tapAt(meadow.localToGlobal(layout.center(cell)));
        await tester.pump();
      }

      for (var i = 0; i < kGuaranteeScenarios.length; i++) {
        final sc = kGuaranteeScenarios[i];
        await tester.tap(find.text(sc.title));
        await tester.pump();
        var used = 0;
        for (final d in sc.used) {
          used |= 1 << d.index;
        }
        final cells = DandState.sow(sc.flowers, sc.used);
        final sure = DandState.guaranteed(cells, used).toList()..sort();
        expect(find.text('찾은 보장된 칸  0 / ${sure.length}'), findsOneWidget, reason: sc.title);
        // 보장되지 않은 빈칸을 누르면 이유가 나오고, 찾은 칸으로 세지 않는다
        final wrong = [for (var c = 0; c < cells.length; c++) if (cells[c] == kEmpty && !sure.contains(c)) c].first;
        await tapCell(wrong);
        expect(find.textContaining('보장되지 않아요'), findsOneWidget, reason: sc.title);
        expect(find.text('찾은 보장된 칸  0 / ${sure.length}'), findsOneWidget);
        // '정답 보기'는 찾은 칸으로 세지 않는다
        await tester.tap(find.text('보장된 칸 모두 보기'));
        await tester.pump();
        expect(find.text('찾은 보장된 칸  0 / ${sure.length}'), findsOneWidget);
        await tester.tap(find.text('정답 숨기기'));
        await tester.pump();
        for (var k = 0; k < sure.length; k++) {
          await tapCell(sure[k]);
          expect(find.text('찾은 보장된 칸  ${k + 1} / ${sure.length}'), findsOneWidget, reason: '${sc.title} ${k + 1}번째');
        }
        expect(find.textContaining('${sc.title} 완성!'), findsOneWidget);
        if (i < kGuaranteeScenarios.length - 1) {
          expect(find.byKey(const ValueKey('guarantee-done')), findsNothing, reason: '아직 다 못 풀었어요');
          expect(find.byKey(const ValueKey('win-celebration')), findsNothing);
        }
      }
      // 세 문제를 모두 찾았다: 축하 연출과 축하 글
      expect(find.byKey(const ValueKey('guarantee-done')), findsOneWidget);
      expect(find.textContaining('축하해요'), findsWidgets);
      expect(find.byKey(const ValueKey('win-celebration')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });
  });
}
