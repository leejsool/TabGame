part of 'stage_painter.dart';

/// actors 조각 (화면 코드를 역할별로 나눈 파일)
extension _SpActors on StagePainter {
  // ── 허수아비: 맞으면 그쪽으로 기울며 흔들리고, 번쩍인다 ──
  void _drawDummy(Canvas canvas, CampLayout L, int i, SwingState? sw) {
    final base = Offset(L.actorX(i), L.dummyBaseY);
    final centerY = base.dy - L.dummyHeight * 0.58;
    var rotate = 0.0;
    var squashY = 1.0;
    var flash = 0.0;
    if (sw != null && sw.sinceImpact >= 0 && sw.sinceImpact < 0.7) {
      final s = sw.sinceImpact;
      final dir = sw.side == Side.right ? 1.0 : -1.0;
      rotate = dir * 0.24 * exp(-4.5 * s) * cos(24 * s);
      squashY = 1 - 0.05 * exp(-10 * s);
      flash = (1 - s / 0.13).clamp(0.0, 1.0);
    }
    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, 'dummy', base, L.dummyScale, rotate: rotate, squashY: squashY, paint: paint);

    if (sw == null || sw.sinceImpact < 0 || sw.sinceImpact > 0.5) return;
    final s = sw.sinceImpact;
    final dir = sw.side == Side.right ? 1.0 : -1.0;
    final player = i == 3;

    _drawSlash(canvas, L, base, dir, centerY, L.dummyHeight * 0.1, s);

    // 맞은 자리의 충격 별
    if (s < 0.17) {
      final kk = s / 0.17;
      final r = L.unit * (0.12 + 0.2 * Curves.easeOut.transform(kk)) * (player ? 1.0 : 0.8);
      final star = Path();
      const spikes = 9;
      final c0 = Offset(base.dx + dir * L.dummyHeight * 0.12, centerY);
      for (var k = 0; k < spikes * 2; k++) {
        final a = -pi + (2 * pi * k / (spikes * 2));
        final rr = k.isEven ? r : r * 0.48;
        final o = c0 + Offset(cos(a) * rr, sin(a) * rr);
        k == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = _gold.withValues(alpha: 1 - kk * 0.6));
      canvas.drawPath(star, Paint()..style = PaintingStyle.stroke..strokeWidth = L.unit * 0.025..strokeJoin = StrokeJoin.round..color = kInk.withValues(alpha: 1 - kk));
    }

