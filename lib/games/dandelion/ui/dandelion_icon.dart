import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_art.dart' show paintWindGust;

// ── 민들레: 노란 꽃과 바람에 날아가는 씨앗 ──
void paintDandelionIcon(Canvas c, double s) {
  // 바람: 위쪽 오른쪽과 아래쪽 왼쪽에 돌돌 말리는 바람 줄
  paintWindGust(c, const Rect.fromLTWH(0.44, 0.0, 0.54, 0.54), Colors.white.withValues(alpha: 0.92), thickness: 0.08);
  // 꽃
  const center = Offset(0.29, 0.66);
  const r = 0.25;
  for (final (w, color) in [(0.1, kIconInk), (0.062, const Color(0xFFFFD84D))]) {
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * pi / 14;
      final d = Offset(cos(a), sin(a));
      c.drawLine(center + d * r * 0.36, center + d * r * 0.94, iconLine(color, w));
    }
  }
  c.drawCircle(center, r * 0.44, iconFill(const Color(0xFFF08A00)));
  c.drawCircle(center, r * 0.44, iconLine(kIconInk, 0.035));
  c.drawCircle(center + const Offset(-0.03, -0.03), 0.03, iconFill(Colors.white.withValues(alpha: 0.6)));
  // 날아가는 씨앗
  void seed(Offset p, double k) {
    for (var i = -2; i <= 2; i++) {
      final a = -pi / 2 + i * 0.5;
      final end = p + Offset(cos(a), sin(a)) * 0.1 * k;
      c.drawLine(p, end, iconLine(kIconInk, 0.03 * k));
      c.drawCircle(end, 0.02 * k, iconFill(Colors.white));
    }
    c.drawOval(Rect.fromCenter(center: p + Offset(0, 0.035 * k), width: 0.034 * k, height: 0.07 * k), iconFill(kIconInk));
  }

  seed(const Offset(0.72, 0.72), 1.0);
  seed(const Offset(0.9, 0.82), 0.85);
  seed(const Offset(0.7, 0.93), 0.7);
}
