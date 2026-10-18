// 카드 앞면 전체(무늬 4 × 13장)를 그림으로 뽑아보는 도구. SOLITAIRE_PREVIEW_DIR 가 있을 때만 실행. BIG_CARDS=1 이면 스페이드 몇 장만 크게.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/card_look.dart';
import 'package:tabgame/games/freecell/ui/playing_card.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['SOLITAIRE_PREVIEW_DIR'];

  testWidgets('카드 앞면 미리보기', (tester) async {
    await loadAppFonts();
    final big = Platform.environment['BIG_CARDS'] != null;
    CardLook.style = CardStyle.values.byName(Platform.environment['CARD_STYLE'] ?? 'bicycle');
    CardLook.palette = SuitPalette.values.byName(Platform.environment['SUIT_PALETTE'] ?? 'twoColor');
    addTearDown(() {
      CardLook.style = CardStyle.bicycle;
      CardLook.palette = SuitPalette.twoColor;
    });
    // 큰 그림: 카드는 늘 가로:세로 = 1:1.4 (칸에 맞춰 찌그러뜨리지 않는다)
    await tester.binding.setSurfaceSize(big ? const Size(1300, 480) : const Size(1400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final suits = big ? [3, 2] : [3, 2, 0, 1];
    final ranks = big ? const [0, 9, 10, 11, 12] : List<int>.generate(13, (i) => i);
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
                for (final suit in suits)
                  Expanded(
                    child: Row(
                      children: [
                        for (final rank in ranks)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1 / 1.4,
                                  child: CustomPaint(painter: PlayingCardPainter(rank * 4 + suit)),
                                ),
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