    // 나무 조각 (포물선)
    _drawDebris(canvas, L, i, sw, Offset(base.dx + dir * L.dummyHeight * 0.1, centerY),
        colors: const [Color(0xFFE9B96E), Color(0xFFC9482F)], count: 7, round: false);
  }

  // ── 슬라임: 숨 쉬듯 말랑거리다가, 칼이 올라오면 깜짝 놀라고, 맞으면 찌그러지며 튕겨 난다 ──
  void _drawSlime(Canvas canvas, CampLayout L, int i, SwingState? sw, double t, double idle, {bool red = false}) {
    final base = Offset(L.actorX(i), L.dummyBaseY);
    final scale = L.slimeScale;
    final centerY = base.dy - 346 * scale * 0.5;
    var kind = 'idle';
    var mirror = false;
    var offset = Offset.zero;
    var rotate = 0.0;
    final breathe = sin(idle * 3.2 + i * 1.3);
    var squashX = 1 - 0.025 * breathe;
    var squashY = 1 + 0.035 * breathe;
    var flash = 0.0;
    var dir = 1.0;

    if (sw != null && sw.sinceImpact >= 0 && sw.sinceImpact < 0.45) {
      // 맞았다: 칼 맞은 쪽 반대로 튕기며 찌그러졌다 돌아온다
      final s = sw.sinceImpact;
      kind = 'hit';
      mirror = sw.side == Side.left;
      dir = sw.side == Side.right ? 1.0 : -1.0;
      rotate = dir * 0.14 * exp(-5 * s) * cos(22 * s);
      squashX = 1 - 0.1 * exp(-9 * s) * cos(30 * s);
      squashY = 1 + 0.12 * exp(-9 * s) * cos(30 * s);
      offset = Offset(-dir * L.unit * 0.05 * exp(-7 * s), 0);
      flash = (1 - s / 0.12).clamp(0.0, 1.0);
    } else if (sw != null && (sw.sinceImpact < 0 || sw.charge != null)) {
      // 칼이 올라온다: 깜짝 놀라 부르르 떤다
      kind = 'ready';
      squashY = 1.04;
      offset = Offset(sin(idle * 60) * L.unit * 0.004, 0);
    } else if (i == 3 && c.pops.isNotEmpty) {
      // 내가 놓치면 내 앞의 슬라임이 덤벼든다
      final p = c.pops.last;
      final age = t - p.at;
      if ((p.rating == Rating.miss || p.rating == Rating.wrongSide) && age >= 0 && age < 0.45) {
        final k = age / 0.45;
        final lunge = sin(pi * k);
        kind = 'attack';
        mirror = p.side == Side.left;
        offset = Offset((mirror ? -1 : 1) * L.unit * 0.18 * lunge, -L.unit * 0.07 * lunge);
        squashX = 1 + 0.05 * lunge;
        squashY = 1 - 0.04 * lunge;
      }
    }

    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, RhythmArt.slimeSprite(kind, red: red), base + offset, scale,
        mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: paint);

    if (kind != 'hit' || sw == null || sw.sinceImpact > 0.5) return;
    _drawSlash(canvas, L, base, dir, centerY, L.unit * 0.18, sw.sinceImpact);
    _drawDebris(canvas, L, i, sw, Offset(base.dx + dir * L.unit * 0.18, centerY),
        colors: red ? const [Color(0xFFE5484D), Color(0xFFFFC2C4)] : const [Color(0xFF63B6FA), Color(0xFFBFE3FF)], count: 6, round: true);
  }

  /// 칼바람: 검사 쪽에서 맞는 자리로 날아가는 흰 줄.
  void _drawSlash(Canvas canvas, CampLayout L, Offset base, double dir, double centerY, double reach, double s, {Offset? origin}) {
    if (s >= 0.1) return;
    final k = s / 0.1;
    final from = origin ?? Offset(base.dx + dir * L.unit * 0.1, L.feetY - L.unit * 0.25);
    final to = Offset(base.dx + dir * reach, centerY);
    final head = Offset.lerp(from, to, Curves.easeOut.transform(k))!;
    final tail = Offset.lerp(from, to, max(0.0, Curves.easeOut.transform(k) - 0.3))!;
    canvas.drawLine(tail, head, Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = L.unit * 0.05..strokeCap = StrokeCap.round);
  }

  /// 맞은 자리에서 포물선으로 흩어지는 조각들 (나무 조각 / 물방울).
  void _drawDebris(Canvas canvas, CampLayout L, int i, SwingState sw, Offset c0, {required List<Color> colors, required int count, required bool round}) {
    final s = sw.sinceImpact;
    final dir = sw.side == Side.right ? 1.0 : -1.0;
    final rng = Random(i * 31 + sw.side.index);
    final k = (s / 0.5).clamp(0.0, 1.0);
    for (var n = 0; n < count; n++) {
      final ang = -pi * (0.1 + 0.8 * rng.nextDouble()) + dir * 0.4;
      final sp = L.unit * (0.5 + 0.7 * rng.nextDouble());
      final pos = c0 + Offset(cos(ang) * sp * s, sin(ang) * sp * s + L.unit * 2.2 * s * s);
      final sz = L.unit * (0.014 + 0.016 * rng.nextDouble());
      final paint = Paint()..color = colors[n.isEven ? 0 : 1].withValues(alpha: 1 - k);
      if (round) {
        canvas.drawCircle(pos, sz * 1.3, paint);
        continue;
      }
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(s * (6 + n * 3));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 1.3), paint);
      canvas.restore();
    }
  }
}
