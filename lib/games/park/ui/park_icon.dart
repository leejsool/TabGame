import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 공원 길찾기: 바둑판 산책로, 숲 두 개, A→B로 꺾여 가는 길 ──
void paintParkIcon(Canvas c, double s) {
  const o = 0.16, g = 0.34;
  c.drawRect(const Rect.fromLTWH(o, o, g * 2, g * 2), iconFill(const Color(0xFFEAF5E4)));
  for (var i = 0; i <= 2; i++) {
    c.drawLine(Offset(o, o + g * i), Offset(o + g * 2, o + g * i), iconLine(kIconInk, 0.025));
    c.drawLine(Offset(o + g * i, o), Offset(o + g * i, o + g * 2), iconLine(kIconInk, 0.025));
  }
  for (final p in const [Offset(o + g / 2, o + g / 2), Offset(o + g * 1.5, o + g * 1.5)]) {
    c.drawCircle(p, 0.085, iconFill(const Color(0xFF7BC47F)));
    c.drawCircle(p, 0.085, iconLine(const Color(0xFF2D6A3A), 0.025));
  }
  final path = Path()
    ..moveTo(o, o)
    ..lineTo(o + g, o)
    ..lineTo(o + g, o + g * 2)
    ..lineTo(o + g * 2, o + g * 2);
  c.drawPath(path, iconLine(const Color(0xFFE5730B), 0.07)..style = PaintingStyle.stroke);
  c.drawCircle(const Offset(o, o), 0.05, iconFill(const Color(0xFF3E9B5F)));
  c.drawCircle(const Offset(o + g * 2, o + g * 2), 0.05, iconFill(const Color(0xFFC62828)));
}
