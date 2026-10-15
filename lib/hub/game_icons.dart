import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../games/freecell/ui/playing_card.dart';
import '../games/dandelion/ui/dandelion_art.dart' show paintWindGust;
import '../games/getcolor/ui/getcolor_painter.dart';

const Color _ink = Color(0xFF1A1523);

/// 허브 게임 카드의 큰 그림 아이콘.
///
/// 머티리얼 아이콘 대신 게임 안에서 쓰는 그림 그대로(겟 컬러의 병, 솔리테어·프리셀의 카드, 리듬 검사단의
/// 검사 …)나 직접 그린 그림을 쓴다. 그림은 게임 등록(`GameInfo.iconPainter` / `iconImage`)에서 정하고,
/// 없는 게임은 [GameInfo.icon]을 보여 준다. 그림 함수는 이 파일의 `paint…Icon`들.
class GameIcon extends StatelessWidget {
  const GameIcon({super.key, required this.game, this.size = 56});

  final GameInfo game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = game.iconImage;
    if (image != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Icon(game.icon, size: size * 0.7, color: Colors.white),
        ),
      );
    }
    final paint = game.iconPainter;
    if (paint == null) return Icon(game.icon, size: size * 0.7, color: Colors.white);
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _IconPainter(paint)));
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.draw);

  final void Function(Canvas c, double s) draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    draw(canvas, size.width);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => false;
}

// ── 공통 도구 (좌표는 모두 0~1) ──

Paint _fill(Color c) => Paint()..color = c;

Paint _line(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round
  ..color = c;

void _shadow(Canvas c, Path p) => c.drawPath(p.shift(const Offset(0, 0.025)), _fill(Colors.black.withValues(alpha: 0.22)));

void _text(Canvas c, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w900, color: color, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// 카드·병처럼 픽셀 단위로 그리는 함수를 0~1 좌표 안에서 쓰게 한다.
void _pixels(Canvas c, double s, Offset origin, void Function() draw) {
  c.save();
  c.translate(origin.dx, origin.dy);
  c.scale(1 / s);
  draw();
  c.restore();
}

// ── 스도쿠: 숫자가 든 3×3 칸 ──
void paintSudokuIcon(Canvas c, double s) {
  final box = RRect.fromRectAndRadius(const Rect.fromLTWH(0.08, 0.08, 0.84, 0.84), const Radius.circular(0.09));
  _shadow(c, Path()..addRRect(box));
  c.drawRRect(box, _fill(Colors.white));
  c.drawRect(const Rect.fromLTWH(0.36, 0.36, 0.28, 0.28), _fill(const Color(0xFFFFE08A)));
  final grid = _line(const Color(0xFF9AA5B8), 0.02, cap: StrokeCap.butt);
  for (final t in [0.36, 0.64]) {
    c.drawLine(Offset(t, 0.08), Offset(t, 0.92), grid);
    c.drawLine(Offset(0.08, t), Offset(0.92, t), grid);
  }
  c.drawRRect(box, _line(_ink, 0.04));
  const xs = [0.22, 0.5, 0.78];
  void digit(String d, int col, int row, Color color) => _text(c, d, Offset(xs[col], xs[row] + (row == 0 ? 0.055 : 0.035)), 0.2, color);
  digit('5', 0, 0, const Color(0xFF3F7CAC));
  digit('3', 2, 0, _ink);
  digit('7', 1, 1, const Color(0xFFD1495B));
  digit('1', 0, 2, _ink);
  digit('9', 2, 2, const Color(0xFF3F7CAC));
}

// ── 지뢰찾기: 도화선이 타는 지뢰 ──
void paintMinesIcon(Canvas c, double s) {
  const center = Offset(0.48, 0.58);
  const r = 0.2;
  for (var k = 0; k < 8; k++) {
    final a = k * pi / 4 + pi / 8;
    c.drawLine(center + Offset(cos(a), sin(a)) * (r * 0.7), center + Offset(cos(a), sin(a)) * (r + 0.1), _line(_ink, 0.065));
  }
  c.drawCircle(center + const Offset(0, 0.025), r, _fill(Colors.black.withValues(alpha: 0.22)));
  c.drawCircle(center, r, _fill(const Color(0xFF2B2F3A)));
  c.drawCircle(center, r, _line(Colors.white.withValues(alpha: 0.85), 0.025));
  c.drawCircle(center + const Offset(-0.07, -0.07), 0.05, _fill(Colors.white.withValues(alpha: 0.75)));
  // 도화선 + 불꽃
  final fuse = Path()
    ..moveTo(0.6, 0.43)
    ..quadraticBezierTo(0.7, 0.3, 0.68, 0.2);
  c.drawPath(fuse, _line(_ink, 0.07));
  c.drawPath(fuse, _line(const Color(0xFFE9C27A), 0.04));
  final spark = Path();
  const sc = Offset(0.69, 0.15);
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? 0.1 : 0.04;
    final a = k * pi / 5 - pi / 2;
    final o = sc + Offset(cos(a), sin(a)) * rr;
    k == 0 ? spark.moveTo(o.dx, o.dy) : spark.lineTo(o.dx, o.dy);
  }
  spark.close();
  c.drawPath(spark, _line(_ink, 0.04));
  c.drawPath(spark, _fill(const Color(0xFFFFD84D)));
}

// ── 솔리테어: 펼친 카드 세 장 (게임의 실제 카드 그림) ──
void paintSolitaireIcon(Canvas c, double s) {
  const cw = 0.4, ch = 0.56;
  const pivot = Offset(0.5, 0.95);
  void card(int id, double angle) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    c.translate(-cw / 2, -ch);
    c.scale(1 / s);
    drawCard(c, id, Size(cw * s, ch * s), compact: true);
    c.restore();
  }

  card(9 * 4 + 1, -0.46); // 10♦
  card(12 * 4 + 2, 0.46); // K♥
  card(3, 0.0); // A♠
}

