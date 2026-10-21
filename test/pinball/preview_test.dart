// 핀볼 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 PINBALL_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/pinball/core/pinball_run.dart';
import 'package:tabgame/games/pinball/core/pinball_engine.dart';
import 'package:tabgame/games/pinball/game/pinball_controller.dart';
import 'package:tabgame/games/pinball/ui/pinball_menu_screen.dart';
import 'package:tabgame/games/pinball/ui/pinball_screen.dart';
import 'package:tabgame/games/pinball/ui/pinball_scoring_screen.dart';
import 'package:tabgame/games/pinball/ui/pinball_sprites.dart';
import 'package:tabgame/hub/game_icons.dart';

import '../support/preview_kit.dart';
import 'bot_sim_test.dart' show botFrame;

void main() {
  final dir = Platform.environment['PINBALL_PREVIEW_DIR'];

  testWidgets('핀볼 미리보기 이미지 만들기', (tester) async {
    await loadAppFonts();
    await tester.runAsync(PinballArt.load);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, Widget home) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    PinballController playing(int seed, {double secs = 12, int round = 1}) {
      final c = PinballController(seed: seed);
      final r = c.run;
      r.update(3.1);
      for (var i = 0; i < secs * 60; i++) {
        botFrame(r);
        r.update(1 / 60);
        if (r.phase == RunPhase.choosing) {
          r.pickFree(0);
          r.startNextRound();
        }
        if (r.phase == RunPhase.countdown) r.update(3.1);
      }
      return c;
    }

    for (final e in kPreviewSizes.entries) {
      final dbg = PinballController(seed: 9);
      dbg.run.update(3.1);
      await shoot('debug_bottom_${e.key}', e.value, PinballScreen(controller: dbg, debugWalls: true));
      final dbgTop = PinballController(seed: 9);
      dbgTop.run.update(3.1);
      dbgTop.camY = 0;
      dbgTop.run.engine.balls.clear();
      dbgTop.run.engine.balls.add(Ball(330, 300)..waiting = false);
      await shoot('debug_top_${e.key}', e.value, PinballScreen(controller: dbgTop, debugWalls: true));
      await shoot('countdown_${e.key}', e.value, PinballScreen(controller: PinballController(seed: 1)));
      await shoot('play_${e.key}', e.value, PinballScreen(controller: playing(2, secs: 14)));
      final choose = PinballController(seed: 3);
      choose.run
        ..update(3.1)
        ..score = choose.run.targetScore + 900
        ..update(0.02);
      await shoot('choose_${e.key}', e.value, PinballScreen(controller: choose));
      final picked = PinballController(seed: 3);
      picked.run
        ..update(3.1)
        ..score = picked.run.targetScore + 900
        ..update(0.02)
        ..pickFree(1);
      await shoot('choose_picked_${e.key}', e.value, PinballScreen(controller: picked));
      final over = PinballController(seed: 4);
      over.run
        ..update(3.1)
        ..stacks.addAll({'flip_len': 2, 'gold': 1})
        ..timeLeft = 0.01
        ..update(0.05);
      await shoot('over_${e.key}', e.value, PinballScreen(controller: over));
    }
    await shoot('menu', const Size(400, 860), const PinballMenuScreen());
    await shoot('scoring', const Size(400, 860), const PinballScoringScreen());
    await shoot('scoring_tablet', const Size(800, 1280), const PinballScoringScreen());
    final info = allGames.firstWhere((g) => g.id == 'pinball');
    await shoot('icon', const Size(300, 300), Scaffold(backgroundColor: info.color, body: Center(child: GameIcon(game: info, size: 240))));
  }, skip: dir == null);
}
