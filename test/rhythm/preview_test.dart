// 리듬 검사단 장면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 RHYTHM_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
import 'package:tabgame/games/rhythm/game/rhythm_controller.dart';
import 'package:tabgame/games/rhythm/ui/camp_painter.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_art.dart';
import 'package:tabgame/games/rhythm/ui/stage_painter.dart';

void main() {
  final dir = Platform.environment['RHYTHM_PREVIEW_DIR'];

  testWidgets('리듬 검사단 장면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final art = (await tester.runAsync(RhythmArt.load))!;
    final chart = RhythmChart.tutorial(bpm: 100);
    final beat = chart.beat;
    // 마지막 단계(소리만 듣기)의 첫 물결 시작 시간
    final lastStage = chart.stages.length - 1;
    final lastWave0 = chart.events.firstWhere((e) => e.stage == lastStage);

    final scenarios = <String, (Size, double, Side?)>{
      'landscape_windup': (const Size(1100, 700), 2.4 - 0.12, null),
      'landscape_impact': (const Size(1100, 700), 2.4 + 0.04, null),
      'landscape_cue': (const Size(1100, 700), 3.9, null),
      'landscape_player_tap': (const Size(1100, 700), 4.2 + 0.05, Side.left),
      'landscape_ghost': (const Size(1100, 700), lastWave0.time + 2 * beat + 0.04, null),
      'portrait_impact': (const Size(600, 1000), 3.0 + 0.04, null),
      'portrait_player_tap': (const Size(600, 1000), 4.2 + 0.05, Side.right),
    };

    for (final entry in scenarios.entries) {
      final (size, t, tapSide) = entry.value;
      await tester.binding.setSurfaceSize(size);
      final c = RhythmController(chart: chart);
      c.start();
      // 시간을 조금씩 흘려 보내며 소리/놓침 처리를 거친다
      for (var x = 0.0; x < t - 0.1; x += 0.1) {
        c.update(x);
      }
      if (tapSide != null) {
        // 플레이어가 정확한 시간에 침 (방향은 곡의 정답과 상관없이 보여주기용)
        c.tap(tapSide, t - 0.05);
      }
      c.update(t);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: BackgroundPainter(art))),
                Positioned.fill(child: CustomPaint(painter: StagePainter(c, art: art, clock: () => t, wall: () => t))),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/${entry.key}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
    }
    // 꾹 누르기 코스: 선배가 힘을 모으는 장면 / 내가 누르고 있는 장면
    for (final scene in ['hold_npc', 'hold_player']) {
      await tester.binding.setSurfaceSize(const Size(1100, 700));
      final hc = RhythmChart.course(1);
      final c = RhythmController(chart: hc);
      c.start();
      final mine = hc.playerEvents.firstWhere((e) => e.isHold);
      final npc = hc.events.firstWhere((e) => e.actor == 1 && e.isHold);
      final t = scene == 'hold_npc' ? npc.pressTime + 0.45 : mine.pressTime + 0.4;
      var x = 0.0;
      final limit = scene == 'hold_player' ? mine.pressTime - 0.05 : t - 0.1;
      for (; x < limit; x += 0.1) {
        c.update(x);
      }
      if (scene == 'hold_player') {
        c.update(mine.pressTime);
        c.tap(mine.side, mine.pressTime);
        for (x = mine.pressTime + 0.1; x < t - 0.05; x += 0.1) {
          c.update(x);
        }
      }
      c.update(t);
      final k = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: k,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: BackgroundPainter(art))),
            Positioned.fill(child: CustomPaint(painter: StagePainter(c, art: art, clock: () => t, wall: () => t))),
          ]),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$scene.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    // 메뉴의 네 명 줄
    await tester.binding.setSurfaceSize(const Size(900, 330));
    final key2 = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key2,
        child: Container(color: const Color(0xFFE8C98E), child: CustomPaint(painter: SquadPainter(art), size: Size.infinite)),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key2.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/menu_squad.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('RHYTHM_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
