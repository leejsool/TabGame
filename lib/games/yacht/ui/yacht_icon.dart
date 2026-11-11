import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 야추: 초록 판 위의 주사위 두 개 ──
void paintYachtIcon(Canvas c, double s) {
  final felt = RRect.fromRectAndRadius(const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9), const Radius.circular(0.2));
  iconShadow(c, Path()..addRRect(felt));
  c.drawRRect(felt, iconFill(const Color(0xFF2D7D5A)));
  c.drawRRect(felt.deflate(0.05), iconLine(Colors.white.withValues(alpha: 0.25), 0.012));

  void die(Offset center, double size, double angle, Color body, Color pip, List<Offset> pips) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size, height: size), Radius.circular(size * 0.2));
    c.drawRRect(r.shift(const Offset(0, 0.02)), iconFill(Colors.black.withValues(alpha: 0.28)));
    c.drawRRect(r, iconFill(body));
    for (final p in pips) {
      c.drawCircle(p * (size * 0.27), size * 0.085, iconFill(pip));
    }
    c.restore();
  }

  const ink = Color(0xFF26222E);
  // 뒤: 6 (빨간 주사위)
  die(const Offset(0.63, 0.37), 0.36, 0.22, const Color(0xFFD1495B), Colors.white, const [
    Offset(-1, -1), Offset(-1, 0), Offset(-1, 1), Offset(1, -1), Offset(1, 0), Offset(1, 1),
  ]);
  // 앞: 5 (흰 주사위)
  die(const Offset(0.4, 0.62), 0.42, -0.2, const Color(0xFFFDFBF5), ink, const [
    Offset(-1, -1), Offset(1, -1), Offset.zero, Offset(-1, 1), Offset(1, 1),
  ]);
}