// ── 프리셀: 숫자가 이어지는 카드 줄 (실제 카드 그림) + 빈 칸 ──
void paintFreecellIcon(Canvas c, double s) {
  const cw = 0.37, ch = 0.52;
  // 위쪽 빈 칸 두 개
  for (final x in [0.56, 0.76]) {
    final slot = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0.1, 0.17, 0.22), const Radius.circular(0.04));
    c.drawRRect(slot, _fill(Colors.white.withValues(alpha: 0.18)));
    c.drawRRect(slot, _line(Colors.white.withValues(alpha: 0.85), 0.025));
  }
  void card(int id, double x, double y) => _pixels(c, s, Offset(x, y), () => drawCard(c, id, Size(cw * s, ch * s), compact: true));
  card(6 * 4 + 0, 0.08, 0.1); // 7♣
  card(5 * 4 + 1, 0.08, 0.27); // 6♦
  card(4 * 4 + 3, 0.08, 0.44); // 5♠
  card(12 * 4 + 2, 0.55, 0.38); // K♥
}

// ── 직소퍼즐: 맞물린 두 조각 ──
Path _piece(Rect r, {int top = 0, int right = 0, int bottom = 0, int left = 0}) {
  var p = Path()..addRect(r);
  final k = min(r.width, r.height) * 0.2; // 손잡이 반지름
  final neck = k * 0.35;
  Path knob(Offset center) => Path()..addOval(Rect.fromCircle(center: center, radius: k));
  Path join(Path base, int kind, Offset edge, Offset out) {
    if (kind == 0) return base;
    final center = edge + out * (k * 0.7 * kind);
    final shape = Path.combine(PathOperation.union, knob(center), Path()..addRect(Rect.fromCenter(center: edge, width: neck * 2 + (out.dx == 0 ? 0 : k), height: neck * 2 + (out.dy == 0 ? 0 : k))));
    return Path.combine(kind > 0 ? PathOperation.union : PathOperation.difference, base, shape);
  }

  p = join(p, top, r.topCenter, const Offset(0, -1));
  p = join(p, right, r.centerRight, const Offset(1, 0));
  p = join(p, bottom, r.bottomCenter, const Offset(0, 1));
  p = join(p, left, r.centerLeft, const Offset(-1, 0));
  return p;
}

void paintJigsawIcon(Canvas c, double s) {
  final a = _piece(const Rect.fromLTWH(0.07, 0.3, 0.4, 0.4), right: 1, top: 1);
  final b = _piece(const Rect.fromLTWH(0.49, 0.3, 0.44, 0.4), left: -1, bottom: 1);
  for (final (path, color) in [(a, const Color(0xFF55C1F2)), (b, Colors.white)]) {
    _shadow(c, path);
    c.drawPath(path, _fill(color));
    c.drawPath(path, _line(_ink, 0.035));
  }
}

