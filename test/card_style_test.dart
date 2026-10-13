import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/card_look.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/games/freecell/ui/playing_card.dart';
import 'package:tabgame/hub/settings_screen.dart';

void main() {
  tearDown(() {
    CardLook.style = CardStyle.bicycle;
    CardLook.layout = CardLayout.auto;
    CardLook.fourColor = false;
  });

  test('기본 카드 모양은 바이시클, 4색은 꺼짐', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.cardStyle, CardStyle.bicycle);
    expect(s.fourColor, isFalse);
    expect(CardLook.style, CardStyle.bicycle);
  });

  test('카드 모양과 4색 설정이 저장되고 다시 열면 그대로', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    s.cardStyle = CardStyle.cute;
    s.fourColor = true;
    expect(CardLook.style, CardStyle.cute);
    expect(CardLook.fourColor, isTrue);
    CardLook.style = CardStyle.bicycle; // 앱을 다시 켠 것처럼
    CardLook.fourColor = false;
    final again = await Settings.load();
    expect(again.cardStyle, CardStyle.cute);
    expect(again.fourColor, isTrue);
    expect(CardLook.style, CardStyle.cute);
  });

  test('모르는 값이 저장돼 있으면 바이시클로', () async {
    SharedPreferences.setMockInitialValues({'cardStyle': 'nope'});
    final s = await Settings.load();
    expect(s.cardStyle, CardStyle.bicycle);
  });

  test('52장 모두 모든 모양으로 오류 없이 그려진다', () {
    for (final style in CardStyle.values) {
      for (final four in [false, true]) {
        for (var card = 0; card < 52; card++) {
          final recorder = ui.PictureRecorder();
          drawCard(Canvas(recorder), card, const Size(100, 140), style: style, fourColor: four);
          recorder.endRecording().dispose();
        }
      }
    }
  });

  test('4색이면 무늬마다 색이 다르고, 아니면 빨강/검정 둘뿐', () {
    CardLook.fourColor = false;
    expect({for (var s = 0; s < 4; s++) suitColor(s)}.length, 2);
    CardLook.fourColor = true;
    expect({for (var s = 0; s < 4; s++) suitColor(s)}.length, 4);
  });

  test('카드 표시 방식: 기본은 자동이고, 자동은 폰(짧은 변 600 미만)에서만 폰용으로 그린다', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.cardLayout, CardLayout.auto);
    expect(CardLook.compactFor(360), isTrue);
    expect(CardLook.compactFor(599), isTrue);
    expect(CardLook.compactFor(800), isFalse);
    s.cardLayout = CardLayout.phone;
    expect(CardLook.compactFor(1200), isTrue, reason: '폰용을 고르면 태블릿에서도 간결하게');
    s.cardLayout = CardLayout.full;
    expect(CardLook.compactFor(360), isFalse, reason: '전체를 고르면 폰에서도 전체로');
  });

  test('카드 표시 방식이 저장되고, 모르는 값이면 자동', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    s.cardLayout = CardLayout.phone;
    CardLook.layout = CardLayout.auto; // 앱을 다시 켠 것처럼
    final again = await Settings.load();
    expect(again.cardLayout, CardLayout.phone);
    expect(CardLook.layout, CardLayout.phone);
    SharedPreferences.setMockInitialValues({'cardLayout': 'nope'});
    expect((await Settings.load()).cardLayout, CardLayout.auto);
  });

  test('52장 모두 모든 모양의 폰용 카드로도 오류 없이 그려진다', () {
    for (final style in CardStyle.values) {
      for (var card = 0; card < 52; card++) {
        final recorder = ui.PictureRecorder();
        drawCard(Canvas(recorder), card, const Size(44, 62), style: style, compact: true);
        recorder.endRecording().dispose();
      }
    }
  });

  testWidgets('설정 화면에서 카드 표시 방식을 고르면 바로 적용된다 (폰·태블릿 폭)', (tester) async {
    for (final size in const [Size(800, 1800), Size(360, 740)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
      for (final l in CardLayout.values) {
        final tile = find.byKey(ValueKey('card-layout-${l.name}'));
        if (tile.evaluate().isEmpty) {
          await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
        }
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pump();
        expect(settings.cardLayout, l, reason: '$size ${l.label}');
      }
      expect(find.text('카드 표시 (프리셀·솔리테어)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('설정 화면 맨 아래 항목이 아래 시스템 바에 가려지지 않는다', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 96); // 태블릿 아래 시스템 바
    tester.view.viewPadding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
    // 끝까지 스크롤한다
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();
    final last = tester.getRect(find.text('화면 모드')); // 업데이트 항목이 없는 환경에서는 맨 아래 항목
    expect(last.bottom, lessThanOrEqualTo(900 - 96), reason: '시스템 바 위로 올라와야 한다');
  });

  testWidgets('설정 화면에서 카드 모양을 고르면 바로 적용된다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
    expect(find.text('카드 모양'), findsOneWidget);
    for (final s in CardStyle.values) {
      expect(find.text(s.label), findsOneWidget);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('card-style-simple')));
    await tester.tap(find.byKey(const ValueKey('card-style-simple')));
    await tester.pump();
    expect(settings.cardStyle, CardStyle.simple);
    await tester.tap(find.text('무늬 4색으로 보기'));
    await tester.pump();
    expect(settings.fourColor, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 폭의 설정 화면에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
