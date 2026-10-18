
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 콩나물: 점 셋과 두 가닥 곡선, 선 위에 새로 찍힌 점 ──
void paintSproutsIcon(Canvas c, double s) {
  const a = Offset(0.2, 0.7), b = Offset(0.78, 0.76), d = Offset(0.5, 0.2);
  final green = Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(0.15, 0.3, 0.3, 0.1, d.dx, d.dy);
  final pink = Path()
    ..moveTo(d.dx, d.dy)
    ..cubicTo(0.85, 0.2, 0.9, 0.5, b.dx, b.dy);
  final chord = Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(0.35, 0.95, 0.6, 0.95, b.dx, b.dy);
  for (final (p, color) in [(green, const Color(0xFF9CF0B8)), (pink, const Color(0xFFFFA6D5)), (chord, const Color(0xFF9CF0B8))]) {
    c.drawPath(p, iconLine(kIconInk, 0.085));
    c.drawPath(p, iconLine(color, 0.05));
  }
  for (final dot in [a, b, d, const Offset(0.205, 0.37), const Offset(0.5, 0.9)]) {
    final big = dot == a || dot == b || dot == d;
    c.drawCircle(dot, big ? 0.085 : 0.06, iconFill(big ? kIconInk : Colors.white));
    c.drawCircle(dot, big ? 0.085 : 0.06, iconLine(big ? Colors.white : kIconInk, 0.03));
  }
}
