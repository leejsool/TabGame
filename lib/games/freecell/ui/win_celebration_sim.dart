part of 'win_celebration.dart';

/// sim 조각 (화면 코드를 역할별로 나눈 파일)
extension WinCelebrationSim on WinCelebration {
  void update(double dt) {
    time += dt;
    final cw = cardSize.width, ch = cardSize.height;
    final floor = view.height - ch;
    final g = ch * 3.6; // 윈도우처럼 느릿한 포물선
    final gBurst = ch * 6.0;
    if (_flash > 0) _flash = max(0, _flash - dt * 1.6);

    for (final f in List.of(_flyers)) {
      if (f.gone) {
        // 사라진 뒤에도 잔상은 천천히 걷힌다
        if (f.trail.isNotEmpty) {
          f.trail.removeAt(0);
        } else {
          _flyers.remove(f);
        }
        continue;
      }
      if (time < f.launchAt) continue;
      if (!f.launched) {
        f.launched = true;
        _sparkle(f.x + cw / 2, f.y + ch / 2, suitOf(f.card), 8, 0.6);
      }
      f.age += dt;
      switch (f.mode) {
        case _Mode.bounce:
          f.vy += g * dt;
          f.x += f.vx * dt;
          f.y += f.vy * dt;
          if (f.y > floor) {
            f.y = floor;
            f.vy = -f.vy * 0.82;
            if (f.vy.abs() < ch * 0.5) f.vy = -ch * 0.95;
            _sparkle(f.x + cw / 2, f.y + ch, suitOf(f.card), 4, 0.35, upward: true);
          }
          if (_accOk) _stampAlong(f);
          if (f.x < -cw * 1.5 || f.x > view.width + cw * 0.5) f.gone = true;
        case _Mode.burst:
          f.vy += gBurst * dt;
          f.x += f.vx * dt;
          f.y += f.vy * dt;
          f.rot += f.spin * dt;
          if (f.age > 0.4 && f.vy > 0) {
            _explode(f.x + cw / 2, f.y + ch / 2, suitOf(f.card), big: false);
            f.gone = true;
          }
        case _Mode.zoom:
          const dur = 1.15;
          final t = (f.age / dur).clamp(0.0, 1.0);
          final p = t * t * (3 - 2 * t) * 0.35 + t * t * t * 0.65; // 처음엔 천천히, 갈수록 빠르게
          final target = Offset(f.tx, f.ty);
          final cx = f.x0 + cw / 2 + (target.dx - (f.x0 + cw / 2)) * p;
          final cy = f.y0 + ch / 2 + (target.dy - (f.y0 + ch / 2)) * p;
          f.scale = 1 + 2.8 * p;
          f.x = cx - cw / 2;
          f.y = cy - ch / 2;
          f.rot = f.spin * 0.4 * p;
          f.alpha = t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1;
          if (t >= 1) {
            _explode(cx, cy, suitOf(f.card), big: true);
            _flash = min(0.5, _flash + 0.3);
            f.gone = true;
          }
      }
      if (!_accOk || f.mode != _Mode.bounce) {
        f.trail.add((f.x + cw / 2, f.y + ch / 2, f.scale, f.rot));
        if (f.trail.length > (f.mode == _Mode.bounce ? 22 : 12)) f.trail.removeAt(0);
      }
    }
    _flushStamps();

    // 색종이 비
    if (time < 12) {
      final n = (110 * dt).floor() + (_rng.nextDouble() < 110 * dt - (110 * dt).floor() ? 1 : 0);
      for (var i = 0; i < n && _particles.length < 900; i++) {
        _particles.add(_Particle(
          _rng.nextDouble() * view.width,
          -ch * 0.2,
          (_rng.nextDouble() - 0.5) * cw * 1.2,
          ch * (1.0 + _rng.nextDouble() * 1.8),
          6,
          cw * (0.07 + _rng.nextDouble() * 0.06),
          WinCelebration._confettiColors[_rng.nextInt(WinCelebration._confettiColors.length)],
          0,
          gravity: ch * 0.4,
          spin: (_rng.nextDouble() - 0.5) * 12,
        ));
      }
    }

    for (final p in List.of(_particles)) {
      p.life -= dt;
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.spin * dt;
      if (p.life <= 0 || p.y > view.height + ch) _particles.remove(p);
    }
    for (final r in List.of(_rings)) {
      r.age += dt;
      if (r.age > 0.55) _rings.remove(r);
    }
  }

