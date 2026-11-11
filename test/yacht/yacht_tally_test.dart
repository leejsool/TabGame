import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_game.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_tally.dart';

import '../support/preview_kit.dart';

final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

/// [leaveLast]면 마지막 사람의 마지막 칸만 비워 둔다.
YachtGame playedGame(int players, {bool threeKind = false, bool leaveLast = false, int seed = 5}) {
  final rng = Random(seed);
  final game = YachtGame(playerCount: players, threeKind: threeKind);
  final cats = game.categories;
  for (var i = 0; i < cats.length; i++) {
    for (var p = 0; p < players; p++) {
      if (leaveLast && i == cats.length - 1 && p == players - 1) return game;
      game.roll(rng);
      game.score(cats[i]);
    }
  }
  return game;
}

void main() {
  group('정산 계산', () {
    test('점수판 줄 순서대로 (에이스부터, 보너스는 식스 바로 뒤, 야추 보너스는 맨 끝)', () {
      final game = playedGame(3);
      final tally = YachtTally(game, scale: (d) => d);
      final kinds = [for (final s in tally.steps) s.category?.label ?? s.kind.name];
      expect(kinds.first, '에이스');
      expect(kinds.sublist(0, 7), ['에이스', '듀스', '트레이', '포', '파이브', '식스', 'upperBonus']);
      expect(kinds.last, 'yahtzeeBonus');
      expect(tally.steps.length, game.categories.length + 2);
    });

    test('다 더하면 합계와 같다 (쓰리카드를 켠 판도)', () {
      for (final three in [false, true]) {
        final game = playedGame(4, threeKind: three, seed: three ? 9 : 4);
        final tally = YachtTally(game, scale: (d) => d);
        expect(tally.totals, [for (final c in game.cards) c.total]);
        expect(tally.frameAt(tally.duration).shown, tally.totals);
        expect(tally.frameAt(tally.duration).step, tally.steps.length);
      }
    });

    test('시간이 흐를수록 합계는 줄지 않고, 숫자가 내려가는 순간이 있다', () {
      final game = playedGame(2);
      final tally = YachtTally(game, scale: (d) => d);
      expect(tally.frameAt(Duration.zero).step, -1);
      expect(tally.frameAt(Duration.zero).shown, [0, 0]);
      var prev = [0, 0];
      var sawFly = false;
      var lastStep = -1;
      for (var ms = 0; ms <= tally.duration.inMilliseconds + 50; ms += 10) {
        final f = tally.frameAt(Duration(milliseconds: ms));
        for (var s = 0; s < 2; s++) {
          expect(f.shown[s], greaterThanOrEqualTo(prev[s]), reason: '$ms ms');
        }
        expect(f.step, greaterThanOrEqualTo(lastStep), reason: '줄은 위에서 아래로만 간다');
        lastStep = f.step;
        prev = f.shown;
        if (f.fly != null) {
          sawFly = true;
          expect(f.fly, inInclusiveRange(0, 1));
        }
      }
      expect(sawFly, isTrue);
    });

    test('점수가 없는 줄은 빨리 지나간다', () {
      final game = playedGame(2);
      final tally = YachtTally(game);
      expect(YachtTally.emptyStep, lessThan(YachtTally.valueStep));
      expect(tally.duration, greaterThan(YachtTally.leadTime));
    });
  });

  testWidgets('점수판: 합계는 끝나기 전엔 숨겨져 있고, 끝나면 맨 윗줄부터 더해져 최종 점수가 나온다', (tester) async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(3));
    final game = playedGame(2, leaveLast: true);
    c.game = game;
    c.actions = 1;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: c.players, controller: c)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('yacht-total-0')), findsNothing, reason: '진행 중에는 합계가 없다');
    expect(find.text('합계'), findsNothing);

    // 마지막 칸을 적어 게임을 끝낸다
    game.applyRoll([3, 3, 3, 4, 5]);
    c.pick = game.categories.last;
    c.notifyListeners();
    await tester.pump();
    c.confirm();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.isOver, isTrue);
    final totals = [for (final card in game.cards) card.total];

    // 합계 줄이 나타나고 0에서 시작한다
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('yacht-total-0')), findsOneWidget);
    expect(find.text('점수 계산!'), findsOneWidget);
    expect(find.text('끝!'), findsNothing);
    int shown(int seat) => int.parse(tester.widget<Text>(find.byKey(ValueKey('yacht-total-$seat'))).data!);
    expect(shown(0), 0);

    // 정산이 진행되는 동안 숫자가 내려가고 합계가 단계적으로 올라간다
    var sawFly = false;
    var prev = 0;
    var steps = 0;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(const ValueKey('yacht-fly-0')).evaluate().isNotEmpty || find.byKey(const ValueKey('yacht-fly-1')).evaluate().isNotEmpty) sawFly = true;
      final now = shown(0);
      expect(now, greaterThanOrEqualTo(prev));
      if (now != prev) steps++;
      prev = now;
      if (find.text('끝!').evaluate().isNotEmpty) break;
    }
    expect(sawFly, isTrue, reason: '점수가 합계로 내려오는 숫자가 보였어야 한다');
    expect(steps, greaterThan(3), reason: '한꺼번에 바뀌지 않고 줄마다 더해진다');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('끝!'), findsOneWidget);
    expect(shown(0), totals[0]);
    expect(shown(1), totals[1]);
    // 이긴 사람이 표시된다 (머리줄에 트로피)
    expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    // 축하 연출이 끝나도록 기다린다
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
