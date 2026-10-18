part of 'win_celebration.dart';

/// draw 조각 (화면 코드를 역할별로 나눈 파일)
extension WinCelebrationDraw on WinCelebration {
  void paint(Canvas canvas, Size size) {
    final cw = cardSize.width, ch = cardSize.height;

    // 지워지지 않는 잔상 (튀는 카드가 지나간 자리)
    final acc = _acc;
    if (acc != null) {
      canvas.drawImageRect(
        acc,
        Rect.fromLTWH(0, 0, acc.width.toDouble(), acc.height.toDouble()),
        Offset.zero & view,
        Paint()..filterQuality = FilterQuality.low,
      );
    }

    // 카드와 짧은 잔상
    for (final f in _flyers) {
      if (!f.launched) continue;
      for (var i = 0; i < f.trail.length; i++) {
        final t = (i + 1) / f.trail.length;
        final g = f.trail[i];
        _drawCardAt(canvas, f.card, g.$1, g.$2, g.$3, g.$4, 0.38 * t * t * (f.gone ? 1 : f.alpha));
      }
      if (!f.gone) _drawCardAt(canvas, f.card, f.x + cw / 2, f.y + ch / 2, f.scale, f.rot, f.alpha);
    }

    // 폭발 고리
    for (final r in _rings) {
      final t = r.age / 0.55;
      canvas.drawCircle(
        Offset(r.x, r.y),
        r.maxRadius * Curves.easeOut.transform(t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cw * 0.12 * (1 - t) + 1
          ..color = r.color.withValues(alpha: (1 - t) * 0.9),
      );
    }

    // 입자
    for (final p in _particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: min(1, a * 1.6));
      switch (p.kind) {
        case 0:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
          canvas.restore();
        case 1:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          final r = p.size;
          canvas.drawPath(
            Path()
              ..moveTo(0, -r)
              ..quadraticBezierTo(0, 0, r, 0)
              ..quadraticBezierTo(0, 0, 0, r)
              ..quadraticBezierTo(0, 0, -r, 0)
              ..quadraticBezierTo(0, 0, 0, -r),
            paint,
          );
          canvas.restore();
        default:
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x - p.vx * 0.05, p.y - p.vy * 0.05),
            paint
              ..strokeWidth = p.size
              ..strokeCap = StrokeCap.round,
          );
      }
    }

    // 섬광
    if (_flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: _flash.clamp(0.0, 0.7)));
    }

    // "클리어!"
    final bt = ((time - 0.5) / 0.55).clamp(0.0, 1.0);
    if (bt > 0) {
      final pulse = 1 + 0.035 * sin(time * 5);
      final s = Curves.easeOutBack.transform(bt) * pulse;
      final (outline, fill) = _banner;
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.36);
      canvas.rotate(-0.06 + 0.02 * sin(time * 3));
      canvas.scale(s);
      final off = Offset(-outline.width / 2, -outline.height / 2);
      outline.paint(canvas, off);
      fill.paint(canvas, off);
      canvas.restore();
    }

    // 눌러서 건너뛸 수 있다는 안내
    final ht = ((time - 4) / 1.0).clamp(0.0, 1.0);
    if (ht > 0) {
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height - 34),
          width: _skipHint.width + 32,
          height: _skipHint.height + 16,
        ),
        const Radius.circular(20),
      );
      canvas.drawRRect(pill, Paint()..color = Colors.black.withValues(alpha: 0.5 * ht));
      canvas.saveLayer(pill.outerRect, Paint()..color = Colors.white.withValues(alpha: ht));
      _skipHint.paint(canvas, Offset(pill.left + 16, pill.top + 8));
      canvas.restore();
    }
  }

  void _drawCardAt(Canvas canvas, int card, double cx, double cy, double scale, double rot, double alpha) {
    if (alpha <= 0.01) return;
    final cw = cardSize.width, ch = cardSize.height;
    canvas.save();
    canvas.translate(cx, cy);
    if (rot != 0) canvas.rotate(rot);
    canvas.scale(scale);
    final image = _images[card];
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(-cw / 2, -ch / 2, cw, ch),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    } else {
      canvas.translate(-cw / 2, -ch / 2);
      drawCard(canvas, card, cardSize);
    }
    canvas.restore();
  }
}
