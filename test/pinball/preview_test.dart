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
      // 다음 라운드 3·2·1: 판 위에서 움직이던 공에 방향·빠르기 화살표가 붙는다
      final moving = PinballController(seed: 1);
      moving.run.engine.balls
        ..clear()
        ..add(Ball(300, 1000)
          ..waiting = false
          ..vx = 500
          ..vy = -1500)
        ..add(Ball(200, 1150)
          ..waiting = false
          ..vx = -200
          ..vy = 300);
      moving.camY = 400;
      await shoot('countdown_moving_${e.key}', e.value, PinballScreen(controller: moving));
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
    // 판 전체가 한 화면에 보이는 크기로, 그림 위에 충돌 벽을 겹쳐 그린다 (배경 그림을 바꾸면 이걸로 벽 자리를 맞춘다)
    final full = PinballController(seed: 9);
    full.run
      ..update(3.1)
      ..ballSaveLeft = PinballRun.ballSaveSecs; // (볼 세이브 불빛 자리도 같이 본다)
    await shoot('debug_full', const Size(700, 1900), PinballScreen(controller: full, debugWalls: true));
    await shoot('menu', const Size(400, 860), const PinballMenuScreen());
    await shoot('scoring', const Size(400, 860), const PinballScoringScreen());
    await shoot('scoring_tablet', const Size(800, 1280), const PinballScoringScreen());
    final info = allGames.firstWhere((g) => g.id == 'pinball');
    await shoot('icon', const Size(300, 300), Scaffold(backgroundColor: info.color, body: Center(child: GameIcon(game: info, size: 240))));
  }, skip: dir == null);
}
