import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/card_look.dart';
import 'playing_card.dart';

// 인물 그림에 쓰는 색
const _outline = Color(0xFF3A2A1A);
const _skin = Color(0xFFF6D2B0);
const _gold = Color(0xFFF2B63C);
const _goldDark = Color(0xFFB9801A);
const _hairDark = Color(0xFF5A3A22);
const _beard = Color(0xFFE8E4DA);

/// 무늬별 옷 색: ♣ 초록, ♦ 주황, ♥ 빨강, ♠ 남색.
const _robe = [Color(0xFF2F6B45), Color(0xFFE08A1E), Color(0xFFC42B3B), Color(0xFF26336B)];

/// 왕(K)·여왕(Q)·잭(J) 카드의 가운데 그림. 트럼프처럼 위쪽 인물과, 180도 돌려 놓은 아래쪽 인물이 있다.
void drawCourtPanel(Canvas canvas, Size size, int rank, int suit, Color suitColor, CardStyle style) {
  final w = size.width, h = size.height;
  final cute = style == CardStyle.cute;
  final panel = RRect.fromRectAndRadius(
    Rect.fromLTRB(w * 0.27, h * 0.1, w * 0.73, h * 0.9),
    Radius.circular(w * 0.05),
  );
  final isRed = suit == 1 || suit == 2;
  canvas.drawRRect(
    panel,
    Paint()..color = cute ? (isRed ? const Color(0xFFFFEEF0) : const Color(0xFFEAF2FF)) : const Color(0xFFFFF8E6),
  );
  canvas.drawRRect(
    panel,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.014)
      ..color = suitColor.withValues(alpha: 0.85),
  );
  // 안쪽 가는 테두리
  canvas.drawRRect(
    panel.deflate(w * 0.022),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.006)
      ..color = suitColor.withValues(alpha: 0.35),
  );

  final center = panel.outerRect.center;
  final half = Rect.fromLTRB(panel.left + w * 0.03, panel.top + h * 0.012, panel.right - w * 0.03, center.dy - h * 0.004);
  _bust(canvas, half, rank, suit, cute);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(pi);
  canvas.translate(-center.dx, -center.dy);
  _bust(canvas, half, rank, suit, cute);
  canvas.restore();

  // 가운데 구분선과 작은 무늬
  canvas.drawLine(
    Offset(panel.left + w * 0.03, center.dy),
    Offset(panel.right - w * 0.03, center.dy),
    Paint()
      ..strokeWidth = max(0.8, w * 0.01)
      ..color = suitColor.withValues(alpha: 0.6),
  );
  final s = w * 0.09;
  canvas.drawCircle(center, s * 0.75, Paint()..color = const Color(0xFFFFF8E6));
  drawSuit(canvas, suit, Rect.fromCenter(center: center, width: s, height: s), Paint()..color = suitColor);
}

/// 폰용 카드의 아래쪽 [body]에 인물 한 명을 크게 그린다 (위아래 두 명 대신).
void drawCourtCompact(Canvas canvas, Rect body, int rank, int suit, Color suitColor, CardStyle style) {
  final cute = style == CardStyle.cute;
  final w = body.width;
  final panel = RRect.fromRectAndRadius(body, Radius.circular(w * 0.07));
  final isRed = suit == 1 || suit == 2;
  canvas.drawRRect(
    panel,
    Paint()..color = cute ? (isRed ? const Color(0xFFFFEEF0) : const Color(0xFFEAF2FF)) : const Color(0xFFFFF8E6),
  );
  canvas.drawRRect(
    panel,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.025)
      ..color = suitColor.withValues(alpha: 0.85),
  );
  _bust(canvas, body.deflate(w * 0.05), rank, suit, cute);
}

