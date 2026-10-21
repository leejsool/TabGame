import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pinball_engine.dart';
import '../core/pinball_run.dart';
import '../core/pinball_table.dart';
import 'pinball_ball_arrow.dart';
import 'pinball_ball_save_light.dart';
import 'pinball_sprites.dart';

/// 화면 폭에 판이 꽉 차게 키우되, 한 화면에 판 높이 900쯤만 보이게 한다 (나머지는 카메라가 따라다니며 보여 준다).
/// 화면이 아주 크면 판 전체가 한 번에 보이도록 줄인다.
double pinballScale(Size s) {
  final fitW = s.width / kTableW;
  final fitWhole = min(fitW, s.height / kTableH);
  return max(fitWhole, min(fitW, s.height / 900));
}

/// 화면에 보이는 판의 높이 (판 좌표 단위).
double pinballViewH(Size s) => s.height / pinballScale(s);

const List<String> _domes = [
  'bumper_red',
  'bumper_yellow',
  'bumper_green',
  'bumper_blue',
  'bumper_purple',
];

// 플리퍼 그림에서의 축(굵은 쪽) 위치와 끝 위치, 그림 안에서 축→끝 방향 (픽셀·라디안).
const _flipL = (pivot: Offset(20, 19), tip: Offset(127, 57));
const _flipR = (pivot: Offset(128, 19), tip: Offset(18, 55));

