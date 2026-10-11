// 고블렛 고블러스 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 GOBLET_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
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
import 'package:tabgame/games/goblet/core/goblet_ai.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';

/// AI가 고른 수로 [plies]수 진행한다.
void playPlies(GobbletController c, int plies, int seed) {
  final rng = Random(seed);
  for (var i = 0; i < plies && !c.isOver; i++) {
    final m = GobbletAi.choose(c.board, CpuLevel.normal, rng);
    final id = m.isPlace ? c.reserveFront(c.turn, m.size)! : c.topAt(m.from)!;
    c.select(id);
    c.dropPiece(id, m.to);
  }
}

void main() {
  final dir = Platform.environment['GOBLET_PREVIEW_DIR'];

  testWidgets('고블렛 화면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scenarios = <String, (Size, bool, PlayMode)>{
      'portrait_midgame': (const Size(600, 1000), false, PlayMode.local2p),
      'portrait_picked': (const Size(600, 1000), true, PlayMode.local2p),
      'landscape_midgame': (const Size(1100, 700), false, PlayMode.vsCpu),
      'landscape_picked': (const Size(1100, 700), true, PlayMode.local2p),
    };

    for (final entry in scenarios.entries) {
      final (size, picked, mode) = entry.value;
      await tester.binding.setSurfaceSize(size);
      final c = GobbletController(mode: mode, humanTeam: Team.blue);
      playPlies(c, 6, 9);
      if (picked && !c.isOver) {
        // 지금 차례인 팀의 첫 번째로 집을 수 있는 말을 집는다
        for (var id = 0; id < 12; id++) {
          if (c.isSelectable(id) && c.loc[id] >= 0) {
            c.select(id);
            break;
          }
        }
        if (c.selected == null) c.select(c.reserveFront(c.turn, 3)!);
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: GobbletScreen(controller: c),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/${entry.key}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('GOBLET_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
