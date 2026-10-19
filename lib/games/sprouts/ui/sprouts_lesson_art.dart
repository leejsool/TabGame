import 'dart:math';

import 'package:flutter/material.dart';

import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';

/// 콩나물 교과학습(위상수학)에서 쓰는 그림들.

const Color _green = Color(0xFF2E9E5B);
const Color _pink = Color(0xFFC2478F);
const Color _ink = Color(0xFF1A1523);

/// [a]에서 [b]로 가는 곡선 ([shape]: 'arc' 활 모양, 'wave' 구불구불, 'loop' 한 번 말린 모양).
List<P> demoCurve(P a, P b, {double bend = 0, String shape = 'arc', int n = 60}) {
  final d = b - a;
  final len = sqrt(d.x * d.x + d.y * d.y);
  final nx = -d.y / len, ny = d.x / len;
  return [
    for (var i = 0; i <= n; i++)
      () {
        final t = i / n;
        var off = 0.0;
        switch (shape) {
          case 'arc':
            off = bend * 4 * t * (1 - t);
          case 'wave':
            off = bend * sin(t * 2 * pi) * 0.9;
          case 'loop':
            off = bend * 4 * t * (1 - t) * (1 + 0.8 * sin(t * 3 * pi));
        }
        return P(a.x + d.x * t + nx * off, a.y + d.y * t + ny * off);
      }(),
  ];
}

/// 점 [dots]를 놓고, 각 수 (시작 점, 끝 점, 곡선)를 차례로 둔 판 (그림용).
SproutsBoard demoBoard(List<P> dots, List<(int, int, List<P>)> moves) {
  final b = SproutsBoard([for (final p in dots) Dot(p, 3)], []);
  var owner = 0;
  for (final (s, e, path) in moves) {
    final r = b.validate(s, e, path.sublist(1, path.length - 1));
    assert(r.ok, r.reason);
    if (r.ok) b.apply(s, e, r, owner);
    owner = 1 - owner;
  }
  return b;
}

/// 콩나물 벌레들 (콘웨이가 알아낸, 가장 빨리 끝난 판의 대략적인 끝 모양). 100×100 칸 안에 그린다.
enum SproutsBug { louse, beetle, cockroach, earwig, scorpion }

extension SproutsBugName on SproutsBug {
  String get label => switch (this) {
        SproutsBug.louse => '이',
        SproutsBug.beetle => '풍뎅이',
        SproutsBug.cockroach => '바퀴',
        SproutsBug.earwig => '집게벌레',
        SproutsBug.scorpion => '전갈',
      };
}

class SproutsBugPainter extends CustomPainter {
  const SproutsBugPainter(this.bug);

  final SproutsBug bug;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    Paint line(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    void dot(double x, double y) {
      canvas.drawCircle(Offset(x, y), 3.6, Paint()..color = _ink);
      canvas.drawCircle(Offset(x, y), 3.6, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white);
    }

    void curve(Color c, double x0, double y0, double cx, double cy, double x1, double y1) {
      canvas.drawPath(Path()..moveTo(x0, y0)..quadraticBezierTo(cx, cy, x1, y1), line(c));
    }

    void seg(Color c, double x0, double y0, double x1, double y1) {
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), line(c));
    }

    switch (bug) {
      case SproutsBug.louse:
        curve(_pink, 50, 6, 8, 50, 50, 94);
        curve(_pink, 50, 6, 92, 50, 50, 94);
        seg(_pink, 50, 6, 50, 94);
        dot(50, 6);
        dot(50, 50);
        dot(50, 94);
      case SproutsBug.beetle:
        // 맨 위 점 하나와 아래 세 점이 만드는 고리 + 맨 아래 점에서 갈라져 올라오는 두 바깥 선과 가운뎃줄
        curve(_green, 50, 5, 33, 10, 26, 31);
        curve(_green, 50, 5, 72, 9, 74, 28);
        curve(_green, 26, 31, 36, 48, 53, 48);
        curve(_green, 74, 28, 68, 44, 53, 48);
        seg(_green, 53, 48, 55, 95);
        curve(_green, 26, 31, 22, 66, 55, 95);
        curve(_green, 74, 28, 86, 76, 55, 95);
        dot(50, 5);
        dot(26, 31);
        dot(74, 28);
        dot(53, 48);
        dot(55, 95);
      case SproutsBug.cockroach:
        // 위아래 두 개의 작은 고리(점 하나가 아랫변 가운데에 걸려 있다)를 양옆의 긴 선 두 개가 이어 준다
        curve(_pink, 26, 8, 50, 0, 74, 9.5);
        curve(_pink, 26, 8, 36, 19, 50.7, 21.4);
        curve(_pink, 50.7, 21.4, 65, 19, 74, 9.5);
        curve(_pink, 26, 8, 12, 44, 29.7, 79.7);
        curve(_pink, 74, 9.5, 85, 41, 73, 74);
        curve(_pink, 29.7, 79.7, 51, 64, 73, 74);
        curve(_pink, 29.7, 79.7, 36, 90, 52.5, 92);
        curve(_pink, 52.5, 92, 68, 92, 73, 74);
        dot(26, 8);
        dot(74, 9.5);
        dot(50.7, 21.4);
        dot(29.7, 79.7);
        dot(73, 74);
        dot(52.5, 92);
      case SproutsBug.earwig:
        canvas.drawCircle(const Offset(50, 28), 24, line(_green));
        seg(_green, 26, 28, 74, 28);
        seg(_green, 50, 52, 50, 70);
        canvas.drawCircle(const Offset(50, 80), 11, line(_green));
        dot(26, 28);
        dot(74, 28);
        dot(50, 28);
        dot(50, 52);
        dot(50, 69);
        dot(50, 91);
      case SproutsBug.scorpion:
        canvas.drawOval(const Rect.fromLTWH(24, 4, 52, 32), line(_pink));
        seg(_pink, 24, 20, 76, 20);
        seg(_pink, 50, 36, 50, 64);
        canvas.drawOval(const Rect.fromLTWH(24, 64, 52, 32), line(_pink));
        seg(_pink, 24, 80, 76, 80);
        dot(24, 20);
        dot(76, 20);
        dot(50, 20);
        dot(50, 36);
        dot(50, 64);
        dot(24, 80);
        dot(76, 80);
        dot(50, 80);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SproutsBugPainter old) => old.bug != bug;
}

