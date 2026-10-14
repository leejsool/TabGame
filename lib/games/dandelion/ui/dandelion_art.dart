import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/dandelion_rules.dart';

const Color kDandelionColor = Color(0xFFE5A100);
const Color kWindColor = Color(0xFF2F80D0);

const Color _grassDark = Color(0xFF5E8F33);
const Color _grassLight = Color(0xFF8DC155);
const Color _cellEmpty = Color(0xFFF1F7DD);
const Color _cellSeed = Color(0xFFD3E8A9);
const Color _cellFlower = Color(0xFFFFF2B8);
const Color _petal = Color(0xFFFFC61A);
const Color _petalEdge = Color(0xFFE08A00);
const Color _seedBody = Color(0xFF6B5A2E);

Color roleColor(Role r) => r == Role.dandelion ? kDandelionColor : kWindColor;

/// 정사각형 판 위의 칸 위치.
class DandLayout {
  DandLayout(this.side)
      : pad = side * 0.035,
        cell = (side - side * 0.07) / kSize;

  final double side;
  final double pad;
  final double cell;

  Rect cellRect(int i) => Rect.fromLTWH(pad + (i % kSize) * cell, pad + (i ~/ kSize) * cell, cell, cell);
  Offset center(int i) => cellRect(i).center;

  /// 누른 자리가 속한 칸 (판 밖이면 null).
  int? hit(Offset p) {
    final c = ((p.dx - pad) / cell).floor(), r = ((p.dy - pad) / cell).floor();
    if (c < 0 || c >= kSize || r < 0 || r >= kSize) return null;
    return r * kSize + c;
  }
}

/// 민들레 꽃 (위에서 내려다본 모습). [r]은 반지름, [scale]은 심을 때 톡 튀어 오르는 크기.
void drawFlower(Canvas canvas, Offset c, double r, {double scale = 1, double alpha = 1}) {
  final big = r * scale;
  if (big < 0.5) return;
  const petals = 16;
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = big * 0.3
    ..color = _petalEdge.withValues(alpha: alpha);
  final body = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = big * 0.2
    ..color = _petal.withValues(alpha: alpha);
  for (final p in [edge, body]) {
    for (var i = 0; i < petals; i++) {
      final a = i * 2 * pi / petals;
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(c + dir * big * 0.34, c + dir * big * 0.92, p);
    }
  }
  canvas.drawCircle(c, big * 0.4, Paint()..color = const Color(0xFFF08A00).withValues(alpha: alpha));
  canvas.drawCircle(c, big * 0.4, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = big * 0.06
    ..color = _petalEdge.withValues(alpha: alpha));
  canvas.drawCircle(c + Offset(-big * 0.1, -big * 0.1), big * 0.12, Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha));
}

/// 씨앗 한 알: 작은 낙하산 모양. [angle]만큼 기울인다.
void drawSeed(Canvas canvas, Offset c, double r, {double alpha = 1, double angle = 0}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  final fluff = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(1.0, r * 0.05)
    ..color = const Color(0xFF4F7A2A).withValues(alpha: alpha);
  final tip = Paint()..color = Colors.white.withValues(alpha: alpha);
  final top = Offset(0, -r * 0.02);
  for (var i = -2; i <= 2; i++) {
    final a = -pi / 2 + i * 0.5;
    final end = top + Offset(cos(a), sin(a)) * r * 0.62;
    canvas.drawLine(top, end, fluff);
    canvas.drawCircle(end, r * 0.075, tip);
    canvas.drawCircle(end, r * 0.075, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * 0.025)
      ..color = const Color(0xFF4F7A2A).withValues(alpha: alpha));
  }
  final seed = Rect.fromCenter(center: Offset(0, r * 0.2), width: r * 0.2, height: r * 0.46);
  canvas.drawOval(seed, Paint()..color = _seedBody.withValues(alpha: alpha));
  canvas.restore();
}

