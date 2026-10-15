// 민들레 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 DANDELION_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
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
import 'package:tabgame/games/dandelion/core/dandelion_ai.dart';
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/game/dandelion_controller.dart';
import 'package:tabgame/games/dandelion/tutorial/dandelion_tutorial.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_lesson_screen.dart';
import 'package:tabgame/hub/game_icons.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('NanumGothic');
  for (final f in ['Regular', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  final dir = Platform.environment['DANDELION_PREVIEW_DIR'];
  testWidgets('민들레 화면 미리보기', (tester) async {
    await _loadFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final theme = ThemeData(useMaterial3: true, fontFamily: 'NanumGothic');
    final key = GlobalKey();

    Future<void> pumpHome(Widget home) async {
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: SettingsScope(
          settings: settings,
          child: MaterialApp(key: UniqueKey(), debugShowCheckedModeBanner: false, theme: theme, home: home),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
    }

    for (final (name, size) in [('phone', const Size(390, 844)), ('tablet', const Size(1280, 800))]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final c = DandelionController(mode: PlayMode.local2p, level: DandLevel.easy);
      // 책의 그림처럼: 꽃, 왼쪽 바람, 꽃, 왼쪽 아래 바람, 꽃
      for (final m in [7, WindDir.left.index, 19, WindDir.downLeft.index, 12]) {
        c.moves.add(m);
      }
      c.state = DandState.fromMoves(c.moves);
      await pumpHome(DandelionScreen(controller: c));
      await tester.pump(const Duration(seconds: 3));
      await _shot(tester, key, '$dir/screen_$name.png');
      // 바람이 부는 중
      c.blow(WindDir.up);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 550));
      await _shot(tester, key, '$dir/blowing_$name.png');
      await tester.pump(const Duration(seconds: 3));
    }

    tester.view.physicalSize = const Size(390, 844);
    final t = dandelionTutorial();
    for (var i = 0; i < t.steps.length; i++) {
      await pumpHome(Scaffold(
        backgroundColor: Colors.white,
        body: Builder(
          builder: (context) => Center(
            child: SizedBox(width: 340, height: 340, child: t.steps[i].art!(context, t.color)),
          ),
        ),
      ));
      await _shot(tester, key, '$dir/tutorial_$i.png');
    }

    await pumpHome(Scaffold(
      body: Center(child: Container(color: const Color(0xFFD99A00), child: GameIcon(game: allGames.firstWhere((g) => g.id == 'dandelion'), size: 200))),
    ));
    await _shot(tester, key, '$dir/icon.png');

    // 교과학습: 단원마다 한 장씩
    tester.view.physicalSize = const Size(430, 1500);
    for (var i = 1; i <= 7; i++) {
      await pumpHome(const DandelionLessonScreen());
      if (i == 1) await _shot(tester, key, '$dir/lesson_list.png');
      await tester.tap(find.textContaining('$i. '));
      await tester.pumpAndSettle();
      if (i == 3) {
        await tester.tap(find.text('보장된 칸 모두 보기'));
        await tester.pump();
      }
      await _shot(tester, key, '$dir/lesson_$i.png');
    }
    tester.view.reset();
  }, skip: dir == null);
}
