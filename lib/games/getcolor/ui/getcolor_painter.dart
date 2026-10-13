import 'dart:math';

import 'package:flutter/material.dart';

import '../core/getcolor_rules.dart';

/// 물 색깔 12가지 (색 번호 → 색). 서로 헷갈리지 않게 골랐다.
const List<Color> kWaterColors = [
  Color(0xFFE5484D), // 빨강
  Color(0xFFF28C28), // 주황
  Color(0xFFF5D547), // 노랑
  Color(0xFF9BD14B), // 연두
  Color(0xFF2FA84F), // 초록
  Color(0xFF1FB5A5), // 청록
  Color(0xFF55C1F2), // 하늘
  Color(0xFF3E63DD), // 파랑
  Color(0xFF8E4EC6), // 보라
  Color(0xFFF06BA8), // 분홍
  Color(0xFF9A6B43), // 갈색
  Color(0xFFB9C2CF), // 회색
];

Color waterColor(int c) => kWaterColors[c % kWaterColors.length];

/// 병의 가로세로 비율 (높이 = 너비 × 이 값).
const double kBottleAspect = 3.0;

// 병 모양의 비율 (모두 병 너비 기준)
const double _capH = 0.14;
const double _neckH = 0.30;
const double _shoulder = 0.30;
const double _neckHalf = 0.30;
const double _bodyHalf = 0.46;

/// 병 입구(마개 아래 목 위쪽 가운데) 위치 — 붓기 애니메이션에서 병을 이 점을 중심으로 기울인다.
Offset bottleMouth(double w) => Offset(w / 2, w * _capH);

/// 병 입구의 한쪽 가장자리까지의 거리.
double bottleNeckHalf(double w) => w * _neckHalf;

/// 물이 가득 찼을 때 맨 위 / 맨 아래 높이, 한 칸의 높이.
double _liquidTop(double w) => w * (_capH + _neckH + _shoulder * 0.45);
double _liquidBottom(double w) => w * kBottleAspect - w * 0.05;
double unitHeight(double w) => (_liquidBottom(w) - _liquidTop(w)) / kBottleCapacity;

/// 병 안에서 물 [units]칸 높이일 때 수면의 y (병 왼쪽 위가 (0,0)인 좌표).
double surfaceY(double w, double units) => _liquidBottom(w) - units * unitHeight(w);

Path _bottlePath(double w) {
  final h = w * kBottleAspect;
  final cx = w / 2;
  final nw = w * _neckHalf, bw = w * _bodyHalf;
  final top = w * _capH;
  final shoulderY = top + w * _neckH;
  final bodyY = shoulderY + w * _shoulder;
  return Path()
    ..moveTo(cx - nw, top)
    ..lineTo(cx - nw, shoulderY)
    ..cubicTo(cx - nw, shoulderY + w * _shoulder * 0.55, cx - bw, shoulderY + w * _shoulder * 0.35, cx - bw, bodyY)
    ..lineTo(cx - bw, h - bw)
    ..arcToPoint(Offset(cx + bw, h - bw), radius: Radius.circular(bw), clockwise: false)
    ..lineTo(cx + bw, bodyY)
    ..cubicTo(cx + bw, shoulderY + w * _shoulder * 0.35, cx + nw, shoulderY + w * _shoulder * 0.55, cx + nw, shoulderY)
    ..lineTo(cx + nw, top)
    ..close();
}

/// 같은 색 칸들을 합친 물 한 덩어리: (색 번호, 칸 수 — 붓는 중에는 소수).
typedef WaterLayer = (int color, double units);

/// 병 안의 색 목록(아래→위)을 덩어리로 묶는다.
List<WaterLayer> layersOf(List<int> colors) {
  final out = <WaterLayer>[];
  for (final c in colors) {
    if (out.isNotEmpty && out.last.$1 == c) {
      out[out.length - 1] = (c, out.last.$2 + 1);
    } else {
      out.add((c, 1));
    }
  }
  return out;
}

/// 병 하나를 그린다. 병의 왼쪽 위가 (0,0), 너비가 [w] (높이는 `w * kBottleAspect`).
/// 호출하는 쪽이 canvas 를 옮기고 돌려서 놓는다.
void paintBottle(
  Canvas canvas,
  double w,
  List<WaterLayer> layers, {
  bool done = false,
  double glow = 0,
  Color glowColor = const Color(0xFFFFD84D),
}) {
  final path = _bottlePath(w);
  final stroke = max(1.6, w * 0.04);

  if (glow > 0) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.16
        ..color = glowColor.withValues(alpha: 0.75 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10),
    );
  }

  // 유리 바탕
  canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.16));

  // 물
  canvas.save();
  canvas.clipPath(path);
  final unit = unitHeight(w);
  var y = _liquidBottom(w);
  for (final (color, units) in layers) {
    if (units <= 0) continue;
    final top = y - units * unit;
    final base = waterColor(color);
    canvas.drawRect(Rect.fromLTRB(0, top, w, y + 1), Paint()..color = base);
    // 수면 쪽이 살짝 밝게
    canvas.drawRect(
      Rect.fromLTRB(0, top, w, min(y, top + unit * 0.22)),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    // 덩어리 사이 경계
    canvas.drawLine(
      Offset(0, top),
      Offset(w, top),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = max(1.0, w * 0.015),
    );
    y = top;
  }
  // 유리의 입체감: 왼쪽은 밝게, 오른쪽은 살짝 어둡게
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, w * kBottleAspect),
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.12),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, w * kBottleAspect)),
  );
  canvas.restore();

  // 윤곽선 + 하이라이트
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.85),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, w * (_capH + _neckH + _shoulder), w * 0.07, w * 1.35),
      Radius.circular(w * 0.035),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );

  // 다 모은 병에는 마개
  if (done && layers.isNotEmpty) {
    final c = HSLColor.fromColor(waterColor(layers.first.$1));
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * (0.5 - _neckHalf - 0.05), w * 0.0, w * (_neckHalf * 2 + 0.10), w * (_capH + 0.10)),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(cap, Paint()..color = c.withLightness((c.lightness * 0.8).clamp(0.0, 1.0)).toColor());
    canvas.drawRRect(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.8
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }
}

/// 병 밑에 깔리는 그림자.
void paintBottleShadow(Canvas canvas, double w) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset(w / 2, w * kBottleAspect + w * 0.02), width: w * 0.95, height: w * 0.22),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
  );
}
