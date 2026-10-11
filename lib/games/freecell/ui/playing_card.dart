import 'dart:math';

import 'package:flutter/material.dart';

import '../core/freecell_rules.dart';

const Color kCardRed = Color(0xFFD62F3A);
const Color kCardBlack = Color(0xFF1E2430);

Color suitColor(int suit) => isRedSuit(suit) ? kCardRed : kCardBlack;

/// 무늬 하나를 [r] 안에 그린다 (♣=0, ♦=1, ♥=2, ♠=3). 폰트에 의존하지 않는다.
void drawSuit(Canvas canvas, int suit, Rect r, Paint paint) {
  Offset p(double x, double y) => Offset(r.left + x * r.width, r.top + y * r.height);

  Path heart({bool flip = false}) {
    double fy(double y) => flip ? 1 - y : y;
    return Path()
      ..moveTo(p(0.5, fy(0.97)).dx, p(0.5, fy(0.97)).dy)
      ..cubicTo(p(0.04, fy(0.64)).dx, p(0.04, fy(0.64)).dy, p(-0.02, fy(0.34)).dx,
          p(-0.02, fy(0.34)).dy, p(0.17, fy(0.17)).dx, p(0.17, fy(0.17)).dy)
      ..cubicTo(p(0.33, fy(0.03)).dx, p(0.33, fy(0.03)).dy, p(0.47, fy(0.1)).dx,
          p(0.47, fy(0.1)).dy, p(0.5, fy(0.27)).dx, p(0.5, fy(0.27)).dy)
      ..cubicTo(p(0.53, fy(0.1)).dx, p(0.53, fy(0.1)).dy, p(0.67, fy(0.03)).dx,
          p(0.67, fy(0.03)).dy, p(0.83, fy(0.17)).dx, p(0.83, fy(0.17)).dy)
      ..cubicTo(p(1.02, fy(0.34)).dx, p(1.02, fy(0.34)).dy, p(0.96, fy(0.64)).dx,
          p(0.96, fy(0.64)).dy, p(0.5, fy(0.97)).dx, p(0.5, fy(0.97)).dy)
      ..close();
  }

  switch (suit) {
    case 2: // ♥
      canvas.drawPath(heart(), paint);
    case 1: // ♦
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.0).dx, p(0.5, 0.0).dy)
          ..quadraticBezierTo(p(0.62, 0.34).dx, p(0.62, 0.34).dy, p(0.92, 0.5).dx, p(0.92, 0.5).dy)
          ..quadraticBezierTo(p(0.62, 0.66).dx, p(0.62, 0.66).dy, p(0.5, 1.0).dx, p(0.5, 1.0).dy)
          ..quadraticBezierTo(p(0.38, 0.66).dx, p(0.38, 0.66).dy, p(0.08, 0.5).dx, p(0.08, 0.5).dy)
          ..quadraticBezierTo(p(0.38, 0.34).dx, p(0.38, 0.34).dy, p(0.5, 0.0).dx, p(0.5, 0.0).dy)
          ..close(),
        paint,
      );
    case 3: // ♠
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.02).dx, p(0.5, 0.02).dy)
          ..cubicTo(p(0.98, 0.34).dx, p(0.98, 0.34).dy, p(1.04, 0.62).dx, p(1.04, 0.62).dy,
              p(0.83, 0.78).dx, p(0.83, 0.78).dy)
          ..cubicTo(p(0.67, 0.9).dx, p(0.67, 0.9).dy, p(0.53, 0.84).dx, p(0.53, 0.84).dy,
              p(0.5, 0.68).dx, p(0.5, 0.68).dy)
          ..cubicTo(p(0.47, 0.84).dx, p(0.47, 0.84).dy, p(0.33, 0.9).dx, p(0.33, 0.9).dy,
              p(0.17, 0.78).dx, p(0.17, 0.78).dy)
          ..cubicTo(p(-0.04, 0.62).dx, p(-0.04, 0.62).dy, p(0.02, 0.34).dx, p(0.02, 0.34).dy,
              p(0.5, 0.02).dx, p(0.5, 0.02).dy)
          ..close(),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.55).dx, p(0.5, 0.55).dy)
          ..quadraticBezierTo(p(0.5, 0.8).dx, p(0.5, 0.8).dy, p(0.36, 1.0).dx, p(0.36, 1.0).dy)
          ..lineTo(p(0.64, 1.0).dx, p(0.64, 1.0).dy)
          ..quadraticBezierTo(p(0.5, 0.8).dx, p(0.5, 0.8).dy, p(0.5, 0.55).dx, p(0.5, 0.55).dy)
          ..close(),
        paint,
      );
    default: // ♣
      final rr = r.width * 0.22;
      canvas.drawCircle(p(0.5, 0.27), rr, paint);
      canvas.drawCircle(p(0.25, 0.6), rr, paint);
      canvas.drawCircle(p(0.75, 0.6), rr, paint);
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.25).dx, p(0.5, 0.25).dy)
          ..lineTo(p(0.27, 0.6).dx, p(0.27, 0.6).dy)
          ..lineTo(p(0.73, 0.6).dx, p(0.73, 0.6).dy)
          ..close(),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.55).dx, p(0.5, 0.55).dy)
          ..quadraticBezierTo(p(0.5, 0.82).dx, p(0.5, 0.82).dy, p(0.36, 1.0).dx, p(0.36, 1.0).dy)
          ..lineTo(p(0.64, 1.0).dx, p(0.64, 1.0).dy)
          ..quadraticBezierTo(p(0.5, 0.82).dx, p(0.5, 0.82).dy, p(0.5, 0.55).dx, p(0.5, 0.55).dy)
          ..close(),
        paint,
      );
  }
}

