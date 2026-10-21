import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pinball_engine.dart';

/// 공이 이 빠르기(판 좌표/초)보다 느리면 화살표를 그리지 않는다 (통로에서 기다리는 공 등).
const double kArrowMinSpeed = 60;

/// 3·2·1 동안 공이 움직이던 방향과 빠르기를 화살표로 보여 준다: 빠를수록 길고 굵다.
/// 화살표는 공 둘레의 고리 바깥에서 시작한다 ([ringR]).
void paintBallArrow(Canvas canvas, Ball b, double ringR) {
  final speed = sqrt(b.vx * b.vx + b.vy * b.vy);
  if (b.waiting || speed < kArrowMinSpeed) return;
  final dx = b.vx / speed, dy = b.vy / speed;
  // 빠르기 0 → 짧게, 2400 이상 → 가장 길게
  final t = (speed / 2400).clamp(0.0, 1.0);
  final len = 34 + 120 * t;
  final width = 5 + 4 * t;
  final start = Offset(b.x + dx * ringR, b.y + dy * ringR);
  final tip = start + Offset(dx, dy) * len;
  final head = 14 + 6 * t;
  final back = tip - Offset(dx, dy) * head;
  final side = Offset(-dy, dx) * head * 0.6;
  final shaftEnd = tip - Offset(dx, dy) * head * 0.8;

  final color = Color.lerp(const Color(0xFF69F0AE), const Color(0xFFFF5252), t)!;
  final outline = Paint()
    ..color = const Color(0xCC000000)
    ..strokeWidth = width + 4
    ..strokeCap = StrokeCap.round;
  final shaft = Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  final headPath = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(back.dx + side.dx, back.dy + side.dy)
    ..lineTo(back.dx - side.dx, back.dy - side.dy)
    ..close();
  canvas.drawLine(start, shaftEnd, outline);
  canvas.drawPath(headPath, Paint()
    ..color = const Color(0xCC000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = StrokeJoin.round);
  canvas.drawLine(start, shaftEnd, shaft);
  canvas.drawPath(headPath, Paint()..color = color);
}

/// 화살표가 위쪽을 가리키는지 ("공" 글자를 화살표와 겹치지 않게 아래로 옮길 때 쓴다).
bool arrowPointsUp(Ball b) {
  final speed = sqrt(b.vx * b.vx + b.vy * b.vy);
  return !b.waiting && speed >= kArrowMinSpeed && b.vy < -b.vx.abs() * 0.4;
}
