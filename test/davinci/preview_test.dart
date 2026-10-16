// 다빈치 코드 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 DAVINCI_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
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
import 'package:tabgame/games/davinci/core/davinci_ai.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/tutorial/davinci_tutorial.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_setup_screen.dart';

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  final dir = Platform.environment['DAVINCI_PREVIEW_DIR'];
  testWidgets('다빈치 코드 화면 미리보기', (tester) async {
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

    Future<void> pumpHome(Widget home, {Size size = const Size(400, 860)}) async {
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

    // 중반 판: CPU끼리 몇 차례 두고 내 차례(맞히기 단계)로 만든다
    DavinciController midgame(int players) {
      final c = DavinciController(mode: PlayMode.vsCpu, players: players, seed: 8)..cpuStepDelay = Duration.zero;
      final rng = Random(2);
      var guard = 0;
      while (guard++ < 400 && !(c.state.turnCount >= 7 && c.state.turn == 0 && c.state.phase == DvPhase.draw)) {
        c.state.apply(DvAi.choose(c.state, DvLevel.hard, rng));
        if (c.state.isOver) break;
      }
      return c;
    }

    final c3 = midgame(3);
    c3.draw(0);
    c3.selectTarget(1, 1);
    await pumpHome(DavinciScreen(players: 3, controller: c3));
    await _shot(tester, key, '$dir/game3_phone.png');
    // 상대(CPU)가 내 타일을 맞히는 연출: 추측 중(떠오름 + 말풍선) → 결과
    DavinciController fx() {
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: 5, animate: true)..cpuStepDelay = const Duration(seconds: 1);
      c.state.rows[0]
        ..clear()
        ..addAll([dvTile(0, 1), dvTile(1, 4), dvTile(0, 6), dvTile(1, 9)]);
      c.state.rows[1]
        ..clear()
        ..addAll([dvTile(0, 2), dvTile(1, 7), dvTile(0, 10), dvTile(1, 11)]);
      c.state.revealed
        ..clear()
        ..addAll([dvTile(1, 7), dvTile(0, 1)]);
      c.state.turn = 1;
      c.state.phase = DvPhase.guess;
      c.state.drawn = dvTile(0, 10);
      return c;
    }

    final cfx = fx();
    await pumpHome(DavinciScreen(controller: cfx));
    cfx.receiveMove(DvMove.guess(0, 1, 4), index: 0); // 맞힘
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, key, '$dir/fx_ask.png');
    await tester.pump(const Duration(milliseconds: 1300));
    await _shot(tester, key, '$dir/fx_right.png');
    await tester.pump(const Duration(seconds: 2));
    final cfx2 = fx();
    await pumpHome(DavinciScreen(controller: cfx2));
    cfx2.receiveMove(DvMove.guess(0, 2, 8), index: 0); // 틀림
    await tester.pump(const Duration(milliseconds: 1500));
    await _shot(tester, key, '$dir/fx_wrong.png');
    await tester.pump(const Duration(seconds: 3));
    final c2 = midgame(2);
    await pumpHome(DavinciScreen(controller: c2));
    await _shot(tester, key, '$dir/game2_draw.png');
    await pumpHome(const DavinciSetupScreen(mode: PlayMode.wifi));
    await _shot(tester, key, '$dir/setup_wifi.png');
    await pumpHome(davinciTutorial().screen(tester.element(find.byType(Scaffold).first), firstTime: false));
    await _shot(tester, key, '$dir/tutorial.png');
  }, skip: dir == null);
}
