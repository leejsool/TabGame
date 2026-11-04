import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 건반 톡톡: 크림색 4줄 판 위에 계단처럼 내려오는 남색 블록, 하나는 방금 쳐서 빛나고 음표가 튄다 ──
void paintKeytapIcon(Canvas c, double s) {
  final board = RRect.fromRectAndRadius(const Rect.fromLTWH(0.08, 0.06, 0.84, 0.88), const Radius.circular(0.14));
  c.drawRRect(board.shift(const Offset(0, 0.025)), iconFill(Colors.black.withValues(alpha: 0.2)));
  c.drawRRect(board, iconFill(const Color(0xFFFBF7EE)));
  c.save();
  c.clipRRect(board);
  final line = Paint()
    ..color = const Color(0xFFDCD3C1)
    ..strokeWidth = 0.012;
  for (var i = 1; i < 4; i++) {
    c.drawLine(Offset(0.08 + 0.21 * i, 0.06), Offset(0.08 + 0.21 * i, 0.94), line);
  }
  // 블록 (칸, 위쪽 y)
  const tiles = [(1, -0.06), (3, 0.16), (0, 0.38), (2, 0.62)];
  for (final (lane, top) in tiles) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0.095 + 0.21 * lane, top, 0.18, 0.2), const Radius.circular(0.03));
    final hit = lane == 2;
    c.drawRRect(r, iconFill(hit ? const Color(0xFF8C87F0) : const Color(0xFF23243A)));
    if (hit) {
      c.drawRRect(
          r.inflate(0.02),
          Paint()
            ..color = const Color(0xFF5A54D6).withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.02);
    }
  }
  c.restore();
  // 음표
  final note = iconFill(const Color(0xFF5A54D6));
  c.drawOval(Rect.fromCenter(center: const Offset(0.70, 0.56), width: 0.1, height: 0.075), note);
  c.drawRect(const Rect.fromLTWH(0.735, 0.38, 0.02, 0.18), note);
  final flag = Path()
    ..moveTo(0.755, 0.38)
    ..quadraticBezierTo(0.83, 0.42, 0.80, 0.49)
    ..quadraticBezierTo(0.79, 0.44, 0.755, 0.43)
    ..close();
  c.drawPath(flag, note);
}
