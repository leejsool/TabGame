import 'dart:math';

import 'package:flutter/material.dart' hide Curve;

import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';

/// 플레이어 색: 1번(먼저)은 초록, 2번(나중)은 분홍 (책 속 그림과 같은 색).
const List<Color> kSproutsColors = [Color(0xFF2E9E5B), Color(0xFFC2478F)];

const Color kSproutsInk = Color(0xFF1A1523);
const Color kSproutsPaper = Color(0xFFFFFBF0);

Color sproutsColor(int player) => kSproutsColors[player % 2];

/// 콩나물 판 그림. 판 좌표(0~[kBoardW], 0~[kBoardH])를 그려진 크기에 맞게 늘려 그린다.
class SproutsPainter extends CustomPainter {
  const SproutsPainter({
    required this.board,
    this.drawing = const [],
    this.drawingColor = const Color(0xFF2E9E5B),
    this.rejected = const [],
    this.rejectedFade = 0,
    this.hint,
    this.lastCurveT = 1,
    this.popT = 1,
    this.highlightDots = const {},
    this.morphFrom,
    this.morphT = 1,
    this.showGrid = true,
    this.remoteCue = false,
    this.overlay,
    super.repaint,
  });

  final SproutsBoard board;

  /// 지금 손가락으로 그리고 있는 궤적.
  final List<P> drawing;
  final Color drawingColor;

  /// 방금 안 된다고 판정된 궤적 (빨갛게 보였다가 사라진다): [rejectedFade] 1 → 0.
  final List<P> rejected;
  final double rejectedFade;

  /// 힌트 곡선 (점선).
  final List<P>? hint;

  /// 가장 최근 곡선이 그려진 정도 (0~1)와 그 새 점이 나타난 정도 (0~1).
  final double lastCurveT;
  final double popT;

  /// 반짝이게 할 점들.
  final Set<int> highlightDots;

  /// 점과 선이 밀려 옮겨 가는 중이면 밀리기 전의 판과 진행 정도 (0~1). 이때는 새 곡선과 새 점을 아직 그리지 않는다.
  final SproutsBoard? morphFrom;
  final double morphT;
  final bool showGrid;

  /// 상대 기기에서 온 선을 보여 주는 연출: 출발 점에서 물결이 퍼지고, 펜 끝이 빛나며 선을 그리고, 도착 점에서 다시 물결이 퍼진다.
  final bool remoteCue;

  /// 튜토리얼 그림용: 점 좌표계에서 덧그릴 것.
  final void Function(Canvas canvas, double scale)? overlay;

