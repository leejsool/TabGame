import 'dart:math';

import 'package:flutter/material.dart';

import 'yacht_look.dart';

/// 구르는 주사위를 입체(정육면체)로 그린다.
///
/// [ax]·[ay]·[az]만큼 돌아간 모습이고, 셋 다 0이면 [value] 눈이 정면을 보는 (멈춘 주사위와 같은) 모습이다.
class YachtCubePainter extends CustomPainter {
  YachtCubePainter({required this.value, required this.ax, required this.ay, required this.az, this.lift = 0, this.daesung = false});

  final int value;

  /// 대성One 주사위 (초록 몸통, 흰 눈, 1 면에는 흰 동그라미 + 학교 로고).
  final bool daesung;
  final double ax, ay, az;

  /// 바닥에서 떠오른 정도 (0~1). 클수록 그림자가 멀어지고 옅어진다.
  final double lift;

  /// 면: 바깥쪽 방향 N, 면 위의 가로 U · 세로 V, 그 면의 눈. (마주 보는 면의 합은 7)
  static const _faces = [
    ([0.0, 0.0, 1.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], 1),
    ([0.0, 0.0, -1.0], [-1.0, 0.0, 0.0], [0.0, 1.0, 0.0], 6),
    ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0], 2),
    ([-1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0], 5),
    ([0.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, -1.0], 3),
    ([0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0], 4),
  ];

  static List<double> _mul(List<double> a, List<double> b) => [
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c],
      ];

  static List<double> _apply(List<double> m, List<double> v) => [
        m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
        m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
        m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final h = s * 0.368; // 정면을 볼 때 멈춘 주사위와 같은 크기로 보이는 반 변 길이
    final d = h * 5; // 눈(카메라)까지의 거리
    final center = Offset(s / 2, s / 2);

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(0, s * (0.06 + 0.3 * lift)), width: s * (0.9 - 0.25 * lift), height: s * (0.82 - 0.3 * lift)),
      Paint()..color = Colors.black.withValues(alpha: 0.2 - 0.1 * lift),
    );

    // 돌리기: Rz · Rx · Ry · (고른 눈이 정면을 보게 하는 기본 자세)
    final base = _faces.firstWhere((f) => f.$4 == value);
    final sx = sin(ax), cx = cos(ax), sy = sin(ay), cy = cos(ay), sz = sin(az), cz = cos(az);
    var m = <double>[...base.$2, ...base.$3, ...base.$1];
    m = _mul([cy, 0, sy, 0, 1, 0, -sy, 0, cy], m);
    m = _mul([1, 0, 0, 0, cx, -sx, 0, sx, cx], m);
    m = _mul([cz, -sz, 0, sz, cz, 0, 0, 0, 1], m);

    Offset project(double x, double y, double z) {
      final f = d / (d - z);
      return center + Offset(x * f, y * f);
    }

    for (final face in _faces) {
      final n = _apply(m, face.$1);
      if (n[2] * d - h <= 0) continue; // 뒤쪽을 보는 면
      final u = _apply(m, face.$2), v = _apply(m, face.$3);
      Offset at(double a, double b) => project(
            h * (n[0] + a * u[0] + b * v[0]),
            h * (n[1] + a * u[1] + b * v[1]),
            h * (n[2] + a * u[2] + b * v[2]),
          );

      // 면: 조금 작게 그린 네모에 굵은 둥근 테두리를 둘러 모서리를 둥글린다
      const inset = 0.74;
      final quad = Path()..addPolygon([at(-inset, -inset), at(inset, -inset), at(inset, inset), at(-inset, inset)], true);
      final shade = (0.62 + 0.38 * n[2]).clamp(0.0, 1.0);
      final color = daesung
          ? Color.lerp(kDaesungEdge, kDaesungBody, shade)!
          : Color.lerp(const Color(0xFF8D8778), kYachtDieBody, shade)!;
      canvas.drawPath(quad, Paint()..color = color);
      canvas.drawPath(
        quad,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = h * 0.52 * d / (d - h * n[2]),
      );

      if (daesung && face.$4 == 1) {
        _logoFace(canvas, at, shade);
        continue;
      }

      // 눈
      final pips = kYachtPips[face.$4];
      final r = face.$4 == 1 ? 0.283 : 0.185;
      final paint = Paint()
        ..color = daesung
            ? Color.lerp(kDaesungEdge, Colors.white, 0.5 + 0.5 * shade)!
            : Color.lerp(Colors.black, face.$4 == 1 ? kYachtDieOne : kYachtDiePip, 0.55 + 0.45 * shade)!;
      for (final i in pips) {
        final gx = (i % 3 - 1) * 0.5, gy = (i ~/ 3 - 1) * 0.5;
        canvas.drawPath(
          Path()..addPolygon([for (var k = 0; k < 14; k++) at(gx + r * cos(k * pi / 7), gy + r * sin(k * pi / 7))], true),
          paint,
        );
      }
    }
  }

  /// 대성One 주사위의 1 면: 흰 동그라미 위에 로고 (면의 기울기를 따라 비스듬히).
  void _logoFace(Canvas canvas, Offset Function(double a, double b) at, double shade) {
    final disc = Path()..addPolygon([for (var k = 0; k < 28; k++) at(0.66 * cos(k * pi / 14), 0.66 * sin(k * pi / 14))], true);
    canvas.drawPath(disc, Paint()..color = Color.lerp(const Color(0xFFB8C8BC), Colors.white, shade)!);
    final logo = DaesungLogo.image;
    if (logo == null) return;
    // 그림의 (0,0) · (w,0) · (0,h)를 면 위의 세 점으로 옮기는 기울인 변환
    final o = at(-0.5, -0.5), x = at(0.5, -0.5), y = at(-0.5, 0.5);
    final w = logo.width.toDouble(), h = logo.height.toDouble();
    final m = Matrix4.identity()
      ..setEntry(0, 0, (x.dx - o.dx) / w)
      ..setEntry(1, 0, (x.dy - o.dy) / w)
      ..setEntry(0, 1, (y.dx - o.dx) / h)
      ..setEntry(1, 1, (y.dy - o.dy) / h)
      ..setEntry(0, 3, o.dx)
      ..setEntry(1, 3, o.dy);
    canvas.save();
    canvas.transform(m.storage);
    canvas.drawImage(logo, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  @override
  bool shouldRepaint(YachtCubePainter old) =>
      old.value != value || old.ax != ax || old.ay != ay || old.az != az || old.lift != lift || old.daesung != daesung;
}
