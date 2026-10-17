import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../games/freecell/ui/playing_card.dart';
import '../games/dandelion/ui/dandelion_art.dart' show paintWindGust;
import '../games/dotcannon/ui/dot_painter.dart' show paintCannon;
import '../games/getcolor/ui/getcolor_painter.dart';
import '../games/goblet/core/goblet_rules.dart' show Team;
import '../games/goblet/ui/goblet_piece.dart' show GobblerPainter;
import '../games/prophecy/ui/prophecy_board.dart' show paintPenDigit, penColor;

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

/// 숫자·글자 하나를 [center]의 한가운데에 그린다. 글자를 100배 키운 크기로 그려서 줄여 붙이고 (0~1 좌표에 바로 쓰는 아주 작은 글자 크기는
/// 흐리게 그려진다), 글자 상자가 아니라 숫자 모양 자체의 가운데(기준선에서 숫자 높이의 절반 위)가 [center]에 오게 맞춘다.
void _crispText(Canvas c, String s, Offset center, double size, Color color) {
  final fontSize = size * 100;
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'NanumGothic', fontSize: fontSize, fontWeight: FontWeight.w900, color: color, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  c.save();
  c.translate(center.dx, center.dy);
  c.scale(0.01);
  tp.paint(c, Offset(-tp.width / 2, -(baseline - fontSize * 0.36)));
  c.restore();
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
  void digit(String d, int col, int row, Color color) => _crispText(c, d, Offset(xs[col], xs[row]), 0.2, color);
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
  const pivot = Offset(0.5, 0.74); // 부채꼴 전체가 그림 한가운데에 오도록
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


// ── 도트 캐논: 나무 액자 속 도트 하트, 아래에서 쏘는 대포 ──
void paintDotCannonIcon(Canvas c, double s) {
  const wood = Color(0xFF8C5A34);
  final frame = RRect.fromRectAndRadius(const Rect.fromLTWH(0.1, 0.06, 0.8, 0.7), const Radius.circular(0.06));
  c.drawRRect(frame.shift(const Offset(0, 0.025)), _fill(Colors.black.withValues(alpha: 0.22)));
  c.drawRRect(frame, _fill(wood));
  c.drawRRect(frame.deflate(0.04), _fill(const Color(0xFFF7F1E3)));
  // 하트 도트 (맨 아랫줄은 이미 맞혀서 지워졌다)
  const heart = [
    '.RR.RR.',
    'RWRRRRR',
    'RRRRRRR',
    '.RRRRR.',
    '..RRR..',
    '...R...',
  ];
  const cols = 7;
  const cell = 0.085;
  const ox = 0.5 - cols * cell / 2;
  const oy = 0.13;
  for (var y = 0; y < heart.length; y++) {
    for (var x = 0; x < cols; x++) {
      final ch = heart[y][x];
      if (ch == '.') continue;
      final color = ch == 'W' ? Colors.white : const Color(0xFFE5484D);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ox + x * cell + 0.004, oy + y * cell + 0.004, cell - 0.008, cell - 0.008), const Radius.circular(0.012)),
        _fill(color),
      );
    }
  }
  // 탄 한 발
  c.drawCircle(const Offset(0.5, 0.74), 0.028, _fill(Colors.white));
  c.drawCircle(const Offset(0.5, 0.74), 0.02, _fill(const Color(0xFFE5484D)));
  // 대포 (위를 향한다)
  _pixels(c, s, const Offset(0.36, 0.76), () => paintCannon(c, Offset(0.14 * s, 0.14 * s), 0.28 * s, const Color(0xFFE5484D), -1.5708, label: '9'));
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

