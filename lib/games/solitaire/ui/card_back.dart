import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/card_look.dart';

/// 선택한 스타일로 카드 뒷면을 그린다. 모든 패턴은 앱에서 직접 그린다.
void drawCardBack(Canvas canvas, Size size, {CardBackStyle? style}) {
  final selected = style ?? CardLook.backStyle;
  final w = size.width;
  final h = size.height;
  final rect = Offset.zero & size;
  final radius = w * 0.12;
  final card = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawShadow(Path()..addRRect(card), Colors.black, 1.6, true);

  switch (selected) {
    case CardBackStyle.classic:
      _classic(canvas, size, card);
    case CardBackStyle.floral:
      _floral(canvas, size, card);
    case CardBackStyle.ornate:
      _ornate(canvas, size, card);
    case CardBackStyle.vortex:
      _vortex(canvas, size, card);
    case CardBackStyle.blueOrb:
      _blueOrb(canvas, size, card);
  }
}

void _base(Canvas c, Size s, RRect card, List<Color> colors) {
  c.drawRRect(card, Paint()..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  ).createShader(Offset.zero & s));
}

void _classic(Canvas c, Size s, RRect card) {
  final w = s.width, h = s.height;
  _base(c, s, card, const [Color(0xFF4A86D4), Color(0xFF2B55A0)]);
  _frame(c, s, const Color(0xFFEAF2FF));
  c.save();
  c.clipRRect(card.deflate(w * .1));
  final p = Paint()..color = Colors.white.withValues(alpha: .2)..style = PaintingStyle.stroke..strokeWidth = max(1, w * .016);
  for (var d = -h; d < w + h; d += w * .2) {
    c.drawLine(Offset(d, 0), Offset(d + h, h), p);
    c.drawLine(Offset(d, h), Offset(d + h, 0), p);
  }
  c.restore();
  _drawGuilloche(c, Rect.fromLTWH(w * .15, h * .13, w * .7, h * .74), Colors.white.withValues(alpha: .14), w * .009);
  final center = Offset(w / 2, h / 2);
  final radius = w * .2;
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * .45;
    final a = -pi / 2 + i * pi / 5;
    final point = center + Offset(cos(a) * r, sin(a) * r);
    if (i == 0) { star.moveTo(point.dx, point.dy); } else { star.lineTo(point.dx, point.dy); }
  }
  star.close();
  c.drawCircle(center, radius * 1.4, Paint()..color = const Color(0xFF2B55A0));
  c.drawCircle(center, radius * 1.4, Paint()..style = PaintingStyle.stroke..strokeWidth = max(1, w * .02)..color = Colors.white);
  c.drawPath(star, Paint()..color = const Color(0xFFFFE08A));
}

void _floral(Canvas c, Size s, RRect card) {
  final w = s.width, h = s.height;
  const red = Color(0xFFB51F32), ink = Color(0xFF172D62), paper = Color(0xFFFFF8EC);
  _base(c, s, card, const [Color(0xFFF5EBDC), Color(0xFFE6D4B9)]);
  _frame(c, s, red, second: ink);
  c.save();
  c.clipRRect(card.deflate(w * .14));
  final center = Offset(w / 2, h / 2);
  _drawGuilloche(c, Rect.fromLTWH(w * .16, h * .12, w * .68, h * .76), ink.withValues(alpha: .28), w * .007);
  _drawRosette(c, center, w * .37, red, ink, petals: 20);
  for (final y in [h * .235, h * .765]) {
    _drawRosette(c, Offset(w / 2, y), w * .13, ink, red, petals: 12);
  }
  for (final x in [w * .205, w * .795]) {
    c.save();
    c.translate(x, h / 2);
    c.rotate(pi / 2);
    _drawRosette(c, Offset.zero, w * .115, red, ink, petals: 12);
    c.restore();
  }
  for (final y in [h * .23, h * .77]) {
    c.save();
    c.translate(w / 2, y);
    if (y > h / 2) c.rotate(pi);
    _flourish(c, w * .24, ink, w * .014);
    c.restore();
  }
  c.restore();
}

