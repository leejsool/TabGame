import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/ui/yacht_lesson_parts.dart';
import 'package:tabgame/games/yacht/ui/yacht_lesson_screen.dart';

void main() {
  group('교과학습에 적은 수가 맞다', () {
    final values = YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync());
    final advisor = YachtAdvisor(values);

    test('차례 처음의 야추 확률 약 4.6%, 찬스만 노리면 평균 70/3점', () {
      expect(advisor.chanceFromStart(YachtCategory.yacht), closeTo(0.046, 0.0005));
      expect(advisor.expectedFromStart(YachtCategory.choice), closeTo(70 / 3, 1e-6));
    });

    test('같은 눈 4개면 11/36, 3개면 121/1296 (다시 굴리기 2번)', () {
      expect(advisor.outlook(YachtCategory.yacht, [3, 3, 3, 3, 5], 2).chance, closeTo(11 / 36, 1e-9));
      expect(advisor.outlook(YachtCategory.yacht, [3, 3, 3, 1, 5], 2).chance, closeTo(121 / 1296, 1e-9));
    });

    test('첫 굴림에 바로 라지 스트레이트는 240/7776', () {
      var hit = 0;
      for (var t = 0; t < 7776; t++) {
        final dice = [for (var i = 0; i < 5; i++) (t ~/ _pow6(i)) % 6 + 1];
        if (yachtScore(YachtCategory.largeStraight, yachtCounts(dice)) > 0) hit++;
      }
      expect(hit, 240);
    });
  });

  testWidgets('모든 단원이 오류 없이 열리고, 만져 보는 그림이 동작한다', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const YachtLessonScreen()),
    ));
    await tester.pump();
    await tester.tap(find.textContaining('1. 확률이란?'));
    await tester.pumpAndSettle();
    expect(find.text('전체 36칸 중에서 6칸'), findsOneWidget); // 합이 7
    await tester.tap(find.text('6이 적어도 하나'));
    await tester.pump();
    expect(find.text('전체 36칸 중에서 11칸'), findsOneWidget);

    for (var i = 1; i < YachtLessonScreen.units.length; i++) {
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('다음:'));
      await tester.pumpAndSettle();
      if (i == 3) {
        // 도박사의 오류: 많이 굴려 보면 "6이 5번 안 나온 다음"에도 6은 약 1/6
        await tester.scrollUntilVisible(find.text('10000번 굴리기'), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.text('10000번 굴리기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10000번 굴리기'));
        await tester.pump();
        final r = (tester.widget<Text>(find.byKey(const ValueKey('streak-result'))).data!);
        final pct = double.parse(RegExp(r'([\d.]+)%').firstMatch(r)!.group(1)!);
        expect(pct, inInclusiveRange(10, 24), reason: r);
      }
      if (i == 4) {
        // 조건부 확률: 처음엔 "6이 적어도 하나" 조건 → 11칸 중 1칸. 고르개 앞에 사건 A · 사건 B 꼬리표
        expect(find.text('사건 A'), findsWidgets);
        expect(find.text('사건 B'), findsWidgets);
        expect(find.text('조건에 맞는 11칸 중에서 1칸'), findsOneWidget);
        await tester.tap(find.textContaining('이 6', findRichText: true).first);
        await tester.pump();
        expect(find.text('조건에 맞는 6칸 중에서 1칸'), findsOneWidget);
        // 식 뒤집기: 단추를 누를 때마다 다음 단계 (마지막엔 처음부터)
        await tester.scrollUntilVisible(find.byKey(const ValueKey('formula-flip')), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.byKey(const ValueKey('formula-flip')));
        await tester.pumpAndSettle();
        final flip = tester.state<FormulaFlipDemoState>(find.byType(FormulaFlipDemo));
        for (final want in [1, 2, 0]) {
          await tester.tap(find.byKey(const ValueKey('formula-flip')));
          await tester.pumpAndSettle();
          expect(flip.stage, want);
        }
      }
      if (i == 5) {
        await tester.tap(find.text('1000번'));
        await tester.pump();
        final avg = tester.widget<Text>(find.byKey(const ValueKey('yacht-lesson-average'))).data!;
        expect(avg, startsWith('1000번 굴린 눈의 평균'));
      }
    }
    expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
    await tester.tap(find.byType(OutlinedButton).first); // 첫 문제의 첫 보기 (1/12, 분수 모양으로 그려진다)
    await tester.pump();
    expect(find.text('정답! 🎉'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

int _pow6(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 6;
  }
  return r;
}