/// 바람 아이콘: 가로줄 세 개가 오른쪽(앞)에서 돌돌 말려 올라가거나 내려가는 모양. 줄이 뒤에 흩날리고 말린 끝이 앞이라 방향이 보인다.
/// [r] 안에 가득 그린다 (정사각형에 맞춰 그린다).
void paintWindGust(Canvas canvas, Rect r, Color color, {double thickness = 0.09}) {
  final s = min(r.width, r.height);
  final o = Offset(r.left + (r.width - s) / 2, r.top + (r.height - s) / 2);
  Offset p(double x, double y) => Offset(o.dx + x * s, o.dy + y * s);
  Rect circle(double x, double y, double rad) => Rect.fromCircle(center: p(x, y), radius: rad * s);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = s * thickness
    ..color = color;
  // 위쪽 줄: 오른쪽 끝이 위로 말려 올라간다
  final top = Path()
    ..moveTo(p(0.06, 0.34).dx, p(0.06, 0.34).dy)
    ..lineTo(p(0.52, 0.34).dx, p(0.52, 0.34).dy)
    ..arcTo(circle(0.52, 0.23, 0.11), pi / 2, -1.4 * pi, false);
  // 가운데 줄: 가장 길고, 큰 원으로 말려 올라간다
  final mid = Path()
    ..moveTo(p(0.06, 0.54).dx, p(0.06, 0.54).dy)
    ..lineTo(p(0.72, 0.54).dx, p(0.72, 0.54).dy)
    ..arcTo(circle(0.72, 0.38, 0.16), pi / 2, -1.45 * pi, false);
  // 아래쪽 줄: 중간에서 아래로 말려 내려간다
  final bottom = Path()
    ..moveTo(p(0.06, 0.74).dx, p(0.06, 0.74).dy)
    ..lineTo(p(0.44, 0.74).dx, p(0.44, 0.74).dy)
    ..arcTo(circle(0.44, 0.85, 0.11), -pi / 2, 1.4 * pi, false);
  for (final path in [top, mid, bottom]) {
    canvas.drawPath(path, stroke);
  }
}

/// 판 하나를 그리는 그림. 게임 화면과 안내 그림이 함께 쓴다.
class DandScenePainter extends CustomPainter {
  DandScenePainter({
    required this.cells,
    this.flying = const {},
    this.plantCell = -1,
    this.plantT = 1,
    this.windDir,
    this.windT = 0,
    this.streaksStatic = false,
    this.rings = const {},
    this.ringColor = kWindColor,
    this.ringColors = const {},
    this.badges = const {},
    this.links = const [],
    this.endT = 0,
    this.endWon = false,
    this.dimCells = const {},
  });

  final List<int> cells;

  /// 아직 날아가는 중인 씨앗: 칸 → (출발한 꽃, 진행 0~1). 진행이 끝나기 전에는 빈칸으로 그린다.
  final Map<int, ({int from, double t})> flying;
  final int plantCell;
  final double plantT;

  /// 바람이 부는 모습(줄무늬). [windT]가 0~1로 가는 동안 지나간다. [streaksStatic]이면 멈춘 그림.
  final WindDir? windDir;
  final double windT;
  final bool streaksStatic;

  /// 눈에 띄게 둘러싸 보일 칸 (안내 그림용).
  final Set<int> rings;
  final Color ringColor;

  /// 칸마다 다른 테두리 색 (없으면 [ringColor]).
  final Map<int, Color> ringColors;

  /// 칸 한가운데에 붙이는 맞음(true, 체크)/틀림(false, 가위표) 표시.
  final Map<int, bool> badges;

  /// 한 칸에서 다른 칸으로 이어지는 화살표 (씨앗이 가는 길을 보여 줄 때).
  final List<(int, int)> links;

  /// 끝난 뒤 효과 (0~1): 이기면 금빛, 빈칸이 남으면 붉게 반짝인다.
  final double endT;
  final bool endWon;

