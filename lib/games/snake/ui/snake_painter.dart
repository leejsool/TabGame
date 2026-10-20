import 'dart:math';

import 'package:flutter/material.dart';

import '../core/snake_body.dart';

/// 뱀 색 (번호 = [SnakeBody.color]). `snakeColorCount`와 수를 맞춘다.
const List<Color> snakeColors = [
  Color(0xFFFF5A5F),
  Color(0xFFFFA62B),
  Color(0xFFFFE04A),
  Color(0xFF7ED957),
  Color(0xFF2ED1A2),
  Color(0xFF3BC9F5),
  Color(0xFF4D7CFE),
  Color(0xFF9B6BFF),
  Color(0xFFFF6FD8),
  Color(0xFFF2F2F2),
  Color(0xFFB5E61D),
  Color(0xFFFF8A65),
  Color(0xFF26C6DA),
  Color(0xFFFFC94D),
];

const Color kSnakeField = Color(0xFF14192B);
const Color kSnakeOutside = Color(0xFF2A1218);
const Color kSnakeWall = Color(0xFFFF4D5E);

/// 화면이 보여 줄 필드의 폭 (짧은 변 기준, 필드 단위). 굵어질수록 조금씩 멀리 본다.
double snakeViewUnits(double radius) => 560 * (1 + max(0.0, radius - 9.6) / 22);

/// 카메라: 화면 가운데에 둘 필드 위치와 배율.
class SnakeCamera {
  double x = 2500, y = 2500, scale = 1;

  /// [target] 뱀을 부드럽게 따라간다 (없으면 그 자리에 머문다).
  void follow(SnakeBody? target, Size size, double dt) {
    if (target != null) {
      x = target.x;
      y = target.y;
      final want = size.shortestSide / snakeViewUnits(target.radius);
      scale += (want - scale) * min(1.0, dt * 2);
    } else if (scale == 1) {
      scale = size.shortestSide / snakeViewUnits(10);
    }
  }
}

/// 필드 전체를 그린다: 바깥, 바닥 무늬, 벽, 먹이, 뱀.
class SnakeFieldPainter extends CustomPainter {
  SnakeFieldPainter({
    required this.field,
    required this.bodies,
    required this.foods,
    required this.camera,
    required this.mySeat,
    required this.clock,
    super.repaint,
  });

  final double field;
  final Iterable<SnakeBody> Function() bodies;
  final Iterable<Food> Function() foods;
  final SnakeCamera camera;
  final int mySeat;

  /// 반짝임용 시계 (초).
  final double Function() clock;

  static final Map<String, TextPainter> _names = {};

  @override
  void paint(Canvas canvas, Size size) {
    final s = camera.scale;
    final half = Offset(size.width / 2, size.height / 2);
    final view = Rect.fromCenter(center: Offset(camera.x, camera.y), width: size.width / s, height: size.height / s);
    canvas.drawRect(Offset.zero & size, Paint()..color = kSnakeOutside);
    canvas.save();
    canvas.translate(half.dx, half.dy);
    canvas.scale(s);
    canvas.translate(-camera.x, -camera.y);
    _floor(canvas, view);
    final t = clock();
    _foods(canvas, view.inflate(20), t);
    final all = bodies().toList();
    SnakeBody? me;
    for (final b in all) {
      if (b.seat == mySeat) {
        me = b;
      } else {
        _snake(canvas, b, view, s, false);
      }
    }
    if (me != null) _snake(canvas, me, view, s, true);
    canvas.restore();
  }

  void _floor(Canvas canvas, Rect view) {
    final fieldRect = Rect.fromLTWH(0, 0, field, field);
    canvas.drawRect(fieldRect, Paint()..color = kSnakeField);
    final area = view.intersect(fieldRect);
    if (area.isEmpty) return;
    // 육각 벌집 무늬 대신 가벼운 점 격자
    const gap = 70.0;
    final dot = Paint()..color = const Color(0xFF26304D);
    final x0 = (area.left / gap).floor() * gap, y0 = (area.top / gap).floor() * gap;
    for (var y = y0; y <= area.bottom; y += gap) {
      final odd = ((y / gap).round()).isOdd;
      for (var x = x0 + (odd ? gap / 2 : 0); x <= area.right; x += gap) {
        canvas.drawCircle(Offset(x, y), 5, dot);
      }
    }
    // 벽: 빨간 띠
    canvas.drawRect(fieldRect, Paint()
      ..color = kSnakeWall.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40);
    canvas.drawRect(fieldRect, Paint()
      ..color = kSnakeWall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10);
  }

  void _foods(Canvas canvas, Rect view, double t) {
    final glow = Paint(), core = Paint();
    for (final f in foods()) {
      if (!view.contains(Offset(f.x, f.y))) continue;
      final c = snakeColors[f.color % snakeColors.length];
      final pulse = 1 + 0.15 * sin(t * 3 + f.id);
      final r = f.radius * pulse;
      glow.color = c.withValues(alpha: 0.28);
      core.color = c;
      canvas.drawCircle(Offset(f.x, f.y), r * 1.9, glow);
      canvas.drawCircle(Offset(f.x, f.y), r, core);
    }
  }

