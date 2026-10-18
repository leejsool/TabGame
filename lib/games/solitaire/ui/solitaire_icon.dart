
import 'package:flutter/material.dart';

import 'package:tabgame/games/freecell/ui/playing_card.dart';

// ── 솔리테어: 펼친 카드 세 장 (게임의 실제 카드 그림) ──
void paintSolitaireIcon(Canvas c, double s) {
  const cw = 0.4, ch = 0.56;
  const pivot = Offset(0.5, 0.74); // 부채꼴 전체가 그림 한가운데에 오도록
  void card(int id, double angle) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    c.translate(-cw / 2, -ch);
    c.scale(1 / s);
    drawCard(c, id, Size(cw * s, ch * s), compact: true);
    c.restore();
  }

  card(9 * 4 + 1, -0.46); // 10♦
  card(12 * 4 + 2, 0.46); // K♥
  card(3, 0.0); // A♠
}