void _ornate(Canvas c, Size s, RRect card) {
  final w = s.width, h = s.height;
  const ink = Color(0xFF172D62), paper = Color(0xFFFFFDF5);
  _base(c, s, card, const [Color(0xFF263D70), Color(0xFF101F49)]);
  _frame(c, s, paper, second: const Color(0xFF91A8D4));
  c.save();
  c.clipRRect(card.deflate(w * .14));
  _drawGuilloche(c, Rect.fromLTWH(w * .17, h * .1, w * .66, h * .8), paper.withValues(alpha: .14), w * .007);
  final p = Paint()..style = PaintingStyle.stroke..strokeWidth = max(.8, w * .012)..color = paper;
  // 대칭 곡선 장식의 반복으로 고전적인 인쇄 무늬를 만든다.
  for (var i = 0; i < 6; i++) {
    final y = h * (.18 + i * .128);
    final side = i.isEven ? 1.0 : -1.0;
    for (final x in [w * .1, w * .9]) {
      final path = Path()
        ..moveTo(x, y)
        ..cubicTo(x + side * w * .24, y - h * .1, x - side * w * .18, y - h * .1, x, y - h * .2)
        ..cubicTo(x + side * w * .16, y - h * .12, x + side * w * .16, y + h * .12, x, y + h * .2);
      c.drawPath(path, p);
      c.drawCircle(Offset(x, y), w * .025, Paint()..color = paper);
    }
  }
  final medallion = Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * .48, height: h * .32);
  c.drawOval(medallion, Paint()..style = PaintingStyle.stroke..strokeWidth = max(1, w * .022)..color = paper);
  c.drawOval(medallion.deflate(w * .035), Paint()..style = PaintingStyle.stroke..strokeWidth = max(.7, w * .009)..color = const Color(0xFF91A8D4));
  _drawRosette(c, Offset(w / 2, h / 2), w * .2, paper, const Color(0xFF91A8D4), petals: 18);
  for (var i = 0; i < 9; i++) {
    final y = h * (.19 + i * .0775);
    for (final x in [w * .19, w * .81]) {
      final r = w * (i.isEven ? .018 : .012);
      c.drawCircle(Offset(x, y), r, Paint()..color = i.isEven ? paper : const Color(0xFF91A8D4));
      c.drawCircle(Offset(x, y), r * 1.8, Paint()..style = PaintingStyle.stroke..strokeWidth = max(.6, w * .006)..color = paper.withValues(alpha: .8));
    }
  }
  for (final y in [h * .22, h * .78]) {
    c.save();
    c.translate(w / 2, y);
    if (y > h / 2) c.rotate(pi);
    _flourish(c, w * .34, paper, w * .016);
    c.restore();
  }
  c.restore();
}

void _vortex(Canvas c, Size s, RRect card) {
  final w = s.width, h = s.height;
  _base(c, s, card, const [Color(0xFF171311), Color(0xFF050608), Color(0xFF24140E)]);
  _frame(c, s, const Color(0xFFD58A35), second: const Color(0xFF5B3018));
  c.save();
  c.clipRRect(card.deflate(w * .08));
  _drawGuilloche(c, Rect.fromLTWH(w * .1, h * .08, w * .8, h * .84), const Color(0xFFD58A35).withValues(alpha: .16), w * .006);
  final center = Offset(w * .51, h * .5);
  for (var j = 0; j < 42; j++) {
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final t = i / 80;
      final a = t * pi * 5.1 + j * .065;
      final rx = w * (.035 + .49 * t);
      final ry = h * (.025 + .46 * t);
      final point = Offset(center.dx + cos(a) * rx, center.dy + sin(a) * ry);
      if (i == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
    }
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
      ..strokeWidth = max(.55, w * (j % 6 == 0 ? .01 : .004))
      ..color = (j % 4 == 0 ? const Color(0xFFFFD58B) : const Color(0xFF9D4D1F)).withValues(alpha: j % 4 == 0 ? .78 : .48));
  }
  c.restore();
}

