import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/rhythm/ui/calibration_screen.dart';

import '../records/records_test.dart' show appWith;

void main() {
  testWidgets('박자 보정: 처음 네 박은 4, 3, 2, 1로 세고, 그다음부터 탭하라고 알려 준다', (tester) async {
    SharedPreferences.setMockInitialValues({'sound': false});
    await tester.pumpWidget(await appWith(const CalibrationScreen()));
    await tester.pump();

    String bubble() => tester
        .widget<Text>(find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(Text)))
        .data!;

    expect(bubble(), '준비');
    await tester.tap(find.text('시작'));
    // 진짜 시간으로 흐르는 시계라서, 조금씩 기다리며 원 안의 글자가 바뀌는 순서를 모은다
    final seen = <String>[];
    for (var i = 0; i < 60 && !seen.contains('탭!'); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      final b = bubble();
      if (seen.isEmpty || seen.last != b) seen.add(b);
    }
    expect(seen, ['준비', '4', '3', '2', '1', '탭!']);
    // 화면을 닫으면 돌고 있던 시계를 멈춘다
    await tester.pumpWidget(const SizedBox());
  });
}
