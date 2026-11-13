// 앱 아이콘 후보를 그림 파일로 만든다 (그림 내용은 icon_designs.dart).
//
// 실행 (사용자 폴더가 한글인 PC는 TEMP/TMP 를 영문 경로로 먼저 지정):
//   flutter test tool/app_icon/make_app_icons_test.dart
// 결과: build/icon_candidates/icon_<번호>_<이름>.png (1024x1024 원본) 과 compare.png (한눈에 비교).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/preview_kit.dart';
import 'icon_designs.dart';

const String _outDir = 'build/icon_candidates';

void main() {
  testWidgets('앱 아이콘 후보 그림 만들기', (tester) async {
    await loadAppFonts();
    Directory(_outDir).createSync(recursive: true);

    for (final d in iconDesigns) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(1024);
      d.paint(c);
      final image = (await tester.runAsync(() => rec.endRecording().toImage(1024, 1024)))!;
      await savePng(tester, image, '$_outDir/icon_${d.id}.png');
    }

    final sheet = await _compareSheet(tester);
    await savePng(tester, sheet, '$_outDir/compare.png');
  });
}

enum _Mask { square, rounded, squircle, circle }

/// [size] 크기의 아이콘을 [at]에 그린다. [mask] 모양으로 잘라서 (홈 화면에서 잘리는 모습).
void _drawIcon(Canvas c, IconDesign d, Offset at, double size, _Mask mask) {
  final box = at & Size(size, size);
  c.save();
  switch (mask) {
    case _Mask.square:
      c.clipRect(box);
    case _Mask.rounded:
      c.clipRRect(RRect.fromRectAndRadius(box, Radius.circular(size * 0.16)));
    case _Mask.squircle:
      c.clipRRect(RRect.fromRectAndRadius(box, Radius.circular(size * 0.3)));
    case _Mask.circle:
      c.clipPath(Path()..addOval(box));
  }
  c.translate(at.dx, at.dy);
  c.scale(size);
  d.paint(c);
  c.restore();
}

void _text(Canvas c, String s, Offset at, double size, Color color, {FontWeight weight = FontWeight.w700, bool center = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: 'Pretendard', fontSize: size, fontWeight: weight, color: color, height: 1.2)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center ? at - Offset(tp.width / 2, 0) : at);
}

Future<ui.Image> _compareSheet(WidgetTester tester) async {
  const cellW = 620.0, cellH = 430.0, pad = 24.0;
  const w = cellW * 3 + pad * 2, h = cellH * 2 + pad * 2;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF6F3EE));

  for (var i = 0; i < iconDesigns.length; i++) {
    final d = iconDesigns[i];
    final o = Offset(pad + (i % 3) * cellW, pad + (i ~/ 3) * cellH);
    c.drawRRect(
      RRect.fromRectAndRadius((o + const Offset(8, 8)) & const Size(cellW - 16, cellH - 16), const Radius.circular(20)),
      Paint()..color = Colors.white,
    );
    _text(c, '${i + 1}번  ${d.name}', o + const Offset(30, 24), 28, const Color(0xFF1A1523), weight: FontWeight.w800);

    // 큰 그림
    _drawIcon(c, d, o + const Offset(30, 78), 320, _Mask.rounded);

    // 홈 화면 (어두운 배경화면 위, 동그라미 / 둥근 네모)
    final home = (o + const Offset(374, 78)) & const Size(216, 212);
    c.drawRRect(
      RRect.fromRectAndRadius(home, const Radius.circular(16)),
      Paint()..shader = ui.Gradient.linear(home.topLeft, home.bottomRight, const [Color(0xFF2B3A67), Color(0xFF6B4E8E)]),
    );
    _drawIcon(c, d, home.topLeft + const Offset(24, 20), 72, _Mask.squircle);
    _drawIcon(c, d, home.topLeft + const Offset(120, 20), 72, _Mask.circle);
    _text(c, 'TabGame', home.topLeft + const Offset(60, 97), 13, Colors.white, center: true);
    _text(c, 'TabGame', home.topLeft + const Offset(156, 97), 13, Colors.white, center: true);
    _drawIcon(c, d, home.topLeft + const Offset(36, 132), 48, _Mask.squircle);
    _drawIcon(c, d, home.topLeft + const Offset(132, 132), 48, _Mask.circle);
    _text(c, '홈 화면 (큰 것 · 작은 것)', home.bottomLeft + const Offset(0, 6), 13, const Color(0xFF6B6570));

    // 브라우저 탭
    final bar = (o + const Offset(374, 330)) & const Size(216, 40);
    c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(8)), Paint()..color = const Color(0xFFDEE1E6));
    final tab = Rect.fromLTWH(bar.left + 8, bar.top + 6, 150, 34);
    c.drawRRect(RRect.fromRectAndCorners(tab, topLeft: const Radius.circular(8), topRight: const Radius.circular(8)), Paint()..color = Colors.white);
    _drawIcon(c, d, tab.topLeft + const Offset(10, 9), 16, _Mask.square);
    _text(c, 'TabGame', tab.topLeft + const Offset(34, 9), 13, const Color(0xFF3C4043), weight: FontWeight.w400);
    _text(c, '×', tab.topRight + const Offset(-20, 6), 15, const Color(0xFF5F6368), weight: FontWeight.w400);
    _text(c, '인터넷 창 탭', bar.bottomLeft + const Offset(0, 6), 13, const Color(0xFF6B6570));
  }

  final picture = rec.endRecording();
  return (await tester.runAsync(() => picture.toImage(w.ceil(), h.ceil())))!;
}
