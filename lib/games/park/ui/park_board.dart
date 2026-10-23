import 'package:flutter/material.dart';

import '../core/park_rules.dart';

const Color kParkColor = Color(0xFF3E9B5F);
const Color kLeftColor = Color(0xFF2F6FDE);
const Color kRightColor = Color(0xFFE5730B);

/// 공원 판. 점 A(왼쪽 위)에서 손가락으로 그으면 길이 이어진다 (오른쪽·아래로만, 되돌아가면 지워진다).
///
/// 구간마다 숲이 진행 방향의 바로 왼편이면 파랑 "왼", 오른편이면 주황 "오"를 숲 쪽에 붙인다.
class ParkBoard extends StatefulWidget {
  const ParkBoard({super.key, required this.stage, required this.steps, this.onChanged, this.onDone, this.compact = false});

  final ParkStage stage;
  final List<Walk> steps;

  /// 길이 바뀔 때마다 (null이면 그을 수 없는 그림).
  final ValueChanged<List<Walk>>? onChanged;

  /// 손가락을 뗐을 때.
  final VoidCallback? onDone;

  /// 찾은 길 목록의 작은 그림 (글자·A/B 없이).
  final bool compact;

  @override
  State<ParkBoard> createState() => _ParkBoardState();
}

class _ParkBoardState extends State<ParkBoard> {
  bool _drawing = false;

  /// 판 그림의 틀: 점 사이 간격과 A의 위치.
  ({double gap, Offset origin}) _frame(Size size) {
    final n = widget.stage.size;
    final pad = widget.compact ? 0.18 : 0.62;
    final gap = (size.shortestSide / (n + pad * 2));
    final w = gap * n;
    return (gap: gap, origin: Offset((size.width - w) / 2, (size.height - w) / 2));
  }

  Pt? _nearest(Offset p, Size size, {double reach = 0.45}) {
    final f = _frame(size);
    final n = widget.stage.size;
    final c = ((p.dx - f.origin.dx) / f.gap).round();
    final r = ((p.dy - f.origin.dy) / f.gap).round();
    if (r < 0 || r > n || c < 0 || c > n) return null;
    final d = (p - (f.origin + Offset(c * f.gap, r * f.gap))).distance;
    return d <= f.gap * reach ? (r, c) : null;
  }

  /// 긋는 동안의 길. 손가락 움직임은 화면을 다시 그리기 전에도 연달아 오므로 부모의 [ParkBoard.steps]를 기다리지 않는다.
  List<Walk> _live = const [];

  void _set(List<Walk> steps) {
    _live = steps;
    widget.onChanged!(steps);
  }

  void _start(Offset p, Size size) {
    final pt = _nearest(p, size, reach: 0.6);
    final end = widget.stage.points(widget.steps).last;
    if (pt == widget.stage.start) {
      _drawing = true;
      _set(const []);
    } else if (pt != null && pt == end && widget.steps.isNotEmpty) {
      _drawing = true; // 그리던 길 끝에서 이어 긋기
      _live = widget.steps;
    }
  }

  void _move(Offset p, Size size) {
    if (!_drawing) return;
    final pt = _nearest(p, size);
    if (pt == null) return;
    final steps = List<Walk>.of(_live);
    final pts = widget.stage.points(steps);
    // 지나온 점으로 돌아가면 거기까지 지운다
    final back = pts.indexOf(pt);
    if (back >= 0) {
      if (back < steps.length) _set(steps.sublist(0, back));
      return;
    }
    // 앞으로: 손가락 쪽으로 한 칸씩 (오른쪽·아래로만, 더 많이 남은 쪽 먼저)
    var (r, c) = pts.last;
    var moved = false;
    while ((r, c) != pt) {
      final right = pt.$2 - c, down = pt.$1 - r;
      if (right > 0 && right >= down) {
        steps.add(Walk.right);
        c++;
      } else if (down > 0) {
        steps.add(Walk.down);
        r++;
      } else {
        break; // 왼쪽·위로는 갈 수 없다 (최단경로)
      }
      moved = true;
    }
    if (moved) _set(steps);
  }

  void _end() {
    if (!_drawing) return;
    _drawing = false;
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight.isFinite ? box.maxHeight : box.maxWidth);
      final paint = CustomPaint(
        size: size,
        painter: _ParkPainter(
          stage: widget.stage,
          steps: widget.steps,
          frame: _frame(size),
          compact: widget.compact,
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
      );
      if (widget.onChanged == null) return paint;
      return GestureDetector(
        onPanStart: (d) => _start(d.localPosition, size),
        onPanUpdate: (d) => _move(d.localPosition, size),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: paint,
      );
    });
  }
}

