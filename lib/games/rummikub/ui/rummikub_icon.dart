
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 루미큐브: 같은 숫자 다른 색 타일 세 장이 부채꼴로 놓인 그룹 ──
void paintRummikubIcon(Canvas c, double s) {
  const w = 0.34, h = 0.46;
  const colors = [Color(0xFF1E63C6), Color(0xFFD32F2F), Color(0xFFEF8A17)];
  const angles = [-0.26, 0.0, 0.26];
  const centers = [Offset(0.27, 0.53), Offset(0.5, 0.45), Offset(0.73, 0.53)];
  for (var i = 0; i < 3; i++) {
    c.save();
    c.translate(centers[i].dx, centers[i].dy);
    c.rotate(angles[i]);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2, -h / 2, w, h), const Radius.circular(0.055));
    iconShadow(c, Path()..addRRect(tile));
    c.drawRRect(tile, iconFill(const Color(0xFFFFF8E6)));
    c.drawRRect(tile, iconLine(const Color(0xFF8D5A2B), 0.02));
    // 숫자는 패 안쪽 위에, 색 무늬(●■▲)는 아래에 작은 도형으로 (글자 상자가 커서 패 밖으로 나가지 않게 크기와 자리를 줄였다)
    iconCrispText(c, '7', const Offset(0, -0.06), 0.17, colors[i]);
    final mark = iconFill(colors[i]);
    const my = 0.115, r = 0.034;
    switch (i) {
      case 0:
        c.drawCircle(const Offset(0, my), r, mark);
      case 1:
        c.drawRect(Rect.fromCenter(center: const Offset(0, my), width: r * 1.8, height: r * 1.8), mark);
      default:
        c.drawPath(
          Path()
            ..moveTo(0, my - r * 1.1)
            ..lineTo(r * 1.15, my + r * 0.9)
            ..lineTo(-r * 1.15, my + r * 0.9)
            ..close(),
          mark,
        );
    }
    c.restore();
  }
}
