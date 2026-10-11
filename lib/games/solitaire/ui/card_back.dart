import 'dart:math';

import 'package:flutter/material.dart';

/// 카드 뒷면: 파란 바탕에 마름모 무늬와 별.
void drawCardBack(Canvas canvas, Size size) {
  final w = size.width, h = size.height;
  final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.12));
  canvas.drawShadow(Path()..addRRect(rr), Colors.black, 1.6, true);
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A86D4), Color(0xFF2B55A0)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF1E3E78),
  );

  // 흰 테두리 + 안쪽 무늬 영역
  final inner = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.09, w * 0.09, w * 0.82, h - w * 0.18), Radius.circular(w * 0.07));
  canvas.drawRRect(
    inner,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, w * 0.025)
      ..color = Colors.white.withValues(alpha: 0.85),
  );
  canvas.save();
  canvas.clipRRect(inner.deflate(w * 0.02));
  final lattice = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, w * 0.018)
    ..color = Colors.white.withValues(alpha: 0.22);
  final step = w * 0.2;
  for (var d = -h; d < w + h; d += step) {
    canvas.drawLine(Offset(d, 0), Offset(d + h, h), lattice);
    canvas.drawLine(Offset(d, h), Offset(d + h, 0), lattice);
  }
  canvas.restore();

  // 가운데 별
  final c = Offset(w / 2, h / 2);
  final r = w * 0.2;
  canvas.drawCircle(c, r * 1.35, Paint()..color = const Color(0xFF2B55A0));
  canvas.drawCircle(
    c,
    r * 1.35,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, w * 0.022)
      ..color = Colors.white.withValues(alpha: 0.85),
  );
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final p = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
    if (i == 0) {
      star.moveTo(p.dx, p.dy);
    } else {
      star.lineTo(p.dx, p.dy);
    }
  }
  star.close();
  canvas.drawPath(star, Paint()..color = const Color(0xFFFFE08A));
}

class CardBackPainter extends CustomPainter {
  const CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) => drawCardBack(canvas, size);

  @override
  bool shouldRepaint(CardBackPainter old) => false;
}
