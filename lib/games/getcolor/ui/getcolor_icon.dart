
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_painter.dart';

// ── 겟 컬러: 게임에서 쓰는 병 모양 그대로, 물이 든 병 세 개 ──
void paintGetColorIcon(Canvas c, double s) {
  const w = 0.28;
  void bottle(double x, double y, List<int> colors, {bool done = false}) {
    iconPixels(c, s, Offset(x, y), () => paintBottle(c, w * s, layersOf(colors), done: done));
  }

  bottle(0.04, 0.13, const [0, 2, 6, 0]); // 섞인 병
  bottle(0.36, 0.03, const [8, 8, 4]); // 들어 올린 병
  bottle(0.68, 0.13, const [6, 6, 6, 6], done: true); // 다 모은 병 (마개)
}
