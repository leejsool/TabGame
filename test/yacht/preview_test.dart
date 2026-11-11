// 야추 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 YACHT_PREVIEW_DIR 가 지정됐을 때만 실행한다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_cpu.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/tutorial/yacht_tutorial.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_setup_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['YACHT_PREVIEW_DIR'];
  final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));

  /// [rounds] 라운드까지 CPU끼리 둔 판. [rolled]면 지금 차례가 주사위를 한 번 굴린 모습.
  YachtController played(PlayMode mode, int players, int rounds, {bool rolled = true, int seed = 4}) {
    final rng = Random(seed);
    final c = YachtController(mode: mode, players: players, level: YachtLevel.hard, advisor: advisor, rng: rng);
    final game = c.game;
    for (var turn = 0; turn < rounds * players && !game.over; turn++) {
      game.roll(rng);
      while (true) {
        final move = YachtCpu.choose(advisor, game, YachtLevel.normal, rng);
        if (move.category != null) {
          c.lastSeat = game.turn;
          c.lastCategory = move.category;
          game.score(move.category!);
          break;
        }
        game.setHolds(move.holds!);
        game.roll(rng);
      }
    }
    c.actions = 1;
    if (rolled && !game.over) game.roll(rng);
    return c;
  }

  testWidgets('야추 화면 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(tester.view.reset);

    Future<void> shoot(String name, Widget Function() home, {bool dark = false, int wait = 600}) async {
      final shots = <ui.Image>[];
      for (final e in kPreviewSizes.entries) {
        if (dark && e.key != 'phone') continue;
        tester.view.physicalSize = e.value;
        tester.view.devicePixelRatio = 1.0;
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: previewTheme(Brightness.light),
              darkTheme: previewTheme(Brightness.dark),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Builder(builder: (_) => home()),
            ),
          ),
        ));
        await tester.pump(Duration(milliseconds: wait));
        final image = await captureBoundary(tester, key);
        await savePng(tester, image, '$dir/${name}_${e.key}${dark ? '_dark' : ''}.png');
        shots.add(image);
      }
      if (shots.length > 1) await savePng(tester, await sideBySide(tester, shots), '$dir/${name}_all.png');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Widget screen(YachtController c) => YachtScreen(mode: c.mode, players: c.players, controller: c);

    // 4명이 한 기기로: 한 번 굴리고 주사위 둘을 잡은 뒤 칸을 고른 모습
    YachtController four() {
      final c = played(PlayMode.local2p, 4, 5);
      c.game.toggleHold(0);
      c.game.toggleHold(1);
      c.pick = YachtCategory.values.firstWhere(c.game.card.isOpen);
      return c;
    }

    // 주사위가 구르는 도중 (잡은 둘은 그대로, 셋이 굴러온다)
    YachtController rollingNow() {
      final c = four();
      c.pick = null;
      c.rollTarget = [c.game.dice[0], c.game.dice[1], 6, 3, 5];
      c.rolling = true;
      return c;
    }

    await shoot('rolling', () => screen(rollingNow()), wait: 380);
    await shoot('local4', () => screen(four()));
    await shoot('local4', () => screen(four()), dark: true);
    await shoot('cpu2', () => screen(played(PlayMode.vsCpu, 2, 8)));
    await shoot('start', () => screen(played(PlayMode.local2p, 2, 0, rolled: false)));
    await shoot('over3', () => screen(played(PlayMode.local2p, 3, 12)));
    await shoot('setup', () => const YachtSetupScreen(mode: PlayMode.vsCpu));
    await shoot('tutorial', () => Builder(builder: (context) => yachtTutorial().screen(context, firstTime: false)));
    expect(tester.takeException(), isNull);
  }, skip: dir == null);
}