// ── 고블렛 고블러스: 게임 안의 고블러(귀 달린 돔 모양 컵) 크기별 세 개 ──
void paintGobletIcon(Canvas c, double s) {
  // 그림 좌표가 0~1이라, 100배 키운 크기로 말을 그려서 줄여 붙인다 (선 굵기 등이 게임 안과 같게).
  // 말은 바닥 선에 맞춰 놓이고 큰 말의 귀가 솟아 있어서, 상자 기준이 아니라 그려진 모양의 위아래 가운데를 그림 가운데에 맞춘다.
  const k = 1.0;
  void piece(Team team, int size, double cx, double w) {
    const base = 0.77; // 말 그림의 위아래 가운데가 그림 한가운데(0.5)에 오는 자리
    final x = 0.5 + (cx - 0.5) * k, ww = w * k;
    c.save();
    c.translate(x - ww / 2, base - ww);
    c.scale(0.01);
    GobblerPainter(team: team, size: size).paint(c, Size(ww * 100, ww * 100));
    c.restore();
  }

  piece(Team.red, 3, 0.74, 0.52);
  piece(Team.blue, 2, 0.44, 0.42);
  piece(Team.red, 1, 0.17, 0.32);
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

// ── 예언: 게임이 끝났을 때의 채점 화면 ──
// 줄(행·열)마다 숫자(X 제외)가 몇 개인지 줄 끝에 센다. 그 개수와 같은 숫자는 동그라미를 치고,
// 행에서 맞았으면 좌우 화살표, 열에서 맞았으면 위아래 화살표를 단다 (둘 다 맞으면 네 방향, 점수도 두 번).
// 동그라미·화살표는 쓴 사람의 펜 색, 개수가 맞은 줄은 초록 동그라미로 표시한다. (게임 안 ProphBoardPainter와 같은 모양)
void paintProphecyIcon(Canvas c, double s) {
  const rows = 3, cols = 3;
  const x = -1; // X
  // 칸의 숫자(X는 -1)와 쓴 사람(0 = 분홍, 1 = 청록)
  const cells = [
    [2, 1, x],
    [1, 3, 2],
    [3, 2, x],
  ];
  const owners = [
    [0, 1, -1],
    [1, 1, 0],
    [0, 1, -1],
  ];
  const left = 0.07, top = 0.07, cell = 0.245;
  const gridW = cell * cols, gridH = cell * rows;
  final paper = RRect.fromRectAndRadius(const Rect.fromLTWH(left - 0.03, top - 0.03, gridW + 0.06, gridH + 0.06), const Radius.circular(0.04));
  _shadow(c, Path()..addRRect(paper));
  c.drawRRect(paper, _fill(const Color(0xFFFFFDF6)));
  const inkLine = Color(0xFF4A3B3B);
  final grid = _line(inkLine, 0.014);
  for (var k = 0; k <= 3; k++) {
    c.drawLine(Offset(left + cell * k, top), Offset(left + cell * k, top + gridH), grid);
    c.drawLine(Offset(left, top + cell * k), Offset(left + gridW, top + cell * k), grid);
  }
  Offset at(int r, int col) => Offset(left + cell * (col + 0.5), top + cell * (r + 0.5));

  // 줄마다 숫자 개수
  final rowCount = [for (var r = 0; r < rows; r++) cells[r].where((v) => v > 0).length];
  final colCount = [for (var k = 0; k < cols; k++) [for (var r = 0; r < rows; r++) cells[r][k]].where((v) => v > 0).length];

  // 글자는 그림 좌표(0~1)에 바로 못 그리니 100배 키운 크기로 그려서 줄여 붙인다.
  void big(Offset p, void Function() draw) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(0.01);
    draw();
    c.restore();
  }

  // 칸 안: 숫자(쓴 사람의 펜)와 X
  for (var r = 0; r < rows; r++) {
    for (var k = 0; k < cols; k++) {
      final v = cells[r][k];
      if (v == x) {
        final m = at(r, k);
        const d = cell * 0.3;
        final cross = Path()
          ..moveTo(m.dx - d, m.dy - d)
          ..lineTo(m.dx + d, m.dy + d)
          ..moveTo(m.dx + d, m.dy - d)
          ..lineTo(m.dx - d, m.dy + d);
        c.drawPath(cross, _line(inkLine.withValues(alpha: 0.85), 0.014));
      } else {
        big(at(r, k), () => paintPenDigit(c, '$v', Offset.zero, cell * 100 * 0.58, owners[r][k]));
      }
    }
  }

  // 점수: 동그라미 + 행이면 좌우, 열이면 위아래 화살표
  void arrows(Offset m, Color color, {required bool horizontal}) {
    const r0 = cell * 0.3, r1 = cell * 0.5, head = cell * 0.11;
    final pen = _line(color, 0.02);
    for (final dir in const [-1.0, 1.0]) {
      final d = horizontal ? Offset(dir, 0) : Offset(0, dir);
      final n = horizontal ? const Offset(0, 1) : const Offset(1, 0);
      final from = m + d * r0, to = m + d * r1;
      c.drawLine(from, to, pen);
      c.drawLine(to, to - d * head + n * head * 0.8, pen);
      c.drawLine(to, to - d * head - n * head * 0.8, pen);
    }
  }

  final rowOk = <int>{}, colOk = <int>{};
  for (var r = 0; r < rows; r++) {
    for (var k = 0; k < cols; k++) {
      final v = cells[r][k];
      if (v <= 0) continue;
      final byRow = rowCount[r] == v, byCol = colCount[k] == v;
      if (!byRow && !byCol) continue;
      if (byRow) rowOk.add(r);
      if (byCol) colOk.add(k);
      final color = penColor(owners[r][k]);
      c.drawCircle(at(r, k), cell * 0.3, _line(color, 0.02));
      if (byRow) arrows(at(r, k), color, horizontal: true);
      if (byCol) arrows(at(r, k), color, horizontal: false);
    }
  }

  // 줄 끝의 개수 (맞은 줄은 초록)
  void count(Offset p, int n, bool ok) {
    c.drawCircle(p, 0.05, _fill(ok ? const Color(0xFF2E9E4F) : Colors.white.withValues(alpha: 0.28)));
    big(p, () => _text(c, '$n', Offset.zero, 7.5, Colors.white));
  }

  for (var r = 0; r < rows; r++) {
    count(Offset(left + gridW + 0.085, top + cell * (r + 0.5)), rowCount[r], rowOk.contains(r));
  }
  for (var k = 0; k < cols; k++) {
    count(Offset(left + cell * (k + 0.5), top + gridH + 0.085), colCount[k], colOk.contains(k));
  }
}

