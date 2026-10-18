// 쿼리도 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 QUORIDOR_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/quoridor/core/quoridor_ai.dart';
import 'package:tabgame/games/quoridor/game/quoridor_controller.dart';
import 'package:tabgame/games/quoridor/tutorial/quoridor_tutorial.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_setup_screen.dart';
import 'package:tabgame/records/records_screen.dart';

import '../support/preview_kit.dart';

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  final dir = Platform.environment['QUORIDOR_PREVIEW_DIR'];
  testWidgets('쿼리도 화면 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final theme = ThemeData(useMaterial3: true, fontFamily: 'NanumGothic');
    final key = GlobalKey();

    Future<void> pumpHome(Widget home, {Size size = const Size(400, 800)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: SettingsScope(
          settings: settings,
          child: MaterialApp(key: UniqueKey(), debugShowCheckedModeBanner: false, theme: theme, home: home),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
    }

    addTearDown(tester.view.reset);

    QuoridorController midgame(int players) {
      final c = QuoridorController(mode: PlayMode.local2p, players: players);
      final rng = Random(5);
      for (var i = 0; i < 18 && !c.state.isOver; i++) {
        c.state.apply(QAi.choose(c.state, QLevel.normal, rng));
        c.moves.add(c.state.moveCount);
      }
      return c;
    }

    final four = midgame(4);
    four.setWallMode(true);
    four.pickWall(3, 3);
    await pumpHome(QuoridorScreen(players: 4, controller: four));
    await _shot(tester, key, '$dir/game4_phone.png');
    final two = midgame(2);
    await pumpHome(QuoridorScreen(controller: two), size: const Size(1100, 700));
    await _shot(tester, key, '$dir/game2_tablet.png');
    await pumpHome(const QuoridorSetupScreen(mode: PlayMode.vsCpu));
    await _shot(tester, key, '$dir/setup.png');
    await pumpHome(quoridorTutorial().screen(tester.element(find.byType(Scaffold).first), firstTime: false));
    await _shot(tester, key, '$dir/tutorial.png');
    await pumpHome(const RecordsScreen(initialGame: 'quoridor'));
    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Wi‑Fi'));
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, key, '$dir/records_picker.png');
  }, skip: dir == null);
}