/// 점 [nodes]와 선 [edges]로 된 네트워크 (그래프). 좌표는 0~1 안에.
class GraphPainter extends CustomPainter {
  const GraphPainter(this.nodes, this.edges, {this.color = _pink});

  final List<Offset> nodes;
  final List<(int, int)> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(int i) => Offset(nodes[i].dx * size.width, nodes[i].dy * size.height);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final (a, b) in edges) {
      canvas.drawLine(at(a), at(b), line);
    }
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(at(i), 5.5, Paint()..color = _ink);
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}

/// 뫼비우스의 띠(반 바퀴 비튼 띠)와 보통의 띠(고리)를 3차원으로 그린다. [angle]은 돌려 보는 각도(라디안).
class MobiusPainter extends CustomPainter {
  const MobiusPainter({required this.twisted, required this.angle});

  final bool twisted;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    const nu = 90, nv = 6;
    const radius = 1.0, half = 0.42;
    final scale = min(size.width, size.height) * 0.36;
    final center = Offset(size.width / 2, size.height / 2);
    const tilt = 1.0; // 위에서 내려다보는 기울기(라디안)

    // 3차원 점 → (화면 x, y, 깊이)
    (double, double, double) project(double u, double v) {
      final phi = twisted ? u / 2 : 0.0;
      final rr = radius + v * half * sin(phi);
      final z = v * half * cos(phi);
      var x = rr * cos(u), y = rr * sin(u);
      final ca = cos(angle), sa = sin(angle);
      final x2 = x * ca - y * sa, y2 = x * sa + y * ca;
      x = x2;
      y = y2;
      final y3 = y * cos(tilt) - z * sin(tilt);
      final d = y * sin(tilt) + z * cos(tilt);
      return (x, y3, d);
    }

    final quads = <(double, Path, Color)>[];
    for (var i = 0; i < nu; i++) {
      final u0 = 2 * pi * i / nu, u1 = 2 * pi * (i + 1) / nu;
      for (var j = 0; j < nv; j++) {
        final v0 = -1 + 2 * j / nv, v1 = -1 + 2 * (j + 1) / nv;
        final pts = [project(u0, v0), project(u1, v0), project(u1, v1), project(u0, v1)];
        final path = Path()
          ..moveTo(center.dx + pts[0].$1 * scale, center.dy + pts[0].$2 * scale)
          ..lineTo(center.dx + pts[1].$1 * scale, center.dy + pts[1].$2 * scale)
          ..lineTo(center.dx + pts[2].$1 * scale, center.dy + pts[2].$2 * scale)
          ..lineTo(center.dx + pts[3].$1 * scale, center.dy + pts[3].$2 * scale)
          ..close();
        final depth = pts.map((p) => p.$3).reduce((a, b) => a + b) / 4;
        // 길이 방향으로 색이 이어지도록 (한 바퀴 돌면 처음 색으로 돌아온다)
        final hue = (u0 / (2 * pi)) * 360;
        final stripe = j.isEven ? 0.0 : 0.06;
        final light = 0.46 + 0.10 * sin(u0 * 2) + stripe;
        quads.add((depth, path, HSLColor.fromAHSL(1, hue, 0.55, light.clamp(0.3, 0.7)).toColor()));
      }
    }
    quads.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, path, color) in quads) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(MobiusPainter old) => old.twisted != twisted || old.angle != angle;
}

/// 컵이 점점 도넛이 되는 모습 ([stage] 0~1: 0 = 손잡이 달린 컵, 1 = 도넛). 구멍은 늘 하나뿐이다. 100×100 칸 안에 그린다.
class CupToDonutPainter extends CustomPainter {
  const CupToDonutPainter(this.stage);

  final double stage;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    double l(double a, double b) => a + (b - a) * stage;

    // 몸통(컵)과 손잡이 바깥 모양을 합치고, 손잡이 구멍을 뺀다
    final bodyCx = l(36, 50), bodyW = l(50, 72), bodyH = l(58, 72), bodyR = l(7, 36);
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(bodyCx, 54), width: bodyW, height: bodyH), Radius.circular(bodyR)));
    final handle = Path()..addOval(Rect.fromCenter(center: Offset(l(70, 50), 54), width: l(30, 72), height: l(38, 72)));
    final hole = Path()..addOval(Rect.fromCenter(center: Offset(l(70, 50), 54), width: l(12, 24), height: l(20, 24)));
    final solid = Path.combine(PathOperation.difference, Path.combine(PathOperation.union, body, handle), hole);

    canvas.drawPath(solid, Paint()..color = const Color(0xFFF4EEE0));
    // 컵 속(오목한 곳): 도넛이 되면서 사라진다
    if (stage < 0.85) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyCx, 54 - bodyH / 2 + 8), width: bodyW * 0.78, height: 10),
        Paint()..color = const Color(0xFFD9D0BC).withValues(alpha: (1 - stage / 0.85).clamp(0.0, 1.0)),
      );
    }
    canvas.drawPath(
      solid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF6B6354),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CupToDonutPainter old) => old.stage != stage;
}
