// 앱 화면을 한 번에 찍는 미리보기 도구: 허브·설정·기록, 모든 게임의 첫 화면과 게임 화면을
// 폰 · 태블릿 세로 · 태블릿 가로로 찍고, 세 크기를 나란히 붙인 그림(<이름>_all.png)도 만든다. 폰은 다크 모드도 찍는다.
//
// 환경변수 PREVIEW_DIR 가 있을 때만 실행된다 (평소 테스트에서는 건너뜀). 쓰는 법은 tool/preview_all.ps1 참고.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dotcannon/core/dot_levels.dart';
import 'package:tabgame/games/dotcannon/game/dot_controller.dart';
import 'package:tabgame/games/dotcannon/ui/dot_screen.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';
import 'package:tabgame/games/getcolor/core/getcolor_rules.dart';
import 'package:tabgame/games/getcolor/game/getcolor_controller.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/minesweeper/core/mines_rules.dart';
import 'package:tabgame/games/minesweeper/game/mines_controller.dart';
import 'package:tabgame/games/minesweeper/ui/mines_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/rummikub/game/rummikub_controller.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_screen.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';
import 'package:tabgame/games/snake/game/snake_controller.dart';
import 'package:tabgame/games/snake/ui/snake_screen.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/ui/game_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/hub/hub_screen.dart';
import 'package:tabgame/hub/settings_screen.dart';
import 'package:tabgame/records/records_screen.dart';

import 'support/preview_kit.dart';

final dir = Platform.environment['PREVIEW_DIR'];
late Settings settings;

Future<void> setup() async {
  await loadAppFonts();
  SharedPreferences.setMockInitialValues({});
  settings = await Settings.load();
  Directory(dir!).createSync(recursive: true);
}

/// [home]을 세 크기로 찍어 `<name>_<크기>.png`와 나란히 붙인 `<name>_all.png`를 남긴다. [dark]면 폰 크기만 다크 모드로 찍는다.
Future<void> shoot(WidgetTester tester, String name, Widget Function() home, {bool dark = false}) async {
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
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final image = await captureBoundary(tester, key);
    await savePng(tester, image, '$dir/${name}_${e.key}${dark ? '_dark' : ''}.png');
    shots.add(image);
  }
  if (shots.length > 1) await savePng(tester, await sideBySide(tester, shots), '$dir/${name}_all.png');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  RummikubScreen.playSounds = false;
  final skip = dir == null;

  testWidgets('hub', (tester) async {
    await setup();
    addTearDown(tester.view.reset);
    await shoot(tester, 'hub', () => HubScreen(settings: settings));
    await shoot(tester, 'hub', () => HubScreen(settings: settings), dark: true);
    await shoot(tester, 'settings', () => SettingsScreen(settings: settings));
    await shoot(tester, 'records', () => const RecordsScreen(initialGame: 'sudoku'));
  }, skip: skip);

  // 게임마다 처음 여는 화면 (메뉴·설정)
  for (final g in allGames.where((g) => g.isReady)) {
    testWidgets('entry ${g.id}', (tester) async {
      await setup();
      addTearDown(tester.view.reset);
      final mode = g.hasSolo ? PlayMode.solo : PlayMode.vsCpu;
      await shoot(tester, 'entry_${g.id}', () => Builder(builder: (ctx) => g.builder!(ctx, mode)));
      await shoot(tester, 'entry_${g.id}', () => Builder(builder: (ctx) => g.builder!(ctx, mode)), dark: true);
    }, skip: skip);
  }

  // 게임 화면 (새 게임을 추가하면 여기에도 한 줄 더한다)
  final games = <String, Widget Function()>{
    'sudoku': () => SudokuGameScreen(game: SudokuGame(puzzle: PuzzleGenerator.generate(Difficulty.easy, rng: Random(1)))),
    'mines': () => MinesScreen(controller: MinesController(level: MinesLevel.intermediate, rng: Random(4))),
    'solitaire': () => SolitaireScreen(controller: SolitaireController(deal: 4, draw: 1, autoMoveEnabled: false)),
    'freecell': () => FreecellScreen(controller: FreecellController(deal: 617, autoMoveEnabled: false)),
    'getcolor': () => GetColorScreen(controller: GetColorController(level: GcLevel.normal, initial: WaterState.shuffled(GcLevel.normal, Random(3)))),
    'dotcannon': () => DotScreen(controller: DotController(level: dotLevels.first)),
    'uttt': () => const UtttScreen(mode: PlayMode.local2p),
    'goblet': () => const GobbletScreen(mode: PlayMode.local2p),
    'prophecy': () => const ProphecyScreen(mode: PlayMode.local2p),
    'quoridor': () => const QuoridorScreen(mode: PlayMode.local2p),
    'dandelion': () => const DandelionScreen(mode: PlayMode.local2p),
    'sprouts': () => const SproutsScreen(mode: PlayMode.local2p, dotCount: 4),
    'davinci': () => DavinciScreen(players: 3, controller: DavinciController(mode: PlayMode.vsCpu, players: 3, seed: 8)..cpuStepDelay = Duration.zero),
    'snake': () => SnakeScreen(controller: SnakeController.host(nick: '나', rng: Random(5)), showHint: false),
    'rummikub': () => RummikubScreen(controller: RummikubController(animate: false, mode: PlayMode.vsCpu, players: 3, seed: 12)),
  };
  for (final e in games.entries) {
    testWidgets('game ${e.key}', (tester) async {
      await setup();
      addTearDown(tester.view.reset);
      await shoot(tester, 'game_${e.key}', e.value);
      await shoot(tester, 'game_${e.key}', e.value, dark: true);
    }, skip: skip);
  }
}
