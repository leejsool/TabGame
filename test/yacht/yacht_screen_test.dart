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
    expect(find.textContaining('플레이어 1 차례'), findsOneWidget);

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
    expect(find.text('초이스 · $sum점 적기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('yacht-confirm')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.game.cards[0].scores[YachtCategory.choice.index], sum);
    expect(c.game.turn, 1);
    expect(find.textContaining('플레이어 2 차례'), findsOneWidget);
    expect(await GameSave.load('yacht'), isNotNull, reason: '하던 판은 이어하기용으로 보관된다');
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
    expect(find.text('추천: 표시한 주사위를 잡고 다시 굴리기'), findsOneWidget);
    expect(find.textContaining('완성'), findsWidgets);
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
