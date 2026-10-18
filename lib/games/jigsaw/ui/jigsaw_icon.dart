import 'dart:math';

import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';

// ── 직소퍼즐: 맞물린 두 조각 ──
Path _piece(Rect r, {int top = 0, int right = 0, int bottom = 0, int left = 0}) {
  var p = Path()..addRect(r);
  final k = min(r.width, r.height) * 0.2; // 손잡이 반지름
  final neck = k * 0.35;
  Path knob(Offset center) => Path()..addOval(Rect.fromCircle(center: center, radius: k));
  Path join(Path base, int kind, Offset edge, Offset out) {
    if (kind == 0) return base;
    final center = edge + out * (k * 0.7 * kind);
    final shape = Path.combine(PathOperation.union, knob(center), Path()..addRect(Rect.fromCenter(center: edge, width: neck * 2 + (out.dx == 0 ? 0 : k), height: neck * 2 + (out.dy == 0 ? 0 : k))));
    return Path.combine(kind > 0 ? PathOperation.union : PathOperation.difference, base, shape);
  }

  p = join(p, top, r.topCenter, const Offset(0, -1));
  p = join(p, right, r.centerRight, const Offset(1, 0));
  p = join(p, bottom, r.bottomCenter, const Offset(0, 1));
  p = join(p, left, r.centerLeft, const Offset(-1, 0));
  return p;
}

void paintJigsawIcon(Canvas c, double s) {
  final a = _piece(const Rect.fromLTWH(0.07, 0.3, 0.4, 0.4), right: 1, top: 1);
  final b = _piece(const Rect.fromLTWH(0.49, 0.3, 0.44, 0.4), left: -1, bottom: 1);
  for (final (path, color) in [(a, const Color(0xFF55C1F2)), (b, Colors.white)]) {
    iconShadow(c, path);
    c.drawPath(path, iconFill(color));
    c.drawPath(path, iconLine(kIconInk, 0.035));
  }
}
