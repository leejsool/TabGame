import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/nickname.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/settings_screen.dart';
import 'package:tabgame/net/lan_screens.dart';

Future<Widget> appWith(Settings settings, Widget home) async => SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
    );

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  group('별명 만들기와 다듬기', () {
    test('저절로 지은 별명은 "형용사 동물" 모양이고 여러 가지가 나온다', () {
      final rng = Random(1);
      final names = {for (var i = 0; i < 80; i++) randomNickname(rng)};
      expect(names.length, greaterThan(40));
      for (final n in names) {
        expect(n.split(' ').length, 2);
        expect(n.runes.length, lessThanOrEqualTo(kMaxNicknameLength));
      }
    });

    test('다듬기: 앞뒤·겹친 공백을 정리하고, 열 글자까지만 남기고, 비면 null', () {
      expect(cleanNickname('  빨간   토끼 '), '빨간 토끼');
      expect(cleanNickname('가나다라마바사아자차카타파하'), '가나다라마바사아자차');
      expect(cleanNickname('가나다라마바사아자 카'), '가나다라마바사아자'); // 열 글자 끝의 공백은 지운다
      expect(cleanNickname('   '), isNull);
      expect(cleanNickname(''), isNull);
      expect(cleanNickname(null), isNull);
      expect(cleanNickname(42), isNull);
      expect(cleanNickname('😀😀😀😀😀😀😀😀😀😀😀😀')!.runes.length, kMaxNicknameLength); // 이모지도 글자 수대로
    });
  });

  group('설정에 저장', () {
    test('처음 켜면 별명이 저절로 지어져 저장되고, 다음에 켜도 그대로다', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await Settings.load();
      expect(cleanNickname(first.nickname), first.nickname);
      expect((await SharedPreferences.getInstance()).getString('nickname'), first.nickname);
      final again = await Settings.load();
      expect(again.nickname, first.nickname);
    });

    test('바꾸면 저장되고 알려진다. 빈 별명은 무시하고 긴 별명은 잘린다', () async {
      SharedPreferences.setMockInitialValues({'nickname': '옛 이름'});
      final s = await Settings.load();
      expect(s.nickname, '옛 이름');
      var notified = 0;
      s.addListener(() => notified++);
      s.nickname = '  새   이름 ';
      expect(s.nickname, '새 이름');
      expect(notified, 1);
      expect((await SharedPreferences.getInstance()).getString('nickname'), '새 이름');
      s.nickname = '   ';
      expect(s.nickname, '새 이름');
      s.nickname = '새 이름'; // 같은 이름은 알리지 않는다
      expect(notified, 1);
      s.nickname = '가나다라마바사아자차카타';
      expect(s.nickname, '가나다라마바사아자차');
    });

    test('다시 뽑기는 지금과 다른 별명을 준다', () async {
      SharedPreferences.setMockInitialValues({'nickname': '빨간 토끼'});
      final s = await Settings.load();
      for (var i = 0; i < 30; i++) {
        final before = s.nickname;
        s.rerollNickname();
        expect(s.nickname, isNot(before));
      }
    });

    test('저장된 별명이 비었거나 망가졌으면 새로 짓는다', () async {
      SharedPreferences.setMockInitialValues({'nickname': '   '});
      final s = await Settings.load();
      expect(s.nickname.trim(), isNotEmpty);
      expect((await SharedPreferences.getInstance()).getString('nickname'), s.nickname);
    });
  });

  group('별명 바꾸는 화면', () {
    testWidgets('설정 화면에 내 별명이 보이고, 눌러서 바꿀 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'nickname': '빨간 토끼'});
      final settings = await Settings.load();
      await tester.pumpWidget(await appWith(settings, SettingsScreen(settings: settings)));
      await settle(tester);
      expect(find.text('내 별명'), findsOneWidget);
      expect(find.textContaining('빨간 토끼'), findsOneWidget);
      await tester.tap(find.text('내 별명'));
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '민수');
      await tester.tap(find.text('저장'));
      await settle(tester);
      expect(settings.nickname, '민수');
      expect(find.textContaining('민수'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('주사위(다시 뽑기)를 누르면 입력칸에 새 별명이 들어가고, 취소하면 바뀌지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'nickname': '빨간 토끼'});
      final settings = await Settings.load();
      await tester.pumpWidget(await appWith(settings, SettingsScreen(settings: settings)));
      await settle(tester);
      await tester.tap(find.text('내 별명'));
      await settle(tester);
      String field() => tester.widget<TextField>(find.byType(TextField)).controller!.text;
      expect(field(), '빨간 토끼');
      await tester.tap(find.byTooltip('다시 뽑기'));
      await tester.pump();
      expect(field(), isNot('빨간 토끼'));
      expect(cleanNickname(field()), field());
      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(settings.nickname, '빨간 토끼');
    });

    testWidgets('같은 Wi‑Fi 첫 화면 맨 위에서도 별명을 보고 바꿀 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'nickname': '빨간 토끼'});
      final settings = await Settings.load();
      await tester.pumpWidget(await appWith(
        settings,
        LanChooseScreen(
          title: '시험 · 같은 Wi‑Fi로 함께',
          color: Colors.indigo,
          recordsGame: 'sudoku',
          createRoom: (_) => const SizedBox(),
          findRoom: (_) => const SizedBox(),
        ),
      ));
      await settle(tester);
      expect(find.text('빨간 토끼'), findsOneWidget);
      await tester.tap(find.text('바꾸기'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '수진');
      await tester.tap(find.text('저장'));
      await settle(tester);
      expect(find.text('수진'), findsOneWidget);
      expect(settings.nickname, '수진');
    });
  });
}
