import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 지렁이의 모험: 어두운 필드 위에 S자로 기어가는 초록 뱀과 반짝이는 먹이 ──
void paintSnakeIcon(Canvas c, double s) {
  final field = RRect.fromRectAndRadius(const Rect.fromLTWH(0.06, 0.06, 0.88, 0.88), const Radius.circular(0.16));
  c.drawRRect(field.shift(const Offset(0, 0.025)), iconFill(Colors.black.withValues(alpha: 0.22)));
  c.drawRRect(field, iconFill(const Color(0xFF14192B)));
  // 먹이
  const foods = [(0.22, 0.24, Color(0xFFFFE04A)), (0.78, 0.30, Color(0xFFFF6FD8)), (0.30, 0.78, Color(0xFF3BC9F5)), (0.72, 0.62, Color(0xFFFFA62B))];
  for (final (x, y, col) in foods) {
    c.drawCircle(Offset(x, y), 0.045, iconFill(col.withValues(alpha: 0.3)));
    c.drawCircle(Offset(x, y), 0.024, iconFill(col));
  }
  // 몸 (S자)
  final body = Path()
    ..moveTo(0.20, 0.62)
    ..cubicTo(0.20, 0.42, 0.50, 0.42, 0.50, 0.55)
    ..cubicTo(0.50, 0.70, 0.78, 0.72, 0.76, 0.46);
  Paint stroke(Color color, double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawPath(body, stroke(const Color(0xFF17694F), 0.15));
  c.drawPath(body, stroke(const Color(0xFF2ED1A2), 0.12));
  c.drawPath(body, stroke(Colors.white.withValues(alpha: 0.25), 0.03));
  // 머리와 눈
  const head = Offset(0.76, 0.42);
  c.drawCircle(head, 0.085, iconFill(const Color(0xFF17694F)));
  c.drawCircle(head, 0.075, iconFill(const Color(0xFF2ED1A2)));
  for (final dx in const [-0.035, 0.035]) {
    c.drawCircle(head + Offset(dx, -0.025), 0.028, iconFill(Colors.white));
    c.drawCircle(head + Offset(dx, -0.035), 0.014, iconFill(const Color(0xFF111111)));
  }
}