void _blueOrb(Canvas c, Size s, RRect card) {
  final w = s.width, h = s.height;
  _base(c, s, card, const [Color(0xFF174A86), Color(0xFF06244D), Color(0xFF24659B)]);
  _frame(c, s, const Color(0xFF9CD4F0), second: const Color(0xFF1C67A2));
  c.save();
  c.clipRRect(card.deflate(w * .08));
  final center = Offset(w / 2, h / 2);
  for (var i = 0; i < 22; i++) {
    final p = Path();
    final phase = i * pi / 11;
    for (var j = 0; j <= 40; j++) {
      final t = j / 40;
      final a = phase + t * pi * 1.8;
      final rx = w * (.22 + .31 * t);
      final ry = h * (.12 + .34 * t);
      final point = Offset(center.dx + cos(a) * rx, center.dy + sin(a) * ry);
      if (j == 0) { p.moveTo(point.dx, point.dy); } else { p.lineTo(point.dx, point.dy); }
    }
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = max(.7, w * .014)
      ..color = Colors.white.withValues(alpha: i.isEven ? .42 : .18));
  }
  _drawGuilloche(c, Rect.fromLTWH(w * .12, h * .1, w * .76, h * .8), const Color(0xFFBDEBFF).withValues(alpha: .16), w * .006);
  final orb = Rect.fromCenter(center: center, width: w * .57, height: w * .57);
  c.drawCircle(center, w * .3, Paint()..color = const Color(0xFF061A38));
  c.drawCircle(center, w * .27, Paint()..shader = const LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFF7654), Color(0xFFE43C32), Color(0xFFF3F0DB), Color(0xFFB8D9D6)],
    stops: [0, .46, .47, 1],
  ).createShader(orb));
  c.drawLine(Offset(center.dx - w * .25, center.dy), Offset(center.dx + w * .25, center.dy),
    Paint()..color = const Color(0xFF17253A)..strokeWidth = max(1.5, w * .035));
  c.drawCircle(center, w * .09, Paint()..color = const Color(0xFF071B31));
  c.drawCircle(center, w * .058, Paint()..color = const Color(0xFF64D5ED));
  c.drawCircle(center.translate(-w * .018, -w * .018), w * .022, Paint()..color = Colors.white.withValues(alpha: .9));
  c.restore();
}

void _frame(Canvas c, Size s, Color color, {Color? second}) {
  final w = s.width, h = s.height;
  final outer = RRect.fromRectAndRadius(Rect.fromLTWH(w * .07, w * .07, w * .86, h - w * .14), Radius.circular(w * .07));
  final inner = RRect.fromRectAndRadius(Rect.fromLTWH(w * .12, w * .12, w * .76, h - w * .24), Radius.circular(w * .045));
  final mid = RRect.fromRectAndRadius(Rect.fromLTWH(w * .095, w * .095, w * .81, h - w * .19), Radius.circular(w * .055));
  final fine = RRect.fromRectAndRadius(Rect.fromLTWH(w * .145, w * .145, w * .71, h - w * .29), Radius.circular(w * .035));
  for (final item in [
    (outer, color, max(1.2, w * .024)),
    (mid, second ?? color, max(.8, w * .008)),
    (inner, second ?? color, max(1.0, w * .014)),
    (fine, color.withValues(alpha: .8), max(.7, w * .007)),
  ]) {
    c.drawRRect(item.$1, Paint()..style = PaintingStyle.stroke..strokeWidth = item.$3..color = item.$2);
  }
  final ornament = Paint()..style = PaintingStyle.stroke..strokeWidth = max(.65, w * .009)..color = second ?? color;
  // Fine diamond chain inside both long and short edges.
  for (var x = .16; x < .85; x += .055) {
    for (final y in [w * .105, h - w * .105]) {
      final center = Offset(w * x, y);
      final r = w * .018;
      c.drawPath(Path()..moveTo(center.dx, center.dy - r)..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx, center.dy + r)..lineTo(center.dx - r, center.dy)..close(), ornament);
      c.drawCircle(center, max(.45, w * .004), Paint()..color = color);
    }
  }
  for (var y = .16; y < .85; y += .035) {
    for (final x in [w * .105, w * .895]) {
      c.drawCircle(Offset(x, h * y), max(.55, w * .007), Paint()..color = color);
    }
  }
  c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * .12)),
    Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = Colors.black.withValues(alpha: .25));
}

