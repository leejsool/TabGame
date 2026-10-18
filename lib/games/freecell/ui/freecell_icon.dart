
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';
import 'package:tabgame/games/freecell/ui/playing_card.dart';

// ── 프리셀: 숫자가 이어지는 카드 줄 (실제 카드 그림) + 빈 칸 ──
void paintFreecellIcon(Canvas c, double s) {
  const cw = 0.37, ch = 0.52;
  // 위쪽 빈 칸 두 개
  for (final x in [0.56, 0.76]) {
    final slot = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0.1, 0.17, 0.22), const Radius.circular(0.04));
    c.drawRRect(slot, iconFill(Colors.white.withValues(alpha: 0.18)));
    c.drawRRect(slot, iconLine(Colors.white.withValues(alpha: 0.85), 0.025));
  }
  void card(int id, double x, double y) => iconPixels(c, s, Offset(x, y), () => drawCard(c, id, Size(cw * s, ch * s), compact: true));
  card(6 * 4 + 0, 0.08, 0.1); // 7♣
  card(5 * 4 + 1, 0.08, 0.27); // 6♦
  card(4 * 4 + 3, 0.08, 0.44); // 5♠
  card(12 * 4 + 2, 0.55, 0.38); // K♥
}
