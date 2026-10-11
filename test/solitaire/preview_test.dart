// 솔리테어 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 SOLITAIRE_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/solitaire/core/solitaire_rules.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_screen.dart';

void main() {
  final dir = Platform.environment['SOLITAIRE_PREVIEW_DIR'];

  testWidgets('솔리테어 화면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, SolitaireController c) async {
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
              home: SolitaireScreen(controller: c),
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

    // 새 판 (세로 / 가로, 1장·3장), 몇 수 둔 뒤 + 힌트
    await shoot('portrait_new', const Size(820, 1300), SolitaireController(deal: 617, autoMoveEnabled: false));
    await shoot('landscape_new', const Size(1280, 720), SolitaireController(deal: 617, draw: 3, autoMoveEnabled: false));

    final c = SolitaireController(deal: 4, draw: 3, autoMoveEnabled: false);
    for (var i = 0; i < 4; i++) {
      c.drawFromStock();
    }
    final wMove = c.state.legalMoves().where((m) => m.kind == SolKind.wasteToCol || m.kind == SolKind.colToCol);
    if (wMove.isNotEmpty) c.tryMove(wMove.first);
    c.hint = c.state.hint();
    await shoot('portrait_play', const Size(820, 1300), c);
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('SOLITAIRE_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