/// 반복된 사인 곡선을 겹쳐 판화의 촘촘한 guilloché 바탕을 만든다.
void _drawGuilloche(Canvas c, Rect bounds, Color color, double strokeWidth) {
  final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = max(.45, strokeWidth)..color = color;
  const lines = 34;
  for (var i = 0; i < lines; i++) {
    final path = Path();
    final phase = i * pi * 2 / lines;
    for (var step = 0; step <= 70; step++) {
      final t = step / 70;
      final x = bounds.left + t * bounds.width;
      final wave = sin(t * pi * 5 + phase) * .5 + sin(t * pi * 11 - phase) * .12;
      final y = bounds.top + bounds.height * (.5 + wave * .48);
      if (step == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    c.drawPath(path, paint);
  }
}

/// Dense, layered rosette with engraved petal veins and a beaded center.
void _drawRosette(Canvas c, Offset center, double radius, Color primary, Color secondary, {required int petals}) {
  final fine = Paint()..style = PaintingStyle.stroke..strokeWidth = max(.55, radius * .035);
  for (var i = 0; i < petals; i++) {
    final a = i * 2 * pi / petals;
    final ux = cos(a), uy = sin(a), tx = -uy, ty = ux;
    Offset point(double along, double across) => center + Offset(ux * along + tx * across, uy * along + ty * across);
    final petal = Path()
      ..moveTo(point(radius * .12, 0).dx, point(radius * .12, 0).dy)
      ..cubicTo(point(radius * .32, radius * .2).dx, point(radius * .32, radius * .2).dy,
          point(radius * .76, radius * .18).dx, point(radius * .76, radius * .18).dy,
          point(radius, 0).dx, point(radius, 0).dy)
      ..cubicTo(point(radius * .76, -radius * .18).dx, point(radius * .76, -radius * .18).dy,
          point(radius * .32, -radius * .2).dx, point(radius * .32, -radius * .2).dy,
          point(radius * .12, 0).dx, point(radius * .12, 0).dy);
    fine.color = i.isEven ? primary : secondary;
    c.drawPath(petal, fine);
    final vein = Path()
      ..moveTo(point(radius * .2, 0).dx, point(radius * .2, 0).dy)
      ..quadraticBezierTo(point(radius * .55, radius * .025).dx, point(radius * .55, radius * .025).dy,
          point(radius * .88, 0).dx, point(radius * .88, 0).dy);
    fine.color = primary.withValues(alpha: .8);
    c.drawPath(vein, fine);
    c.drawCircle(point(radius * .53, 0), max(.55, radius * .022), Paint()..color = secondary);
  }
  for (final r in [radius * .19, radius * .14, radius * .075]) {
    c.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = max(.65, radius * .035)..color = primary);
  }
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6;
    c.drawCircle(center + Offset(cos(a), sin(a)) * radius * .115, max(.55, radius * .025), Paint()..color = secondary);
  }
  c.drawCircle(center, radius * .045, Paint()..color = primary);
}

void _flourish(Canvas c, double radius, Color color, double width) {
  final p = Paint()..style = PaintingStyle.stroke..strokeWidth = width..color = color;
  for (final flip in [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(flip * radius * .28, -radius * .8, flip * radius * .95, -radius * .7, flip * radius, 0)
      ..cubicTo(flip * radius * .72, radius * .72, flip * radius * .3, radius * .8, 0, 0);
    c.drawPath(path, p);
    c.drawCircle(Offset(flip * radius * .62, 0), radius * .12, p);
  }
  c.drawCircle(Offset.zero, radius * .1, Paint()..color = color);
}

class CardBackPainter extends CustomPainter {
  CardBackPainter({CardBackStyle? style})
      : style = style ?? CardLook.backStyle,
        super(repaint: _CardBackRasterCache.revision) {
    _CardBackRasterCache.prepare(this.style);
  }

  final CardBackStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final image = _CardBackRasterCache.images[style];
    if (image == null) {
      drawCardBack(canvas, size, style: style);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(CardBackPainter old) => old.style != style;
}

/// Vector art is rasterized once per style so moving cards only composites a bitmap.
class _CardBackRasterCache {
  static final revision = ValueNotifier<int>(0);
  static final Map<CardBackStyle, ui.Image> images = {};
  static final Set<CardBackStyle> _pending = {};

  static void prepare(CardBackStyle style) {
    if (images.containsKey(style) || !_pending.add(style)) return;

    const logicalSize = Size(100, 140);
    const scale = 3.2;
    const imageWidth = 320;
    const imageHeight = 448;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    drawCardBack(canvas, logicalSize, style: style);
    final picture = recorder.endRecording();
    picture.toImage(imageWidth, imageHeight).then((image) {
      picture.dispose();
      images[style] = image;
      _pending.remove(style);
      revision.value++;
    }, onError: (Object error, StackTrace stackTrace) {
      picture.dispose();
      _pending.remove(style);
    });
  }
}
