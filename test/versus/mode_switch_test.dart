import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/uttt/ui/uttt_setup_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_wifi_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/net/lan_screens.dart';
import 'package:tabgame/versus/vs_mode_switch.dart';

Future<Widget> _app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 허브 대신 쓰는 첫 화면: 누르면 [mode]로 게임을 연다.
Widget _hub(GameInfo game, PlayMode mode) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (ctx) => game.builder!(ctx, mode))),
            child: const Text('허브에서 열기'),
          ),
        ),
      ),
    );

void main() {
  final uttt = allGames.firstWhere((g) => g.id == 'ultimate_tictactoe');

  testWidgets('CPU 설정 화면에서 허브로 나가지 않고 Wi‑Fi · 둘이서로 바꾸고, 뒤로 가면 원래 설정 화면으로 돌아온다', (tester) async {
    await tester.pumpWidget(await _app(_hub(uttt, PlayMode.vsCpu)));
    await tester.tap(find.text('허브에서 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(UtttSetupScreen), findsOneWidget);
    expect(find.byType(VsModeSwitch), findsOneWidget);
    for (final label in ['CPU', '둘이서', 'Wi‑Fi']) {
      expect(find.widgetWithText(SegmentedButton<PlayMode>, label), findsOneWidget, reason: label);
    }

    // Wi‑Fi로 바꾸면 방 만들기/찾기 화면이 위에 쌓인다
    await tester.tap(find.text('Wi‑Fi'));
    await tester.pumpAndSettle();
    expect(find.byType(UtttWifiScreen), findsOneWidget);
    expect(find.byType(LanChooseScreen), findsOneWidget);
    expect(find.byType(VsModeSwitch), findsOneWidget);

    // 거기서 다시 CPU로 (칩으로 연 화면에서는 바꿔 끼운다)
    await tester.tap(find.text('CPU'));
    await tester.pumpAndSettle();
    expect(find.byType(UtttSetupScreen), findsOneWidget);
    expect(find.byType(UtttWifiScreen), findsNothing);

    // 뒤로: 처음 열었던 CPU 설정 화면 → 허브
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(UtttSetupScreen), findsOneWidget, reason: '처음 설정 화면으로 돌아온다');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('허브에서 열기'), findsOneWidget);
  });

  testWidgets('설정 화면 없이 바로 시작하는 "둘이서" 게임에서 뒤로 가면 CPU 설정 화면으로 돌아와 다시 바꿀 수 있다', (tester) async {
    await tester.pumpWidget(await _app(_hub(uttt, PlayMode.vsCpu)));
    await tester.tap(find.text('허브에서 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘이서'));
    await _settle(tester);
    expect(find.byType(UtttScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(UtttSetupScreen), findsOneWidget);
    expect(find.byType(VsModeSwitch), findsOneWidget);
  });

  testWidgets('방 만들기 설정 화면에는 전환 칩이 없다 (방 찾기 첫 화면에서 바꾼다)', (tester) async {
    await tester.pumpWidget(await _app(const UtttHostSetupScreen()));
    await tester.pump();
    expect(find.byType(VsModeSwitch), findsNothing);
  });

  group('모든 대결 게임의 시작 전 화면에 전환 칩이 있다', () {
    final versus = [for (final g in allGames) if (g.isReady && g.modes.contains(PlayMode.vsCpu) && g.modes.contains(PlayMode.wifi)) g];
    test('대결 게임이 있다', () => expect(versus.length, greaterThanOrEqualTo(8)));
    for (final g in versus) {
      for (final mode in [PlayMode.vsCpu, PlayMode.wifi]) {
        testWidgets('${g.title} · ${mode.name}', (tester) async {
          await tester.pumpWidget(await _app(Builder(builder: (context) => g.builder!(context, mode))));
          await tester.pump();
          expect(find.byType(VsModeSwitch), findsOneWidget);
          expect(find.byType(SegmentedButton<PlayMode>), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