  void _snake(Canvas canvas, SnakeBody b, Rect view, double scale, bool mine) {
    final t = b.trail;
    final r = b.radius;
    // 화면에 걸치는지 대강 본다
    var seen = view.inflate(r * 2).contains(Offset(b.x, b.y));
    for (var i = t.length - 1; !seen && i >= 0; i -= 6) {
      seen = view.inflate(r * 2).contains(Offset(t.xAt(i), t.yAt(i)));
    }
    if (!seen) return;
    final path = _bodyPath(b, view.inflate(r * 2 + 8), r);
    final color = snakeColors[b.color % snakeColors.length];
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (b.boost) {
      canvas.drawPath(path, stroke
        ..color = color.withValues(alpha: 0.30)
        ..strokeWidth = r * 2 + 16);
    }
    if (mine) {
      canvas.drawPath(path, stroke
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = r * 2 + 7);
    }
    canvas.drawPath(path, stroke
      ..color = dark
      ..strokeWidth = r * 2 + 3);
    canvas.drawPath(path, stroke
      ..color = color
      ..strokeWidth = r * 2);
    // 줄무늬 비늘
    final scaleDot = Paint()..color = Color.lerp(color, Colors.black, 0.18)!;
    final gap = max(3, (r * 1.8 / 6).round());
    final near = view.inflate(r * 2 + 8);
    for (var i = t.length - 1 - gap; i >= 0; i -= gap * 2) {
      final p = Offset(t.xAt(i), t.yAt(i));
      if (near.contains(p)) canvas.drawCircle(p, r * 0.55, scaleDot);
    }
    canvas.drawPath(path, stroke
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = r * 0.5);
    _head(canvas, b, color, dark, r);
    if (!mine) _name(canvas, b, r, scale);
  }

  /// 머리에서 꼬리까지의 몸 선. 점수가 높아 몸이 길고 굵을수록 선을 굵게 그리는 값이 비싸지므로,
  /// 굵은 몸은 점을 성기게 잇고(굵기에 비해 6칸 간격은 촘촘하다), 화면 밖으로 나간 토막은 잇지 않는다.
  Path _bodyPath(SnakeBody b, Rect near, double r) {
    final t = b.trail;
    final stride = max(1, (r * 0.8 / SnakeRules.spacing).floor());
    final path = Path();
    var prevX = b.x, prevY = b.y, down = false;
    void visit(double x, double y) {
      final inside = near.contains(Offset(x, y));
      if (inside || down) {
        if (!down) path.moveTo(prevX, prevY);
        path.lineTo(x, y);
        down = inside;
      }
      prevX = x;
      prevY = y;
    }

    visit(b.x, b.y);
    var i = t.length - 1;
    for (; i > 0; i -= stride) {
      visit(t.xAt(i), t.yAt(i));
    }
    if (t.length > 0) visit(t.xAt(0), t.yAt(0));
    return path;
  }

  void _head(Canvas canvas, SnakeBody b, Color color, Color dark, double r) {
    final c = Offset(b.x, b.y);
    canvas.drawCircle(c, r * 1.08 + 1.5, Paint()..color = dark);
    canvas.drawCircle(c, r * 1.08, Paint()..color = color);
    final fx = cos(b.angle), fy = sin(b.angle);
    final white = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF111111);
    for (final side in const [-1.0, 1.0]) {
      final e = c + Offset(fx * r * 0.35 - fy * r * 0.48 * side, fy * r * 0.35 + fx * r * 0.48 * side);
      canvas.drawCircle(e, r * 0.38, white);
      canvas.drawCircle(e + Offset(fx * r * 0.14, fy * r * 0.14), r * 0.2, pupil);
    }
  }

  void _name(Canvas canvas, SnakeBody b, double r, double scale) {
    final label = b.covered ? '${b.name} (CPU)' : b.name;
    final tp = _names.putIfAbsent(label, () {
      if (_names.length > 200) _names.clear();
      return TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w800, color: b.human ? Colors.white : Colors.white70),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    canvas.save();
    canvas.translate(b.x, b.y - r * 1.6 - 14 / scale);
    canvas.scale(1 / scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SnakeFieldPainter old) => true;
}

/// 작은 지도: 필드 테두리, 내 위치(흰 점), 상위 5마리(색 점).
class SnakeMiniMapPainter extends CustomPainter {
  SnakeMiniMapPainter({required this.field, required this.me, required this.top});

  final double field;
  final SnakeBody? me;
  final List<SnakeBody> top;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)), Paint()
      ..color = kSnakeWall.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    Offset at(SnakeBody b) => Offset(b.x / field * size.width, b.y / field * size.height);
    for (final b in top) {
      canvas.drawCircle(at(b), 2.6, Paint()..color = snakeColors[b.color % snakeColors.length]);
    }
    final m = me;
    if (m != null) {
      canvas.drawCircle(at(m), 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(at(m), 4.5, Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(SnakeMiniMapPainter old) => true;
}
