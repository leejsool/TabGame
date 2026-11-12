import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_daesung_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_look.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_setup_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_wifi_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final advisor = YachtDaesungAdvisor(YachtDaesungValues.fromBytes(File('assets/yacht/values_ds.bin').readAsBytesSync()));
  final dir = Platform.environment['YACHT_PREVIEW_DIR'];

  Future<Settings> setUpView(WidgetTester tester, Size size) async {
    await loadAppFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    return Settings.load();
  }

  testWidgets('설정: 대성One Rule을 켜면 쓰리카드 옵션이 사라지고, 물음표를 누르면 규칙 설명이 뜬다', (tester) async {
    final settings = await setUpView(tester, const Size(400, 1100));
    final shot = GlobalKey();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: RepaintBoundary(key: shot, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: const YachtSetupScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('대성One Rule'), findsOneWidget);
    expect(find.text('쓰리카드 칸 넣기'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('yacht-daesung')), matching: find.byType(Switch)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('쓰리카드 칸 넣기'), findsNothing);
    if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/ds_setup.png');
    await tester.tap(find.byKey(const ValueKey('yacht-daesung-help')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('로고가 나오면 만능'), findsOneWidget);
    expect(find.textContaining('고정 70점'), findsOneWidget);
    if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/ds_help.png');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wi‑Fi 방 만들기 전 규칙 화면: 대성One Rule 스위치와 물음표 설명, 방 만들기 단추', (tester) async {
    final settings = await setUpView(tester, const Size(400, 860));
    final shot = GlobalKey();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: RepaintBoundary(key: shot, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: const YachtRoomOptionsScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('대성One Rule'), findsOneWidget);
    expect(find.byKey(const ValueKey('yacht-room-create')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('yacht-daesung')), matching: find.byType(Switch)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('yacht-daesung')), matching: find.byType(Switch))).value, isTrue);
    if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/ds_room_options.png');
    await tester.tap(find.byKey(const ValueKey('yacht-daesung-help')));
    await tester.pumpAndSettle();
    expect(find.textContaining('로고가 나오면 만능'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final (name, size) in const [('tabP', Size(800, 1280)), ('phone', Size(400, 860))]) {
    testWidgets('게임: 0번이 초록 대성One 주사위, 점수판에 원즈 · 55점 보너스, 야추 보너스 줄 없음, 힌트가 된다 ($name)', (tester) async {
      final settings = await setUpView(tester, size);
      final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, daesung: true, cpuSeats: const [1], rng: Random(3));
      c.game.applyRoll([1, 6, 6, 2, 5]);
      c.actions = 1;
      final shot = GlobalKey();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: RepaintBoundary(
          key: shot,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: 2, controller: c)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('원즈'), findsOneWidget);
      expect(find.text('에이스'), findsNothing);
      expect(find.text('포카드'), findsNothing);
      expect(find.text('스몰 스트레이트'), findsNothing);
      expect(find.text('야추 보너스'), findsNothing);
      expect(find.textContaining('/55'), findsWidgets, reason: '보너스 줄: 합/55');
      expect(find.byWidgetPredicate((w) => w is YachtDie && w.daesung && w.value == 1), findsOneWidget, reason: '로고(1) 대성One 주사위');
      // 풀하우스 미리보기: 로고 = 6 → 6 6 6 5? (아니고) → 1 6 6 2 5는 풀하우스가 아니다 / 찬스 = 6+6+6+2+5 = 25
      expect(find.descendant(of: find.byKey(const ValueKey('yacht-cell-0-choice')), matching: find.text('25')), findsOneWidget);
      if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/ds_game_$name.png');
      await tester.tap(find.text('힌트'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('추천'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/ds_hint_$name.png');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
