import 'package:flutter/material.dart';

const Color kIconInk = Color(0xFF1A1523);

/// 허브 카드 아이콘을 그릴 때 쓰는 공통 도구 (좌표는 모두 0~1).

Paint iconFill(Color c) => Paint()..color = c;

Paint iconLine(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round
  ..color = c;

void iconShadow(Canvas c, Path p) => c.drawPath(p.shift(const Offset(0, 0.025)), iconFill(Colors.black.withValues(alpha: 0.22)));

void iconText(Canvas c, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// 숫자·글자 하나를 [center]의 한가운데에 그린다. 글자를 100배 키운 크기로 그려서 줄여 붙이고 (0~1 좌표에 바로 쓰는 아주 작은 글자 크기는
/// 흐리게 그려진다), 글자 상자가 아니라 숫자 모양 자체의 가운데(기준선에서 숫자 높이의 절반 위)가 [center]에 오게 맞춘다.
void iconCrispText(Canvas c, String s, Offset center, double size, Color color) {
  final fontSize = size * 100;
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'NanumGothic', fontSize: fontSize, fontWeight: FontWeight.w900, color: color, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  c.save();
  c.translate(center.dx, center.dy);
  c.scale(0.01);
  tp.paint(c, Offset(-tp.width / 2, -(baseline - fontSize * 0.36)));
  c.restore();
}

/// 카드·병처럼 픽셀 단위로 그리는 함수를 0~1 좌표 안에서 쓰게 한다.
void iconPixels(Canvas c, double s, Offset origin, void Function() draw) {
  c.save();
  c.translate(origin.dx, origin.dy);
  c.scale(1 / s);
  draw();
  c.restore();
}
