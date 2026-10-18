
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';
import 'package:tabgame/games/dotcannon/ui/dot_painter.dart' show paintCannon;

// ── 도트 캐논: 나무 액자 속 도트 하트, 아래에서 쏘는 대포 ──
void paintDotCannonIcon(Canvas c, double s) {
  const wood = Color(0xFF8C5A34);
  final frame = RRect.fromRectAndRadius(const Rect.fromLTWH(0.1, 0.06, 0.8, 0.7), const Radius.circular(0.06));
  c.drawRRect(frame.shift(const Offset(0, 0.025)), iconFill(Colors.black.withValues(alpha: 0.22)));
  c.drawRRect(frame, iconFill(wood));
  c.drawRRect(frame.deflate(0.04), iconFill(const Color(0xFFF7F1E3)));
  // 하트 도트 (맨 아랫줄은 이미 맞혀서 지워졌다)
  const heart = [
    '.RR.RR.',
    'RWRRRRR',
    'RRRRRRR',
    '.RRRRR.',
    '..RRR..',
    '...R...',
  ];
  const cols = 7;
  const cell = 0.085;
  const ox = 0.5 - cols * cell / 2;
  const oy = 0.13;
  for (var y = 0; y < heart.length; y++) {
    for (var x = 0; x < cols; x++) {
      final ch = heart[y][x];
      if (ch == '.') continue;
      final color = ch == 'W' ? Colors.white : const Color(0xFFE5484D);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ox + x * cell + 0.004, oy + y * cell + 0.004, cell - 0.008, cell - 0.008), const Radius.circular(0.012)),
        iconFill(color),
      );
    }
  }
  // 탄 한 발
  c.drawCircle(const Offset(0.5, 0.74), 0.028, iconFill(Colors.white));
  c.drawCircle(const Offset(0.5, 0.74), 0.02, iconFill(const Color(0xFFE5484D)));
  // 대포 (위를 향한다)
  iconPixels(c, s, const Offset(0.36, 0.76), () => paintCannon(c, Offset(0.14 * s, 0.14 * s), 0.28 * s, const Color(0xFFE5484D), -1.5708, label: '9'));
}
