// 앱 아이콘 후보 그림. 좌표는 모두 0~1 (가운데가 0.5, 0.5).
//
// 안드로이드 적응형 아이콘은 동그라미·둥근 네모로 잘리므로 중요한 그림은 가운데에서 반지름 0.42 안에 그린다.
// 배경은 0~1 밖까지 넉넉히 칠해 둔다 (적응형 아이콘의 바깥 여백을 채울 때 그대로 쓴다).
// 그림 만들기: tool/app_icon/make_app_icons_test.dart 맨 위 설명 참고.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

class IconDesign {
  const IconDesign(this.id, this.name, this.paint);

  final String id;
  final String name;
  final void Function(Canvas c) paint;
}

const List<IconDesign> iconDesigns = [
  IconDesign('1_cards_dice', '카드와 주사위', paintCardsDice),
  IconDesign('2_suit_die', '카드 무늬 주사위', paintSuitDie),
  IconDesign('3_tiles', '게임 타일 네 칸', paintTiles),
  IconDesign('4_t_die', 'T 주사위', paintTDie),
  IconDesign('5_pawns', '게임 말 셋', paintPawns),
  IconDesign('6_gamepad', '게임패드', paintGamepad),
];

/// 실제 앱·웹 아이콘으로 쓰는 그림 (apply_app_icon_test.dart 가 이것으로 파일을 만든다).
const IconDesign appIcon = IconDesign('1_cards_dice', '카드와 주사위', paintCardsDice);

const Color _ink = Color(0xFF1A1523);
const Color _white = Color(0xFFFFFFFF);
const Color _red = Color(0xFFE5484D);
const Color _yellow = Color(0xFFFFC233);
const Color _green = Color(0xFF3DBE7B);
const Color _blue = Color(0xFF4A9BE8);

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Color _dark(Color c, [double t = 0.25]) => Color.lerp(c, const Color(0xFF000000), t)!;

void _background(Canvas c, Color a, Color b) {
  c.drawRect(
    const Rect.fromLTRB(-1, -1, 2, 2),
    Paint()..shader = Gradient.linear(const Offset(0.1, 0), const Offset(0.9, 1), [a, b]),
  );
}

/// [center]로 옮기고 [angle]만큼 돌린 뒤 [draw]를 부른다 (그 안에서는 가운데가 0,0).
void _at(Canvas c, Offset center, double angle, void Function() draw) {
  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(angle);
  draw();
  c.restore();
}

const Color _shadow = Color(0x40000000);

// ── 카드 무늬 (가운데 0,0, 크기 1) ─────────────────────────────────────────

Path _heart() => Path()
  ..moveTo(0, 0.44)
  ..cubicTo(-0.62, 0.02, -0.52, -0.44, -0.25, -0.44)
  ..cubicTo(-0.11, -0.44, 0, -0.34, 0, -0.2)
  ..cubicTo(0, -0.34, 0.11, -0.44, 0.25, -0.44)
  ..cubicTo(0.52, -0.44, 0.62, 0.02, 0, 0.44)
  ..close();

Path _stem() => Path()
  ..moveTo(0, -0.02)
  ..quadraticBezierTo(-0.02, 0.34, -0.18, 0.46)
  ..lineTo(0.18, 0.46)
  ..quadraticBezierTo(0.02, 0.34, 0, -0.02)
  ..close();

Path _spade() {
  final m = Float64List.fromList([0.9, 0, 0, 0, 0, -0.9, 0, 0, 0, 0, 1, 0, 0, -0.08, 0, 1]);
  return Path.combine(PathOperation.union, _heart().transform(m), _stem());
}

Path _diamond() => Path()
  ..moveTo(0, -0.47)
  ..lineTo(0.35, 0)
  ..lineTo(0, 0.47)
  ..lineTo(-0.35, 0)
  ..close();

Path _club() {
  var p = Path()..addOval(Rect.fromCircle(center: const Offset(0, -0.22), radius: 0.21));
  p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: const Offset(-0.23, 0.1), radius: 0.21)));
  p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: const Offset(0.23, 0.1), radius: 0.21)));
  return Path.combine(PathOperation.union, p, _stem());
}

void _suit(Canvas c, Path unit, Offset center, double size, Color color) {
  c.save();
  c.translate(center.dx, center.dy);
  c.scale(size);
  c.drawPath(unit, _fill(color));
  c.restore();
}

// ── 주사위 · 카드 · 말 ─────────────────────────────────────────────────────

const Map<int, List<Offset>> _pips = {
  1: [Offset(0, 0)],
  2: [Offset(-1, -1), Offset(1, 1)],
  3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
  4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
  5: [Offset(-1, -1), Offset(1, -1), Offset(0, 0), Offset(-1, 1), Offset(1, 1)],
  6: [Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0), Offset(-1, 1), Offset(1, 1)],
};