  @override
  void paint(Canvas canvas, Size size) {
    final morphing = morphFrom != null && morphT < 1;
    final board = morphing ? lerpBoard(morphFrom!, this.board, morphT) : this.board;
    final lastCurveT = morphing ? 1.0 : this.lastCurveT;
    final popT = morphing ? 1.0 : this.popT;
    final bounds = board.bounds;
    // 판이 넓어져서 멀어 보여도 선과 점이 너무 작아지지 않게 조금 키워 그린다
    final vf = pow(max(1.0, bounds.scale), 0.7).toDouble();
    final scale = min(size.width / bounds.width, size.height / bounds.height);
    final dx = (size.width - bounds.width * scale) / 2;
    final dy = (size.height - bounds.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.translate(-bounds.x0, -bounds.y0);

    // 종이
    final paper = RRect.fromRectAndRadius(
      Rect.fromLTRB(bounds.x0, bounds.y0, bounds.x1, bounds.y1),
      const Radius.circular(14),
    );
    canvas.drawRRect(paper, Paint()..color = kSproutsPaper);
    if (showGrid) {
      final grid = Paint()
        ..color = const Color(0x14000000)
        ..strokeWidth = 0.8 * max(1.0, bounds.scale);
      canvas.save();
      canvas.clipRRect(paper);
      for (var x = (bounds.x0 / 20).ceil() * 20.0; x < bounds.x1; x += 20) {
        canvas.drawLine(Offset(x, bounds.y0), Offset(x, bounds.y1), grid);
      }
      for (var y = (bounds.y0 / 20).ceil() * 20.0; y < bounds.y1; y += 20) {
        canvas.drawLine(Offset(bounds.x0, y), Offset(bounds.x1, y), grid);
      }
      canvas.restore();
    }
    canvas.drawRRect(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33000000),
    );

    // 곡선
    for (var i = 0; i < board.curves.length; i++) {
      final c = board.curves[i];
      final isLast = i == board.curves.length - 1;
      _stroke(canvas, c.pts, sproutsColor(c.owner), 3.2 * vf, isLast ? lastCurveT : 1);
    }

    // 상대가 그은 선: 출발 점의 물결, 선을 그리는 펜 끝, 도착 점의 물결
    if (remoteCue && !morphing && board.curves.isNotEmpty) _remoteCue(canvas, board, vf, lastCurveT, popT);

    // 힌트
    final h = hint;
    if (h != null && h.length > 1) _dashed(canvas, h, const Color(0xFFF2A900), 3.4 * vf);

    // 안 되는 선 / 지금 그리는 선
    if (rejected.length > 1 && rejectedFade > 0) {
      _stroke(canvas, rejected, const Color(0xFFE5484D).withValues(alpha: 0.35 + 0.65 * rejectedFade), 3.2 * vf, 1);
    }
    if (drawing.length > 1) _stroke(canvas, drawing, drawingColor, 3.2 * vf, 1);

    // 점
    for (var i = 0; i < board.dots.length; i++) {
      final d = board.dots[i];
      final isNew = board.curves.isNotEmpty && i == board.curves.last.mid;
      final r0 = kDotR * vf;
      var r = r0;
      if (isNew) {
        // 새 점은 곡선이 다 그려진 뒤에 통통 튀며 나타난다
        if (lastCurveT < 1) continue;
        r = r0 * (popT < 1 ? Curves.elasticOut.transform(popT).clamp(0.0, 1.4) : 1.0);
      }
      if (highlightDots.contains(i)) {
        canvas.drawCircle(
          Offset(d.pos.x, d.pos.y),
          r + 7 * vf,
          Paint()
            ..color = const Color(0xFFF2A900).withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
      }
      final dead = d.lives <= 0;
      canvas.drawCircle(Offset(d.pos.x, d.pos.y), r, Paint()..color = dead ? const Color(0xFF9A93A6) : kSproutsInk);
      canvas.drawCircle(
        Offset(d.pos.x, d.pos.y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * vf
          ..color = Colors.white.withValues(alpha: 0.9),
      );
      if (!dead && r > 4) {
        // 남은 목숨(= 더 이을 수 있는 선의 수)
        final tp = TextPainter(
          text: TextSpan(text: '${d.lives}', style: TextStyle(color: Colors.white, fontSize: r * 1.25, fontWeight: FontWeight.w900, height: 1)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(d.pos.x - tp.width / 2, d.pos.y - tp.height / 2));
      }
    }

    overlay?.call(canvas, scale);
    canvas.restore();
  }

  void _remoteCue(Canvas canvas, SproutsBoard board, double vf, double t, double pop) {
    final last = board.curves.last;
    final color = sproutsColor(last.owner);
    void ring(P at, double k) {
      // k: 0 → 1 로 퍼지며 옅어지는 물결
      if (k <= 0 || k >= 1) return;
      final r = kDotR * vf + 22 * vf * Curves.easeOut.transform(k);
      canvas.drawCircle(
        Offset(at.x, at.y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * vf * (1 - 0.5 * k)
          ..color = color.withValues(alpha: 0.75 * (1 - k)),
      );
    }

    if (t < 1) {
      // 선을 그리는 동안: 앞 3할은 출발 점에서 물결이 퍼진다
      ring(board.dots[last.from].pos, (t / 0.3).clamp(0.0, 1.0));
      // 펜 끝: 지금까지 그린 곳의 맨 끝에서 빛난다
      final n = max(2, (last.pts.length * t).ceil());
      final head = last.pts[min(n, last.pts.length) - 1];
      canvas.drawCircle(Offset(head.x, head.y), 11 * vf, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawCircle(Offset(head.x, head.y), 6.5 * vf, Paint()..color = color.withValues(alpha: 0.45));
      canvas.drawCircle(Offset(head.x, head.y), 3.4 * vf, Paint()..color = Colors.white.withValues(alpha: 0.95));
    } else if (pop < 1) {
      // 다 그은 뒤: 도착 점에서 물결이 퍼지고, 새 점이 튀어나온다
      ring(board.dots[last.to].pos, pop);
    }
  }

  void _stroke(Canvas canvas, List<P> pts, Color color, double width, double t) {
    if (pts.length < 2) return;
    final n = max(2, (pts.length * t).ceil());
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    for (var i = 1; i < n && i < pts.length; i++) {
      path.lineTo(pts[i].x, pts[i].y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  void _dashed(Canvas canvas, List<P> pts, Color color, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    var on = true;
    var run = 0.0;
    var path = Path()..moveTo(pts.first.x, pts.first.y);
    for (var i = 1; i < pts.length; i++) {
      run += pts[i - 1].dist(pts[i]);
      if (on) {
        path.lineTo(pts[i].x, pts[i].y);
      } else {
        path.moveTo(pts[i].x, pts[i].y);
      }
      if (run >= (on ? 9 : 7)) {
        run = 0;
        if (on) canvas.drawPath(path, paint);
        on = !on;
        path = Path()..moveTo(pts[i].x, pts[i].y);
      }
    }
    if (on) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SproutsPainter old) => true;
}

/// 밀리기 전의 판 [from]에서 밀린 뒤의 판 [to]로 [t]만큼 옮겨 간 모습 (새 곡선·새 점은 뺀다).
SproutsBoard lerpBoard(SproutsBoard from, SproutsBoard to, double t) {
  final k = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
  P mix(P a, P b) => P(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k);
  final dots = <Dot>[
    for (var i = 0; i < from.dots.length && i < to.dots.length; i++) Dot(mix(from.dots[i].pos, to.dots[i].pos), to.dots[i].lives),
  ];
  final curves = <Curve>[
    for (var i = 0; i < from.curves.length && i < to.curves.length; i++)
      Curve(
        from: to.curves[i].from,
        to: to.curves[i].to,
        mid: to.curves[i].mid,
        owner: to.curves[i].owner,
        pts: _mixPath(from.curves[i].pts, to.curves[i].pts, mix),
      ),
  ];
  return SproutsBoard(dots, curves, bounds: Bounds.lerp(from.bounds, to.bounds, k));
}

/// 점 수가 달라도 (선 정리하기로 짧아진 곡선) 길이를 따라 같은 개수로 맞춰 섞는다.
List<P> _mixPath(List<P> a, List<P> b, P Function(P, P) mix) {
  if (a.length == b.length) return [for (var j = 0; j < b.length; j++) mix(a[j], b[j])];
  final n = max(a.length, b.length);
  P at(List<P> pts, double f) => pointAtArc(pts, pathLength(pts) * f);
  return [for (var j = 0; j < n; j++) mix(at(a, j / (n - 1)), at(b, j / (n - 1)))];
}
