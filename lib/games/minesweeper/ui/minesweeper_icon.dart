import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 지뢰찾기: 도화선이 타는 지뢰 ──
void paintMinesIcon(Canvas c, double s) {
  const center = Offset(0.48, 0.58);
  const r = 0.2;
  for (var k = 0; k < 8; k++) {
    final a = k * pi / 4 + pi / 8;
    c.drawLine(center + Offset(cos(a), sin(a)) * (r * 0.7), center + Offset(cos(a), sin(a)) * (r + 0.1), iconLine(kIconInk, 0.065));
  }
  c.drawCircle(center + const Offset(0, 0.025), r, iconFill(Colors.black.withValues(alpha: 0.22)));
  c.drawCircle(center, r, iconFill(const Color(0xFF2B2F3A)));
  c.drawCircle(center, r, iconLine(Colors.white.withValues(alpha: 0.85), 0.025));
  c.drawCircle(center + const Offset(-0.07, -0.07), 0.05, iconFill(Colors.white.withValues(alpha: 0.75)));
  // 도화선 + 불꽃
  final fuse = Path()
    ..moveTo(0.6, 0.43)
    ..quadraticBezierTo(0.7, 0.3, 0.68, 0.2);
  c.drawPath(fuse, iconLine(kIconInk, 0.07));
  c.drawPath(fuse, iconLine(const Color(0xFFE9C27A), 0.04));
  final spark = Path();
  const sc = Offset(0.69, 0.15);
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? 0.1 : 0.04;
    final a = k * pi / 5 - pi / 2;
    final o = sc + Offset(cos(a), sin(a)) * rr;
    k == 0 ? spark.moveTo(o.dx, o.dy) : spark.lineTo(o.dx, o.dy);
  }
  spark.close();
  c.drawPath(spark, iconLine(kIconInk, 0.04));
  c.drawPath(spark, iconFill(const Color(0xFFFFD84D)));
}