/// 판 전체를 [size]에 맞춰 그린다. [camY]는 화면 맨 위에 보이는 판 좌표의 y.
class PinballPainter extends CustomPainter {
  PinballPainter({
    required this.run,
    required this.charge,
    required this.camY,
    required this.art,
    this.debug = false,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final PinballRun run;

  /// 발사 막대를 당긴 정도 (0~1).
  final double charge;
  final double camY;

  /// 그림을 아직 못 불러왔으면 null (밋밋한 바탕에 부품만 그린다).
  final PinballArt? art;

  /// 충돌하는 벽을 그림 위에 그려서 맞는지 확인한다 (개발용).
  final bool debug;

  PinballTable get _table => run.engine.table;
  PinballEngine get _e => run.engine;

  @override
  void paint(Canvas canvas, Size size) {
    final s = pinballScale(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05070F),
    );
    canvas.translate((size.width - kTableW * s) / 2, -camY * s);
    canvas.scale(s);
    _board(canvas);
    _lights(canvas);
    paintBallSaveLights(canvas, run);
    _spinners(canvas);
    _saucer(canvas);
    _bumpers(canvas);
    _targets(canvas);
    _flippers(canvas);
    _plunger(canvas);
    _balls(canvas);
    _shield(canvas);
    if (debug) _debugWalls(canvas);
    _popups(canvas);
    if (run.tilted)
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, kTableW, kTableH),
        Paint()..color = const Color(0x33FF1744),
      );
    if (run.phase == RunPhase.countdown) _spotlightBalls(canvas);
    canvas.restore();
    _banners(canvas, size);
  }

  Paint get _smooth => Paint()..filterQuality = FilterQuality.medium;

  void _board(Canvas canvas) {
    final a = art;
    if (a == null) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, kTableW, kTableH),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1F5E), Color(0xFF0C1235)],
          ).createShader(const Rect.fromLTWH(0, 0, kTableW, kTableH)),
      );
      _debugWalls(canvas);
      return;
    }
    canvas.drawImage(a['board_background'], Offset.zero, _smooth);
  }

  /// 켜진 불빛(별 롤오버)과 달리는 궤도 표시.
  void _lights(Canvas canvas) {
    for (final s in _table.sensors) {
      if (s.kind != SensorKind.lane) continue;
      final art = this.art;
      if (art != null) {
        final star = art['star'];
        canvas.drawImageRect(
          star,
          Rect.fromLTWH(0, 0, star.width.toDouble(), star.height.toDouble()),
          Rect.fromCenter(center: Offset(s.x, s.y), width: 28, height: 28),
          _smooth,
        );
      }
      final lit = _e.laneLit[s.index];
      if (!lit) continue;
      final pulse = 0.6 + 0.4 * sin(run.clock * 14);
      canvas.drawCircle(
        Offset(s.x, s.y),
        24,
        Paint()..color = Color.fromRGBO(255, 235, 120, 0.55 * pulse),
      );
      canvas.drawCircle(
        Offset(s.x, s.y),
        11,
        Paint()..color = const Color(0xFFFFF59D),
      );
    }
    for (final left in [true, false]) {
      if (_e.orbitArmed[left ? 0 : 1] <= 0) continue;
      final x = left ? 65.0 : 551.0;
      canvas.drawCircle(
        Offset(x, 340),
        20 + 4 * sin(run.clock * 12),
        Paint()..color = const Color(0x6640C4FF),
      );
    }
  }

  void _spinners(Canvas canvas) {
    for (var i = 0; i < _table.spinners.length; i++) {
      final sp = _table.spinners[i];
      final st = _e.spinners[i];
      final flat = 3 + 12 * sin(st.angle).abs();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(sp.x, sp.y),
            width: sp.w,
            height: flat,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFFFD54F),
      );
      canvas.drawLine(
        Offset(sp.x - sp.w / 2, sp.y),
        Offset(sp.x + sp.w / 2, sp.y),
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..strokeWidth = 2,
      );
    }
  }

  void _saucer(Canvas canvas) {
    final c = _table.saucer;
    final o = Offset(c.x, c.y);
    final a = art;
    if (a != null) {
      final logo = a['logo_r'];
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromCenter(center: o, width: 92, height: 92),
        _smooth,
      );
    }
    if (_e.saucerLit) {
      canvas.drawCircle(
        o,
        40 + 7 * sin(run.clock * 8),
        Paint()..color = const Color(0x6669F0AE),
      );
      canvas.drawCircle(
        o,
        c.r + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF69F0AE),
      );
    }
    if (_e.held != null) canvas.drawCircle(o, 8, Paint()..color = Colors.white);
  }

  void _bumpers(Canvas canvas) {
    final a = art;
    for (var i = 0; i < _table.bumpers.length; i++) {
      final d = _table.bumpers[i];
      final g = run.glow['b$i'] ?? 0;
      final o = Offset(d.x, d.y);
      if (g > 0)
        canvas.drawCircle(
          o,
          d.r + 14 + 12 * g,
          Paint()..color = Color.fromRGBO(255, 235, 130, 0.5 * g),
        );
      if (a != null && i < _domes.length) {
        final size = (d.r * 2 + 10) * (1 + 0.12 * g);
        canvas.drawImageRect(
          a[_domes[i]],
          Rect.fromLTWH(
            0,
            0,
            a[_domes[i]].width.toDouble(),
            a[_domes[i]].height.toDouble(),
          ),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a != null && i == 5) {
        final size = (d.r * 2 + 10) * (1 + 0.12 * g);
        canvas.drawImageRect(
          a['bumper_purple'],
          Rect.fromLTWH(
            0,
            0,
            a['bumper_purple'].width.toDouble(),
            a['bumper_purple'].height.toDouble(),
          ),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a != null && (i == 6 || i == 7)) {
        final img = a[i == 6 ? 'pokeball' : 'pokeball_ring'];
        final size = d.r * 2.1 * (1 + 0.12 * g);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a == null) {
        canvas.drawCircle(
          o,
          d.r,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFE5484D),
              const Color(0xFFFFF176),
              g,
            )!,
        );
      } else if (g > 0) {
        // 그림에 그려진 큰 공은 맞으면 하얗게 반짝인다
        canvas.drawCircle(
          o,
          d.r,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.45 * g),
        );
      }
    }
  }

  void _targets(Canvas canvas) {
    final a = art;
    for (var i = 0; i < _table.targets.length; i++) {
      final t = _table.targets[i];
      final down = _e.targetDown[i];
      final o = Offset(t.x, t.y);
      if (t.bank == 0) {
        if (a != null) {
          const targetAssets = [
            'target_red',
            'target_yellow',
            'target_blue',
            'target_green',
          ];
          const targetAngles = [-0.32, 0.32, -0.32, 0.32];
          final img = a[targetAssets[i % targetAssets.length]];
          final scale = down ? 0.58 : 1.0;
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(targetAngles[i % targetAngles.length]);
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(
              center: Offset.zero,
              width: 36 * scale,
              height: 72 * scale,
            ),
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Color.fromRGBO(255, 255, 255, down ? 0.5 : 1),
          );
          canvas.restore();
        }
        if (down) {
          canvas.drawCircle(
            o,
            t.r + 12,
            Paint()..color = const Color(0x55FFEB3B),
          );
          canvas.drawCircle(
            o,
            t.r - 2,
            Paint()..color = const Color(0xCCFFEE58),
          );
        }
        continue;
      }
      if (a == null) {
        canvas.drawCircle(
          o,
          down ? t.r * 0.45 : t.r,
          Paint()
            ..color = down ? const Color(0xFF55607A) : const Color(0xFFFFC107),
        );
        continue;
      }
      final img = a[t.bank == 1 ? 'pokeball_ring' : 'medal_pikachu'];
      final size = down ? t.r * 1.0 : t.r * 2.4;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, down ? 0.4 : 1),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: o, width: size, height: size),
        _smooth,
      );
      canvas.restore();
    }
    for (final d in _table.posts) {
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r,
        Paint()..color = const Color(0xFFB0BEC5),
      );
      canvas.drawCircle(
        Offset(d.x - d.r * 0.25, d.y - d.r * 0.25),
        d.r * 0.32,
        Paint()..color = const Color(0xFFDCE4EA),
      );
    }
  }

  void _flippers(Canvas canvas) {
    final a = art;
    for (final f in _e.flippers) {
      final left = f.spec.left;
      final (tx, ty) = _e.flipperTip(f);
      if (a == null) {
        canvas.drawLine(
          Offset(f.spec.px, f.spec.py),
          Offset(tx, ty),
          Paint()
            ..color = const Color(0xFFFFB400)
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final img = a[left ? 'flipper_l' : 'flipper_r'];
      final m = left ? _flipL : _flipR;
      final spriteLen = (m.tip - m.pivot).distance;
      final spriteAngle = atan2(m.tip.dy - m.pivot.dy, m.tip.dx - m.pivot.dx);
      // 긴 플리퍼는 길이 방향으로만 늘린다 (두께는 그대로).
      final k = f.spec.length / spriteLen;
      canvas.save();
      canvas.translate(f.spec.px, f.spec.py);
      canvas.rotate(f.angle);
      canvas.scale(k * _e.flipperLenMul, k);
      canvas.rotate(-spriteAngle);
      canvas.drawImage(img, -m.pivot, _smooth);
      canvas.restore();
    }
  }

  void _plunger(Canvas canvas) {
    final pull = charge * 52;
    final spring = Paint()
      ..color = const Color(0xFF9AA7C4)
      ..strokeWidth = 3;
    for (var y = kLaneFloorY + 4 + pull; y < kTableH - 6; y += 8) {
      canvas.drawLine(
        Offset(kLaneX - 11, y),
        Offset(kLaneX + 11, y + 4),
        spring,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(kLaneX, kLaneFloorY + 3 + pull),
          width: 24,
          height: 9,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF7043),
    );
  }

  void _balls(Canvas canvas) {
    final r = _e.ballR;
    final a = art;
    for (final b in _e.balls) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(
        c + const Offset(2, 4),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      if (a != null) {
        final img = a['ball1'];
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: c, width: r * 2.1, height: r * 2.1),
          _smooth,
        );
      } else {
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFC3CCDA));
      }
    }
  }

  /// 3·2·1 동안 판을 어둡게 덮고 공만 밝게, 둘레에 번쩍이는 고리를 그려서 공이 어디 있는지 알려 준다.
  void _spotlightBalls(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(-600, -600, kTableW + 1200, kTableH + 1200),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final r = _e.ballR;
    final pulse = 0.5 + 0.5 * sin(run.clock * 9);
    for (final b in _e.balls) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(
        c,
        r * (2.6 + pulse * 0.8),
        Paint()
          ..color = const Color(0xFFFFD84D)
              .withValues(alpha: 0.18 + 0.12 * pulse),
      );
      canvas.drawCircle(
        c,
        r * (1.9 + pulse * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD84D),
      );
    }
    // 공이 움직이던 방향·빠르기 화살표 (멈춰 있던 판이 다시 움직이면 공이 어디로 갈지)
    for (final b in _e.balls) {
      paintBallArrow(canvas, b, r * 2.6);
    }
    _balls(canvas);
    for (final b in _e.balls) {
      final tp = _text('공', 30, const Color(0xFFFFD84D));
      // 화살표가 위를 가리키면 글자는 공 아래에 둔다
      final y = arrowPointsUp(b) ? b.y + r * 3.2 + 6 * pulse : b.y - r * 3.2 - tp.height - 6 * pulse;
      // 통로 안 공은 오른쪽 끝에 붙어 있어서 글자가 판 밖으로 나가지 않게 안쪽으로 당긴다.
      final x = min(b.x - tp.width / 2, kTableW - tp.width - 4);
      tp.paint(canvas, Offset(x, y));
    }
  }

  void _shield(Canvas canvas) {
    final n = _e.shields;
    if (n <= 0) return;
    final p = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final y = 1318.0 + i * 9;
      canvas.drawLine(Offset(70, y), Offset(546, y), p);
    }
  }

  void _popups(Canvas canvas) {
    for (final p in run.popups) {
      if (p.banner) continue;
      final t = p.age / 1.1;
      final tp = _text(
        p.text,
        p.text.length > 5 ? 40 : 28,
        p.color.withValues(alpha: 1 - t * t),
      );
      tp.paint(
        canvas,
        Offset(p.x - tp.width / 2, p.y - tp.height / 2 - 60 * t),
      );
    }
  }

  /// 잭팟·틸트 같은 큰 알림은 화면 가운데 (판이 움직여도 늘 같은 자리).
  void _banners(Canvas canvas, Size size) {
    var row = 0;
    for (final p in run.popups) {
      if (!p.banner) continue;
      final t = p.age / 1.1;
      final grow = 1 + 0.25 * (1 - min(1.0, p.age * 6));
      final tp = _text(p.text, 46 * grow, p.color.withValues(alpha: 1 - t * t));
      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          size.height * 0.36 + row * 54 - tp.height / 2,
        ),
      );
      row++;
    }
  }

  TextPainter _text(String text, double size, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 5)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _debugWalls(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xCC00E5FF)
      ..strokeWidth = 2;
    for (final w in _table.walls) {
      canvas.drawLine(
        Offset(w.ax, w.ay),
        Offset(w.bx, w.by),
        w.sling >= 0
            ? (Paint()
                ..color = const Color(0xFFFF4081)
                ..strokeWidth = 3)
            : p,
      );
    }
    for (final d in [..._table.bumpers, ..._table.posts, _table.saucer]) {
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFFEB3B)
          ..strokeWidth = 2,
      );
    }
    for (final t in _table.targets) {
      canvas.drawCircle(
        Offset(t.x, t.y),
        t.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF76FF03)
          ..strokeWidth = 2,
      );
    }
    for (final s in _table.sensors) {
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFF9100)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(PinballPainter old) => true;
}
