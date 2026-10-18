part of 'stage_painter.dart';

/// cues 조각 (화면 코드를 역할별로 나눈 파일)
extension _SpCues on StagePainter {
  // ── 안내 링: 실제로 엄지가 닿을 화면 양옆 아래쪽에서 줄어든다 ──
  void _drawRing(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final pt = Offset(size.width * (cue.side == Side.left ? 0.12 : 0.88), size.height * (L.landscape ? 0.74 : 0.78));
    final u = L.unit;
    final r = cue.remain.clamp(0.0, 1.0);
    final ring = u * (0.2 + 0.45 * r);
    // 꾹 누르기: 누를 때는 금색, 떼야 할 때는 주황색 링
    final ringColor = cue.releasing ? const Color(0xFFFF7A2F) : _gold;
    final centerColor = cue.releasing ? const Color(0xFFFF4D5E) : (cue.isHold ? const Color(0xFF5AA7FF) : const Color(0xFFFF4D5E));
    canvas.drawCircle(pt, u * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.drawCircle(pt, u * 0.2, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.035..color = kInk);
    canvas.drawCircle(pt, u * 0.08, Paint()..color = centerColor);
    canvas.drawCircle(pt, u * 0.08, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.025..color = kInk);
    canvas.drawCircle(pt, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
    canvas.drawCircle(pt, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = ringColor);
    if (cue.isHold) {
      _sticker(canvas, cue.releasing ? '떼!' : '꾹', pt + Offset(0, -u * 0.42), u * 0.17, cue.releasing ? const Color(0xFFFF9A4D) : const Color(0xFF9CCBFF));
    }
  }

  // ── 옆으로 긋기 안내: 시작점에서 링이 줄어든 뒤, 구슬이 화살표를 따라 달려가 끝에 닿는 순간이 박자 ──
  void _drawSwipeGuide(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final u = L.unit;
    final y = size.height * (L.landscape ? 0.74 : 0.78);
    final toRight = cue.side == Side.right;
    final startX = size.width * (toRight ? 0.2 : 0.8);
    final endX = size.width * (toRight ? 0.8 : 0.2);
    final dirX = toRight ? 1.0 : -1.0;
    final start = Offset(startX, y);
    final end = Offset(endX, y);

    // 화살표 띠: 바깥 검은 선 + 안쪽 흰 선 + 끝의 화살촉
    final head = u * 0.16;
    final bodyEnd = Offset(endX - dirX * head * 0.7, y);
    final band = Path()..moveTo(startX, y)..lineTo(bodyEnd.dx, y);
    final tip = Path()
      ..moveTo(endX, y)
      ..lineTo(endX - dirX * head, y - head * 0.7)
      ..lineTo(endX - dirX * head, y + head * 0.7)
      ..close();
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.115..strokeCap = StrokeCap.round..color = kInk);
    canvas.drawPath(tip, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeJoin = StrokeJoin.round..color = kInk);
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawPath(tip, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // 시작점 + 줄어드는 링 (remain 1 → 0.35), 그 뒤 구슬이 끝까지 달린다 (0.35 → 0)
    const run = 0.35;
    final ringK = ((cue.remain - run) / (1 - run)).clamp(0.0, 1.0);
    final travel = Curves.easeIn.transform((1 - cue.remain / run).clamp(0.0, 1.0));
    canvas.drawCircle(start, u * 0.15, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.drawCircle(start, u * 0.15, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    if (ringK > 0) {
      final ring = u * (0.15 + 0.45 * ringK);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = const Color(0xFF5AD7FF));
    }
    final dot = Offset.lerp(start, end, travel)!;
    canvas.drawCircle(dot, u * 0.1, Paint()..color = const Color(0xFF5AD7FF));
    canvas.drawCircle(dot, u * 0.1, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    _sticker(canvas, '쓱!', Offset(size.width * 0.5, y - u * 0.34), u * 0.17, const Color(0xFF8BE3FF));
  }

  // ── 힘 모으기: 칼끝에 에너지 구슬이 커지고, 빛 알갱이가 빨려 든다 ──
  void _drawCharge(Canvas canvas, CampLayout L, int actor, Offset foot, bool mirror, double charge, double idle) {
    final name = RhythmArt.actorSprite(actor, 'windup');
    final info = art.info(name);
    if (info == null || info.tipX == null || info.tipY == null) return;
    final sc = L.charScale * info.scale;
    var dx = (info.tipX! - info.footX) * sc;
    final dy = (info.tipY! - info.footY) * sc;
    if (mirror) dx = -dx;
    final tip = foot + Offset(dx, dy);
    final u = L.unit;
    final ready = charge >= 0.98;
    final pulse = ready ? 1 + 0.15 * sin(idle * 30) : 1.0;
    final r = u * (0.04 + 0.11 * charge) * pulse;
    // 바깥 빛무리
    canvas.drawCircle(tip, r * 2.2, Paint()..color = _gold.withValues(alpha: 0.28 + 0.2 * charge));
    canvas.drawCircle(tip, r * 1.4, Paint()..color = _gold.withValues(alpha: 0.55));
    canvas.drawCircle(tip, r, Paint()..color = Colors.white);
    canvas.drawCircle(tip, r, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.02..color = kInk);
    // 빨려 드는 알갱이
    for (var k = 0; k < 8; k++) {
      final f = (idle * 1.4 + k / 8) % 1.0;
      final a = k * pi / 4 + idle * 2;
      final dist = u * 0.38 * (1 - f) + r * 0.6;
      final pos = tip + Offset(cos(a) * dist, sin(a) * dist);
      final sz = u * 0.018 * (0.4 + f);
      canvas.drawCircle(pos, sz, Paint()..color = (k.isEven ? Colors.white : _gold).withValues(alpha: 0.4 + 0.6 * f));
    }
    if (ready) {
      canvas.drawCircle(tip, r * 2.6, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.025..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  // ── 판정 글자: 스티커처럼 통통 튀며 떠오른다 ──
  void _drawPop(Canvas canvas, CampLayout L, RatingPop p, double t) {
    final age = t - p.at;
    if (age < 0 || age > 1.0) return;
    final k = age / 1.0;
    final u = L.unit;
    final (word, color) = switch (p.rating) {
      Rating.perfect => (p.guard ? '완벽 방어!' : '완벽!', _gold),
      Rating.good => (p.guard ? '막았다!' : '좋아요', const Color(0xFF8CFF9E)),
      Rating.miss => (p.guard ? '당했다!' : '놓쳤어요', p.guard ? const Color(0xFFFF8A8A) : const Color(0xFFE0E0E0)),
      Rating.wrongSide => ('반대쪽!', const Color(0xFFFF6B6B)),
      Rating.stray => ('앗!', const Color(0xFFE0E0E0)),
      Rating.holdStart => ('', _gold),
    };
    final pop = k < 0.16 ? 0.5 + 0.7 * Curves.easeOutBack.transform(k / 0.16) : 1.2 - 0.2 * ((k - 0.16) / 0.84).clamp(0.0, 1.0);
    final alpha = k < 0.7 ? 1.0 : 1 - (k - 0.7) / 0.3;
    final center = Offset(L.actorX(3), L.feetY - u * (1.12 + 0.1 * k));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((p.side == Side.left ? -1 : 1) * 0.05);
    _sticker(canvas, word, Offset.zero, u * 0.22 * pop, color, alpha: alpha);
    canvas.restore();
  }

  /// 두꺼운 검은 외곽선 + 그림자 + 쨍한 색 글자.
  void _sticker(Canvas canvas, String s, Offset center, double size, Color color, {double alpha = 1}) {
    TextPainter make(Paint? stroke, Color? fill) => TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1.0,
              foreground: stroke,
              color: fill,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final outline = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.24
        ..strokeJoin = StrokeJoin.round
        ..color = kInk.withValues(alpha: alpha),
      null,
    );
    final shadow = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.24
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.28 * alpha),
      null,
    );
    final fill = make(null, color.withValues(alpha: color.a * alpha));
    final o = center - Offset(outline.width / 2, outline.height / 2);
    shadow.paint(canvas, o + Offset(size * 0.05, size * 0.09));
    outline.paint(canvas, o);
    fill.paint(canvas, center - Offset(fill.width / 2, fill.height / 2));
  }
}
