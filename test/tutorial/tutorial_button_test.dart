import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/ui/freecell_menu_screen.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_menu_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_setup_screen.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_menu_screen.dart';
import 'package:tabgame/games/minesweeper/ui/mines_menu_screen.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_menu_screen.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_menu_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_setup_screen.dart';
import 'package:tabgame/tutorial/tutorial_screen.dart';

/// 게임 첫 화면(난이도·설정을 고르는 곳)마다 "튜토리얼 보기" 버튼이 눈에 띄게 있고, 누르면 안내가 열린다.
void main() {
  final screens = <String, Widget Function()>{
    '겟 컬러': () => const GetColorMenuScreen(),
    '지뢰찾기': () => const MinesMenuScreen(),
    '솔리테어': () => const SolitaireMenuScreen(),
    '프리셀': () => const FreecellMenuScreen(),
    '직소퍼즐': () => const JigsawMenuScreen(),
    '리듬 검사단': () => const RhythmMenuScreen(),
    '고블렛 고블러스': () => const GobbletSetupScreen(),
    '얼티밋 틱택토': () => const UtttSetupScreen(),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final (label, size) in const [('폰 세로', Size(360, 740)), ('폰 가로', Size(740, 360))]) {
      testWidgets('$name 첫 화면($label): 튜토리얼 보기 버튼이 있고, 눌러서 안내를 열 수 있다', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final settings = await Settings.load();
        await tester.pumpWidget(SettingsScope(
          settings: settings,
          child: MaterialApp(theme: ThemeData(useMaterial3: true), home: build()),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 60));
        }
        final button = find.text('튜토리얼 보기');
        // 가로 화면처럼 낮은 화면에서는 스크롤해야 보일 수 있다 (목록은 보이는 곳만 만들어진다)
        if (button.evaluate().isEmpty) {
          await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
        }
        expect(button, findsOneWidget, reason: '$name: 버튼이 보이지 않아요');
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button, warnIfMissed: false);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(find.byType(TutorialScreen), findsOneWidget, reason: '$name: 안내가 열리지 않아요');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