/// 주사위 몸통 (눈 없이). 아래쪽에 두께가 살짝 보인다.
void _dieBody(Canvas c, double size, Color face) {
  final r = Radius.circular(size * 0.2);
  final box = Rect.fromCenter(center: Offset.zero, width: size, height: size);
  c.drawRRect(RRect.fromRectAndRadius(box.shift(Offset(0, size * 0.1)), r), _fill(_shadow));
  c.drawRRect(RRect.fromRectAndRadius(box.shift(Offset(0, size * 0.045)), r), _fill(_dark(face, 0.22)));
  c.drawRRect(RRect.fromRectAndRadius(box, r), _fill(face));
}

void _die(Canvas c, Offset center, double size, double angle, {required Color face, required Color pip, List<Offset>? spots, int n = 5}) {
  _at(c, center, angle, () {
    _dieBody(c, size, face);
    for (final p in spots ?? _pips[n]!) {
      c.drawCircle(p * (size * 0.27), size * 0.095, _fill(pip));
    }
  });
}

/// 비스듬히 내려다본 입체 주사위 (윗면 5, 왼쪽 면 4, 오른쪽 면 1). [size]는 가로 폭.
void _cube(Canvas c, Offset center, double size, double angle) {
  const top = Color(0xFFFFDB63), left = Color(0xFFFFC233), right = Color(0xFFEFA31A), edge = Color(0xFFF8B92C);
  _at(c, center, angle, () {
    c.scale(size);
    const l = Offset(-0.5, -0.27), r = Offset(0.5, -0.27), d = Offset(0, 0.56);
    c.drawOval(Rect.fromCenter(center: const Offset(0, 0.36), width: 1.1, height: 0.5), _fill(_shadow));
    final hull = Path()..addPolygon([l, l + r, r, r + d, d, l + d], true);
    c.drawPath(hull, _fill(edge));
    c.drawPath(
      hull,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..strokeJoin = StrokeJoin.round,
    );
    // 한 면: [o]에서 [u], [v] 방향으로 펼친 네모. 그 안에서는 0~1 좌표.
    void face(Offset o, Offset u, Offset v, Color color, int n) {
      c.save();
      c.transform(Float64List.fromList([u.dx, u.dy, 0, 0, v.dx, v.dy, 0, 0, 0, 0, 1, 0, o.dx, o.dy, 0, 1]));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.03, 0.03, 0.97, 0.97), const Radius.circular(0.16)), _fill(color));
      for (final p in _pips[n]!) {
        c.drawCircle(const Offset(0.5, 0.5) + p * 0.26, 0.1, _fill(_ink));
      }
      c.restore();
    }

    face(l + r, l * -1, r * -1, top, 5);
    face(l, l * -1, d, left, 4);
    face(Offset.zero, r, d, right, 1);
  });
}

void _card(Canvas c, Offset center, double w, double angle, Path suit, Color color, {double bigDx = 0.04}) {
  final h = w * 1.4;
  _at(c, center, angle, () {
    final r = Radius.circular(w * 0.13);
    final box = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    c.drawRRect(RRect.fromRectAndRadius(box.shift(Offset(0, w * 0.06)), r), _fill(_shadow));
    c.drawRRect(RRect.fromRectAndRadius(box, r), _fill(_white));
    _suit(c, suit, Offset(-w * 0.29, -h * 0.33), w * 0.26, color);
    _suit(c, suit, Offset(w * bigDx, h * 0.06), w * 0.62, color);
  });
}

/// 게임 말. [foot]이 바닥 가운데, [h]가 키.
void _pawn(Canvas c, Offset foot, double h, Color color) {
  c.save();
  c.translate(foot.dx, foot.dy - h / 2);
  c.scale(h);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 0.47), width: 0.86, height: 0.2), _fill(_shadow));
  final body = Path()
    ..moveTo(-0.11, -0.16)
    ..quadraticBezierTo(-0.12, 0.2, -0.3, 0.36)
    ..lineTo(0.3, 0.36)
    ..quadraticBezierTo(0.12, 0.2, 0.11, -0.16)
    ..close();
  final base = RRect.fromRectAndRadius(const Rect.fromLTRB(-0.36, 0.32, 0.36, 0.5), const Radius.circular(0.08));
  c.drawRRect(base, _fill(_dark(color, 0.22)));
  c.drawPath(body, _fill(color));
  c.drawOval(Rect.fromCenter(center: const Offset(0, -0.13), width: 0.44, height: 0.12), _fill(_dark(color, 0.22)));
  c.drawCircle(const Offset(0, -0.3), 0.2, _fill(color));
  c.drawCircle(const Offset(-0.07, -0.37), 0.055, _fill(const Color(0x66FFFFFF)));
  c.restore();
}

