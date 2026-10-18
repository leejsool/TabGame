
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 쿼리도: 칸 판 위에 두 말과 벽 ──
void paintQuoridorIcon(Canvas c, double s) {
  const n = 5;
  const left = 0.1, top = 0.1, cell = 0.14, gap = 0.04;
  const pitch = cell + gap;
  final board = RRect.fromRectAndRadius(const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9), const Radius.circular(0.07));
  iconShadow(c, Path()..addRRect(board));
  c.drawRRect(board, iconFill(const Color(0xFFB98C52)));
  for (var r = 0; r < n; r++) {
    for (var k = 0; k < n; k++) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + k * pitch, top + r * pitch, cell, cell), const Radius.circular(0.025)),
        iconFill(const Color(0xFFEBD3A3)),
      );
    }
  }
  // 벽: 가로 하나(2~3열 사이 위), 세로 하나
  final wall = iconFill(const Color(0xFF4A2F1B));
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left + 1 * pitch, top + 2 * pitch - gap, cell * 2 + gap, gap), const Radius.circular(0.02)), wall);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left + 3 * pitch - gap, top + 3 * pitch, gap, cell * 2 + gap), const Radius.circular(0.02)), wall);
  // 말
  void pawn(int r, int k, Color color) {
    final center = Offset(left + k * pitch + cell / 2, top + r * pitch + cell / 2);
    c.drawCircle(center + const Offset(0, 0.012), cell * 0.4, iconFill(Colors.black.withValues(alpha: 0.25)));
    c.drawCircle(center, cell * 0.4, iconFill(color));
    c.drawCircle(center, cell * 0.4, iconLine(Colors.white.withValues(alpha: 0.85), 0.012));
  }

  pawn(4, 2, const Color(0xFFD1495B));
  pawn(0, 2, const Color(0xFF3F7CAC));
}