/// 위쪽 반 칸 [r] 안에 가슴 위 인물을 그린다. [rank] 10=J, 11=Q, 12=K.
void _bust(Canvas canvas, Rect r, int rank, int suit, bool cute) {
  final w = r.width, h = r.height;
  Offset p(double fx, double fy) => Offset(r.left + fx * w, r.top + fy * h);
  final line = max(0.6, w * 0.013);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = line
    ..strokeJoin = StrokeJoin.round
    ..color = _outline.withValues(alpha: 0.8);
  Paint fill(Color c) => Paint()..color = c;
  Color soft(Color c) => cute ? Color.lerp(c, Colors.white, 0.28)! : c;
  final robe = soft(_robe[suit]);

  final isK = rank == 12, isQ = rank == 11, isJ = rank == 10;
  final headY = cute ? 0.40 : 0.38;
  final headW = cute ? 0.5 : 0.36;
  final headH = cute ? 0.46 : 0.38;

  // 긴 머리(여왕)는 얼굴 뒤에서 어깨까지
  if (isQ) {
    final hair = fill(cute ? const Color(0xFFD9A35B) : _hairDark);
    final back = Rect.fromCenter(center: p(0.5, headY + 0.04), width: w * (headW + 0.14), height: h * (headH + 0.14));
    canvas.drawOval(back, hair);
    canvas.drawOval(back, stroke);
    for (final fx in [0.27, 0.73]) {
      final strand = Rect.fromCenter(center: p(fx, 0.62), width: w * 0.14, height: h * 0.34);
      canvas.drawOval(strand, hair);
      canvas.drawOval(strand, stroke);
    }
  }

  // 어깨(옷)
  final shoulders = Path()
    ..moveTo(p(0.04, 1.0).dx, p(0.04, 1.0).dy)
    ..lineTo(p(0.12, 0.72).dx, p(0.12, 0.72).dy)
    ..quadraticBezierTo(p(0.5, 0.58).dx, p(0.5, 0.58).dy, p(0.88, 0.72).dx, p(0.88, 0.72).dy)
    ..lineTo(p(0.96, 1.0).dx, p(0.96, 1.0).dy)
    ..close();
  canvas.drawPath(shoulders, fill(robe));
  canvas.drawPath(shoulders, stroke);
  // 금색 장식 (어깨선과 가운데 V)
  final trim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, w * 0.045)
    ..strokeCap = StrokeCap.round
    ..color = _gold;
  canvas.drawPath(
    Path()
      ..moveTo(p(0.12, 0.72).dx, p(0.12, 0.72).dy)
      ..quadraticBezierTo(p(0.5, 0.58).dx, p(0.5, 0.58).dy, p(0.88, 0.72).dx, p(0.88, 0.72).dy),
    trim,
  );
  canvas.drawPath(
    Path()
      ..moveTo(p(0.36, 0.66).dx, p(0.36, 0.66).dy)
      ..lineTo(p(0.5, 0.92).dx, p(0.5, 0.92).dy)
      ..lineTo(p(0.64, 0.66).dx, p(0.64, 0.66).dy),
    trim,
  );
  for (final fx in [0.25, 0.75]) {
    drawSuit(canvas, suit, Rect.fromCenter(center: p(fx, 0.9), width: w * 0.13, height: w * 0.13), fill(Colors.white.withValues(alpha: 0.9)));
  }

  // 목
  final neck = Rect.fromLTRB(p(0.42, 0).dx, p(0, headY + 0.12).dy, p(0.58, 0).dx, p(0, 0.68).dy);
  canvas.drawRect(neck, fill(const Color(0xFFE9BE95)));

  // 잭: 목 둘레 주름 깃
  if (isJ) {
    for (var i = 0; i < 7; i++) {
      final fx = 0.34 + i * 0.053;
      canvas.drawCircle(p(fx, 0.665), w * 0.04, fill(Colors.white));
      canvas.drawCircle(p(fx, 0.665), w * 0.04, stroke);
    }
  }

  // 수염(왕): 얼굴 아래쪽
  if (isK) {
    final beard = Path()
      ..moveTo(p(0.33, headY + 0.02).dx, p(0.33, headY + 0.02).dy)
      ..quadraticBezierTo(p(0.32, 0.66).dx, p(0.32, 0.66).dy, p(0.5, 0.7).dx, p(0.5, 0.7).dy)
      ..quadraticBezierTo(p(0.68, 0.66).dx, p(0.68, 0.66).dy, p(0.67, headY + 0.02).dx, p(0.67, headY + 0.02).dy)
      ..quadraticBezierTo(p(0.5, headY + 0.1).dx, p(0.5, headY + 0.1).dy, p(0.33, headY + 0.02).dx, p(0.33, headY + 0.02).dy)
      ..close();
    canvas.drawPath(beard, fill(cute ? Colors.white : _beard));
    canvas.drawPath(beard, stroke);
  }

  // 얼굴
  final head = Rect.fromCenter(center: p(0.5, headY), width: w * headW, height: h * headH);
  // 잭/왕의 머리카락(귀 옆)
  if (isJ || isK) {
    final hair = fill(isK ? (cute ? const Color(0xFFE0E0E8) : const Color(0xFFCFCBC0)) : (cute ? const Color(0xFFB07A48) : _hairDark));
    for (final fx in [0.5 - headW / 2 - 0.01, 0.5 + headW / 2 + 0.01]) {
      final o = Rect.fromCenter(center: p(fx, headY - 0.02), width: w * 0.12, height: h * 0.26);
      canvas.drawOval(o, hair);
      canvas.drawOval(o, stroke);
    }
  }
  canvas.drawOval(head, fill(_skin));
  canvas.drawOval(head, stroke);

  // 이목구비
  final eyeY = headY - 0.02;
  final eyeDx = headW * 0.22;
  if (cute) {
    for (final sx in [-1.0, 1.0]) {
      final e = p(0.5 + sx * eyeDx, eyeY + 0.03);
      canvas.drawOval(Rect.fromCenter(center: e, width: w * 0.075, height: h * 0.085), fill(_outline));
      canvas.drawCircle(e + Offset(-w * 0.012, -h * 0.014), w * 0.014, fill(Colors.white));
      canvas.drawCircle(p(0.5 + sx * (eyeDx + 0.1), eyeY + 0.12), w * 0.045, fill(const Color(0xFFFF9EAE).withValues(alpha: 0.7)));
    }
    canvas.drawArc(
      Rect.fromCenter(center: p(0.5, headY + 0.09), width: w * 0.12, height: h * 0.07),
      0.2,
      pi - 0.4,
      false,
      stroke,
    );
  } else {
    for (final sx in [-1.0, 1.0]) {
      final e = p(0.5 + sx * eyeDx, eyeY);
      canvas.drawOval(Rect.fromCenter(center: e, width: w * 0.055, height: h * 0.04), fill(_outline));
      canvas.drawLine(e + Offset(-w * 0.035, -h * 0.04), e + Offset(w * 0.035, -h * 0.04), stroke);
    }
    canvas.drawLine(p(0.5, eyeY + 0.03), p(0.5, eyeY + 0.1), Paint()
      ..strokeWidth = line
      ..color = const Color(0xFFC08F6A));
    if (isQ) {
      canvas.drawOval(Rect.fromCenter(center: p(0.5, headY + 0.1), width: w * 0.1, height: h * 0.035), fill(const Color(0xFFD83A4E)));
      for (final fx in [0.5 - headW / 2 - 0.0, 0.5 + headW / 2 + 0.0]) {
        canvas.drawCircle(p(fx, headY + 0.08), w * 0.025, fill(_gold));
      }
    } else if (!isK) {
      canvas.drawLine(p(0.46, headY + 0.1), p(0.54, headY + 0.1), stroke);
    }
  }
  // 왕의 콧수염
  if (isK) {
    for (final sx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: p(0.5 + sx * 0.06, headY + 0.08), width: w * 0.12, height: h * 0.05),
        fill(cute ? Colors.white : _beard),
      );
      canvas.drawOval(Rect.fromCenter(center: p(0.5 + sx * 0.06, headY + 0.08), width: w * 0.12, height: h * 0.05), stroke);
    }
  }

  // 왕관 / 티아라 / 모자
  if (isK || isQ) {
    final big = isK;
    final top = big ? 0.0 : 0.05;
    final baseY = headY - headH / 2 + 0.05;
    final cl = 0.5 - (big ? 0.19 : 0.16), cr = 0.5 + (big ? 0.19 : 0.16);
    final crown = Path()
      ..moveTo(p(cl, baseY).dx, p(cl, baseY).dy)
      ..lineTo(p(cl - 0.01, top + 0.06).dx, p(cl - 0.01, top + 0.06).dy)
      ..lineTo(p(cl + 0.1, top + 0.14).dx, p(cl + 0.1, top + 0.14).dy)
      ..lineTo(p(0.5, top).dx, p(0.5, top).dy)
      ..lineTo(p(cr - 0.1, top + 0.14).dx, p(cr - 0.1, top + 0.14).dy)
      ..lineTo(p(cr + 0.01, top + 0.06).dx, p(cr + 0.01, top + 0.06).dy)
      ..lineTo(p(cr, baseY).dx, p(cr, baseY).dy)
      ..close();
    canvas.drawPath(crown, fill(_gold));
    canvas.drawPath(crown, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..strokeJoin = StrokeJoin.round
      ..color = _goldDark);
    // 보석
    canvas.drawCircle(p(0.5, top + 0.1), w * 0.03, fill(const Color(0xFFD83A4E)));
    canvas.drawCircle(p(cl + 0.04, baseY - 0.03), w * 0.022, fill(const Color(0xFF3E7BFA)));
    canvas.drawCircle(p(cr - 0.04, baseY - 0.03), w * 0.022, fill(const Color(0xFF3E7BFA)));
    for (final fx in [cl - 0.01, 0.5, cr + 0.01]) {
      canvas.drawCircle(p(fx, fx == 0.5 ? top : top + 0.06), w * 0.022, fill(Colors.white));
    }
  } else {
    // 잭: 깃털 달린 모자
    final hatC = p(0.5, headY - headH / 2 + 0.03);
    final hat = Rect.fromCenter(center: hatC, width: w * 0.6, height: h * 0.26);
    canvas.drawOval(hat, fill(robe));
    canvas.drawOval(hat, stroke);
    canvas.drawLine(hatC + Offset(-w * 0.28, h * 0.02), hatC + Offset(w * 0.28, h * 0.02), Paint()
      ..strokeWidth = max(0.8, w * 0.04)
      ..strokeCap = StrokeCap.round
      ..color = _gold);
    final feather = Path()
      ..moveTo(p(0.62, 0.14).dx, p(0.62, 0.14).dy)
      ..cubicTo(p(0.8, -0.05).dx, p(0.8, -0.05).dy, p(1.0, 0.05).dx, p(1.0, 0.05).dy, p(0.92, 0.22).dx, p(0.92, 0.22).dy)
      ..cubicTo(p(0.86, 0.16).dx, p(0.86, 0.16).dy, p(0.76, 0.18).dx, p(0.76, 0.18).dy, p(0.62, 0.14).dx, p(0.62, 0.14).dy)
      ..close();
    canvas.drawPath(feather, fill(cute ? const Color(0xFFFFFFFF) : const Color(0xFFFFFAF0)));
    canvas.drawPath(feather, stroke);
  }
}