// ── 겟 컬러: 게임에서 쓰는 병 모양 그대로, 물이 든 병 세 개 ──
void paintGetColorIcon(Canvas c, double s) {
  const w = 0.28;
  void bottle(double x, double y, List<int> colors, {bool done = false}) {
    _pixels(c, s, Offset(x, y), () => paintBottle(c, w * s, layersOf(colors), done: done));
  }

  bottle(0.04, 0.13, const [0, 2, 6, 0]); // 섞인 병
  bottle(0.36, 0.03, const [8, 8, 4]); // 들어 올린 병
  bottle(0.68, 0.13, const [6, 6, 6, 6], done: true); // 다 모은 병 (마개)
}

// ── 핀볼: 은색 공, 범퍼, 플리퍼 ──
void paintPinballIcon(Canvas c, double s) {
  // 범퍼
  c.drawCircle(const Offset(0.24, 0.3), 0.12, _fill(const Color(0xFFFF6B6B)));
  c.drawCircle(const Offset(0.24, 0.3), 0.12, _line(_ink, 0.035));
  c.drawCircle(const Offset(0.24, 0.3), 0.06, _fill(Colors.white.withValues(alpha: 0.85)));
  // 플리퍼 (왼쪽·오른쪽)
  for (final left in [true, false]) {
    final a = left ? const Offset(0.16, 0.74) : const Offset(0.84, 0.74);
    final b = left ? const Offset(0.44, 0.88) : const Offset(0.56, 0.88);
    c.drawLine(a, b, _line(_ink, 0.16));
    c.drawLine(a, b, _line(const Color(0xFFFFD84D), 0.11));
    c.drawCircle(a, 0.045, _fill(_ink));
  }
  // 공
  const ball = Offset(0.62, 0.42);
  c.drawCircle(ball + const Offset(0, 0.03), 0.17, _fill(Colors.black.withValues(alpha: 0.22)));
  c.drawCircle(
    ball,
    0.17,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.45), colors: [Color(0xFFFFFFFF), Color(0xFFB9C2CF), Color(0xFF7A8499)]).createShader(Rect.fromCircle(center: ball, radius: 0.17)),
  );
  c.drawCircle(ball, 0.17, _line(_ink, 0.035));
  // 튕기는 선
  for (final a in [-2.6, -2.1, -0.5]) {
    c.drawLine(ball + Offset(cos(a), sin(a)) * 0.24, ball + Offset(cos(a), sin(a)) * 0.32, _line(Colors.white, 0.03));
  }
}

// ── 궁극 틱택토: # 판 위의 X와 O ──
void paintUtttIcon(Canvas c, double s) {
  final hash = _line(Colors.white, 0.07);
  for (final t in [0.37, 0.63]) {
    c.drawLine(Offset(t, 0.1), Offset(t, 0.9), hash);
    c.drawLine(Offset(0.1, t), Offset(0.9, t), hash);
  }
  const cell = [0.235, 0.5, 0.765];
  void x(int col, int row) {
    const d = 0.075;
    final center = Offset(cell[col], cell[row]);
    final p = Path()
      ..moveTo(center.dx - d, center.dy - d)
      ..lineTo(center.dx + d, center.dy + d)
      ..moveTo(center.dx + d, center.dy - d)
      ..lineTo(center.dx - d, center.dy + d);
    c.drawPath(p, _line(_ink, 0.095));
    c.drawPath(p, _line(const Color(0xFFFFD84D), 0.055));
  }

  void o(int col, int row) {
    final center = Offset(cell[col], cell[row]);
    c.drawCircle(center, 0.085, _line(_ink, 0.095));
    c.drawCircle(center, 0.085, _line(const Color(0xFF9CE7FF), 0.055));
  }

  x(0, 0);
  o(1, 0);
  o(0, 1);
  x(1, 1);
  x(2, 2);
  o(2, 1);
  o(1, 2);
}

