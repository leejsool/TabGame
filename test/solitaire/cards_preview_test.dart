// 카드 앞면 전체(무늬 4 × 13장)를 그림으로 뽑아보는 도구. SOLITAIRE_PREVIEW_DIR 가 있을 때만 실행.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/freecell/ui/playing_card.dart';

void main() {
  final dir = Platform.environment['SOLITAIRE_PREVIEW_DIR'];

  testWidgets('카드 앞면 미리보기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    await tester.binding.setSurfaceSize(const Size(1400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
          color: const Color(0xFF1F6B4A),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (final suit in [3, 2, 0, 1])
                Expanded(
                  child: Row(
                    children: [
                      for (var rank = 0; rank < 13; rank++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: AspectRatio(
                              aspectRatio: 1 / 1.4,
                              child: CustomPaint(painter: PlayingCardPainter(rank * 4 + suit)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/cards.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  }, skip: dir == null);
}
