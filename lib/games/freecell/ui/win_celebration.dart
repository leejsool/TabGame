import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/freecell_rules.dart' show suitOf;
import 'playing_card.dart';

enum _Mode {
  /// 윈도우 프리셀처럼 통통 튀면서 화면 밖으로 (잔상을 길게 남긴다).
  bounce,

  /// 위로 솟구쳤다가 꼭대기에서 폭발한다.
  burst,

  /// 화면 쪽으로 날아와 점점 커지다가 부딪히며 터진다.
  zoom,
}

class _Flyer {
  _Flyer({
    required this.card,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.launchAt,
    required this.mode,
    required this.spin,
  })  : x0 = x,
        y0 = y;

  final int card;
  double x, y, vx, vy; // 카드 왼쪽 위 좌표
  final double x0, y0;
  final double launchAt;
  final _Mode mode;
  final double spin;
  double rot = 0, scale = 1, alpha = 1, age = 0;
  bool launched = false, gone = false;

  /// 잔상: (가운데 x, 가운데 y, 크기, 회전)
  final List<(double, double, double, double)> trail = [];
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.kind,
      {this.gravity = 0, this.spin = 0})
      : maxLife = life;

  double x, y, vx, vy, life, size, gravity, spin, rot = 0;
  final double maxLife;
  final Color color;

  /// 0 = 색종이 조각, 1 = 별, 2 = 불꽃(선)
  final int kind;
}

class _Ring {
  _Ring(this.x, this.y, this.color, this.maxRadius);

  final double x, y, maxRadius;
  final Color color;
  double age = 0;
}

/// 프리셀/솔리테어를 끝냈을 때의 화려한 축하 연출.
/// 카드가 완성 칸에서 튀어나와 잔상을 남기며 튀고, 솟구쳐 터지고, 화면으로 날아와 부딪히며,
/// 색종이와 불꽃이 쏟아진다.
class WinCelebration {
  WinCelebration({
    required this.view,
    required this.cardSize,
    required List<Offset> foundationPositions,
    required int seed,
    double pixelRatio = 2,
  })  : _rng = Random(seed),
        // ignore: prefer_initializing_formals
        _pixelRatio = pixelRatio {
    _buildImages();
    _banner = _bannerPainters();
    var order = 0;
    for (var rank = 12; rank >= 0; rank--) {
      for (var suit = 0; suit < 4; suit++) {
        final p = foundationPositions[suit];
        final mode = switch (order % 5) {
          2 => _Mode.burst,
          4 => _Mode.zoom,
          _ => _Mode.bounce,
        };
        final dir = _rng.nextBool() ? 1.0 : -1.0;
        final cw = cardSize.width, ch = cardSize.height;
        _flyers.add(_Flyer(
          card: rank * 4 + suit,
          x: p.dx,
          y: p.dy,
          vx: switch (mode) {
            _Mode.bounce => dir * cw * (2.2 + _rng.nextDouble() * 3.6),
            _Mode.burst => dir * cw * (0.3 + _rng.nextDouble() * 1.6),
            _Mode.zoom => 0,
          },
          vy: switch (mode) {
            _Mode.bounce => -ch * (1.5 + _rng.nextDouble() * 2.8),
            _Mode.burst => -ch * (4.2 + _rng.nextDouble() * 2.0),
            _Mode.zoom => 0,
          },
          launchAt: 0.25 + order * 0.085,
          mode: mode,
          spin: dir * (0.5 + _rng.nextDouble() * 2.5),
        ));
        order++;
      }
    }
  }

  final Size view;
  final Size cardSize;
  final double _pixelRatio;
  final Random _rng;
  final List<_Flyer> _flyers = [];
  final List<_Particle> _particles = [];
  final List<_Ring> _rings = [];
  final Map<int, ui.Image> _images = {};
  late final (TextPainter, TextPainter) _banner;

  double time = 0;
  double _flash = 0.6;

  static const _confettiColors = [
    Color(0xFFFFD84D),
    Color(0xFFFF5C7A),
    Color(0xFF5CC8FF),
    Color(0xFF7CFFB2),
    Color(0xFFFFFFFF),
    Color(0xFFFF9F43),
    Color(0xFFB388FF),
  ];

