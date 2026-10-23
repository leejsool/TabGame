import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 바둑돌 옮기기: 세 줄 판 위의 흰 돌과 검은 돌, 옮기는 화살표 ──
void paintStonesIcon(Canvas c, double s) {
  final board = RRect.fromRectAndRadius(const Rect.fromLTWH(0.06, 0.2, 0.88, 0.6), const Radius.circular(0.06));
  c.drawRRect(board, iconFill(const Color(0xFFF3E2B3)));
  c.drawRRect(board, iconLine(kIconInk, 0.035));
  for (final y in const [0.4, 0.6]) {
    c.drawLine(Offset(0.06, y), Offset(0.94, y), iconLine(kIconInk, 0.02));
  }
  void stone(Offset p, bool white) {
    c.drawCircle(p, 0.075, iconFill(white ? Colors.white : kIconInk));
    c.drawCircle(p, 0.075, iconLine(kIconInk, 0.025));
  }

  stone(const Offset(0.18, 0.3), true);
  stone(const Offset(0.82, 0.3), false);
  stone(const Offset(0.3, 0.5), true);
  stone(const Offset(0.7, 0.5), false);
  stone(const Offset(0.42, 0.7), true);
  stone(const Offset(0.6, 0.7), false);
  // 첫 줄 흰 돌이 오른쪽으로 옮겨 가는 화살표
  c.drawLine(const Offset(0.3, 0.3), const Offset(0.62, 0.3), iconLine(const Color(0xFFE53935), 0.04));
  c.drawPath(
    Path()
      ..moveTo(0.69, 0.3)
      ..lineTo(0.6, 0.25)
      ..lineTo(0.6, 0.35)
      ..close(),
    iconFill(const Color(0xFFE53935)),
  );
}
