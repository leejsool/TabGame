// 직소퍼즐 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 JIGSAW_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/jigsaw/core/jigsaw_geometry.dart';
import 'package:tabgame/games/jigsaw/game/jigsaw_controller.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_table.dart';

Future<void> savePng(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  final dir = Platform.environment['JIGSAW_PREVIEW_DIR'];

  testWidgets('직소퍼즐 미리보기 이미지 만들기', (tester) async {
    // 1) 샘플 그림 3장
    await tester.runAsync(() async {
      for (final s in SampleArt.all) {
        final img = await SampleArt.render(s.id, scale: 0.6);
        await savePng(img, '$dir/sample_${s.id}.png');
      }
    });

    // 2) 진행 중인 판 / 모양 확인용(모두 맞춘 판)
    Future<void> shoot(
      String name,
      String sampleId,
      int target,
      Size view,
      void Function(JigsawController c) setup,
    ) async {
      late ui.Image image;
      late JigsawController controller;
      late PieceImages pieces;
      await tester.runAsync(() async {
        image = await SampleArt.render(sampleId);
        final (rows, cols) = JigsawGeometry.gridFor(target, image.width / image.height);
        final g = JigsawGeometry(
          rows: rows,
          cols: cols,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          seed: 4,
        );
        controller = JigsawController(geometry: g, scatterSeed: 8);
        pieces = await PieceImages.build(image, g);
      });
      setup(controller);
      await tester.binding.setSurfaceSize(view);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: JigsawTable(controller: controller, pieces: pieces, image: image),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await savePng(await boundary.toImage(pixelRatio: 1.0), '$dir/$name.png');
      });
      await tester.pumpWidget(const SizedBox());
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 절반쯤 맞춘 상태
    await shoot('table_midgame', 'garden', 24, const Size(800, 1000), (c) {
      for (var i = 0; i < c.geometry.count; i++) {
        if (i % 2 == 0) {
          c.pos[i] = c.targetPos(i);
          c.placed[i] = true;
        }
      }
      c.order.sort((a, b) => (c.placed[a] ? 0 : 1).compareTo(c.placed[b] ? 0 : 1));
      c.dragging = null;
    });
    // 조각 모양 확인: 전부 맞춘 상태 (완성 연출 없이)
    await shoot('table_assembled', 'sunset', 12, const Size(1000, 700), (c) {
      for (var i = 0; i < c.geometry.count; i++) {
        c.pos[i] = c.targetPos(i);
        c.placed[i] = true;
      }
      c.ghost = false;
    });
    // 조각을 끌고 있는 모습 + 힌트
    await shoot('table_drag_hint', 'space', 24, const Size(800, 800), (c) {
      c.giveHint(Random(3));
      final i = c.order.last;
      c.beginDrag(i, c.pos[i] + const Offset(40, 40));
      c.dragTo(c.pos[i] + const Offset(100, 20));
    });
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('JIGSAW_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
