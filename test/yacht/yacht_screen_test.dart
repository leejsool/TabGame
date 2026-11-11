import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_save.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_cpu.dart';
import 'package:tabgame/games/yacht/core/yacht_game.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_glow_border.dart';
import 'package:tabgame/games/yacht/ui/yacht_fraction_view.dart';
import 'package:tabgame/games/yacht/ui/yacht_look.dart';
import 'package:tabgame/games/yacht/ui/yacht_scale.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';

import '../support/preview_kit.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

Future<void> pumpScreen(WidgetTester tester, YachtController c, {Size size = const Size(400, 860)}) async {
  await loadAppFonts();
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(
    settings: settings,
    child: MaterialApp(theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: c.players, controller: c)),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('굴리고 · 잡고 · 칸을 골라 적으면 다음 사람 차례', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(3));
    await pumpScreen(tester, c);
    expect(c.game.turn, 0);
    expect(find.text('잡음'), findsNothing, reason: '"잡음" 대신 "고정"');
    expect(find.text('고정'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('yacht-roll')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.rolling, isTrue);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(c.rolling, isFalse);
    expect(c.game.rollsUsed, 1);
    final first = List<int>.of(c.game.dice);

    await tester.tap(find.byKey(const ValueKey('yacht-die-0')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.game.held[0], isTrue);
    await tester.tap(find.byKey(const ValueKey('yacht-roll')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(c.game.rollsUsed, 2);
    expect(c.game.dice[0], first[0]);

    // 적을 칸을 고르기 전에는 "적기"가 꺼져 있다
    await tester.tap(find.byKey(const ValueKey('yacht-confirm')));
    await tester.pump();
    expect(c.game.turn, 0);

    final sum = c.game.dice.reduce((a, b) => a + b);
    await tester.tap(find.byKey(const ValueKey('yacht-cell-0-choice')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.pick, YachtCategory.choice);
    expect(find.text('찬스 · $sum점 적기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('yacht-confirm')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.game.cards[0].scores[YachtCategory.choice.index], sum);
    expect(c.game.turn, 1);
    expect(find.textContaining('적을까요'), findsNothing, reason: '점수판 위의 안내 박스는 없앴다');
    expect(await GameSave.load('yacht'), isNotNull, reason: '하던 판은 이어하기용으로 보관된다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('족보 이름을 누르면 설명이 팝업으로 뜬다 (점수 칸은 따로 눌러서 고른다)', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(3), threeKind: true);
    await pumpScreen(tester, c);

    Future<void> expectHelp(String key, String body) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('yacht-help-body')), findsOneWidget, reason: key);
      expect(find.text(body), findsOneWidget, reason: key);
      await tester.tap(find.text('확인'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('yacht-help-body')), findsNothing);
    }

    await expectHelp('yacht-help-ones', '1이 나온 주사위 눈의 총합 (최대 5점)');
    await expectHelp('yacht-help-sixes', '6이 나온 주사위 눈의 총합 (최대 30점)');
    await expectHelp('yacht-help-threeKind', '같은 눈이 3개 이상일 때 주사위 눈 5개의 총합 (최대 30점)');
    await expectHelp('yacht-help-fullHouse', '같은 눈 3개와 같은 눈 2개로 묶을 수 있을 때 고정 25점');
    await expectHelp('yacht-help-largeStraight', '이어지는 눈이 5개일 때 고정 40점 (1-2-3-4-5 또는 2-3-4-5-6)');
    await expectHelp('yacht-help-bonus', '에이스~식스 여섯 칸의 합이 63점 이상이면 보너스 35점! 숫자마다 3개씩 모으면 딱 63점이에요.');
    await expectHelp('yacht-help-yahtzee-bonus', '야추 칸에 50점을 적은 뒤, 야추(같은 눈 5개)를 또 굴려서 아무 칸에나 적으면 그때마다 100점을 더 받아요.');
    expect(c.pick, isNull, reason: '이름을 눌러도 칸이 골라지지는 않는다');

    // 굴린 뒤에도 이름은 설명, 점수 칸은 고르기
    await tester.tap(find.byKey(const ValueKey('yacht-roll')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const ValueKey('yacht-help-choice')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('주사위 눈 5개의 총합 (최대 30점). 모양이 필요 없어서 애매한 주사위를 버리기 좋아요.'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.pick, isNull);
    await tester.tap(find.byKey(const ValueKey('yacht-cell-0-choice')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.pick, YachtCategory.choice);
    expect(tester.takeException(), isNull);
  });

  testWidgets('힌트 팝업은 폭이 넓고, 분수를 누르면 왜 그 확률인지 한 번 더 팝업으로 설명한다', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(3));
    await pumpScreen(tester, c);
    c.game.applyRoll([1, 1, 1, 2, 3]);
    c.game.applyRoll([1, 1, 1, 2, 3]); // 굴림이 한 번 남았다
    c.actions = 1;
    c.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('힌트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.byKey(const ValueKey('yacht-hint-row-fourKind')));
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-fourKind')));
    await tester.pump(const Duration(milliseconds: 500));
    final popup = find.byKey(const ValueKey('yacht-chance-popup'));
    expect(popup, findsOneWidget);
    expect(tester.getSize(popup).width, greaterThan(370), reason: '좌우 폭을 넓혀서 한 줄에 다 보인다 (화면 400)');
    expect(find.textContaining('왜 그런 값인지'), findsOneWidget);

    // 11/36 (바로 완성)을 누르면 설명이 한 번 더 뜬다
    final fractions = find.descendant(of: popup, matching: find.byType(YachtTapFraction));
    expect(fractions, findsWidgets);
    await tester.tap(fractions.first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('yacht-explain-popup')), findsOneWidget);
    expect(find.text('6 × 6 = 36가지예요.', findRichText: false), findsNothing);
    expect(tester.widget<Text>(find.byKey(const ValueKey('yacht-explain-total'))).data, '주사위 하나마다 6가지씩이라 6 × 6 = 36가지예요.');
    expect(tester.widget<Text>(find.byKey(const ValueKey('yacht-explain-ways'))).data, '합쳐서 11가지');
    expect(find.text('A가 1일 때, B가 1~6 → 6가지'), findsOneWidget);
    expect(find.textContaining('반대로 세기'), findsOneWidget);
    expect(find.textContaining('겹치는 것 빼기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('확인').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-explain-popup')), findsNothing);
    expect(popup, findsOneWidget, reason: '설명만 닫히고 아래 팝업은 그대로');
    await tester.tap(find.text('확인').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(popup, findsNothing);
  });

  testWidgets('태블릿: 족보 설명 글이 모든 줄에서 같은 자리에서 시작한다 (스몰 스트레이트 설명에 맞춰)', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 3, advisor: advisor, rng: Random(3), threeKind: true);
    await pumpScreen(tester, c, size: const Size(800, 1280));
    final texts = [
      '1만 모두 더해요', // 에이스 (주사위 그림이 있는 줄)
      '6만 모두 더해요',
      '1~6 칸의 합이 63점 이상이면 +35점', // 보너스
      '같은 눈 3개 이상 → 눈 5개의 합', // 쓰리카드
      '같은 눈 4개 이상 → 눈 5개의 합', // 포카드
      '이어진 눈 4개 → 30점', // 스몰 스트레이트 (가장 긴 이름)
      '이어진 눈 5개 → 40점',
      '같은 눈 5개 → 50점', // 야추
      '눈 5개의 합', // 찬스
      '야추를 또 굴려 적으면 +100점씩', // 야추 보너스
    ];
    final xs = [for (final t in texts) tester.getTopLeft(find.text(t)).dx];
    for (var i = 0; i < xs.length; i++) {
      expect(xs[i], closeTo(xs[5], 0.6), reason: '${texts[i]}의 시작 위치 ${xs[i]} (스몰 스트레이트 설명 ${xs[5]})');
    }
    expect(tester.takeException(), isNull);
  });

  test('전자칠판처럼 큰 화면만 통째로 키운다 (폰 · 일반 태블릿은 그대로)', () {
    expect(YachtScaled.factor(const Size(400, 860)), 1);
    expect(YachtScaled.factor(const Size(844, 390)), 1, reason: '폰 가로');
    expect(YachtScaled.factor(const Size(800, 1280)), 1, reason: '태블릿 세로');
    expect(YachtScaled.factor(const Size(1280, 800)), 1, reason: '태블릿 가로');
    expect(YachtScaled.factor(const Size(1920, 1080)), closeTo(1.35, 1e-9), reason: '전자칠판: 세로가 빠듯한 쪽에 맞춘다');
    expect(YachtScaled.factor(const Size(3840, 2160)), closeTo(2.4, 1e-9), reason: '4K는 2.4배까지');
    expect(YachtScaled.factor(const Size(1080, 1920)), closeTo(1.35, 1e-9), reason: '세로로 세운 칠판');
  });

  testWidgets('전자칠판 크기에서도 같은 화면이 한 화면 안에 들어가고 글자가 커진다', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 3, advisor: advisor, rng: Random(3));
    await pumpScreen(tester, c, size: const Size(1920, 1080));
    final size = tester.getSize(find.byKey(const ValueKey('yacht-help-ones')));
    expect(size.height, greaterThan(40), reason: '칸 높이가 칠판에서 커졌다 (태블릿 가로는 약 45)');
    expect(tester.getBottomRight(find.byKey(const ValueKey('yacht-help-yahtzee-bonus'))).dy, lessThan(1080));
    expect(tester.getBottomRight(find.byKey(const ValueKey('yacht-roll'))).dx, lessThan(1920));
    expect(tester.takeException(), isNull);
  });

  testWidgets('핸드폰 가로 모드: 점수판을 숫자 칸 · 족보 칸 두 덩어리로 잘라 가로로 놓고 글자가 잘리지 않는다', (tester) async {
    for (final players in [2, 4]) {
      final c = YachtController(mode: PlayMode.local2p, players: players, advisor: advisor, rng: Random(3), threeKind: true);
      await pumpScreen(tester, c, size: const Size(844, 390));
      // 숫자 칸은 왼쪽 덩어리, 족보 칸은 오른쪽 덩어리 (같은 높이에서 시작)
      final ones = tester.getTopLeft(find.byKey(const ValueKey('yacht-help-ones')));
      final three = tester.getTopLeft(find.byKey(const ValueKey('yacht-help-threeKind')));
      final four = tester.getTopLeft(find.byKey(const ValueKey('yacht-help-fourKind')));
      expect(three.dx, greaterThan(ones.dx + 200), reason: '$players명: 족보 칸은 오른쪽 덩어리');
      expect((three.dy - ones.dy).abs(), lessThan(40), reason: '$players명: 두 덩어리의 첫 줄 높이가 비슷하다');
      expect(four.dx, three.dx);
      expect(four.dy, greaterThan(three.dy));
      // 줄 높이가 넉넉하다 (세로 모드보다 글자가 작아지지 않게)
      final rowH = tester.getSize(find.byKey(const ValueKey('yacht-help-ones'))).height;
      expect(rowH, greaterThan(26), reason: '$players명: 줄 높이 $rowH');
      // 점수판은 화면(390) 안에 다 들어간다
      expect(tester.getBottomLeft(find.byKey(const ValueKey('yacht-help-yahtzee-bonus'))).dy, lessThan(390));
      // 옆 칸: 주사위 두 줄 + 단추
      expect(find.byKey(const ValueKey('yacht-roll')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('yacht-roll'))).dx, greaterThan(600));
      expect(tester.takeException(), isNull, reason: '$players명 가로 모드');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('굴리기가 끝나면 주사위가 왼쪽부터 눈이 작은 순서로 부드럽게 정렬된다', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(8));
    await pumpScreen(tester, c);

    List<int> leftToRight() {
      final order = [0, 1, 2, 3, 4]..sort((a, b) => tester.getTopLeft(find.byKey(ValueKey('yacht-die-$a'))).dx.compareTo(tester.getTopLeft(find.byKey(ValueKey('yacht-die-$b'))).dx));
      return [for (final i in order) c.game.dice[i]];
    }

    Future<void> rollAndSettle() async {
      await tester.tap(find.byKey(const ValueKey('yacht-roll')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(c.rolling, isFalse);
      await tester.pump(const Duration(milliseconds: 50)); // 정렬이 막 시작된 때
      final x0 = [for (var i = 0; i < 5; i++) tester.getTopLeft(find.byKey(ValueKey('yacht-die-$i'))).dx];
      await tester.pump(const Duration(milliseconds: 200)); // 가는 중
      final xMid = [for (var i = 0; i < 5; i++) tester.getTopLeft(find.byKey(ValueKey('yacht-die-$i'))).dx];
      await tester.pump(const Duration(milliseconds: 600)); // 도착
      final sorted = leftToRight();
      expect([...sorted]..sort(), sorted, reason: '왼쪽부터 오름차순: $sorted');
      // 자리가 바뀌는 주사위가 있었다면 중간에 움직이고 있었어야 한다 (순간이동이 아니라 미끄러짐)
      final xEnd = [for (var i = 0; i < 5; i++) tester.getTopLeft(find.byKey(ValueKey('yacht-die-$i'))).dx];
      for (var i = 0; i < 5; i++) {
        if ((x0[i] - xEnd[i]).abs() > 1) {
          expect(xMid[i] != x0[i] && xMid[i] != xEnd[i], isTrue, reason: '$i번 주사위는 부드럽게 움직여야 해요');
        }
      }
    }

    await rollAndSettle();
    // 하나를 고정하고 다시 굴려도 다시 정렬된다
    await tester.tap(find.byKey(const ValueKey('yacht-die-2')));
    await tester.pump(const Duration(milliseconds: 200));
    await rollAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('힌트: 추천을 보여 주고, 누르면 그대로 잡거나 칸을 골라 준다', (tester) async {
    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(3));
    await pumpScreen(tester, c);
    expect(c.canHint, isFalse, reason: '굴리기 전에는 힌트가 없다');
    c.game.applyRoll([3, 1, 3, 6, 3]);
    c.actions = 1;
    c.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('힌트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('추천: 표시한 주사위를 고정하고 다시 굴리기'), findsOneWidget);
    // 힌트의 주사위도 게임 화면처럼 왼쪽부터 눈이 작은 순서로 놓인다
    final shownDice = tester.widgetList<YachtDie>(find.descendant(of: find.byType(BottomSheet), matching: find.byType(YachtDie))).take(5).map((d) => d.value).toList();
    expect(shownDice, [1, 3, 3, 3, 6]);
    expect(find.byType(YachtGlowBorder), findsNothing, reason: '칸을 추천하지 않고 주사위를 고정하라는 추천일 때는 띠가 없다');
    expect(find.textContaining('완성'), findsWidgets);
    expect(find.text('121/1296'), findsNothing, reason: '줄에는 퍼센트만 보이고, 분수는 눌러서 여는 계산 과정에서 나온다');
    expect(find.text('완성 9.3%'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('yacht-hint-row-yacht')));
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-yacht')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-chance-popup')), findsOneWidget);
    expect(find.byKey(const ValueKey('yacht-chance-intro')), findsOneWidget);
    expect(find.textContaining('3개를 굴려'), findsNothing);
    expect(find.text('121'), findsWidgets, reason: '분자');
    expect(find.text('1296'), findsWidgets, reason: '분모 (가로줄 위아래로 나뉘어 그려진다)');
    expect(find.text('121/1296'), findsNothing, reason: '/ 글자가 아니라 진짜 분수 모양');
    expect(tester.widget<Text>(find.byKey(const ValueKey('yacht-chance-total'))).data, '≈ 9.3%');
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-chance-popup')), findsNothing);
    // 에이스~식스 줄은 점수만 보이고, 누르면 자세한 확률 창이 뜬다
    expect(find.byKey(const ValueKey('yacht-hint-row-threes')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('yacht-hint-row-threes')));
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-threes')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-odds-intro')), findsOneWidget);
    expect(find.textContaining('트레이 확률'), findsOneWidget);
    expect(find.textContaining('3이 3개예요'), findsOneWidget);
    expect(find.byKey(const ValueKey('yacht-odds-row-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('yacht-odds-average')), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-odds-intro')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('yacht-hint-apply')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.game.held, [true, false, true, false, true]);

    c.game.applyRoll([4, 4, 4, 4, 4]);
    c.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('힌트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('추천: ‘야추’ 칸에 50점 적기'), findsOneWidget);
    expect(find.byKey(const ValueKey('yacht-hint-glow-yacht')), findsOneWidget, reason: '추천하는 족보 테두리에는 빛나는 띠가 돈다');
    expect(find.byKey(const ValueKey('yacht-hint-glow-choice')), findsNothing, reason: '추천이 아닌 줄에는 없다');
    await tester.tap(find.byKey(const ValueKey('yacht-hint-apply')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.pick, YachtCategory.yacht);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CPU는 자기 차례를 스스로 끝내고 내 차례로 넘긴다', (tester) async {
    for (final level in YachtLevel.values) {
      final c = YachtController(mode: PlayMode.vsCpu, players: 3, level: level, advisor: advisor, rng: Random(11), first: 1);
      await pumpScreen(tester, c);
      for (var i = 0; i < 90 && c.game.turn != 0; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.game.turn, 0, reason: level.label);
      expect(c.game.cards[1].scores.where((s) => s != null).length, 1);
      expect(c.game.cards[2].scores.where((s) => s != null).length, 1);
      expect(c.thinking, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
  });

  test('CPU끼리 끝까지 두면 어려움이 쉬움보다 평균 점수가 높다', () {
    double average(YachtLevel level) {
      final rng = Random(21);
      var total = 0;
      const games = 60;
      for (var g = 0; g < games; g++) {
        final game = YachtGame(playerCount: 1);
        while (!game.over) {
          game.roll(rng);
          while (true) {
            final move = YachtCpu.choose(advisor, game, level, rng);
            if (move.category != null) {
              game.score(move.category!);
              break;
            }
            game.setHolds(move.holds!);
            game.roll(rng);
          }
        }
        total += game.cards[0].total;
      }
      return total / games;
    }

    final easy = average(YachtLevel.easy), normal = average(YachtLevel.normal), hard = average(YachtLevel.hard);
    // ignore: avoid_print
    print('평균 점수: 쉬움 ${easy.toStringAsFixed(1)} · 보통 ${normal.toStringAsFixed(1)} · 어려움 ${hard.toStringAsFixed(1)}');
    expect(hard, greaterThan(normal));
    expect(normal, greaterThan(easy));
    expect(hard, greaterThan(170));
  });

  test('보관했다가 되살리면 하던 판 그대로', () {
    final c = YachtController(mode: PlayMode.vsCpu, players: 3, level: YachtLevel.hard, advisor: advisor, rng: Random(1));
    c.game.applyRoll([2, 2, 5, 6, 6]);
    c.game.score(YachtCategory.twos);
    c.actions = 2;
    final back = YachtController.fromJson(c.toJson())!;
    expect(back.mode, PlayMode.vsCpu);
    expect(back.players, 3);
    expect(back.level, YachtLevel.hard);
    expect(back.game.toJson(), c.game.toJson());
    expect(back.savable, isTrue);
    expect(YachtController.fromJson({'mode': 'nope'}), isNull);
  });
}