Path _star(Offset center, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rr = i.isEven ? r : r * 0.45;
    final o = center + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

// ── 후보 6개 ───────────────────────────────────────────────────────────────

/// 1. 카드 두 장 앞에 노란 주사위.
void paintCardsDice(Canvas c) {
  _background(c, const Color(0xFF5AA0D4), const Color(0xFF2A5B87));
  _card(c, const Offset(0.31, 0.45), 0.31, -0.38, _spade(), _ink, bigDx: 0);
  _card(c, const Offset(0.57, 0.4), 0.31, 0.12, _heart(), _red);
  _cube(c, const Offset(0.63, 0.66), 0.37, -0.1);
}

/// 2. 눈이 카드 무늬 네 개인 흰 주사위.
void paintSuitDie(Canvas c) {
  _background(c, const Color(0xFF35AD76), const Color(0xFF17694A));
  _at(c, const Offset(0.5, 0.49), -0.1, () {
    const size = 0.58;
    _dieBody(c, size, _white);
    const d = size * 0.23;
    _suit(c, _spade(), const Offset(-d, -d), size * 0.34, _ink);
    _suit(c, _heart(), const Offset(d, -d), size * 0.32, _red);
    _suit(c, _diamond(), const Offset(-d, d), size * 0.34, _red);
    _suit(c, _club(), const Offset(d, d), size * 0.34, _ink);
  });
}

/// 3. 색깔 타일 네 칸에 주사위·카드·말·별.
void paintTiles(Canvas c) {
  _background(c, const Color(0xFF26355A), const Color(0xFF131A2E));
  const t = 0.275, g = 0.04, d = (t + g) / 2;
  void tile(Offset center, Color color, void Function() draw) {
    _at(c, center, 0, () {
      final box = Rect.fromCenter(center: Offset.zero, width: t, height: t);
      const r = Radius.circular(t * 0.24);
      c.drawRRect(RRect.fromRectAndRadius(box.shift(const Offset(0, t * 0.07)), r), _fill(_dark(color, 0.35)));
      c.drawRRect(RRect.fromRectAndRadius(box, r), _fill(color));
      draw();
    });
  }

  tile(const Offset(0.5 - d, 0.49 - d), _red, () {
    for (final p in _pips[5]!) {
      c.drawCircle(p * (t * 0.25), t * 0.09, _fill(_white));
    }
  });
  tile(const Offset(0.5 + d, 0.49 - d), _yellow, () => _suit(c, _spade(), const Offset(0, -t * 0.01), t * 0.74, _ink));
  tile(const Offset(0.5 - d, 0.49 + d), _green, () => _pawnPlain(c, t * 0.8, _white));
  tile(const Offset(0.5 + d, 0.49 + d), _blue, () => c.drawPath(_star(const Offset(0, t * 0.02), t * 0.36), _fill(_white)));
}

/// 타일 안에 넣는 단색 말 (그림자·무늬 없이).
void _pawnPlain(Canvas c, double h, Color color) {
  c.save();
  c.scale(h);
  c.drawCircle(const Offset(0, -0.26), 0.2, _fill(color));
  c.drawPath(
    Path()
      ..moveTo(-0.12, -0.1)
      ..quadraticBezierTo(-0.12, 0.2, -0.32, 0.44)
      ..lineTo(0.32, 0.44)
      ..quadraticBezierTo(0.12, 0.2, 0.12, -0.1)
      ..close(),
    _fill(color),
  );
  c.restore();
}

/// 4. 눈 다섯 개가 T 모양으로 놓인 주사위 (TabGame의 T).
void paintTDie(Canvas c) {
  _background(c, const Color(0xFFFFA548), const Color(0xFFEE5A2B));
  _die(c, const Offset(0.5, 0.49), 0.58, -0.08, face: _white, pip: _ink, spots: const [Offset(-1, -1), Offset(0, -1), Offset(1, -1), Offset(0, 0), Offset(0, 1)]);
}

/// 5. 보드게임 말 세 개.
void paintPawns(Canvas c) {
  _background(c, const Color(0xFF2CC4B2), const Color(0xFF0F7F76));
  _pawn(c, const Offset(0.32, 0.62), 0.42, _red);
  _pawn(c, const Offset(0.68, 0.62), 0.42, _blue);
  _pawn(c, const Offset(0.5, 0.77), 0.52, _yellow);
}

/// 6. 흰 게임패드.
void paintGamepad(Canvas c) {
  _background(c, const Color(0xFF8A6BEA), const Color(0xFF4428A0));
  var body = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.15, 0.33, 0.85, 0.63), const Radius.circular(0.15)));
  for (final x in [0.27, 0.73]) {
    body = Path.combine(PathOperation.union, body, Path()..addOval(Rect.fromCenter(center: Offset(x, 0.6), width: 0.25, height: 0.3)));
  }
  c.drawPath(body.shift(const Offset(0, 0.045)), _fill(_shadow));
  c.drawPath(body.shift(const Offset(0, 0.022)), _fill(const Color(0xFFCFC8E8)));
  c.drawPath(body, _fill(_white));
  // 십자 단추
  const pad = Offset(0.32, 0.48);
  const r = Radius.circular(0.018);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pad, width: 0.17, height: 0.058), r), _fill(_ink));
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pad, width: 0.058, height: 0.17), r), _fill(_ink));
  // 색 단추 네 개
  const btn = Offset(0.68, 0.48);
  const o = 0.066;
  c.drawCircle(btn + const Offset(0, -o), 0.037, _fill(_yellow));
  c.drawCircle(btn + const Offset(o, 0), 0.037, _fill(_red));
  c.drawCircle(btn + const Offset(0, o), 0.037, _fill(_green));
  c.drawCircle(btn + const Offset(-o, 0), 0.037, _fill(_blue));
}
