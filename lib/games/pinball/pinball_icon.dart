import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 핀볼: 은색 공, 범퍼, 플리퍼 ──
void paintPinballIcon(Canvas c, double s) {
  // 범퍼
  c.drawCircle(const Offset(0.24, 0.3), 0.12, iconFill(const Color(0xFFFF6B6B)));
  c.drawCircle(const Offset(0.24, 0.3), 0.12, iconLine(kIconInk, 0.035));
  c.drawCircle(const Offset(0.24, 0.3), 0.06, iconFill(Colors.white.withValues(alpha: 0.85)));
  // 플리퍼 (왼쪽·오른쪽)
  for (final left in [true, false]) {
    final a = left ? const Offset(0.16, 0.74) : const Offset(0.84, 0.74);
    final b = left ? const Offset(0.44, 0.88) : const Offset(0.56, 0.88);
    c.drawLine(a, b, iconLine(kIconInk, 0.16));
    c.drawLine(a, b, iconLine(const Color(0xFFFFD84D), 0.11));
    c.drawCircle(a, 0.045, iconFill(kIconInk));
  }
  // 공
  const ball = Offset(0.62, 0.42);
  c.drawCircle(ball + const Offset(0, 0.03), 0.17, iconFill(Colors.black.withValues(alpha: 0.22)));
  c.drawCircle(
    ball,
    0.17,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.45), colors: [Color(0xFFFFFFFF), Color(0xFFB9C2CF), Color(0xFF7A8499)]).createShader(Rect.fromCircle(center: ball, radius: 0.17)),
  );
  c.drawCircle(ball, 0.17, iconLine(kIconInk, 0.035));
  // 튕기는 선
  for (final a in [-2.6, -2.1, -0.5]) {
    c.drawLine(ball + Offset(cos(a), sin(a)) * 0.24, ball + Offset(cos(a), sin(a)) * 0.32, iconLine(Colors.white, 0.03));
  }
}
