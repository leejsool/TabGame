import 'dart:math';

import 'package:flutter/material.dart';

import '../core/uttt_rules.dart';
import '../game/uttt_controller.dart';

const Color kXColor = Color(0xFFE5484D);
const Color kOColor = Color(0xFF3E7BFA);

Color sideColor(int side) => side == kX ? kXColor : kOColor;

/// X 또는 O 표시를 [r] 안에 그린다. [t]는 0~1: 선이 그어지듯/원이 그려지듯 나타난다.
void drawMark(Canvas canvas, int side, Rect r, double t, {double alpha = 1, double? strokeWidth}) {
  final sw = strokeWidth ?? r.width * 0.13;
  final paint = Paint()
    ..color = sideColor(side).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = sw
    ..strokeCap = StrokeCap.round;
  final a = r.deflate(r.width * 0.23);
  if (side == kX) {
    final t1 = (t * 2).clamp(0.0, 1.0);
    final t2 = (t * 2 - 1).clamp(0.0, 1.0);
    canvas.drawLine(a.topLeft, Offset.lerp(a.topLeft, a.bottomRight, t1)!, paint);
    if (t2 > 0) canvas.drawLine(a.topRight, Offset.lerp(a.topRight, a.bottomLeft, t2)!, paint);
  } else {
    canvas.drawArc(a, -pi / 2, 2 * pi * t.clamp(0.0, 1.0), false, paint);
  }
}

/// 판의 크기에서 작은 판/칸의 자리를 계산한다.
class UtttLayout {
  UtttLayout(this.side)
      : pad = side * 0.03,
        gap = side * 0.028 {
    sb = (side - 2 * pad - 2 * gap) / 3;
  }

  final double side;
  final double pad;
  final double gap;
  late final double sb;

  Rect boardRect(int b) =>
      Rect.fromLTWH(pad + (b % 3) * (sb + gap), pad + (b ~/ 3) * (sb + gap), sb, sb);

  /// 작은 판 안쪽 칸 영역 (타일 안쪽 여백을 뺀 부분).
  Rect inner(int b) => boardRect(b).deflate(sb * 0.05);

  Rect cellRect(int b, int c) {
    final r = inner(b);
    final cs = r.width / 3;
    return Rect.fromLTWH(r.left + (c % 3) * cs, r.top + (c ~/ 3) * cs, cs, cs);
  }

  /// 화면 좌표 → 수 (b*9+c). 작은 판 밖(틈)이면 null.
  int? moveAt(Offset p) {
    for (var b = 0; b < 9; b++) {
      if (!boardRect(b).inflate(gap * 0.4).contains(p)) continue;
      final r = inner(b);
      final cs = r.width / 3;
      final col = ((p.dx - r.left) / cs).floor().clamp(0, 2);
      final row = ((p.dy - r.top) / cs).floor().clamp(0, 2);
      return b * 9 + row * 3 + col;
    }
    return null;
  }
}

/// 9×9 판. 칸을 누르면 [onMove]로 알린다.
class UtttBoard extends StatefulWidget {
  const UtttBoard({super.key, required this.controller, required this.onMove});

  final UtttController controller;
  final void Function(int move) onMove;

  @override
  State<UtttBoard> createState() => _UtttBoardState();
}

class _UtttBoardState extends State<UtttBoard> with TickerProviderStateMixin {
  UtttController get c => widget.controller;

  late final AnimationController _mark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  late final AnimationController _capture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  late final AnimationController _end = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  int _serial = 0;
  bool _wasOver = false;