class _ParkPainter extends CustomPainter {
  _ParkPainter({required this.stage, required this.steps, required this.frame, required this.compact, required this.dark});

  final ParkStage stage;
  final List<Walk> steps;
  final ({double gap, Offset origin}) frame;
  final bool compact;
  final bool dark;

  Offset _at(Pt p) => frame.origin + Offset(p.$2 * frame.gap, p.$1 * frame.gap);

  void _text(Canvas c, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, color: color, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = stage.size;
    final g = frame.gap;
    final ink = dark ? const Color(0xFFD8E2D6) : const Color(0xFF4A5A4C);
    final lawn = dark ? const Color(0xFF243328) : const Color(0xFFEAF5E4);
    canvas.drawRect(Rect.fromPoints(_at((0, 0)), _at((n, n))), Paint()..color = lawn);

    // 숲 (○)
    for (final (r, c) in stage.forests) {
      final center = _at((r, c)) + Offset(g / 2, g / 2);
      canvas.drawCircle(center, g * 0.24, Paint()..color = const Color(0xFF7BC47F));
      canvas.drawCircle(
        center,
        g * 0.24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1 : g * 0.025
          ..color = const Color(0xFF2D6A3A),
      );
    }

    // 산책로 (격자 선)
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.75)
      ..strokeWidth = compact ? 1 : (g * 0.025).clamp(1.5, 3.0);
    for (var i = 0; i <= n; i++) {
      canvas.drawLine(_at((i, 0)), _at((i, n)), grid);
      canvas.drawLine(_at((0, i)), _at((n, i)), grid);
    }

    // 지금 그은 길: 구간마다 숲 쪽 색
    final pts = stage.points(steps);
    final sides = stage.sides(steps);
    final width = compact ? g * 0.12 : (g * 0.09).clamp(5.0, 14.0);
    for (var i = 0; i < steps.length; i++) {
      final color = switch (sides[i]) {
        ForestSide.left => kLeftColor,
        ForestSide.right => kRightColor,
        ForestSide.none => dark ? const Color(0xFFF0F0F0) : const Color(0xFF263238),
      };
      canvas.drawLine(
        _at(pts[i]),
        _at(pts[i + 1]),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
      if (!compact && sides[i] != ForestSide.none) _badge(canvas, pts[i], steps[i], sides[i]);
      if (!compact) _arrow(canvas, pts[i], pts[i + 1], color);
    }

    if (!compact) {
      // A, B
      final dotR = (g * 0.08).clamp(6.0, 12.0);
      canvas.drawCircle(_at(stage.start), dotR, Paint()..color = kParkColor);
      canvas.drawCircle(_at(stage.goal), dotR, Paint()..color = const Color(0xFFC62828));
      _text(canvas, 'A', _at(stage.start) + Offset(-g * 0.28, -g * 0.28), g * 0.26, ink);
      _text(canvas, 'B', _at(stage.goal) + Offset(g * 0.28, g * 0.28), g * 0.26, ink);
    }
  }

  /// 숲이 있는 쪽 (구간 가운데에서 숲 칸 쪽으로 조금) 에 "왼"/"오" 표시.
  void _badge(Canvas canvas, Pt from, Walk step, ForestSide side) {
    final g = frame.gap;
    final mid = _at(from) + (step == Walk.right ? Offset(g / 2, 0) : Offset(0, g / 2));
    // 오른쪽으로 걸을 때: 왼편 = 위, 오른편 = 아래. 아래로 걸을 때: 왼편 = 오른쪽(동), 오른편 = 왼쪽(서).
    final toLeft = step == Walk.right ? const Offset(0, -1) : const Offset(1, 0);
    final dir = side == ForestSide.left ? toLeft : -toLeft;
    final p = mid + dir * g * 0.19;
    final color = side == ForestSide.left ? kLeftColor : kRightColor;
    final r = g * 0.11;
    canvas.drawCircle(p, r, Paint()..color = color);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    _text(canvas, side == ForestSide.left ? '왼' : '오', p, r * 1.05, Colors.white);
  }

  void _arrow(Canvas canvas, Pt a, Pt b, Color color) {
    final pa = _at(a), pb = _at(b);
    final d = (pb - pa) / (pb - pa).distance;
    final tip = pa + (pb - pa) * 0.62;
    final s = frame.gap * 0.09;
    final n = Offset(-d.dy, d.dx);
    final path = Path()
      ..moveTo(tip.dx + d.dx * s, tip.dy + d.dy * s)
      ..lineTo(tip.dx - d.dx * s + n.dx * s, tip.dy - d.dy * s + n.dy * s)
      ..lineTo(tip.dx - d.dx * s - n.dx * s, tip.dy - d.dy * s - n.dy * s)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ParkPainter old) => true;
}
