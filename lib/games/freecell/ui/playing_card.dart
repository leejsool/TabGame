import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/card_look.dart';
import '../core/freecell_rules.dart';
import 'court_painter.dart';

const Color kCardRed = Color(0xFFD62F3A);
const Color kCardBlack = Color(0xFF1E2430);

/// 4색 모드의 색: ♣ 초록, ♦ 파랑, ♥ 빨강, ♠ 검정.
const List<Color> kFourColors = [Color(0xFF2E8B4F), Color(0xFF2F6FDB), kCardRed, kCardBlack];

Color suitColor(int suit) => CardLook.fourColor ? kFourColors[suit] : (isRedSuit(suit) ? kCardRed : kCardBlack);

/// 무늬마다 모양이 달라 같은 칸에 그리면 크기가 달라 보인다 (클로버가 크고 다이아가 작다).
/// 실제로 칠해진 면적이 비슷해지도록 무늬별로 크기와 세로 위치를 보정한다. (♣ ♦ ♥ ♠)
const List<double> _suitScale = [0.9, 1.0, 0.88, 0.93];
const List<double> _suitDy = [-0.02, 0.0, -0.03, 0.0];

/// 무늬 하나를 [r] 안에 그린다 (♣=0, ♦=1, ♥=2, ♠=3). 폰트에 의존하지 않는다.
void drawSuit(Canvas canvas, int suit, Rect r, Paint paint) {
  final f = _suitScale[suit];
  _drawSuitRaw(
    canvas,
    suit,
    Rect.fromCenter(center: r.center + Offset(0, _suitDy[suit] * r.height), width: r.width * f, height: r.height * f),
    paint,
  );
}

void _drawSuitRaw(Canvas canvas, int suit, Rect r, Paint paint) {
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
          ..quadraticBezierTo(p(0.66, 0.32).dx, p(0.66, 0.32).dy, p(0.95, 0.5).dx, p(0.95, 0.5).dy)
          ..quadraticBezierTo(p(0.66, 0.68).dx, p(0.66, 0.68).dy, p(0.5, 1.0).dx, p(0.5, 1.0).dy)
          ..quadraticBezierTo(p(0.34, 0.68).dx, p(0.34, 0.68).dy, p(0.05, 0.5).dx, p(0.05, 0.5).dy)
          ..quadraticBezierTo(p(0.34, 0.32).dx, p(0.34, 0.32).dy, p(0.5, 0.0).dx, p(0.5, 0.0).dy)
          ..close(),
        paint,
      );
    case 3: // ♠ (발라트로처럼 갸름하게: 뾰족한 윗부분, 작은 양쪽 둥근 부분, 넓게 퍼지는 받침)
      Path spade = Path()..moveTo(p(0.5, 0.0).dx, p(0.5, 0.0).dy);
      void c(double x1, double y1, double x2, double y2, double x3, double y3) =>
          spade.cubicTo(p(x1, y1).dx, p(x1, y1).dy, p(x2, y2).dx, p(x2, y2).dy, p(x3, y3).dx, p(x3, y3).dy);
      c(0.46, 0.16, 0.07, 0.36, 0.07, 0.6); // 왼쪽 윗부분 → 왼쪽 옆
      c(0.07, 0.8, 0.36, 0.86, 0.5, 0.68); // 왼쪽 아래 둥근 부분 → 가운데 홈
      c(0.64, 0.86, 0.93, 0.8, 0.93, 0.6); // 오른쪽 아래 둥근 부분
      c(0.93, 0.36, 0.54, 0.16, 0.5, 0.0); // 오른쪽 옆 → 윗부분
      spade.close();
      canvas.drawPath(spade, paint);
      canvas.drawPath(
        Path()
          ..moveTo(p(0.5, 0.58).dx, p(0.5, 0.58).dy)
          ..quadraticBezierTo(p(0.5, 0.86).dx, p(0.5, 0.86).dy, p(0.31, 1.0).dx, p(0.31, 1.0).dy)
          ..lineTo(p(0.69, 1.0).dx, p(0.69, 1.0).dy)
          ..quadraticBezierTo(p(0.5, 0.86).dx, p(0.5, 0.86).dy, p(0.5, 0.58).dx, p(0.5, 0.58).dy)
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
  [(_l, 0), (_r, 0), (_c, 0.165), (_l, 0.33), (_r, 0.33), (_l, 0.67), (_r, 0.67), (_l, 1), (_r, 1)], // 9
  [
    (_l, 0), (_r, 0), (_c, 0.165), (_l, 0.33), (_r, 0.33), //
    (_l, 0.67), (_r, 0.67), (_c, 0.835), (_l, 1), (_r, 1), // 10
  ],
];