class _TextCache {
  static final Map<int, TextPainter> _m = {};

  static TextPainter get(String s, double size, Color color, FontWeight w) {
    final key = Object.hash(s, size.round(), color.toARGB32(), w.value);
    return _m.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: size,
            color: color,
            fontWeight: w,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

/// 카드 한 장 그리기. 여러 장이 겹쳐 쌓여도 맨 위 한 줄(왼쪽 위 숫자+무늬)만으로 읽히게 한다.
void drawCard(Canvas canvas, int card, Size size, {Color? glow, double glowWidth = 3}) {
  final w = size.width, h = size.height;
  final rank = rankOf(card), suit = suitOf(card);
  final color = suitColor(suit);
  final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.12));

  canvas.drawShadow(Path()..addRRect(rr), Colors.black, 1.6, true);
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFF3EFE6)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFBDB6A6),
  );

  final label = kRankLabels[rank];
  final isFace = rank >= 10;

  // 왼쪽 위 숫자 + 작은 무늬
  final idxSize = w * (label.length > 1 ? 0.27 : 0.31);
  final tp = _TextCache.get(label, idxSize, color, FontWeight.w800);
  tp.paint(canvas, Offset(w * 0.07, h * 0.035));
  final suitSize = w * 0.22;
  drawSuit(
    canvas,
    suit,
    Rect.fromLTWH(w * 0.07 + tp.width + w * 0.03, h * 0.035 + (tp.height - suitSize) / 2, suitSize, suitSize),
    Paint()..color = color,
  );

  // 가운데
  if (isFace) {
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.3, w * 0.72, h * 0.5),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(band, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.35),
    );
    final big = _TextCache.get(label, w * 0.5, color, FontWeight.w900);
    big.paint(canvas, Offset((w - big.width) / 2, h * 0.34));
    final s = w * 0.3;
    drawSuit(canvas, suit, Rect.fromLTWH((w - s) / 2, h * 0.34 + big.height + h * 0.01, s, s), Paint()..color = color);
  } else {
    final s = w * 0.5;
    drawSuit(canvas, suit, Rect.fromLTWH((w - s) / 2, h * 0.38, s, s), Paint()..color = color);
  }

  // 오른쪽 아래 (뒤집힌) 숫자
  canvas.save();
  canvas.translate(w, h);
  canvas.rotate(pi);
  final tp2 = _TextCache.get(label, idxSize * 0.8, color, FontWeight.w800);
  tp2.paint(canvas, Offset(w * 0.07, h * 0.035));
  canvas.restore();

  if (glow != null) {
    canvas.drawRRect(
      rr.deflate(glowWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..color = glow,
    );
  }
}

class PlayingCardPainter extends CustomPainter {
  const PlayingCardPainter(this.card, {this.glow});

  final int card;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) => drawCard(canvas, card, size, glow: glow);

  @override
  bool shouldRepaint(PlayingCardPainter old) => old.card != card || old.glow != glow;
}
