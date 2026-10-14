import 'dart:math';

import 'package:flutter/material.dart';

/// 교과학습(프랙털)에서 쓰는 그림들. 모두 규칙대로 되풀이해 그려서, 단계(depth)를 올릴수록 같은 모양이 더 작게 반복된다.

/// 시에르핀스키 삼각형: 삼각형을 3개의 작은 삼각형으로 나누고, 그 각각을 또 같은 방법으로 나눈다.
class SierpinskiTrianglePainter extends CustomPainter {
  const SierpinskiTrianglePainter(this.depth, {this.color = const Color(0xFFB5384A)});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height * 2 / sqrt(3));
    final h = side * sqrt(3) / 2;
    final left = (size.width - side) / 2;
    final top = (size.height - h) / 2;
    final paint = Paint()..color = color;
    void tri(double x, double y, double s, int d) {
      // (x, y) = 아래 왼쪽 꼭짓점, s = 한 변
      if (d == 0) {
        final p = Path()
          ..moveTo(x, y)
          ..lineTo(x + s, y)
          ..lineTo(x + s / 2, y - s * sqrt(3) / 2)
          ..close();
        canvas.drawPath(p, paint);
        return;
      }
      final half = s / 2;
      tri(x, y, half, d - 1);
      tri(x + half, y, half, d - 1);
      tri(x + half / 2, y - half * sqrt(3) / 2, half, d - 1);
    }

    tri(left, top + h, side, depth);
  }

  @override
  bool shouldRepaint(SierpinskiTrianglePainter old) => old.depth != depth || old.color != color;
}

/// 시에르핀스키 카펫: 정사각형을 3×3으로 나누고 한가운데 칸을 비운 뒤, 나머지 8칸에 같은 일을 되풀이한다.
class SierpinskiCarpetPainter extends CustomPainter {
  const SierpinskiCarpetPainter(this.depth, {this.color = const Color(0xFF2B7A9B)});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final paint = Paint()..color = color;
    void carpet(double x, double y, double s, int d) {
      if (d == 0) {
        canvas.drawRect(Rect.fromLTWH(x, y, s + 0.5, s + 0.5), paint);
        return;
      }
      final t = s / 3;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          if (r == 1 && c == 1) continue;
          carpet(x + c * t, y + r * t, t, d - 1);
        }
      }
    }

    carpet(origin.dx, origin.dy, side, depth);
  }

  @override
  bool shouldRepaint(SierpinskiCarpetPainter old) => old.depth != depth || old.color != color;
}

/// 코흐 눈송이: 선분의 가운데 1/3 자리에 뾰족한 삼각 봉우리를 세우는 일을 모든 선분에 되풀이한다.
class KochSnowflakePainter extends CustomPainter {
  const KochSnowflakePainter(this.depth, {this.color = const Color(0xFF2F9E6B)});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = min(size.width, size.height) * 0.46;
    final c = Offset(size.width / 2, size.height * 0.54);
    final pts = [
      for (var k = 0; k < 3; k++) c + Offset(cos(-pi / 2 + k * 2 * pi / 3), sin(-pi / 2 + k * 2 * pi / 3)) * r,
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    void edge(Offset a, Offset b, int d) {
      if (d == 0) {
        path.lineTo(b.dx, b.dy);
        return;
      }
      final v = b - a;
      final p1 = a + v / 3;
      final p2 = a + v * 2 / 3;
      // 진행 방향(시계 방향)의 왼쪽 = 바깥쪽으로 60도 꺾어 올린다
      final peak = p1 + Offset(v.dx / 6 + v.dy * sqrt(3) / 6, v.dy / 6 - v.dx * sqrt(3) / 6);
      edge(a, p1, d - 1);
      edge(p1, peak, d - 1);
      edge(peak, p2, d - 1);
      edge(p2, b, d - 1);
    }

    for (var k = 0; k < 3; k++) {
      edge(pts[k], pts[(k + 1) % 3], depth);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(KochSnowflakePainter old) => old.depth != depth || old.color != color;
}

/// 나뭇가지: 가지 끝마다 더 작은 가지 두 개가 갈라져 나간다 (나무 전체와 같은 모양이 가지마다 반복된다).
class BranchingTreePainter extends CustomPainter {
  const BranchingTreePainter(this.depth, {this.color = const Color(0xFF8A5A3C), this.leaf = const Color(0xFF4FAE62)});

  final int depth;
  final Color color;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.97);
    final trunk = size.height * 0.27;
    void branch(Offset from, double angle, double len, int d) {
      final to = from + Offset(sin(angle), -cos(angle)) * len;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = max(1.0, d * 1.4)
          ..color = d <= 1 ? leaf : color,
      );
      if (d <= 1) return;
      branch(to, angle - 0.42, len * 0.72, d - 1);
      branch(to, angle + 0.42, len * 0.72, d - 1);
    }

    branch(base, 0, trunk, depth + 1);
  }

  @override
  bool shouldRepaint(BranchingTreePainter old) => old.depth != depth;
}

/// 틱택토 판 속의 틱택토 판…: [depth]단계면 한 줄에 3^depth 칸 (1단계 3×3, 2단계 9×9, 3단계 27×27).
/// 굵은 선은 큰 판, 얇은 선은 작은 판. 맨 위 왼쪽 작은 판에 테두리를 쳐서 "작은 부분이 전체와 같다"는 걸 보여 준다.
class TicTacToeFractalPainter extends CustomPainter {
  const TicTacToeFractalPainter(this.depth, {this.color = const Color(0xFFD1495B), this.highlight = true});