  @override
  void initState() {
    super.initState();
    _serial = c.moveSerial;
    _wasOver = c.isOver;
    if (c.isOver) _end.value = 1;
    c.addListener(_onController);
    _syncPulse();
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _mark.dispose();
    _capture.dispose();
    _end.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse() {
    if (c.isOver) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _onController() {
    if (c.moveSerial != _serial) {
      _serial = c.moveSerial;
      if (c.lastMove >= 0) _mark.forward(from: 0);
      if (c.lastCaptured >= 0) _capture.forward(from: 0);
    }
    if (c.isOver && !_wasOver) {
      _end.forward(from: 0);
    } else if (!c.isOver && _wasOver) {
      _end.value = 0;
    }
    _wasOver = c.isOver;
    _syncPulse();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth, box.maxHeight);
        final layout = UtttLayout(side);
        return SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final m = layout.moveAt(d.localPosition);
              if (m != null) widget.onMove(m);
            },
            child: CustomPaint(
              painter: _BoardPainter(
                c: c,
                layout: layout,
                mark: _mark,
                capture: _capture,
                end: _end,
                pulse: _pulse,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.c,
    required this.layout,
    required this.mark,
    required this.capture,
    required this.end,
    required this.pulse,
  }) : super(repaint: Listenable.merge([c, mark, capture, end, pulse]));

  final UtttController c;
  final UtttLayout layout;
  final Animation<double> mark;
  final Animation<double> capture;
  final Animation<double> end;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final s = c.state;
    final side = layout.side;

    // 나무 판
    final frame = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(side * 0.04));
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7D9A8), Color(0xFFEBC083)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      frame.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFD9A55F),
    );

    // 지금 둘 수 있는 작은 판들
    final active = <int>{};
    if (!s.isOver) {
      if (s.next >= 0) {
        active.add(s.next);
      } else {
        for (var b = 0; b < 9; b++) {
          if (s.boardOpen(b)) active.add(b);
        }
      }
    }
    final turnColor = sideColor(s.turn);
    final p = pulse.value;

    for (var b = 0; b < 9; b++) {
      final tile = layout.boardRect(b);
      final rr = RRect.fromRectAndRadius(tile, Radius.circular(layout.sb * 0.09));
      final owner = s.boardOwner(b);
      var base = const Color(0xFFFFF7E8);
      if (owner == 1) base = Color.lerp(base, kXColor, 0.2)!;
      if (owner == 2) base = Color.lerp(base, kOColor, 0.2)!;
      if (owner == 3) base = Color.lerp(base, const Color(0xFF8A8A8A), 0.25)!;
      if (active.contains(b)) base = Color.lerp(base, turnColor, 0.10 + 0.06 * p)!;

      canvas.drawRRect(
        rr.shift(Offset(0, layout.sb * 0.02)),
        Paint()..color = Colors.brown.withValues(alpha: 0.18),
      );
      canvas.drawRRect(rr, Paint()..color = base);
      if (active.contains(b)) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = layout.sb * (0.03 + 0.012 * p)
            ..color = turnColor.withValues(alpha: 0.55 + 0.4 * p),
        );
      }

      // 안쪽 격자선
      final inner = layout.inner(b);
      final line = Paint()
        ..color = const Color(0xFF8B6B3E).withValues(alpha: 0.38)
        ..strokeWidth = max(1.2, layout.sb * 0.014)
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i <= 2; i++) {
        final x = inner.left + inner.width * i / 3;
        final y = inner.top + inner.height * i / 3;
        canvas.drawLine(Offset(x, inner.top + 4), Offset(x, inner.bottom - 4), line);
        canvas.drawLine(Offset(inner.left + 4, y), Offset(inner.right - 4, y), line);
      }

      // 칸의 표시
      final owned = owner == 1 || owner == 2;
      for (var cell = 0; cell < 9; cell++) {
        final r = layout.cellRect(b, cell);
        final who = s.cellOwner(b, cell);
        final move = b * 9 + cell;
        if (who == 0) {
          // 둘 수 있는 칸에 작은 점
          if (active.contains(b) && c.humanCanAct) {
            canvas.drawCircle(r.center, r.width * 0.07, Paint()..color = turnColor.withValues(alpha: 0.35));
          }
          continue;
        }
        if (move == c.lastMove && !owned) {
          canvas.drawCircle(r.center, r.width * 0.44, Paint()..color = sideColor(who - 1).withValues(alpha: 0.14));
        }
        final t = move == c.lastMove ? Curves.easeOut.transform(mark.value) : 1.0;
        drawMark(canvas, who - 1, r, t, alpha: owned ? 0.3 : 1);
      }

      // 차지한 판 위의 큰 표시
      if (owned) {
        final t = b == c.lastCaptured ? Curves.easeOutBack.transform(capture.value.clamp(0.0, 1.0)) : 1.0;
        final big = Rect.fromCenter(
          center: tile.center,
          width: tile.width * (0.6 + 0.4 * t.clamp(0.0, 1.2)),
          height: tile.height * (0.6 + 0.4 * t.clamp(0.0, 1.2)),
        );
        drawMark(
          canvas,
          owner - 1,
          big.deflate(tile.width * 0.02),
          b == c.lastCaptured ? capture.value.clamp(0.0, 1.0) : 1,
          alpha: 0.92,
          strokeWidth: tile.width * 0.1,
        );
      }
    }

    // 이긴 줄
    final win = s.winningLine;
    if (win != null && end.value > 0) {
      final a = layout.boardRect(win[0]).center;
      final z = layout.boardRect(win[2]).center;
      final tip = Offset.lerp(a, z, Curves.easeOut.transform(end.value))!;
      final color = sideColor(s.outcome == Outcome.xWins ? kX : kO);
      canvas.drawLine(
        a,
        tip,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = layout.sb * 0.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        tip,
        Paint()
          ..color = color
          ..strokeWidth = layout.sb * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
