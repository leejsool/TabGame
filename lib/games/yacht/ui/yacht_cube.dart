import 'dart:math';
import 'dart:typed_data';

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

  @override
  void paint(Canvas canvas, Size size) => paintYachtCube(canvas, size.width, value: value, ax: ax, ay: ay, az: az, lift: lift, daesung: daesung);

  @override
  bool shouldRepaint(YachtCubePainter old) =>
      old.value != value || old.ax != ax || old.ay != ay || old.az != az || old.lift != lift || old.daesung != daesung;
}

/// 면: 바깥쪽 방향 N, 면 위의 가로 U · 세로 V (각 3칸씩 9칸), 그리고 그 면의 눈. (마주 보는 면의 합은 7)
const List<double> _faceAxes = [
  0, 0, 1, 1, 0, 0, 0, 1, 0, //
  0, 0, -1, -1, 0, 0, 0, 1, 0, //
  1, 0, 0, 0, 0, -1, 0, 1, 0, //
  -1, 0, 0, 0, 0, 1, 0, 1, 0, //
  0, 1, 0, 1, 0, 0, 0, 0, -1, //
  0, -1, 0, 1, 0, 0, 0, 0, 1, //
];
const List<int> _facePips = [1, 6, 2, 5, 3, 4];

/// 눈(동그라미)을 다각형으로 그릴 때의 꼭짓점 방향: 14각형, 로고 바탕은 28각형.
final Float64List _cos14 = Float64List.fromList([for (var k = 0; k < 14; k++) cos(k * pi / 7)]);
final Float64List _sin14 = Float64List.fromList([for (var k = 0; k < 14; k++) sin(k * pi / 7)]);
final Float64List _cos28 = Float64List.fromList([for (var k = 0; k < 28; k++) cos(k * pi / 14)]);
final Float64List _sin28 = Float64List.fromList([for (var k = 0; k < 28; k++) sin(k * pi / 14)]);

// 매 프레임 주사위마다 불리므로 계산에 쓰는 칸과 붓은 한 번 만들어 두고 다시 쓴다
// (구르는 동안 작은 목록 · 붓을 수백 개씩 새로 만들면 저성능 기기에서 프레임이 떨어진다).
final Float64List _m = Float64List(9), _m2 = Float64List(9), _rot = Float64List(9);
final Paint _fill = Paint();
final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round;
final Paint _logoPaint = Paint()..filterQuality = FilterQuality.medium;
final Float64List _logoMatrix = Float64List(16);

/// a · b (3x3, 줄 먼저)를 [out]에 담는다.
void _mul(Float64List a, Float64List b, Float64List out) {
  for (var r = 0; r < 3; r++) {
    final a0 = a[r * 3], a1 = a[r * 3 + 1], a2 = a[r * 3 + 2];
    out[r * 3] = a0 * b[0] + a1 * b[3] + a2 * b[6];
    out[r * 3 + 1] = a0 * b[1] + a1 * b[4] + a2 * b[7];
    out[r * 3 + 2] = a0 * b[2] + a1 * b[5] + a2 * b[8];
  }
}

void _setRot(double a, double b, double c, double d, double e, double f, double g, double h, double i) {
  _rot[0] = a;
  _rot[1] = b;
  _rot[2] = c;
  _rot[3] = d;
  _rot[4] = e;
  _rot[5] = f;
  _rot[6] = g;
  _rot[7] = h;
  _rot[8] = i;
}