  final Set<int> dimCells;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    final layout = DandLayout(s);
    final frame = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.05));
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_grassLight, _grassDark],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
    canvas.drawRRect(
      frame.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF47702A),
    );

    final cs = layout.cell;
    final gap = cs * 0.045;
    for (var i = 0; i < cells.length; i++) {
      final r = layout.cellRect(i).deflate(gap);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cs * 0.14));
      final fly = flying[i];
      final state = fly != null && fly.t < 1 ? kEmpty : cells[i];
      var color = switch (state) {
        kSeed => _cellSeed,
        kFlower => _cellFlower,
        _ => _cellEmpty,
      };
      if (endT > 0 && !endWon && state == kEmpty) {
        color = Color.lerp(color, const Color(0xFFFF8A80), 0.45 * (0.5 + 0.5 * sin(endT * pi * 6)))!;
      }
      canvas.drawRRect(rr.shift(Offset(0, cs * 0.03)), Paint()..color = Colors.black.withValues(alpha: 0.16));
      canvas.drawRRect(rr, Paint()..color = color);
      if (dimCells.contains(i)) {
        canvas.drawRRect(rr, Paint()..color = Colors.black.withValues(alpha: 0.12));
      }
    }

    // 앉은 씨앗과 꽃
    for (var i = 0; i < cells.length; i++) {
      final center = layout.center(i);
      final fly = flying[i];
      if (cells[i] == kSeed && !(fly != null && fly.t < 1)) {
        drawSeed(canvas, center, cs * 0.44, angle: ((i * 37) % 11 - 5) * 0.04);
      } else if (cells[i] == kFlower) {
        final t = i == plantCell ? plantT : 1.0;
        final scale = i == plantCell ? Curves.elasticOut.transform(t.clamp(0.0, 1.0)) : 1.0;
        drawFlower(canvas, center, cs * 0.4, scale: scale);
      }
    }

    // 날아가는 씨앗
    flying.forEach((cell, f) {
      if (f.t >= 1 || f.t <= 0) return;
      final from = layout.center(f.from), to = layout.center(cell);
      final u = Curves.easeInOut.transform(f.t);
      final d = to - from;
      final perp = d.distance == 0 ? Offset.zero : Offset(-d.dy, d.dx) / d.distance;
      final wobble = sin(f.t * pi * 2) * cs * 0.12;
      final pos = Offset.lerp(from, to, u)! + perp * wobble;
      drawSeed(canvas, pos, cs * 0.44, angle: sin(f.t * pi * 3) * 0.4);
    });

    // 바람 줄무늬
    final wd = windDir;
    if (wd != null && (streaksStatic || (windT > 0 && windT < 1))) {
      _paintWind(canvas, s, wd, streaksStatic ? 0.5 : windT, streaksStatic ? 0.6 : sin(windT * pi) * 0.7);
    }

    for (final i in rings) {
      final r = layout.cellRect(i).deflate(gap * 0.4);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cs * 0.16));
      // 초록 풀밭 위에서도 보이도록 흰 후광을 먼저 깐다
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cs * 0.15
          ..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cs * 0.075
          ..color = (ringColors[i] ?? ringColor),
      );
    }

    for (final (from, to) in links) {
      final a = layout.center(from), b = layout.center(to);
      final v = b - a;
      if (v.distance == 0) continue;
      final u = v / v.distance;
      final start = a + u * cs * 0.34, end = b - u * cs * 0.3;
      final n = Offset(-u.dy, u.dx);
      for (final (w, color) in [(cs * 0.13, Colors.white), (cs * 0.07, const Color(0xFF0B5CB5))]) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w
          ..color = color;
        canvas.drawLine(start, end, p);
        canvas.drawLine(end, end - u * cs * 0.2 + n * cs * 0.12, p);
        canvas.drawLine(end, end - u * cs * 0.2 - n * cs * 0.12, p);
      }
    }

    badges.forEach((i, ok) {
      final center = layout.cellRect(i).center;
      final color = ok ? const Color(0xFF1E8E3E) : const Color(0xFFD93025);
      final rad = cs * 0.2;
      canvas.drawCircle(center, rad + cs * 0.03, Paint()..color = Colors.white);
      canvas.drawCircle(center, rad, Paint()..color = color);
      final mark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cs * 0.06
        ..color = Colors.white;
      final path = Path();
      if (ok) {
        path
          ..moveTo(center.dx - rad * 0.45, center.dy + rad * 0.02)
          ..lineTo(center.dx - rad * 0.1, center.dy + rad * 0.38)
          ..lineTo(center.dx + rad * 0.5, center.dy - rad * 0.38);
      } else {
        path
          ..moveTo(center.dx - rad * 0.38, center.dy - rad * 0.38)
          ..lineTo(center.dx + rad * 0.38, center.dy + rad * 0.38)
          ..moveTo(center.dx + rad * 0.38, center.dy - rad * 0.38)
          ..lineTo(center.dx - rad * 0.38, center.dy + rad * 0.38);
      }
      canvas.drawPath(path, mark);
    });

    if (endT > 0 && endWon) {
      final glow = (sin(endT * pi * 3) * 0.5 + 0.5) * (1 - endT * 0.4);
      canvas.drawRRect(
        frame.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..color = const Color(0xFFFFD84D).withValues(alpha: 0.35 + 0.5 * glow),
      );
    }
  }

  void _paintWind(Canvas canvas, double s, WindDir dir, double t, double alpha) {
    final v = Offset(dir.dCol.toDouble(), dir.dRow.toDouble());
    final vn = v / v.distance;
    final n = Offset(-vn.dy, vn.dx);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.018
      ..color = Colors.white.withValues(alpha: alpha);
    final mid = Offset(s / 2, s / 2);
    for (var k = -3; k <= 3; k++) {
      final off = n * (k * s * 0.15);
      final phase = (t * 1.25 - k.abs() * 0.04) % 1.4;
      final along = (-0.75 + phase * 1.1) * s;
      final head = mid + off + vn * along;
      final len = s * (0.16 + 0.04 * (k % 2).abs());
      final tail = head - vn * len;
      final bend = n * (s * 0.025);
      final path = Path()
        ..moveTo(tail.dx, tail.dy)
        ..quadraticBezierTo((tail.dx + head.dx) / 2 + bend.dx, (tail.dy + head.dy) / 2 + bend.dy, head.dx, head.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(DandScenePainter old) => true;
}

/// 바람의 나침반: 8방향 화살표. 이미 분 방향은 흐려진다.
///
/// 바람 차례([enabled])에는 화살표를 톡 눌러서 불 수도 있고, 조이스틱처럼 가운데 동그라미를 잡고
/// 원하는 방향으로 끌었다가 놓아도 된다. 끄는 동안에는 가리키는 화살표가 커지고, 놓으면 분다.
/// (가운데로 되돌려 놓으면 취소)
class DandelionCompass extends StatefulWidget {
  const DandelionCompass({
    super.key,
    required this.usedMask,
    this.enabled = false,
    this.onBlow,
    this.size = 160,
    this.windsLeft,
  });

  final int usedMask;
  final bool enabled;
  final void Function(WindDir dir)? onBlow;
  final double size;

  /// 가운데에 쓸 남은 바람 횟수 (null이면 안 쓴다).
  final int? windsLeft;

  /// 가운데에서 이만큼(반지름의 비율) 안쪽은 "아직 방향을 안 정한" 자리.
  static const double deadZone = 0.3;

  /// 나침반 한가운데에서 본 위치([size]는 한 변)가 가리키는 방향 (가운데 가까이면 null).
  static WindDir? dirAt(Offset p, double size) {
    final r = size / 2;
    final d = p - Offset(r, r);
    if (d.distance < r * deadZone) return null;
    final idx = (((atan2(d.dy, d.dx) + pi / 2) / (pi / 4)).round()) % 8;
    return WindDir.values[idx];
  }

  @override
  State<DandelionCompass> createState() => _DandelionCompassState();
}

class _DandelionCompassState extends State<DandelionCompass> {
  /// 끄는 중인 손가락의 자리 (한 변 기준 좌표). 안 끄는 중이면 null.
  Offset? _finger;
  int? _pointer;

  bool get _interactive => widget.enabled && widget.onBlow != null;

  WindDir? get _selected {
    final p = _finger;
    if (p == null) return null;
    final d = DandelionCompass.dirAt(p, widget.size);
    if (d == null || widget.usedMask & (1 << d.index) != 0) return null;
    return d;
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    setState(() => _finger = e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _finger = e.localPosition);
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _finger = e.localPosition;
    final dir = _selected;
    _pointer = null;
    setState(() => _finger = null);
    if (dir != null) widget.onBlow?.call(dir);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _finger = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    // 동그라미(손잡이)는 손가락을 따라가되 판 안쪽까지만 간다
    var knob = Offset.zero;
    final p = _finger;
    if (p != null) {
      final d = p - Offset(r, r);
      final maxLen = r * 0.5;
      knob = d.distance <= maxLen ? d : d / d.distance * maxLen;
    }
    final paint = CustomPaint(
      painter: _CompassPainter(
        usedMask: widget.usedMask,
        enabled: widget.enabled,
        windsLeft: widget.windsLeft,
        selected: _selected,
        knob: knob,
        showKnob: _interactive || widget.windsLeft != null,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    Widget body = paint;
    if (_interactive) {
      // 끌기를 바로 우리가 받는다: 스크롤되는 목록 안에 있어도 화면이 같이 움직이지 않는다
      body = RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: paint,
        ),
      );
    }
    return SizedBox(width: widget.size, height: widget.size, child: body);
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.usedMask,
    required this.enabled,
    required this.windsLeft,
    required this.selected,
    required this.knob,
    required this.showKnob,
    required this.dark,
  });

  final int usedMask;
  final bool enabled;
  final int? windsLeft;

  /// 끌어서 가리키고 있는 방향 (크게 보인다).
  final WindDir? selected;

  /// 가운데 동그라미의 이동량.
  final Offset knob;
  final bool showKnob;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r * 0.97, Paint()..color = kWindColor.withValues(alpha: enabled ? 0.16 : 0.08));
    canvas.drawCircle(
      c,
      r * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = kWindColor.withValues(alpha: enabled ? 0.7 : 0.3),
    );
    final muted = (dark ? Colors.white : Colors.black).withValues(alpha: 0.22);
    for (final d in WindDir.values) {
      final used = usedMask & (1 << d.index) != 0;
      final pick = d == selected;
      final a = -pi / 2 + d.index * pi / 4;
      final u = Offset(cos(a), sin(a));
      final color = used ? muted : (pick ? const Color(0xFF0B5CB5) : kWindColor.withValues(alpha: enabled ? 1 : 0.55));
      final w = used ? r * 0.05 : (pick ? r * 0.16 : r * 0.1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = color;
      final tip = c + u * r * (pick ? 0.94 : 0.86);
      if (pick) {
        // 고른 방향 뒤에 부드러운 빛
        canvas.drawLine(
          c + u * r * 0.38,
          tip,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.3
            ..color = kWindColor.withValues(alpha: 0.25),
        );
      }
      canvas.drawLine(c + u * r * 0.38, tip, paint);
      final head = pick ? 0.3 : 0.24;
      final left = Offset(cos(a + 2.6), sin(a + 2.6)), right = Offset(cos(a - 2.6), sin(a - 2.6));
      canvas.drawLine(tip, tip + left * r * head, paint);
      canvas.drawLine(tip, tip + right * r * head, paint);
      if (used) {
        // 이미 분 방향에는 작은 가위표
        final m = c + u * r * 0.62;
        final x = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.04
          ..color = muted;
        canvas.drawLine(m + Offset(-r * 0.06, -r * 0.06), m + Offset(r * 0.06, r * 0.06), x);
        canvas.drawLine(m + Offset(r * 0.06, -r * 0.06), m + Offset(-r * 0.06, r * 0.06), x);
      }
    }
    if (showKnob) {
      final center = c + knob;
      final dragging = knob != Offset.zero;
      canvas.drawCircle(center + Offset(0, r * 0.03), r * 0.3, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(center, r * 0.3, Paint()..color = dark ? const Color(0xFF1F2430) : Colors.white);
      canvas.drawCircle(
        center,
        r * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (dragging ? 0.06 : 0.035)
          ..color = kWindColor.withValues(alpha: dragging ? 1 : 0.6),
      );
      final left = windsLeft;
      if (left != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$left',
            style: TextStyle(fontSize: r * 0.34, fontWeight: FontWeight.w900, color: kWindColor, height: 1.0),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      } else {
        // 잡을 수 있다는 표시: 작은 점 세 개짜리 손잡이
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(center + Offset(i * r * 0.1, 0), r * 0.027, Paint()..color = kWindColor.withValues(alpha: 0.7));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.usedMask != usedMask ||
      old.enabled != enabled ||
      old.windsLeft != windsLeft ||
      old.dark != dark ||
      old.selected != selected ||
      old.knob != knob ||
      old.showKnob != showKnob;
}
