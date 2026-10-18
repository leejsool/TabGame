
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 다빈치 코드: 숫자가 보이는 검정 타일, 흰색 타일, 그리고 뒷면(?) 타일 ──
void paintDavinciIcon(Canvas c, double s) {
  const w = 0.32, h = 0.45;
  const tiles = [
    (Offset(0.27, 0.54), -0.26, Color(0xFF2A2D32), '7', Colors.white),
    (Offset(0.5, 0.46), 0.0, Color(0xFFF6F1E4), '3', Color(0xFF2A2D32)),
    (Offset(0.73, 0.54), 0.26, Color(0xFF2A2D32), '?', Color(0xFF8FA3B0)),
  ];
  for (final (center, angle, bg, label, fg) in tiles) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2, -h / 2, w, h), const Radius.circular(0.05));
    iconShadow(c, Path()..addRRect(tile));
    c.drawRRect(tile, iconFill(bg));
    c.drawRRect(tile, iconLine(bg == const Color(0xFFF6F1E4) ? const Color(0xFFBDB29A) : const Color(0xFF6A6F78), 0.02));
    iconCrispText(c, label, Offset.zero, 0.24, fg);
    c.restore();
  }
}
