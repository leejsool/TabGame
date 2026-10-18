import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_setup_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_setup_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_setup_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_setup_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_setup_screen.dart';

import '../support/preview_kit.dart';

/// 게임 고르기 → 게임플레이 옵션 선택 → 인게임. 인게임에서 뒤로가면 옵션 선택 화면이어야 한다 (바로 게임 고르기가 아니라).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  final cases = <String, (Widget Function(), Type setup, Type game)>{
    '예언': (() => const ProphecySetupScreen(mode: PlayMode.vsCpu), ProphecySetupScreen, ProphecyScreen),
    '예언 둘이서': (() => const ProphecySetupScreen(mode: PlayMode.local2p), ProphecySetupScreen, ProphecyScreen),
    '콩나물': (() => const SproutsSetupScreen(mode: PlayMode.vsCpu), SproutsSetupScreen, SproutsScreen),
    '궁극 틱택토': (() => const UtttSetupScreen(), UtttSetupScreen, UtttScreen),
    '고블렛': (() => const GobbletSetupScreen(), GobbletSetupScreen, GobbletScreen),
    '민들레': (() => const DandelionSetupScreen(), DandelionSetupScreen, DandelionScreen),
  };

  cases.forEach((name, c) {
    testWidgets('$name: 인게임에서 뒤로가면 옵션 선택 화면으로 돌아오고, 한 번 더 뒤로가면 처음 화면이다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'tutorial.seen.all': true});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => c.$1())),
                  child: const Text('게임 열기'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('게임 열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(c.$2), findsOneWidget);

      await tester.tap(find.text('시작하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(c.$3), findsOneWidget);

      // 인게임에서 뒤로 (시스템 뒤로 버튼과 같은 길)
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      await nav.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(c.$3), findsNothing);
      expect(find.byType(c.$2), findsOneWidget, reason: '$name: 게임에서 뒤로가면 옵션 선택 화면이어야 해요');
      expect(find.text('시작하기'), findsOneWidget);

      await nav.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(c.$2), findsNothing);
      expect(find.text('게임 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
