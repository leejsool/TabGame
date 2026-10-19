// 도트 캐논 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 DOTCANNON_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dotcannon/core/dot_levels.dart';
import 'package:tabgame/games/dotcannon/game/dot_controller.dart';
import 'package:tabgame/games/dotcannon/ui/dot_menu_screen.dart';
import 'package:tabgame/games/dotcannon/ui/dot_screen.dart';
import 'package:tabgame/hub/game_icons.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['DOTCANNON_PREVIEW_DIR'];

  testWidgets('도트 캐논 미리보기 이미지 만들기', (tester) async {
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
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 50));
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

    // 1) 게임 중: 고양이 (벨트에 대포 몇 대 올려 두고 조금 돌린 모습)
    final cat = dotLevels.firstWhere((l) => l.name == '고양이');
    final c = DotController(level: cat);
    await shoot('game_portrait', const Size(430, 900), DotScreen(controller: c), before: () async {
      for (var i = 0; i < 400 && c.game.remaining > 700; i++) {
        final ex = c.game.exposedColors();
        for (var col = 0; col < c.game.queue.length; col++) {
          final q = c.game.queue[col];
          if (q.isNotEmpty && ex.contains(q.first.color) && c.game.canDeploy(col)) {
            c.deploy(col);
            break;
          }
        }
        c.advance(DotController.stepSeconds);
      }
      c.advance(0.07);
      await tester.pump(const Duration(milliseconds: 16));
    });

    final c2 = DotController(level: dotLevels.firstWhere((l) => l.name == '유령'));
    await shoot('game_landscape', const Size(1000, 560), DotScreen(controller: c2), before: () async {
      for (var i = 0; i < 400; i++) {
        final ex = c2.game.exposedColors();
        for (var col = 0; col < c2.game.queue.length; col++) {
          final q = c2.game.queue[col];
          if (q.isNotEmpty && ex.contains(q.first.color) && c2.game.canDeploy(col)) {
            c2.deploy(col);
            break;
          }
        }
        c2.advance(DotController.stepSeconds);
      }
      await tester.pump(const Duration(milliseconds: 16));
    });

    // 1-2) 대기 중인 대포를 꾹 누른 모습: 같은 색의 도트와 대포(대기열·벨트)만 또렷하다
    final c3 = DotController(level: cat);
    await shoot('game_hold', const Size(430, 900), DotScreen(controller: c3), before: () async {
      for (var i = 0; i < 40; i++) {
        final ex = c3.game.exposedColors();
        for (var col = 0; col < c3.game.queue.length; col++) {
          final q = c3.game.queue[col];
          if (q.isNotEmpty && ex.contains(q.first.color) && c3.game.canDeploy(col)) {
            c3.deploy(col);
            break;
          }
        }
        c3.advance(DotController.stepSeconds);
      }
      c3.highlight.value = c3.game.belt.isNotEmpty ? c3.game.belt.first.color : c3.game.queue.first.first.color;
      await tester.pump(const Duration(milliseconds: 16));
    });

    // 2) 첫 화면
    await shoot('menu', const Size(430, 900), const DotMenuScreen());

    // 3) 허브 카드 아이콘
    final info = allGames.firstWhere((g) => g.id == 'dot_cannon');
    await shoot(
      'icon',
      const Size(300, 300),
      Scaffold(
        backgroundColor: info.color,
        body: Center(child: GameIcon(game: info, size: 240)),
      ),
    );
  }, skip: dir == null);
}
