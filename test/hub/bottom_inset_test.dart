import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_menu_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_lesson_screen.dart';
import 'package:tabgame/hub/settings_screen.dart';
import 'package:tabgame/records/records_screen.dart';

/// 안드로이드 내비게이션 바(아래 시스템 바)가 가리는 영역: 화면 내용이 그 위에서 끝나야 한다.
const double _navBar = 60;
const Size _screen = Size(800, 1200);

Future<void> pump(WidgetTester tester, Widget Function(Settings) screen) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: _screen, padding: EdgeInsets.only(top: 24, bottom: _navBar)),
          child: screen(settings),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  void expectAboveNavBar(WidgetTester tester) {
    final lists = find.byType(Scrollable);
    expect(lists, findsWidgets);
    for (final e in lists.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      expect(bottom, lessThanOrEqualTo(_screen.height - _navBar + 0.5), reason: '${e.widget} 이 내비게이션 바에 가려져요');
    }
  }

  testWidgets('설정 화면 내용이 내비게이션 바 위에서 끝난다', (tester) async {
    await pump(tester, (s) => SettingsScreen(settings: s));
    expectAboveNavBar(tester);
  });

  testWidgets('기록 화면 내용이 내비게이션 바 위에서 끝난다', (tester) async {
    await pump(tester, (_) => const RecordsScreen());
    expectAboveNavBar(tester);
  });

  testWidgets('게임 첫 화면(겟 컬러)과 교과학습 내용이 내비게이션 바 위에서 끝난다', (tester) async {
    await pump(tester, (_) => const GetColorMenuScreen());
    expectAboveNavBar(tester);
    await pump(tester, (_) => const UtttLessonScreen());
    expectAboveNavBar(tester);
  });
}
