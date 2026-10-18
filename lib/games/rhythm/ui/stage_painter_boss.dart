part of 'stage_painter.dart';

/// boss 조각 (화면 코드를 역할별로 나눈 파일)
extension _SpBoss on StagePainter {
  // 보스는 항상 검사들보다 뒤(아래)에 그린다: 검사들이 플레이어와 더 가까우니 덮쳐 와도 검사들이 위에 보인다.
  void _drawBoss(Canvas canvas, CampLayout L, double t, double idle) {
    final st = t < 0 ? const BossState(BossPhase.idle, 0) : c.bossState(t);
    final u = L.unit;
    final scale = L.foeScale(foe);
    final bodyH = L.foeBodyHeight(foe);
    final home = Offset(L.size.width * 0.5, L.dummyBaseY + u * 0.1);
    final player = Offset(L.actorX(3), L.feetY - u * 0.45);
    var pos = home;
    var kind = 'idle';
    var mirror = false;
    var grow = 1.0;
    var rotate = 0.0;
    var flash = 0.0;
    final breathe = sin(idle * 2.4);
    var squashX = 1 - 0.02 * breathe;
    var squashY = 1 + 0.03 * breathe;
    final p = st.progress;
    int? hitActor;
    SwingState? hit;

    switch (st.phase) {
      case BossPhase.windup:
        // 세 박 동안 점점 커지고 부르르 떨며 붉게 달아오른다
        kind = 'ready';
        grow = 1 + 0.12 * p;
        pos += Offset(sin(idle * 55) * u * 0.014 * p, 0);
        squashY = 1 + 0.05 * p * sin(idle * 18);
      case BossPhase.lunge:
        kind = 'attack';
        final e = Curves.easeIn.transform(p);
        pos = Offset.lerp(home, player, 0.85 * e)!;
        grow = 1.12 + 0.3 * e;
      case BossPhase.slam:
        // 막지 못했다: 내려찍은 채 있다가 천천히 제자리로
        final e = Curves.easeOut.transform(p);
        kind = p < 0.5 ? 'attack' : 'idle';
        pos = Offset.lerp(Offset.lerp(home, player, 0.85)!, home, e)!;
        grow = 1.42 - 0.42 * e;
        squashY = 1 - 0.1 * (1 - e);
      case BossPhase.blocked:
        // 막혔다: 튕겨 나며 비틀거린다
        kind = 'hit';
        pos = home + Offset(0, -u * 0.14 * sin(pi * min(1.0, p * 1.3)));
        grow = 1.12 - 0.12 * p;
        rotate = 0.18 * exp(-5 * p) * cos(20 * p);
        flash = (1 - p / 0.2).clamp(0.0, 1.0);
      case BossPhase.idle:
        // 가만히 있을 때: 가장 최근에 맞은 공격에 반응한다
        for (var i = 0; i < 4; i++) {
          final sw = c.swing(i, t);
          if (sw == null || sw.guard || sw.sinceImpact < 0 || sw.sinceImpact >= 0.45) continue;
          if (hit == null || sw.sinceImpact < hit.sinceImpact) {
            hit = sw;
            hitActor = i;
          }
        }
        if (hit != null) {
          final s = hit.sinceImpact;
          final dir = hit.side == Side.right ? 1.0 : -1.0;
          kind = 'hit';
          mirror = hit.side == Side.left; // 그림은 오른쪽에서 맞는 모습이라, 왼쪽에서 맞으면 뒤집는다
          rotate = dir * 0.1 * exp(-5 * s) * cos(22 * s);
          squashX = 1 - 0.08 * exp(-9 * s) * cos(30 * s);
          squashY = 1 + 0.1 * exp(-9 * s) * cos(30 * s);
          pos += Offset(-dir * u * 0.04 * exp(-7 * s), 0);
          flash = (1 - s / 0.12).clamp(0.0, 1.0);
        }
    }

    final center = pos + Offset(0, -bodyH * grow * 0.5);
    if (st.phase == BossPhase.windup && p > 0.05) {
      // 달아오르는 붉은 기운
      final r = bodyH * grow * (0.75 + 0.1 * sin(idle * 12));
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = RadialGradient(colors: [const Color(0xFFFF2D3D).withValues(alpha: 0.38 * p), const Color(0x00FF2D3D)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, RhythmArt.foeSprite(foe, kind, red: true), pos, scale * grow,
        mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: paint);
    if (st.phase == BossPhase.windup && p > 0.3) {
      // 머리 위의 경고 표시
      final pop = 1 + 0.15 * sin(idle * 16);
      _sticker(canvas, '!!', Offset(home.dx, home.dy - bodyH * 1.1), u * 0.3 * pop, const Color(0xFFFF4D5E));
    }
    if (hit != null && hitActor != null) {
      final dir = hit.side == Side.right ? 1.0 : -1.0;
      final from = Offset(L.actorX(hitActor), L.feetY - u * 0.3);
      _drawSlash(canvas, L, home, dir, center.dy, u * 0.3, hit.sinceImpact, origin: from);
      if (hit.sinceImpact <= 0.5) {
        _drawDebris(canvas, L, hitActor, hit, center + Offset(dir * u * 0.3, 0),
            colors: const [Color(0xFFE5484D), Color(0xFFFFC2C4)], count: 6, round: true);
      }
    }
  }

  /// 막지 못해 맞은 뒤 얼마나 아파하는지 1(막 맞음)→0.
  double _hurtAmount(double t) {
    var best = 0.0;
    for (final g in c.chart.guards) {
      final o = c.guardOutcome(g);
      if (o == null || o.blocked) continue;
      final dt = t - o.at;
      if (dt >= 0 && dt < 0.5) best = max(best, 1 - dt / 0.5);
    }
    return best;
  }

  /// 막았을 때: 검 끝에서 푸른 방어 막이 퍼지며 터진다.
  void _drawGuardEffect(Canvas canvas, CampLayout L, double t) {
    final ga = c.lastGuardAt;
    if (ga == null || t < 0) return;
    final age = t - ga;
    if (age < 0 || age > 0.55) return;
    final blocked = c.chart.guards.any((g) {
      final o = c.guardOutcome(g);
      return o != null && o.blocked && (o.at - ga).abs() < 0.02;
    });
    if (!blocked) return;
    final u = L.unit;
    final k = age / 0.55;
    final e = Curves.easeOut.transform(k);
    final center = Offset(L.actorX(3), L.feetY - u * 1.05);
    final fade = 1 - k;
    for (final (radius, width, color) in [
      (0.22 + 0.5 * e, 0.07 * fade, const Color(0xFF9CE7FF)),
      (0.12 + 0.34 * e, 0.045 * fade, Colors.white),
    ]) {
      canvas.drawCircle(center, u * radius, Paint()..style = PaintingStyle.stroke..strokeWidth = u * width + 1..color = color.withValues(alpha: fade));
    }
    for (var n = 0; n < 8; n++) {
      final a = n * pi / 4 + 0.3;
      final d0 = u * (0.3 + 0.35 * e);
      final d1 = u * (0.45 + 0.55 * e);
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * d0,
        center + Offset(cos(a), sin(a)) * d1,
        Paint()..color = _gold.withValues(alpha: fade)..strokeWidth = u * 0.03 * fade + 1..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── 막기 안내: 시작점에서 링이 줄어든 뒤, 구슬이 위로 달려가 끝에 닿는 순간이 박자 ──
  void _drawGuardGuide(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final u = L.unit;
    final x = size.width * 0.5;
    final startY = size.height * (L.landscape ? 0.9 : 0.93);
    final endY = size.height * (L.landscape ? 0.5 : 0.55);
    final start = Offset(x, startY);
    final end = Offset(x, endY);
    const accent = Color(0xFFFF9A4D);

    final head = u * 0.16;
    final bodyEnd = Offset(x, endY + head * 0.7);
    final band = Path()..moveTo(x, startY)..lineTo(bodyEnd.dx, bodyEnd.dy);
    final tip = Path()
      ..moveTo(x, endY)
      ..lineTo(x - head * 0.75, endY + head)
      ..lineTo(x + head * 0.75, endY + head)
      ..close();
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.115..strokeCap = StrokeCap.round..color = kInk);
    canvas.drawPath(tip, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeJoin = StrokeJoin.round..color = kInk);
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawPath(tip, Paint()..color = Colors.white.withValues(alpha: 0.85));

    const run = 0.35;
    final ringK = ((cue.remain - run) / (1 - run)).clamp(0.0, 1.0);
    final travel = Curves.easeIn.transform((1 - cue.remain / run).clamp(0.0, 1.0));
    canvas.drawCircle(start, u * 0.15, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.drawCircle(start, u * 0.15, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    if (ringK > 0) {
      final ring = u * (0.15 + 0.45 * ringK);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = accent);
    }
    final dot = Offset.lerp(start, end, travel)!;
    canvas.drawCircle(dot, u * 0.1, Paint()..color = accent);
    canvas.drawCircle(dot, u * 0.1, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    _sticker(canvas, '막아!', Offset(x + u * 0.62, (startY + endY) / 2), u * 0.2, const Color(0xFFFFC38A));
  }

  /// 보스가 힘을 모으는 동안 화면 가장자리가 붉게 달아오르고, 하트를 잃으면 한 번 번쩍인다.
  void _drawBossWarning(Canvas canvas, Size size, double t, double idle) {
    final st = c.bossState(t);
    var a = 0.0;
    if (st.phase == BossPhase.windup) {
      a = (0.12 + 0.3 * st.progress) * (0.75 + 0.25 * sin(idle * 14));
    } else if (st.phase == BossPhase.lunge) {
      a = 0.5;
    }
    if (a > 0.01) {
      final w = size.width * 0.28;
      for (final left in [true, false]) {
        final rect = Rect.fromLTWH(left ? 0 : size.width - w, 0, w, size.height);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [const Color(0xFFFF2D3D).withValues(alpha: a), const Color(0x00FF2D3D)],
            ).createShader(rect),
        );
      }
    }
    final lost = t - c.heartLostAt;
    if (lost >= 0 && lost < 0.3) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF2D3D).withValues(alpha: 0.28 * (1 - lost / 0.3)));
    }
  }

  // ── 화면 가장자리 빛: 탭할 쪽 알려주기 ──
  void _drawEdgeGlow(Canvas canvas, Size size, double remain, Side side) {
    final a = (1 - remain.clamp(0.0, 1.0)) * 0.5;
    if (a <= 0.02) return;
    final w = size.width * 0.3;
    final isLeft = side == Side.left;
    final rect = Rect.fromLTWH(isLeft ? 0 : size.width - w, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }
}
