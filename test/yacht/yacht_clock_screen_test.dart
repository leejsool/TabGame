import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

  testWidgets('시간 제한 판: 점수판 이름 줄 밑에 남은 시간 막대가 있고, 시간이 줄면 막대도 짧아진다', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final shot = GlobalKey();
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, turnSeconds: 60, rng: Random(1), cpuSeats: const [1]);
    c.game.roll(Random(2));
    c.actions = 1;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: RepaintBoundary(key: shot, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: 2, controller: c))),
    ));
    await tester.pump();
    expect(c.secondsLeft, 60);
    expect(find.byKey(const ValueKey('yacht-clock')), findsOneWidget);
    final bar = find.descendant(of: find.byKey(const ValueKey('yacht-clock')), matching: find.byType(DecoratedBox));
    expect(tester.getSize(bar).height, 5, reason: '막대가 보이는 두께');
    final full = tester.getSize(bar).width;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 2));
    final dir = Platform.environment['YACHT_PREVIEW_DIR'];
    if (dir != null) {
      await tester.pump(const Duration(seconds: 1));
      await savePng(tester, await captureBoundary(tester, shot), '$dir/clock_screen.png');
    }
    final half = tester.getSize(find.descendant(of: find.byKey(const ValueKey('yacht-clock')), matching: find.byType(DecoratedBox))).width;
    expect(half, lessThan(full * 0.6));
    expect(half, greaterThan(full * 0.4));
    // 시간 무제한 판에는 막대가 없다
    await tester.pumpWidget(const SizedBox());
    final u = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(1));
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(home: YachtScreen(mode: u.mode, players: 2, controller: u)),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('yacht-clock')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
