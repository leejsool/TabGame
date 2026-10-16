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
    CardLook.palette = SuitPalette.twoColor;
  });

  test('기본 카드 모양은 바이시클, 4색은 꺼짐', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.cardStyle, CardStyle.bicycle);
    expect(s.suitPalette, SuitPalette.twoColor);
    expect(CardLook.style, CardStyle.bicycle);
  });

  test('카드 모양과 4색 설정이 저장되고 다시 열면 그대로', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    s.cardStyle = CardStyle.cute;
    s.suitPalette = SuitPalette.family;
    expect(CardLook.style, CardStyle.cute);
    expect(CardLook.palette, SuitPalette.family);
    CardLook.style = CardStyle.bicycle; // 앱을 다시 켠 것처럼
    CardLook.palette = SuitPalette.twoColor;
    final again = await Settings.load();
    expect(again.cardStyle, CardStyle.cute);
    expect(again.suitPalette, SuitPalette.family);
    expect(CardLook.style, CardStyle.cute);
  });

  test('모르는 값이 저장돼 있으면 바이시클로', () async {
    SharedPreferences.setMockInitialValues({'cardStyle': 'nope'});
    final s = await Settings.load();
    expect(s.cardStyle, CardStyle.bicycle);
  });

  test('52장 모두 모든 모양으로 오류 없이 그려진다', () {
    for (final style in CardStyle.values) {
      for (final palette in SuitPalette.values) {
        for (var card = 0; card < 52; card++) {
          final recorder = ui.PictureRecorder();
          drawCard(Canvas(recorder), card, const Size(100, 140), style: style, palette: palette);
          recorder.endRecording().dispose();
        }
      }
    }
  });

  test('4색이면 무늬마다 색이 다르고, 아니면 빨강/검정 둘뿐', () {
    CardLook.palette = SuitPalette.twoColor;
    expect({for (var s = 0; s < 4; s++) suitColor(s)}.length, 2);
    CardLook.palette = SuitPalette.fourColor;
    expect({for (var s = 0; s < 4; s++) suitColor(s)}.length, 4);
    CardLook.palette = SuitPalette.family;
    expect({for (var s = 0; s < 4; s++) suitColor(s)}.length, 4);
  });

  test('기본은 ♠♣ 검정 · ♥♦ 빨강, 4색은 ♠ 검정 ♥ 빨강 ♣ 초록 ♦ 파랑, 계열 유지는 검정 계열(♠ 검정·♣ 진초록)과 빨강 계열(♥ 빨강·♦ 주황)', () {
    // 무늬 번호: ♣=0 ♦=1 ♥=2 ♠=3
    Color c(SuitPalette p, int suit) => paletteSuitColor(p, suit);
    expect(c(SuitPalette.twoColor, 3), c(SuitPalette.twoColor, 0));
    expect(c(SuitPalette.twoColor, 2), c(SuitPalette.twoColor, 1));
    expect(c(SuitPalette.fourColor, 3), kCardBlack);
    expect(c(SuitPalette.fourColor, 2), kCardRed);
    expect(c(SuitPalette.fourColor, 0), const Color(0xFF2E8B4F)); // 초록
    expect(c(SuitPalette.fourColor, 1), const Color(0xFF2F6FDB)); // 파랑
    expect(c(SuitPalette.family, 3), kCardBlack);
    expect(c(SuitPalette.family, 2), kCardRed);
    // 계열 유지: 클로버는 초록이어도 어둡고, 다이아는 따뜻한 색 (밝기와 색조가 각자 계열 쪽)
    final club = HSLColor.fromColor(c(SuitPalette.family, 0)), diamond = HSLColor.fromColor(c(SuitPalette.family, 1));
    expect(club.lightness, lessThan(0.35));
    expect(diamond.hue, lessThan(40)); // 빨강~주황
  });

  test('예전 "무늬 4색으로 보기"를 켜 둔 사람은 4색으로 이어받는다', () async {
    SharedPreferences.setMockInitialValues({'cardFourColor': true});
    expect((await Settings.load()).suitPalette, SuitPalette.fourColor);
    SharedPreferences.setMockInitialValues({'cardFourColor': true, 'suitPalette': 'family'});
    expect((await Settings.load()).suitPalette, SuitPalette.family);
    SharedPreferences.setMockInitialValues({});
    expect((await Settings.load()).suitPalette, SuitPalette.twoColor);
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
    // 끝까지 스크롤한다 (항목이 늦게 만들어져서 끝이 늘어날 수 있으니 몇 번 되풀이한다)
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
    }
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
    // 무늬 색: 세 가지가 나란히 보이고, 누르면 바로 바뀐다
    expect(find.text('무늬 색깔'), findsOneWidget);
    expect(find.text('기본 (두 색)'), findsOneWidget);
    await tester.ensureVisible(find.text('4색'));
    await tester.tap(find.text('4색'));
    await tester.pump();
    expect(settings.suitPalette, SuitPalette.fourColor);
    await tester.ensureVisible(find.text('4색 (계열 유지)'));
    await tester.tap(find.text('4색 (계열 유지)'));
    await tester.pump();
    expect(settings.suitPalette, SuitPalette.family);
    await tester.tap(find.text('기본 (두 색)'));
    await tester.pump();
    expect(settings.suitPalette, SuitPalette.twoColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 폭에서도 무늬 색 고르기가 넘치지 않고 둘 다 보인다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
    await tester.scrollUntilVisible(find.text('4색'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('기본 (두 색)'), findsOneWidget);
    expect(find.text('검정 · 빨강 두 가지'), findsOneWidget);
    expect(find.text('무늬마다 다른 색'), findsOneWidget);
    expect(find.text('검정 계열 · 빨강 계열'), findsOneWidget);
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
