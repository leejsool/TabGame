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

/// 숫자 카드(2~10)의 무늬 자리: (가로 0~1, 세로 0~1). 가로는 무늬 영역 안의 왼쪽/가운데/오른쪽 줄, 세로 0이 위쪽.
const double _l = 0.0, _c = 0.5, _r = 1.0;
const List<List<(double, double)>> kPipLayouts = [
  [(_c, 0), (_c, 1)], // 2
  [(_c, 0), (_c, 0.5), (_c, 1)], // 3
  [(_l, 0), (_r, 0), (_l, 1), (_r, 1)], // 4
  [(_l, 0), (_r, 0), (_c, 0.5), (_l, 1), (_r, 1)], // 5
  [(_l, 0), (_r, 0), (_l, 0.5), (_r, 0.5), (_l, 1), (_r, 1)], // 6
  [(_l, 0), (_r, 0), (_c, 0.25), (_l, 0.5), (_r, 0.5), (_l, 1), (_r, 1)], // 7
  [(_l, 0), (_r, 0), (_c, 0.25), (_l, 0.5), (_r, 0.5), (_c, 0.75), (_l, 1), (_r, 1)], // 8
  [(_l, 0), (_r, 0), (_l, 1 / 3), (_r, 1 / 3), (_c, 0.5), (_l, 2 / 3), (_r, 2 / 3), (_l, 1), (_r, 1)], // 9
  [
    (_l, 0), (_r, 0), (_c, 1 / 6), (_l, 1 / 3), (_r, 1 / 3), //
    (_l, 2 / 3), (_r, 2 / 3), (_c, 5 / 6), (_l, 1), (_r, 1), // 10
  ],
];

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

/// 카드 한 장 그리기 (발라트로 스타일): 왼쪽 줄에 작은 숫자 + 그 아래 작은 무늬를
/// 위(똑바로)와 아래(뒤집어서)에 놓고, 오른쪽의 넓은 자리에 큰 무늬를 숫자만큼 배치한다.
/// 여러 장이 겹쳐 쌓여도 맨 위 한 줄(숫자)만으로 읽힌다.
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

  // 왼쪽 줄: 숫자 + 그 아래 작은 무늬 (가운데 맞춤). 아래쪽에는 180도 돌려서 한 번 더.
  final tp = _TextCache.get(label, w * (label.length > 1 ? 0.17 : 0.25), color, FontWeight.w800);
  final idxCx = w * 0.05 + max(tp.width, w * 0.15) / 2;
  void index() {
    tp.paint(canvas, Offset(idxCx - tp.width / 2, h * 0.03));
    final s = w * 0.15;
    drawSuit(canvas, suit, Rect.fromLTWH(idxCx - s / 2, h * 0.03 + tp.height + h * 0.008, s, s), Paint()..color = color);
  }

  index();
  canvas.save();
  canvas.translate(idxCx, h / 2); // 같은 세로 줄 위에서 위아래만 뒤집는다
  canvas.rotate(pi);
  canvas.translate(-idxCx, -h / 2);
  index();
  canvas.restore();

  // 오른쪽 자리: 숫자 줄과 사이를 충분히 띄운다
  final mid = w * 0.64;
  if (rank >= 10) {
    final band = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.34, h * 0.1, w * 0.94, h * 0.9),
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
    final big = _TextCache.get(label, w * 0.4, color, FontWeight.w900);
    big.paint(canvas, Offset(mid - big.width / 2, h * 0.3));
    final s = w * 0.26;
    drawSuit(canvas, suit, Rect.fromLTWH(mid - s / 2, h * 0.3 + big.height + h * 0.02, s, s), Paint()..color = color);
  } else if (rank == 0) {
    final s = w * 0.5;
    drawSuit(canvas, suit, Rect.fromLTWH(mid - s / 2, h * 0.5 - s / 2, s, s), Paint()..color = color);
  } else {
    // 2~10: 숫자만큼 큰 무늬를 정해진 자리에 (모두 똑바로)
    final s = w * (rank <= 3 ? 0.27 : rank <= 5 ? 0.24 : 0.21);
    final paint = Paint()..color = color;
    final xHalf = w * 0.23;
    for (final (cx, ty) in kPipLayouts[rank - 1]) {
      final c = Offset(mid + (cx - 0.5) * 2 * xHalf, h * (0.19 + 0.62 * ty));
      drawSuit(canvas, suit, Rect.fromCenter(center: c, width: s, height: s), paint);
    }
  }

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