  final int depth;
  final Color color;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);

    void board(double x, double y, double s, int level) {
      // level: 이 판 아래로 남은 단계 수. 가장 작은 판은 level == 1.
      final w = max(0.6, s * 0.022);
      final inset = s * 0.06;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w
        ..color = Color.lerp(color, color.withValues(alpha: 0.55), level == 1 ? 1 : 0)!;
      final t = (s - 2 * inset) / 3;
      for (var k = 1; k <= 2; k++) {
        final o = inset + t * k;
        canvas.drawLine(Offset(x + o, y + inset), Offset(x + o, y + s - inset), paint);
        canvas.drawLine(Offset(x + inset, y + o), Offset(x + s - inset, y + o), paint);
      }
      if (level > 1) {
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            board(x + inset + c * t, y + inset + r * t, t, level - 1);
          }
        }
      }
    }

    board(origin.dx, origin.dy, side, depth);

    if (highlight && depth >= 2) {
      // 맨 위 왼쪽 한 칸(= 한 단계 작은 판)을 강조한다
      final inset = side * 0.06;
      final t = (side - 2 * inset) / 3;
      final r = Rect.fromLTWH(origin.dx + inset, origin.dy + inset, t, t).deflate(1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFF2A900),
      );
    }
  }

  @override
  bool shouldRepaint(TicTacToeFractalPainter old) => old.depth != depth || old.color != color;
}

/// 유클리드 도형 풍경 (구름=원, 산=원뿔(삼각형), 나무=삼각형): 교과서 속 매끈한 세계.
class EuclidSceneAmbient extends CustomPainter {
  const EuclidSceneAmbient({required this.fractal});

  /// true면 같은 풍경을 들쭉날쭉한 프랙털 모양으로 그린다.
  final bool fractal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEAF4FB));
    final rng = Random(5);

    // 산
    Path ridge(double base, double amp, int detail) {
      final p = Path()..moveTo(0, h);
      p.lineTo(0, base);
      if (!fractal) {
        p.lineTo(w * 0.28, base - amp);
        p.lineTo(w * 0.5, base);
        p.lineTo(w * 0.75, base - amp * 0.8);
        p.lineTo(w, base);
      } else {
        final pts = <double>[base, base - amp, base, base - amp * 0.8, base];
        // 중점 이동법: 선분 가운데를 무작위로 올렸다 내렸다 하며 같은 일을 되풀이한다
        var line = pts;
        var jitter = amp * 0.35;
        for (var d = 0; d < detail; d++) {
          final next = <double>[];
          for (var i = 0; i < line.length - 1; i++) {
            next
              ..add(line[i])
              ..add((line[i] + line[i + 1]) / 2 + (rng.nextDouble() - 0.5) * jitter);
          }
          next.add(line.last);
          line = next;
          jitter *= 0.55;
        }
        for (var i = 0; i < line.length; i++) {
          p.lineTo(w * i / (line.length - 1), line[i]);
        }
      }
      p.lineTo(w, h);
      p.close();
      return p;
    }

    canvas.drawPath(ridge(h * 0.62, h * 0.36, 6), Paint()..color = const Color(0xFF9AA4B2));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), Paint()..color = const Color(0xFF8FC27A));

    // 구름
    void cloud(Offset c, double r) {
      final paint = Paint()..color = Colors.white;
      if (!fractal) {
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 2.4, height: r * 1.3), paint);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2.4, height: r * 1.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF3E7BFA),
        );
      } else {
        // 몽글몽글: 큰 덩어리 둘레에 작은 덩어리, 그 둘레에 더 작은 덩어리
        void puff(Offset p, double rad, int d) {
          canvas.drawCircle(p, rad, paint);
          if (d == 0) return;
          for (var k = 0; k < 5; k++) {
            final a = -pi + k * pi / 4 + (d.isEven ? 0.2 : -0.1);
            puff(p + Offset(cos(a), sin(a) * 0.8) * rad * 0.9, rad * 0.45, d - 1);
          }
        }

        puff(c, r * 0.62, 2);
      }
    }

    cloud(Offset(w * 0.2, h * 0.2), h * 0.15);
    cloud(Offset(w * 0.52, h * 0.15), h * 0.14);
    cloud(Offset(w * 0.82, h * 0.22), h * 0.15);

    // 나무
    void tree(Offset base, double hgt) {
      if (!fractal) {
        final p = Path()
          ..moveTo(base.dx - hgt * 0.3, base.dy)
          ..lineTo(base.dx + hgt * 0.3, base.dy)
          ..lineTo(base.dx, base.dy - hgt)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF2E7D4A));
      } else {
        void br(Offset from, double ang, double len, int d) {
          final to = from + Offset(sin(ang), -cos(ang)) * len;
          canvas.drawLine(
            from,
            to,
            Paint()
              ..strokeWidth = max(1, d * 1.1)
              ..strokeCap = StrokeCap.round
              ..color = d <= 1 ? const Color(0xFF2E7D4A) : const Color(0xFF5A4636),
          );
          if (d <= 1) return;
          br(to, ang - 0.5, len * 0.7, d - 1);
          br(to, ang + 0.5, len * 0.7, d - 1);
        }

        br(base, 0, hgt * 0.32, 5);
      }
    }

    tree(Offset(w * 0.25, h * 0.92), h * 0.32);
    tree(Offset(w * 0.55, h * 0.84), h * 0.26);
    tree(Offset(w * 0.82, h * 0.94), h * 0.34);
  }

  @override
  bool shouldRepaint(EuclidSceneAmbient old) => old.fractal != fractal;
}