// ── 루미큐브: 같은 숫자 다른 색 타일 세 장이 부채꼴로 놓인 그룹 ──
void paintRummikubIcon(Canvas c, double s) {
  const w = 0.34, h = 0.46;
  const colors = [Color(0xFF1E63C6), Color(0xFFD32F2F), Color(0xFFEF8A17)];
  const angles = [-0.26, 0.0, 0.26];
  const centers = [Offset(0.27, 0.53), Offset(0.5, 0.45), Offset(0.73, 0.53)];
  for (var i = 0; i < 3; i++) {
    c.save();
    c.translate(centers[i].dx, centers[i].dy);
    c.rotate(angles[i]);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2, -h / 2, w, h), const Radius.circular(0.055));
    _shadow(c, Path()..addRRect(tile));
    c.drawRRect(tile, _fill(const Color(0xFFFFF8E6)));
    c.drawRRect(tile, _line(const Color(0xFF8D5A2B), 0.02));
    // 숫자는 패 안쪽 위에, 색 무늬(●■▲)는 아래에 작은 도형으로 (글자 상자가 커서 패 밖으로 나가지 않게 크기와 자리를 줄였다)
    _crispText(c, '7', const Offset(0, -0.06), 0.17, colors[i]);
    final mark = _fill(colors[i]);
    const my = 0.115, r = 0.034;
    switch (i) {
      case 0:
        c.drawCircle(const Offset(0, my), r, mark);
      case 1:
        c.drawRect(Rect.fromCenter(center: const Offset(0, my), width: r * 1.8, height: r * 1.8), mark);
      default:
        c.drawPath(
          Path()
            ..moveTo(0, my - r * 1.1)
            ..lineTo(r * 1.15, my + r * 0.9)
            ..lineTo(-r * 1.15, my + r * 0.9)
            ..close(),
          mark,
        );
    }
    c.restore();
  }
}

// ── 쿼리도: 칸 판 위에 두 말과 벽 ──
void paintQuoridorIcon(Canvas c, double s) {
  const n = 5;
  const left = 0.1, top = 0.1, cell = 0.14, gap = 0.04;
  const pitch = cell + gap;
  final board = RRect.fromRectAndRadius(const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9), const Radius.circular(0.07));
  _shadow(c, Path()..addRRect(board));
  c.drawRRect(board, _fill(const Color(0xFFB98C52)));
  for (var r = 0; r < n; r++) {
    for (var k = 0; k < n; k++) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + k * pitch, top + r * pitch, cell, cell), const Radius.circular(0.025)),
        _fill(const Color(0xFFEBD3A3)),
      );
    }
  }
  // 벽: 가로 하나(2~3열 사이 위), 세로 하나
  final wall = _fill(const Color(0xFF4A2F1B));
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left + 1 * pitch, top + 2 * pitch - gap, cell * 2 + gap, gap), const Radius.circular(0.02)), wall);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left + 3 * pitch - gap, top + 3 * pitch, gap, cell * 2 + gap), const Radius.circular(0.02)), wall);
  // 말
  void pawn(int r, int k, Color color) {
    final center = Offset(left + k * pitch + cell / 2, top + r * pitch + cell / 2);
    c.drawCircle(center + const Offset(0, 0.012), cell * 0.4, _fill(Colors.black.withValues(alpha: 0.25)));
    c.drawCircle(center, cell * 0.4, _fill(color));
    c.drawCircle(center, cell * 0.4, _line(Colors.white.withValues(alpha: 0.85), 0.012));
  }

  pawn(4, 2, const Color(0xFFD1495B));
  pawn(0, 2, const Color(0xFF3F7CAC));
}

// ── 다빈치 코드: 숫자가 보이는 검정 타일, 흰색 타일, 그리고 뒷면(?) 타일 ──
void paintDavinciIcon(Canvas c, double s) {
  const w = 0.32, h = 0.45;
  const tiles = [
    (Offset(0.27, 0.54), -0.26, Color(0xFF2A2D32), '7', Colors.white),
    (Offset(0.5, 0.46), 0.0, Color(0xFFF6F1E4), '3', Color(0xFF2A2D32)),
    (Offset(0.73, 0.54), 0.26, Color(0xFF2A2D32), '?', Color(0xFF8FA3B0)),
  ];
  for (final (center, angle, bg, label, fg) in tiles) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final tile = RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2, -h / 2, w, h), const Radius.circular(0.05));
    _shadow(c, Path()..addRRect(tile));
    c.drawRRect(tile, _fill(bg));
    c.drawRRect(tile, _line(bg == const Color(0xFFF6F1E4) ? const Color(0xFFBDB29A) : const Color(0xFF6A6F78), 0.02));
    _crispText(c, label, Offset.zero, 0.24, fg);
    c.restore();
  }
}