/// 한 변이 [s]인 칸 (왼쪽 위가 원점)에 입체 주사위 하나를 그린다. [YachtCubePainter]와 주사위 줄의 구르는 주사위가 함께 쓴다.
void paintYachtCube(
  Canvas canvas,
  double s, {
  required int value,
  required double ax,
  required double ay,
  required double az,
  double lift = 0,
  bool daesung = false,
}) {
  final h = s * 0.368; // 정면을 볼 때 멈춘 주사위와 같은 크기로 보이는 반 변 길이
  final d = h * 5; // 눈(카메라)까지의 거리
  final cx0 = s / 2, cy0 = s / 2;

  // 그림자
  _fill.color = Colors.black.withValues(alpha: 0.2 - 0.1 * lift);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx0, cy0 + s * (0.06 + 0.3 * lift)), width: s * (0.9 - 0.25 * lift), height: s * (0.82 - 0.3 * lift)),
    _fill,
  );

  // 돌리기: Rz · Rx · Ry · (고른 눈이 정면을 보게 하는 기본 자세: 줄이 U, V, N)
  final base = _facePips.indexOf(value) * 9;
  for (var i = 0; i < 3; i++) {
    _m[i] = _faceAxes[base + 3 + i];
    _m[3 + i] = _faceAxes[base + 6 + i];
    _m[6 + i] = _faceAxes[base + i];
  }
  final sx = sin(ax), cx = cos(ax), sy = sin(ay), cy = cos(ay), sz = sin(az), cz = cos(az);
  _setRot(cy, 0, sy, 0, 1, 0, -sy, 0, cy);
  _mul(_rot, _m, _m2);
  _setRot(1, 0, 0, 0, cx, -sx, 0, sx, cx);
  _mul(_rot, _m2, _m);
  _setRot(cz, -sz, 0, sz, cz, 0, 0, 0, 1);
  _mul(_rot, _m, _m2);
  final m = _m2;

  for (var face = 0; face < 6; face++) {
    final o = face * 9;
    // 돌린 뒤의 N · U · V
    final n0 = m[0] * _faceAxes[o] + m[1] * _faceAxes[o + 1] + m[2] * _faceAxes[o + 2];
    final n1 = m[3] * _faceAxes[o] + m[4] * _faceAxes[o + 1] + m[5] * _faceAxes[o + 2];
    final n2 = m[6] * _faceAxes[o] + m[7] * _faceAxes[o + 1] + m[8] * _faceAxes[o + 2];
    if (n2 * d - h <= 0) continue; // 뒤쪽을 보는 면
    final u0 = m[0] * _faceAxes[o + 3] + m[1] * _faceAxes[o + 4] + m[2] * _faceAxes[o + 5];
    final u1 = m[3] * _faceAxes[o + 3] + m[4] * _faceAxes[o + 4] + m[5] * _faceAxes[o + 5];
    final u2 = m[6] * _faceAxes[o + 3] + m[7] * _faceAxes[o + 4] + m[8] * _faceAxes[o + 5];
    final v0 = m[0] * _faceAxes[o + 6] + m[1] * _faceAxes[o + 7] + m[2] * _faceAxes[o + 8];
    final v1 = m[3] * _faceAxes[o + 6] + m[4] * _faceAxes[o + 7] + m[5] * _faceAxes[o + 8];
    final v2 = m[6] * _faceAxes[o + 6] + m[7] * _faceAxes[o + 7] + m[8] * _faceAxes[o + 8];
    // 면 위의 점 (a, b)가 화면에 찍히는 자리
    double px(double a, double b) => cx0 + h * (n0 + a * u0 + b * v0) * d / (d - h * (n2 + a * u2 + b * v2));
    double py(double a, double b) => cy0 + h * (n1 + a * u1 + b * v1) * d / (d - h * (n2 + a * u2 + b * v2));

    // 면: 조금 작게 그린 네모에 굵은 둥근 테두리를 둘러 모서리를 둥글린다
    const inset = 0.74;
    final quad = Path()
      ..moveTo(px(-inset, -inset), py(-inset, -inset))
      ..lineTo(px(inset, -inset), py(inset, -inset))
      ..lineTo(px(inset, inset), py(inset, inset))
      ..lineTo(px(-inset, inset), py(-inset, inset))
      ..close();
    final shade = (0.62 + 0.38 * n2).clamp(0.0, 1.0);
    final color = daesung ? Color.lerp(kDaesungEdge, kDaesungBody, shade)! : Color.lerp(const Color(0xFF8D8778), kYachtDieBody, shade)!;
    _fill.color = color;
    canvas.drawPath(quad, _fill);
    _stroke
      ..color = color
      ..strokeWidth = h * 0.52 * d / (d - h * n2);
    canvas.drawPath(quad, _stroke);

    final pipCount = _facePips[face];
    if (daesung && pipCount == 1) {
      // 대성One 주사위의 1 면: 흰 동그라미 위에 로고 (면의 기울기를 따라 비스듬히)
      final disc = Path()..moveTo(px(0.66 * _cos28[0], 0.66 * _sin28[0]), py(0.66 * _cos28[0], 0.66 * _sin28[0]));
      for (var k = 1; k < 28; k++) {
        disc.lineTo(px(0.66 * _cos28[k], 0.66 * _sin28[k]), py(0.66 * _cos28[k], 0.66 * _sin28[k]));
      }
      disc.close();
      _fill.color = Color.lerp(const Color(0xFFB8C8BC), Colors.white, shade)!;
      canvas.drawPath(disc, _fill);
      final logo = DaesungLogo.image;
      if (logo == null) continue;
      // 그림의 (0,0) · (w,0) · (0,h)를 면 위의 세 점으로 옮기는 기울인 변환
      final ox = px(-0.5, -0.5), oy = py(-0.5, -0.5);
      final w = logo.width.toDouble(), lh = logo.height.toDouble();
      _logoMatrix
        ..fillRange(0, 16, 0)
        ..[0] = (px(0.5, -0.5) - ox) / w
        ..[1] = (py(0.5, -0.5) - oy) / w
        ..[4] = (px(-0.5, 0.5) - ox) / lh
        ..[5] = (py(-0.5, 0.5) - oy) / lh
        ..[10] = 1
        ..[12] = ox
        ..[13] = oy
        ..[15] = 1;
      canvas.save();
      canvas.transform(_logoMatrix);
      canvas.drawImage(logo, Offset.zero, _logoPaint);
      canvas.restore();
      continue;
    }

    // 눈: 한 면의 눈을 모두 한 번에 그린다
    final r = pipCount == 1 ? 0.283 : 0.185;
    final pips = Path();
    for (final i in kYachtPips[pipCount]) {
      final gx = (i % 3 - 1) * 0.5, gy = (i ~/ 3 - 1) * 0.5;
      pips.moveTo(px(gx + r * _cos14[0], gy + r * _sin14[0]), py(gx + r * _cos14[0], gy + r * _sin14[0]));
      for (var k = 1; k < 14; k++) {
        final a = gx + r * _cos14[k], b = gy + r * _sin14[k];
        pips.lineTo(px(a, b), py(a, b));
      }
      pips.close();
    }
    _fill.color = daesung
        ? Color.lerp(kDaesungEdge, Colors.white, 0.5 + 0.5 * shade)!
        : Color.lerp(Colors.black, pipCount == 1 ? kYachtDieOne : kYachtDiePip, 0.55 + 0.45 * shade)!;
    canvas.drawPath(pips, _fill);
  }
}
