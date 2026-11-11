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
  YachtController played(PlayMode mode, int players, int rounds, {bool rolled = true, int seed = 4, int humanSeat = 0, List<String>? names, bool three = false, List<int>? cpus}) {
    final rng = Random(seed);
    final c = YachtController(mode: mode, players: players, level: YachtLevel.hard, advisor: advisor, rng: rng, humanSeat: humanSeat, names: names, threeKind: three, cpuSeats: cpus);
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

    Future<void> shoot(String name, Widget Function() home, {bool dark = false, int wait = 600, bool hint = false}) async {
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
        if (hint) {
          await tester.tap(find.text('힌트'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        }
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
    await shoot('hint_roll', () => screen(played(PlayMode.local2p, 2, 3)), hint: true);
    await shoot('hint_score', () {
      final c = played(PlayMode.vsCpu, 2, 6, rolled: false);
      c.game.applyRoll([2, 3, 4, 5, 6]);
      c.game.applyRoll([2, 3, 4, 5, 6]);
      c.game.applyRoll([2, 3, 4, 5, 6]);
      return screen(c);
    }, hint: true);
    await shoot('cpu2',() => screen(played(PlayMode.vsCpu, 2, 8)));
    await shoot('start', () => screen(played(PlayMode.local2p, 2, 0, rolled: false)));
    await shoot('over3', () => screen(played(PlayMode.local2p, 3, 12)));
    // 같은 Wi-Fi 4명: 별명이 점수판에 들어가는지 (남의 차례 · 끝난 판의 "한 판 더")
    const nicks = ['도라지꽃', '나', '번개맨짱짱', 'CPU'];
    await shoot('wifi4', () => screen(played(PlayMode.wifi, 4, 5, humanSeat: 1, names: nicks)));
    await shoot('wifi_over', () => screen(played(PlayMode.wifi, 4, 12, humanSeat: 1, names: nicks)));
    // 쓰리카드 칸을 넣은 4명 판 (13줄이 스크롤 없이 한 화면에 다 들어가는지)
    await shoot('three4', () => screen(played(PlayMode.local2p, 4, 5, three: true)));
    await shoot('three_over', () => screen(played(PlayMode.local2p, 3, 13, three: true)));
    await shoot('setup', () => const YachtSetupScreen(mode: PlayMode.vsCpu));
    await shoot('setup_local', () => const YachtSetupScreen(mode: PlayMode.local2p));
    // 사람 2 + 봇 1(한 기기): 점수판에 "CPU" 이름이 들어가는 모습
    await shoot('mixed3', () => screen(played(PlayMode.local2p, 3, 4, cpus: [2])));
    await shoot('tutorial', () => Builder(builder: (context) => yachtTutorial().screen(context, firstTime: false)));
    expect(tester.takeException(), isNull);
  }, skip: dir == null);

  testWidgets('야추 정산 애니메이션 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(tester.view.reset);
    tester.view.physicalSize = kPreviewSizes['phone']!;
    tester.view.devicePixelRatio = 1.0;
    // 3명 판을 마지막 칸만 남기고 둔 뒤, 마지막 칸을 적어 끝낸다
    final c = played(PlayMode.local2p, 3, 12, rolled: false);
    c.game.cards.last.scores[YachtCategory.yacht.index] = null; // 마지막 사람의 마지막 칸을 비운다
    c.game.turn = 2;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: SettingsScope(settings: settings, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: c.players, controller: c))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    c.game.applyRoll([4, 4, 4, 4, 4]);
    c.pick = YachtCategory.yacht;
    c.notifyListeners();
    await tester.pump();
    c.confirm();
    var shot = 0;
    for (final ms in [300, 1500, 1500, 1500, 3500]) {
      await tester.pump(Duration(milliseconds: ms));
      final image = await captureBoundary(tester, key);
      await savePng(tester, image, '$dir/tally_${shot++}.png');
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: dir == null);

  testWidgets('야추 힌트 확률 창 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(tester.view.reset);
    tester.view.physicalSize = kPreviewSizes['phone']!;
    tester.view.devicePixelRatio = 1.0;
    final c = played(PlayMode.local2p, 2, 2, rolled: false);
    c.game.applyRoll([3, 1, 3, 6, 3]);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: SettingsScope(settings: settings, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: c.players, controller: c))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    c.actions = 1;
    c.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('힌트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await savePng(tester, await captureBoundary(tester, key), '$dir/odds_sheet.png');
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-threes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await savePng(tester, await captureBoundary(tester, key), '$dir/odds_popup.png');
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-yacht')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await savePng(tester, await captureBoundary(tester, key), '$dir/chance_popup.png');
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('yacht-hint-row-fullHouse')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await savePng(tester, await captureBoundary(tester, key), '$dir/chance_popup_fullhouse.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: dir == null);

  testWidgets('야추 힌트 추천 족보의 빛나는 띠 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(tester.view.reset);
    tester.view.physicalSize = kPreviewSizes['phone']!;
    tester.view.devicePixelRatio = 1.0;
    final c = played(PlayMode.local2p, 2, 3, rolled: false);
    c.game.applyRoll([4, 4, 4, 4, 4]);
    c.actions = 1;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: SettingsScope(settings: settings, child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: c.players, controller: c))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('힌트'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    for (var i = 0; i < 4; i++) {
      await savePng(tester, await captureBoundary(tester, key), '$dir/glow_$i.png');
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, skip: dir == null);
}
