// 루미큐브 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 RUMMIKUB_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/rummikub/core/rummikub_ai.dart';
import 'package:tabgame/games/rummikub/game/rummikub_controller.dart';
import 'package:tabgame/games/rummikub/tutorial/rummikub_tutorial.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_screen.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_setup_screen.dart';
import 'package:tabgame/hub/hub_screen.dart';

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  final dir = Platform.environment['RUMMIKUB_PREVIEW_DIR'];
  testWidgets('루미큐브 화면 미리보기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final theme = ThemeData(useMaterial3: true, fontFamily: 'NanumGothic');
    final key = GlobalKey();

    Future<void> pumpHome(Widget home, {Size size = const Size(412, 890)}) async {
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

    // 중반 판: CPU끼리 몇 차례 두고 내 차례로 만든다
    RummikubController midgame(int players) {
      final c = RummikubController(animate: false, mode: PlayMode.vsCpu, players: players, seed: 12);
      final rng = Random(3);
      var guard = 0;
      while (guard++ < 400 && !(c.state.turnCount >= 14 && c.state.turn == 0 && c.state.table.length >= 3)) {
        final s = c.state;
        final plan = RkAi.plan(rack: s.currentRack, table: s.table, melded: s.melded[s.turn], level: RkLevel.hard, rng: rng);
        if (plan == null) {
          s.applyDraw();
        } else {
          s.applyPlay(plan);
        }
      }
      c.reset();
      c.hand = [...c.state.racks[0]];
      c.sortHand(byColor: true);
      c.moveTiles([c.rackTiles.first, c.rackTiles[1]]);
      return c;
    }

    await pumpHome(RummikubScreen(controller: midgame(3)));
    await _shot(tester, key, '$dir/game_phone.png');
    await pumpHome(RummikubScreen(controller: midgame(2)), size: const Size(1100, 700));
    await _shot(tester, key, '$dir/game_tablet.png');
    await pumpHome(const RummikubSetupScreen(mode: PlayMode.vsCpu));
    await _shot(tester, key, '$dir/setup.png');
    await pumpHome(rummikubTutorial().screen(tester.element(find.byType(Scaffold).first), firstTime: false));
    await _shot(tester, key, '$dir/tutorial.png');
    await pumpHome(HubScreen(settings: settings));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, key, '$dir/hub_phone.png');
    expect(allGames.any((g) => g.id == 'rummikub'), isTrue);
  }, skip: dir == null);
}
