
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 궁극 틱택토: # 판 위의 X와 O ──
void paintUtttIcon(Canvas c, double s) {
  final hash = iconLine(Colors.white, 0.07);
  for (final t in [0.37, 0.63]) {
    c.drawLine(Offset(t, 0.1), Offset(t, 0.9), hash);
    c.drawLine(Offset(0.1, t), Offset(0.9, t), hash);
  }
  const cell = [0.235, 0.5, 0.765];
  void x(int col, int row) {
    const d = 0.075;
    final center = Offset(cell[col], cell[row]);
    final p = Path()
      ..moveTo(center.dx - d, center.dy - d)
      ..lineTo(center.dx + d, center.dy + d)
      ..moveTo(center.dx + d, center.dy - d)
      ..lineTo(center.dx - d, center.dy + d);
    c.drawPath(p, iconLine(kIconInk, 0.095));
    c.drawPath(p, iconLine(const Color(0xFFFFD84D), 0.055));
  }

  void o(int col, int row) {
    final center = Offset(cell[col], cell[row]);
    c.drawCircle(center, 0.085, iconLine(kIconInk, 0.095));
    c.drawCircle(center, 0.085, iconLine(const Color(0xFF9CE7FF), 0.055));
  }

  x(0, 0);
  o(1, 0);
  o(0, 1);
  x(1, 1);
  x(2, 2);
  o(2, 1);
  o(1, 2);
}
