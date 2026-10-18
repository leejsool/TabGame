
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 스도쿠: 숫자가 든 3×3 칸 ──
void paintSudokuIcon(Canvas c, double s) {
  final box = RRect.fromRectAndRadius(const Rect.fromLTWH(0.08, 0.08, 0.84, 0.84), const Radius.circular(0.09));
  iconShadow(c, Path()..addRRect(box));
  c.drawRRect(box, iconFill(Colors.white));
  c.drawRect(const Rect.fromLTWH(0.36, 0.36, 0.28, 0.28), iconFill(const Color(0xFFFFE08A)));
  final grid = iconLine(const Color(0xFF9AA5B8), 0.02, cap: StrokeCap.butt);
  for (final t in [0.36, 0.64]) {
    c.drawLine(Offset(t, 0.08), Offset(t, 0.92), grid);
    c.drawLine(Offset(0.08, t), Offset(0.92, t), grid);
  }
  c.drawRRect(box, iconLine(kIconInk, 0.04));
  const xs = [0.22, 0.5, 0.78];
  void digit(String d, int col, int row, Color color) => iconCrispText(c, d, Offset(xs[col], xs[row]), 0.2, color);
  digit('5', 0, 0, const Color(0xFF3F7CAC));
  digit('3', 2, 0, kIconInk);
  digit('7', 1, 1, const Color(0xFFD1495B));
  digit('1', 0, 2, kIconInk);
  digit('9', 2, 2, const Color(0xFF3F7CAC));
}
