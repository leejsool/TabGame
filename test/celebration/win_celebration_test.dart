import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/freecell/ui/win_celebration.dart';

WinCelebration make({Size view = const Size(820, 1300)}) => WinCelebration(
      view: view,
      cardSize: const Size(100, 140),
      foundationPositions: [for (var i = 0; i < 4; i++) Offset(300 + i * 112.0, 20)],
      seed: 617,
      pixelRatio: 1,
    );

void main() {
  testWidgets('연출이 끝까지 돌아가고 모든 카드가 사라진다', (tester) async {
    final show = make();
    final canvasSize = const Size(820, 1300);
    var frames = 0;
    while (!show.finished && frames < 60 * 30) {
      show.update(1 / 60);
      // 그리기도 해서 예외가 없는지 확인한다
      final recorder = ui.PictureRecorder();
      show.paint(Canvas(recorder), canvasSize);
      recorder.endRecording().dispose();
      frames++;
    }
    expect(show.finished, isTrue, reason: '30초 안에 끝나야 한다 (frames=$frames)');
    expect(frames, greaterThan(60 * 7)); // 최소 7초는 보여준다
    expect(frames, lessThan(60 * 20));
    show.dispose();
  });

  testWidgets('좁은 화면(폰)에서도 예외 없이 돌아간다', (tester) async {
    final show = make(view: const Size(360, 640));
    for (var i = 0; i < 60 * 12; i++) {
      show.update(1 / 60);
      final recorder = ui.PictureRecorder();
      show.paint(Canvas(recorder), const Size(360, 640));
      recorder.endRecording().dispose();
    }
    show.dispose();
  });

  // 미리보기: SOLITAIRE_PREVIEW_DIR 가 있을 때 몇 장면을 PNG로 저장한다.
  final dir = Platform.environment['SOLITAIRE_PREVIEW_DIR'];
  testWidgets('연출 장면 미리보기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    const size = Size(820, 1300);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final show = make();
    final tick = ValueNotifier(0);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(colors: [Color(0xFF2A7F58), Color(0xFF175B3D)], radius: 1.1),
          ),
          child: CustomPaint(size: size, painter: WinCelebrationPainter(show, tick)),
        ),
      ),
    ));
    var shot = 0;
    for (var frame = 0; frame < 60 * 6; frame++) {
      show.update(1 / 60);
      tick.value++;
      if (frame == 90 || frame == 180 || frame == 300) {
        await tester.pump();
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await b.toImage(pixelRatio: 1.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$dir/win_${shot++}.png').writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    }
    show.dispose();
  }, skip: dir == null);
}