  /// 지난 위치에서 지금 위치까지 촘촘하게 카드를 찍는다 (프레임이 느려도 끊기지 않게).
  void _stampAlong(_Flyer f) {
    final step = cardSize.width * 0.1;
    final lx = f.lastStampX, ly = f.lastStampY;
    if (lx == null || ly == null) {
      _stamps.add((f.card, f.x, f.y));
    } else {
      final d = sqrt((f.x - lx) * (f.x - lx) + (f.y - ly) * (f.y - ly));
      final n = min(40, (d / step).floor());
      for (var i = 1; i <= n; i++) {
        final t = i / n;
        _stamps.add((f.card, lx + (f.x - lx) * t, ly + (f.y - ly) * t));
      }
      if (n == 0) return; // 아직 한 칸도 안 움직였으면 다음에
    }
    f.lastStampX = f.x;
    f.lastStampY = f.y;
  }

  void _flushStamps() {
    if (!_accOk || _stamps.isEmpty) return;
    try {
      final w = (view.width * WinCelebration._accScale).ceil(), h = (view.height * WinCelebration._accScale).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(w / view.width, h / view.height);
      final old = _acc;
      if (old != null) {
        canvas.drawImageRect(
          old,
          Rect.fromLTWH(0, 0, old.width.toDouble(), old.height.toDouble()),
          Offset.zero & view,
          Paint(),
        );
      }
      for (final (card, x, y) in _stamps) {
        canvas.save();
        canvas.translate(x, y);
        final image = _images[card];
        if (image != null) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            Offset.zero & cardSize,
            Paint()..filterQuality = FilterQuality.low,
          );
        } else {
          drawCard(canvas, card, cardSize);
        }
        canvas.restore();
      }
      _stamps.clear();
      final picture = recorder.endRecording();
      final image = picture.toImageSync(w, h);
      picture.dispose();
      old?.dispose();
      _acc = image;
    } catch (_) {
      _accOk = false; // 누적 그림을 못 만들면 짧은 잔상으로 대신한다
      _stamps.clear();
    }
  }

  void _sparkle(double x, double y, int suit, int count, double power, {bool upward = false}) {
    final cw = cardSize.width;
    final base = isRedSuitIndex(suit) ? const Color(0xFFFF6B6B) : const Color(0xFFBFD7FF);
    for (var i = 0; i < count; i++) {
      final a = upward ? -pi / 2 + (_rng.nextDouble() - 0.5) * pi * 0.9 : _rng.nextDouble() * 2 * pi;
      final sp = cw * (1.5 + _rng.nextDouble() * 3) * power * 2;
      _particles.add(_Particle(x, y, cos(a) * sp, sin(a) * sp, 0.35 + _rng.nextDouble() * 0.3, cw * 0.05,
          _rng.nextBool() ? const Color(0xFFFFE08A) : base, 2,
          gravity: cardSize.height * 3));
    }
  }

  void _explode(double x, double y, int suit, {required bool big}) {
    final cw = cardSize.width;
    final n = big ? 70 : 38;
    final cardColor = isRedSuitIndex(suit) ? const Color(0xFFFF4D5E) : const Color(0xFF8FB8FF);
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = cw * (1.5 + _rng.nextDouble() * (big ? 9 : 6));
      final kind = i % 3;
      final color = switch (i % 4) {
        0 => const Color(0xFFFFD84D),
        1 => cardColor,
        2 => const Color(0xFFFFFFFF),
        _ => WinCelebration._confettiColors[_rng.nextInt(WinCelebration._confettiColors.length)],
      };
      _particles.add(_Particle(
        x,
        y,
        cos(a) * sp,
        sin(a) * sp,
        0.8 + _rng.nextDouble() * 0.9,
        cw * (kind == 1 ? 0.14 : kind == 2 ? 0.06 : 0.09) * (0.7 + _rng.nextDouble() * 0.7),
        color,
        kind,
        gravity: cardSize.height * (kind == 2 ? 2.2 : 4),
        spin: (_rng.nextDouble() - 0.5) * 14,
      ));
    }
    _rings.add(_Ring(x, y, const Color(0xFFFFE08A), cw * (big ? 3.2 : 1.8)));
    if (big) _rings.add(_Ring(x, y, Colors.white, cw * 2));
  }

  bool isRedSuitIndex(int suit) => suit == 1 || suit == 2;
}
