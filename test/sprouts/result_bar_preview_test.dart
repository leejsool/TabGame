// 끝난 판의 화면을 그림(PNG)으로 뽑아보는 도구. SPROUTS_PREVIEW_DIR 이 지정됐을 때만 실행된다.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';

void main() {
  final dir = Platform.environment['SPROUTS_PREVIEW_DIR'];
  testWidgets('끝난 판 미리보기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final key = GlobalKey();
    for (final (name, size) in [('phone', const Size(390, 844)), ('tablet', const Size(1000, 700))]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, rng: Random(3));
      while (!c.isOver) {
        final m = findMoves(c.board).first;
        expect(c.tryStroke(m.path), isTrue);
      }
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: SettingsScope(
          settings: settings,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
            home: SproutsScreen(controller: c),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/over_$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    tester.view.reset();
  }, skip: dir == null);
}