  /// 연출이 끝났는가 (모든 카드와 잔상이 사라지고 시간이 충분히 지났다).
  bool get finished => time > 7 && _flyers.isEmpty && _particles.isEmpty;

  // ── 카드 그림을 미리 한 번씩만 그려 둔다 (잔상 때문에 매 프레임 많이 그리므로) ──

  void _buildImages() {
    final scale = min(_pixelRatio, 2.5) * 1.6;
    final w = (cardSize.width * scale).ceil(), h = (cardSize.height * scale).ceil();
    for (var card = 0; card < 52; card++) {
      try {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(w / cardSize.width, h / cardSize.height);
        drawCard(canvas, card, cardSize);
        final picture = recorder.endRecording();
        _images[card] = picture.toImageSync(w, h);
        picture.dispose();
      } catch (_) {
        break; // 그림을 못 만들면 아래 paint에서 카드를 직접 그린다
      }
    }
  }

  void dispose() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
  }

  (TextPainter, TextPainter) _bannerPainters() {
    final size = min(view.width * 0.2, view.height * 0.22);
    TextPainter make(Paint? foreground, Color? color) => TextPainter(
          text: TextSpan(
            text: '클리어!',
            style: TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: size,
              fontWeight: FontWeight.w900,
              color: foreground == null ? color : null,
              foreground: foreground,
              letterSpacing: size * 0.04,
              shadows: foreground != null
                  ? [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: size * 0.1, offset: Offset(0, size * 0.05))]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.12
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF7A3E00);
    return (make(stroke, null), make(null, const Color(0xFFFFD84D)));
  }

  // ── 진행 ──

  void update(double dt) {
    time += dt;
    final cw = cardSize.width, ch = cardSize.height;
    final floor = view.height - ch;
    final g = ch * 9.0;
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
          f.rot += f.spin * dt * 0.35;
          if (f.y > floor) {
            f.y = floor;
            f.vy = -f.vy * 0.78;
            if (f.vy.abs() < ch * 0.6) f.vy = -ch * 1.2;
            _sparkle(f.x + cw / 2, f.y + ch, suitOf(f.card), 7, 0.45, upward: true);
          }
          if (f.x < -cw * 1.5 || f.x > view.width + cw * 0.5) f.gone = true;
        case _Mode.burst:
          f.vy += g * dt;
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
          final target = Offset(view.width * (0.3 + 0.4 * ((f.card * 37) % 10) / 10), view.height * 0.45);
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
      f.trail.add((f.x + cw / 2, f.y + ch / 2, f.scale, f.rot));
      if (f.trail.length > (f.mode == _Mode.bounce ? 22 : 12)) f.trail.removeAt(0);
    }

    // 색종이 비
    if (time < 5.5) {
      final n = (200 * dt).round() + (_rng.nextDouble() < 200 * dt - (200 * dt).floor() ? 1 : 0);
      for (var i = 0; i < n && _particles.length < 900; i++) {
        _particles.add(_Particle(
          _rng.nextDouble() * view.width,
          -ch * 0.2,
          (_rng.nextDouble() - 0.5) * cw * 1.2,
          ch * (1.0 + _rng.nextDouble() * 1.8),
          6,
          cw * (0.07 + _rng.nextDouble() * 0.06),
          _confettiColors[_rng.nextInt(_confettiColors.length)],
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
        _ => _confettiColors[_rng.nextInt(_confettiColors.length)],
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

  // ── 그리기 ──

  void paint(Canvas canvas, Size size) {
    final cw = cardSize.width, ch = cardSize.height;

    // 카드와 잔상
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

class WinCelebrationPainter extends CustomPainter {
  WinCelebrationPainter(this.show, Listenable repaint) : super(repaint: repaint);

  final WinCelebration show;

  @override
  void paint(Canvas canvas, Size size) => show.paint(canvas, size);

  @override
  bool shouldRepaint(WinCelebrationPainter old) => true;
}
