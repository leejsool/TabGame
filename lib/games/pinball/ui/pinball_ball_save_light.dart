import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pinball_run.dart';

/// 판 그림에서 양쪽 아웃레인(바깥 길)의 노란 불빛 자리 (판 좌표, 가운데·크기).
const List<Rect> kBallSaveSlots = [
  Rect.fromLTWH(58, 1045, 12, 78),
  Rect.fromLTWH(533, 1055, 12, 72),
];

/// 볼 세이브가 켜져 있는 동안 아웃레인 불빛을 노랗게 밝히고 위에 "세이브" 글자를 띄운다.
/// 꺼지기 2초 전부터는 빠르게 깜빡여서 곧 꺼진다는 걸 알린다.
void paintBallSaveLights(Canvas canvas, PinballRun run) {
  if (!run.ballSaveOn) return;
  final ending = run.ballSaveLeft < 2;
  final pulse = ending ? (sin(run.clock * 22) > 0 ? 1.0 : 0.25) : 0.7 + 0.3 * sin(run.clock * 6);
  const yellow = Color(0xFFFFE066);
  for (final slot in kBallSaveSlots) {
    final r = RRect.fromRectAndRadius(slot, const Radius.circular(6));
    canvas.drawRRect(r.inflate(7), Paint()
      ..color = yellow.withValues(alpha: 0.35 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(r, Paint()..color = yellow.withValues(alpha: 0.9 * pulse));
    final tp = TextPainter(
      text: TextSpan(
        text: '세이브',
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: pulse),
          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(slot.center.dx - tp.width / 2, slot.top - tp.height - 4));
  }
}
