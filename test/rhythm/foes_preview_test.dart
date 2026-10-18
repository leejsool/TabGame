// 고블린(4마리)·오크(보스) 장면을 그림(PNG)으로 뽑아보는 도구. RHYTHM_PREVIEW_DIR 가 지정됐을 때만 만든다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/core/rhythm_chart.dart';
import 'package:tabgame/games/rhythm/game/rhythm_controller.dart';
import 'package:tabgame/games/rhythm/ui/camp_painter.dart';
import 'package:tabgame/games/rhythm/ui/rhythm_art.dart';
import 'package:tabgame/games/rhythm/ui/stage_painter.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['RHYTHM_PREVIEW_DIR'];

  testWidgets('고블린·오크 장면 미리보기 이미지 만들기', (tester) async {
    await loadAppFonts();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final art = (await tester.runAsync(RhythmArt.load))!;

    Future<void> shoot(String name, Size size, int course, double Function(RhythmController) timeOf) async {
      await tester.binding.setSurfaceSize(size);
      final info = RhythmCourse.all[course];
      final c = RhythmController(chart: RhythmChart.course(course));
      c.start();
      final t = timeOf(c);
      for (var x = 0.0; x < t; x += 0.05) {
        c.update(x);
      }
      c.update(t);
      final k = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: k,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: BackgroundPainter(art, name: info.background))),
            Positioned.fill(child: CustomPaint(painter: StagePainter(c, art: art, clock: () => t, wall: () => t, foe: info.foe, iron: true))),
          ]),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    double wave1(RhythmController c) => c.chart.events.firstWhere((e) => e.wave == 1 && e.actor == 0).time;
    double miss(RhythmController c) => c.chart.playerEvents.first.time;
    double guard(RhythmController c) => c.chart.guards.first.time;

    for (final (name, size) in [('landscape', const Size(1100, 700)), ('portrait', const Size(600, 1000))]) {
      await shoot('goblin_${name}_ready', size, 4, (c) => wave1(c) - 0.12);
      await shoot('goblin_${name}_hit', size, 4, (c) => wave1(c) + 0.07);
      await shoot('goblin_${name}_attack', size, 4, (c) => miss(c) + 0.3);
      await shoot('orc_${name}_windup', size, 5, (c) => guard(c) - 1.0 * c.chart.beat);
      await shoot('orc_${name}_lunge', size, 5, (c) => guard(c) - 0.07);
    }
  }, skip: dir == null);
}
