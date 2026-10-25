import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pinball_engine.dart';
import '../core/pinball_run.dart';
import '../core/pinball_table.dart';
import 'pinball_ball_save_light.dart';
import 'pinball_sprites.dart';

part 'pinball_painter_table.dart';
part 'pinball_painter_overlay.dart';

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

  @override
  bool shouldRepaint(PinballPainter old) => true;
}
