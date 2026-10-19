// 지렁이의 모험 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 SNAKE_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/snake/data/snake_prefs.dart';
import 'package:tabgame/games/snake/game/snake_controller.dart';
import 'package:tabgame/games/snake/ui/snake_menu_screen.dart';
import 'package:tabgame/games/snake/ui/snake_screen.dart';
import 'package:tabgame/hub/game_icons.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['SNAKE_PREVIEW_DIR'];

  testWidgets('지렁이의 모험 미리보기 이미지 만들기', (tester) async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, Widget home, {Future<void> Function()? before}) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: home,
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      if (before != null) await before();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// 몇십 초 돌려 둔 판 (내 뱀은 조금 키워 둔다).
    SnakeController grown(int seed, {double mass = 120}) {
      final c = SnakeController.host(nick: '나', rng: Random(seed));
      final me = c.world!.snakeOfSeat(0)!;
      me.mass = mass;
      for (var i = 0; i < 60 * 20; i++) {
        c.steer(me.angle + 0.01);
        c.frame(1 / 60);
        if (c.world!.snakeOfSeat(0) == null) c.world!.respawnSeat(0)!.mass = mass;
      }
      return c;
    }

    await shoot('game_phone', const Size(400, 860), SnakeScreen(controller: grown(1), showHint: false));
    SharedPreferences.setMockInitialValues({'snake.boardFolded': true});
    await shoot('game_folded', const Size(400, 860), SnakeScreen(controller: grown(6), showHint: false));
    SharedPreferences.setMockInitialValues({});
    await SnakePrefs.load();
    await shoot('game_hint', const Size(400, 860), SnakeScreen(controller: SnakeController.host(nick: '나', rng: Random(2))));
    await shoot('game_tablet', const Size(800, 1280), SnakeScreen(controller: grown(3, mass: 400), showHint: false));
    await shoot('game_landscape', const Size(1280, 800), SnakeScreen(controller: grown(4), showHint: false));
    final dead = grown(5);
    await shoot('game_dead', const Size(400, 860), SnakeScreen(controller: dead, showHint: false), before: () async {
      final me = dead.world!.snakeOfSeat(0)!;
      me.x = -50; // 벽 밖으로
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
    });
    await shoot('menu', const Size(400, 860), const SnakeMenuScreen());
    final info = allGames.firstWhere((g) => g.id == 'snake');
    await shoot('icon', const Size(300, 300), Scaffold(backgroundColor: info.color, body: Center(child: GameIcon(game: info, size: 240))));
  }, skip: dir == null);
}
