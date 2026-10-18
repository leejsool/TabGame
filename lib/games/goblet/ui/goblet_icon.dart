
import 'package:flutter/material.dart';

import 'package:tabgame/games/goblet/core/goblet_rules.dart' show Team;
import 'package:tabgame/games/goblet/ui/goblet_piece.dart' show GobblerPainter;

// ── 고블렛 고블러스: 게임 안의 고블러(귀 달린 돔 모양 컵) 크기별 세 개 ──
void paintGobletIcon(Canvas c, double s) {
  // 그림 좌표가 0~1이라, 100배 키운 크기로 말을 그려서 줄여 붙인다 (선 굵기 등이 게임 안과 같게).
  // 말은 바닥 선에 맞춰 놓이고 큰 말의 귀가 솟아 있어서, 상자 기준이 아니라 그려진 모양의 위아래 가운데를 그림 가운데에 맞춘다.
  const k = 1.0;
  void piece(Team team, int size, double cx, double w) {
    const base = 0.77; // 말 그림의 위아래 가운데가 그림 한가운데(0.5)에 오는 자리
    final x = 0.5 + (cx - 0.5) * k, ww = w * k;
    c.save();
    c.translate(x - ww / 2, base - ww);
    c.scale(0.01);
    GobblerPainter(team: team, size: size).paint(c, Size(ww * 100, ww * 100));
    c.restore();
  }

  piece(Team.red, 3, 0.74, 0.52);
  piece(Team.blue, 2, 0.44, 0.42);
  piece(Team.red, 1, 0.17, 0.32);
}