class _TextCache {
  static final Map<int, TextPainter> _m = {};

  static TextPainter get(String s, double size, Color color, FontWeight w, {bool tight = false}) {
    final key = Object.hash(s, size.round(), color.toARGB32(), w.value, tight);
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
            letterSpacing: tight ? -size * 0.1 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

/// 카드 한 장 그리기 (발라트로 스타일): 왼쪽 위에 작은 숫자 + 그 바로 아래 작은 무늬,
/// 오른쪽 아래에는 같은 것이 180도 뒤집혀 있고, 숫자 사이의 가운데에 무늬를 숫자만큼 대칭으로 배치한다.
/// 여러 장이 겹쳐 쌓여도 맨 위 한 줄(숫자)만으로 읽힌다.
void drawCard(Canvas canvas, int card, Size size, {Color? glow, double glowWidth = 3, CardStyle? style, bool? fourColor}) {
  final w = size.width, h = size.height;
  final rank = rankOf(card), suit = suitOf(card);
  final four = fourColor ?? CardLook.fourColor;
  final color = four ? kFourColors[suit] : (isRedSuit(suit) ? kCardRed : kCardBlack);
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

  // 모서리 숫자: 작게 줄여서 가운데 무늬와 여백을 둔다. 아래쪽에는 180도 돌려서 한 번 더.
  final tp = _TextCache.get(label, w * 0.22, color, FontWeight.w800, tight: label.length > 1); // 모든 숫자·글자를 같은 크기로
  final idxCx = w * 0.05 + max(tp.width, w * 0.13) / 2;
  void index() {
    tp.paint(canvas, Offset(idxCx - tp.width / 2, h * 0.03));
    final s = w * 0.13;
    drawSuit(canvas, suit, Rect.fromLTWH(idxCx - s / 2, h * 0.03 + tp.height + h * 0.008, s, s), Paint()..color = color);
  }

  index();
  canvas.save();
  canvas.translate(w, h);
  canvas.rotate(pi);
  index();
  canvas.restore();

  // 가운데: 카드의 가로 가운데에 맞춘 대칭 배치
  final mid = w * 0.5;
  final st = style ?? CardLook.style;
  if (rank >= 10) {
    if (st == CardStyle.simple) {
      final band = RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.3, h * 0.12, w * 0.7, h * 0.88),
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
      final big = _TextCache.get(label, w * 0.36, color, FontWeight.w900);
      big.paint(canvas, Offset(mid - big.width / 2, h * 0.3));
      final s = w * 0.24;
      drawSuit(canvas, suit, Rect.fromLTWH(mid - s / 2, h * 0.3 + big.height + h * 0.02, s, s), Paint()..color = color);
    } else {
      drawCourtPanel(canvas, size, rank, suit, color, st);
    }
  } else if (rank == 0) {
    if (st == CardStyle.simple) {
      final s = w * 0.48;
      drawSuit(canvas, suit, Rect.fromLTWH(mid - s / 2, h * 0.5 - s / 2, s, s), Paint()..color = color);
    } else {
      drawAceFancy(canvas, size, suit, color, st);
    }
  } else {
    // 2~10: 숫자만큼 무늬를 배치한다. 아래쪽 절반의 무늬는 발라트로처럼 위아래를 뒤집는다.
    // rank는 0부터 센다: 무늬 개수 = rank + 1
    final s = w * 1.08 * (rank <= 2 ? 0.26 : rank <= 4 ? 0.22 : rank <= 7 ? 0.19 : 0.15);
    final paint = Paint()..color = color;
    final xHalf = w * 0.16;
    for (final (cx, ty) in kPipLayouts[rank - 1]) {
      final c = Offset(mid + (cx - 0.5) * 2 * xHalf, h * (0.21 + 0.58 * ty));
      final r = Rect.fromCenter(center: c, width: s, height: s);
      if (ty > 0.55) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(pi);
        canvas.translate(-c.dx, -c.dy);
        drawSuit(canvas, suit, r, paint);
        canvas.restore();
      } else {
        drawSuit(canvas, suit, r, paint);
      }
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
  PlayingCardPainter(this.card, {this.glow, CardStyle? style, bool? fourColor})
      : style = style ?? CardLook.style,
        fourColor = fourColor ?? CardLook.fourColor;

  final int card;
  final Color? glow;

  /// 만들 때의 카드 모양 (설정이 바뀌면 다시 그리려고).
  final CardStyle style;
  final bool fourColor;

  @override
  void paint(Canvas canvas, Size size) => drawCard(canvas, card, size, glow: glow, style: style, fourColor: fourColor);

  @override
  bool shouldRepaint(PlayingCardPainter old) =>
      old.card != card || old.glow != glow || old.style != style || old.fourColor != fourColor;
}