// ── 고블렛 고블러스: 크기가 다른 컵 세 개 ──
void paintGobletIcon(Canvas c, double s) {
  void cup(double cx, double h, Color color) {
    const base = 0.92;
    final bw = h * 0.64; // 컵 입구 너비
    final bh = h * 0.5; // 컵 깊이
    final top = base - h;
    final bowl = Path()
      ..moveTo(cx - bw / 2, top)
      ..cubicTo(cx - bw / 2, top + bh * 0.85, cx - bw * 0.25, top + bh, cx, top + bh)
      ..cubicTo(cx + bw * 0.25, top + bh, cx + bw / 2, top + bh * 0.85, cx + bw / 2, top)
      ..close();
    final stem = Path()..addRect(Rect.fromLTRB(cx - h * 0.055, top + bh - 0.01, cx + h * 0.055, base - h * 0.1));
    final foot = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - h * 0.2, base - h * 0.12, cx + h * 0.2, base), Radius.circular(h * 0.05)));
    final all = Path.combine(PathOperation.union, Path.combine(PathOperation.union, bowl, stem), foot);
    _shadow(c, all);
    c.drawPath(all, _fill(color));
    c.drawPath(all, _line(_ink, 0.035));
    // 컵 입구 띠 + 하이라이트
    c.drawLine(Offset(cx - bw / 2 + h * 0.03, top + h * 0.045), Offset(cx + bw / 2 - h * 0.03, top + h * 0.045), _line(Colors.white.withValues(alpha: 0.6), 0.03));
    c.drawLine(Offset(cx - bw * 0.3, top + bh * 0.3), Offset(cx - bw * 0.3, top + bh * 0.65), _line(Colors.white.withValues(alpha: 0.45), 0.03));
  }

  cup(0.2, 0.46, const Color(0xFFFFD84D));
  cup(0.43, 0.64, const Color(0xFF9CE7FF));
  cup(0.74, 0.84, const Color(0xFFFF6B6B));
}

// ── 콩나물: 점 셋과 두 가닥 곡선, 선 위에 새로 찍힌 점 ──
void paintSproutsIcon(Canvas c, double s) {
  const a = Offset(0.2, 0.7), b = Offset(0.78, 0.76), d = Offset(0.5, 0.2);
  final green = Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(0.15, 0.3, 0.3, 0.1, d.dx, d.dy);
  final pink = Path()
    ..moveTo(d.dx, d.dy)
    ..cubicTo(0.85, 0.2, 0.9, 0.5, b.dx, b.dy);
  final chord = Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(0.35, 0.95, 0.6, 0.95, b.dx, b.dy);
  for (final (p, color) in [(green, const Color(0xFF9CF0B8)), (pink, const Color(0xFFFFA6D5)), (chord, const Color(0xFF9CF0B8))]) {
    c.drawPath(p, _line(_ink, 0.085));
    c.drawPath(p, _line(color, 0.05));
  }
  for (final dot in [a, b, d, const Offset(0.205, 0.37), const Offset(0.5, 0.9)]) {
    final big = dot == a || dot == b || dot == d;
    c.drawCircle(dot, big ? 0.085 : 0.06, _fill(big ? _ink : Colors.white));
    c.drawCircle(dot, big ? 0.085 : 0.06, _line(big ? Colors.white : _ink, 0.03));
  }
}

// ── 민들레: 노란 꽃과 바람에 날아가는 씨앗 ──
void paintDandelionIcon(Canvas c, double s) {
  // 바람: 위쪽 오른쪽과 아래쪽 왼쪽에 돌돌 말리는 바람 줄
  paintWindGust(c, const Rect.fromLTWH(0.44, 0.0, 0.54, 0.54), Colors.white.withValues(alpha: 0.92), thickness: 0.08);
  // 꽃
  const center = Offset(0.29, 0.66);
  const r = 0.25;
  for (final (w, color) in [(0.1, _ink), (0.062, const Color(0xFFFFD84D))]) {
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * pi / 14;
      final d = Offset(cos(a), sin(a));
      c.drawLine(center + d * r * 0.36, center + d * r * 0.94, _line(color, w));
    }
  }
  c.drawCircle(center, r * 0.44, _fill(const Color(0xFFF08A00)));
  c.drawCircle(center, r * 0.44, _line(_ink, 0.035));
  c.drawCircle(center + const Offset(-0.03, -0.03), 0.03, _fill(Colors.white.withValues(alpha: 0.6)));
  // 날아가는 씨앗
  void seed(Offset p, double k) {
    for (var i = -2; i <= 2; i++) {
      final a = -pi / 2 + i * 0.5;
      final end = p + Offset(cos(a), sin(a)) * 0.1 * k;
      c.drawLine(p, end, _line(_ink, 0.03 * k));
      c.drawCircle(end, 0.02 * k, _fill(Colors.white));
    }
    c.drawOval(Rect.fromCenter(center: p + Offset(0, 0.035 * k), width: 0.034 * k, height: 0.07 * k), _fill(_ink));
  }

  seed(const Offset(0.72, 0.72), 1.0);
  seed(const Offset(0.9, 0.82), 0.85);
  seed(const Offset(0.7, 0.93), 0.7);
}