/// 에이스: 큰 무늬를 장식 고리와 점으로 꾸민다 (스페이드 에이스는 더 화려하게).
void drawAceFancy(Canvas canvas, Size size, int suit, Color color, CardStyle style) {
  final w = size.width, h = size.height;
  final c = Offset(w * 0.5, h * 0.5);
  final cute = style == CardStyle.cute;
  final spade = suit == 3;
  final s = w * (spade ? 0.56 : 0.5);

  // 장식 고리와 점
  final ringR = w * 0.4;
  canvas.drawCircle(
    c,
    ringR,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.012)
      ..color = color.withValues(alpha: 0.45),
  );
  canvas.drawCircle(
    c,
    ringR - w * 0.035,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.006)
      ..color = color.withValues(alpha: 0.3),
  );
  for (var i = 0; i < 20; i++) {
    final a = i * 2 * pi / 20;
    canvas.drawCircle(c + Offset(cos(a), sin(a)) * (ringR + w * 0.03), w * 0.011, Paint()..color = color.withValues(alpha: 0.5));
  }
  if (spade) {
    // 위아래의 장식 별
    for (final dy in [-1.0, 1.0]) {
      final sc = c + Offset(0, dy * h * 0.36);
      final r = w * 0.05;
      canvas.drawPath(
        Path()
          ..moveTo(sc.dx, sc.dy - r)
          ..quadraticBezierTo(sc.dx, sc.dy, sc.dx + r, sc.dy)
          ..quadraticBezierTo(sc.dx, sc.dy, sc.dx, sc.dy + r)
          ..quadraticBezierTo(sc.dx, sc.dy, sc.dx - r, sc.dy)
          ..quadraticBezierTo(sc.dx, sc.dy, sc.dx, sc.dy - r),
        Paint()..color = color.withValues(alpha: 0.8),
      );
    }
  }

  final rect = Rect.fromCenter(center: c, width: s, height: s);
  drawSuit(canvas, suit, rect, Paint()..color = color);
  // 새긴 듯한 안쪽 하이라이트
  drawSuit(
    canvas,
    suit,
    Rect.fromCenter(center: c + Offset(-s * 0.1, -s * 0.12), width: s * 0.42, height: s * 0.42),
    Paint()..color = Colors.white.withValues(alpha: 0.22),
  );

  if (cute) {
    // 귀여운 얼굴
    final eyeY = c.dy - s * 0.02;
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(c.dx + sx * s * 0.16, eyeY);
      canvas.drawOval(Rect.fromCenter(center: e, width: s * 0.1, height: s * 0.13), Paint()..color = Colors.white);
      canvas.drawCircle(e + Offset(0, s * 0.01), s * 0.04, Paint()..color = const Color(0xFF2B2D42));
      canvas.drawCircle(Offset(c.dx + sx * s * 0.28, eyeY + s * 0.1), s * 0.05, Paint()..color = const Color(0xFFFF9EAE).withValues(alpha: 0.8));
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(c.dx, eyeY + s * 0.1), width: s * 0.2, height: s * 0.12),
      0.2,
      pi - 0.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, s * 0.035)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }
}
