// 프리셀 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 FREECELL_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';

void main() {
  final dir = Platform.environment['FREECELL_PREVIEW_DIR'];

  testWidgets('프리셀 화면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, FreecellController c) async {
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
              home: FreecellScreen(controller: c),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 새 판 (세로 / 가로)
    await shoot('portrait_new', const Size(820, 1300), FreecellController(deal: 617, autoMoveEnabled: false));
    await shoot('landscape_new', const Size(1280, 720), FreecellController(deal: 617, autoMoveEnabled: false));

    // 몇 수 둔 뒤 + 힌트 표시
    final c = FreecellController(deal: 1, autoMoveEnabled: false, autoDelay: const Duration(milliseconds: 1));
    // 프리셀에 두 장을 맡겨 두고, 열 사이로 한 장을 옮긴 뒤 힌트를 보여준다
    for (var i = 0; i < 2; i++) {
      c.tryMove(c.state.legalMoves(forSolver: true).firstWhere((m) => m.to == Place.cell));
    }
    final colMoves = c.state.legalMoves(forSolver: true).where((m) => m.to == Place.column).toList();
    if (colMoves.isNotEmpty) c.tryMove(colMoves.first);
    final hint = c.state.legalMoves(forSolver: true).firstWhere((m) => m.to == Place.column || m.to == Place.foundation);
    c.hint = FcHint(hint);
    await shoot('portrait_hint', const Size(820, 1300), c);
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('FREECELL_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
