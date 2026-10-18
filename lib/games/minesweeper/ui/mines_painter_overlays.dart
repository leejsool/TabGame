part of 'mines_painter.dart';

// 색종이와 눌러 고르기 그림 (화면 코드를 역할별로 나눈 파일)

/// 클리어했을 때의 색종이.
class MinesConfettiPainter extends CustomPainter {
  MinesConfettiPainter({required this.c, required Listenable repaint}) : super(repaint: repaint);

  final MinesController c;

  static const _colors = [
    Color(0xFFFFD84D),
    Color(0xFFFF5C7A),
    Color(0xFF5CC8FF),
    Color(0xFF7CFFB2),
    Color(0xFFFFFFFF),
    Color(0xFFFF9F43),
    Color(0xFFB388FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (c.winAt < 0) return;
    final t = (c.clockMs - c.winAt) / 1000.0;
    if (t < 0 || t > 5) return;
    final rng = Random(7);
    final g = size.height * 0.9;
    for (var i = 0; i < 140; i++) {
      final burst = i < 70;
      final color = _colors[i % _colors.length];
      final delay = burst ? 0.0 : rng.nextDouble() * 1.4;
      final life = t - delay;
      if (life < 0) {
        rng.nextDouble();
        rng.nextDouble();
        rng.nextDouble();
        continue;
      }
      double x, y;
      if (burst) {
        final a = -pi / 2 + (rng.nextDouble() - 0.5) * pi * 1.3;
        final sp = size.height * (0.5 + rng.nextDouble() * 0.9);
        x = size.width / 2 + cos(a) * sp * life;
        y = size.height * 0.55 + sin(a) * sp * life + 0.5 * g * life * life;
        rng.nextDouble();
      } else {
        x = rng.nextDouble() * size.width + sin(life * 3 + i) * 20;
        y = -20 + life * size.height * (0.35 + rng.nextDouble() * 0.3);
        rng.nextDouble();
      }
      final fade = (1 - (t - 3.8) / 1.2).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(life * (3 + i % 5) + i);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 11, height: 6),
        Paint()..color = color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MinesConfettiPainter old) => true;
}

/// 칸을 누르고 있다가 뗄 때의 동작.
enum PressAction { open, flag, question, cancel }

/// 원형 메뉴의 가운데(취소 영역) 반지름과 바깥 반지름 (화면 픽셀).
const double kPressDeadRadius = 28;
const double kPressOuterRadius = 92;

/// 지금 누르고 있는 칸과 손가락의 움직임.
///
/// 누른 자리를 중심으로 원이 그려진다: 가운데는 취소, 위쪽 120도는 열기, 오른쪽 아래 120도는 깃발,
/// 왼쪽 아래 120도는 물음표(?). 원이 뜨기 전에 톡 치고 떼면 그냥 열기다.
class MinesPress {
  const MinesPress({
    required this.cell,
    required this.mark,
    required this.canMark,
    required this.anchor,
    this.action = PressAction.open,
    this.visible = false,
    this.left = false,
  });

  final int cell;
  final CellMark mark;

  /// 깃발·물음표를 달 수 있는 칸인가 (열린 칸이거나 시작 전이면 아니다: 그때는 열기/취소뿐).
  final bool canMark;

  /// 누른 자리 (판 좌표). 원의 중심.
  final Offset anchor;
  final PressAction action;

  /// 안내가 보이는가. 톡 치는 탭에서 번쩍이지 않도록, 잠깐 누르고 있거나 끌기 시작한 뒤부터 보인다.
  final bool visible;

  /// 손가락이 가운데(취소) 영역을 벗어난 적이 있는가.
  final bool left;

  MinesPress copyWith({PressAction? action, bool? visible, bool? left}) => MinesPress(
        cell: cell,
        mark: mark,
        canMark: canMark,
        anchor: anchor,
        action: action ?? this.action,
        visible: visible ?? this.visible,
        left: left ?? this.left,
      );

  /// 누른 자리에서 [d](화면 픽셀)만큼 움직인 곳이 가리키는 동작.
  PressAction actionFor(Offset d) {
    if (!canMark) return d.distance < kPressOuterRadius * 0.7 ? PressAction.open : PressAction.cancel;
    if (d.distance < kPressDeadRadius) return PressAction.cancel;
    final deg = atan2(d.dy, d.dx) * 180 / pi; // 오른쪽 0도, 아래쪽 90도, 위쪽 -90도
    if (deg > -150 && deg <= -30) return PressAction.open; // 위쪽 120도
    if (deg > -30 && deg <= 90) return PressAction.flag; // 오른쪽 아래 120도
    return PressAction.question; // 왼쪽 아래 120도
  }

  /// 손가락을 뗐을 때 실제로 할 동작. 원이 뜨기 전에 가운데에서 톡 쳤다 뗀 것은 열기다.
  PressAction get result => canMark && !visible && !left ? PressAction.open : action;

  /// 지금 가리키는 동작을 할 수 없는가 (깃발 칸은 열 수 없다).
  bool get blocked => action == PressAction.open && mark == CellMark.flagged && canMark;

  String get label {
    switch (action) {
      case PressAction.cancel:
        return '취소';
      case PressAction.flag:
        return mark == CellMark.flagged ? '깃발 뽑기' : '깃발 꽂기';
      case PressAction.question:
        return mark == CellMark.question ? '물음표 떼기' : '물음표(?) 달기';
      case PressAction.open:
        if (mark == CellMark.revealed) return '숫자 주변 열기';
        if (blocked) return '깃발 칸은 열 수 없어요';
        return '열기';
    }
  }
}

/// 누르고 있는 칸 둘레에 원형 메뉴를 그린다. 확대해도 크기가 같게 보이도록 [zoom]의 배율만큼 줄여서 그린다.
class MinesPressPainter extends CustomPainter {
  MinesPressPainter({required this.layout, required this.press, required this.zoom})
      : super(repaint: Listenable.merge([press, zoom]));

  final MinesLayout layout;
  final ValueListenable<MinesPress?> press;
  final TransformationController zoom;

  static const _openColor = Color(0xFF2E9E5B);
  static const _flagColor = Color(0xFFE5484D);

  Color _color(PressAction a) {
    switch (a) {
      case PressAction.open:
        return _openColor;
      case PressAction.flag:
        return _flagColor;
      case PressAction.question:
        return kQuestionColor;
      case PressAction.cancel:
        return const Color(0xFF757575);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = press.value;
    if (p == null || !p.visible) return;
    final u = 1 / zoom.value.getMaxScaleOnAxis(); // 화면 1픽셀이 판 좌표로 얼마인가
    final rect = layout.rect(p.cell);
    final c = p.anchor;
    final accent = _color(p.action);

    // 누른 칸 테두리
    final ring = RRect.fromRectAndRadius(rect.inflate(2 * u), Radius.circular(layout.cell * 0.2));
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * u
        ..color = Colors.white,
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * u
        ..color = accent,
    );

    var top = rect.top - 6 * u;
    if (p.canMark) {
      final r0 = kPressDeadRadius * u, r1 = kPressOuterRadius * u;
      // 바탕
      canvas.drawCircle(c, r1 + 8 * u, Paint()..color = Colors.black.withValues(alpha: 0.28));
      // 세 조각: 위(열기) / 오른쪽 아래(깃발) / 왼쪽 아래(물음표)
      _wedge(canvas, c, -150, PressAction.open, p, r0, r1, u);
      _wedge(canvas, c, -30, PressAction.flag, p, r0, r1, u);
      _wedge(canvas, c, 90, PressAction.question, p, r0, r1, u);
      // 가운데: 취소
      final centerActive = p.action == PressAction.cancel;
      canvas.drawCircle(c, r0, Paint()..color = Colors.white.withValues(alpha: centerActive ? 1 : 0.82));
      canvas.drawCircle(
        c,
        r0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (centerActive ? 4 : 2) * u
          ..color = _color(PressAction.cancel),
      );
      final x = r0 * 0.34;
      final xPaint = Paint()
        ..color = _color(PressAction.cancel)
        ..strokeWidth = 3.5 * u
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + Offset(-x, -x), c + Offset(x, x), xPaint);
      canvas.drawLine(c + Offset(x, -x), c + Offset(-x, x), xPaint);
      top = c.dy - r1 - 14 * u;
    }
    _pill(canvas, size, c.dx, top, p.label, p.blocked ? _color(PressAction.cancel) : accent, u, rect);
  }

  /// 조각 하나: [startDeg]부터 120도. 가리키고 있으면 더 크고 진하게.
  void _wedge(Canvas canvas, Offset c, double startDeg, PressAction which, MinesPress p, double r0, double r1, double u) {
    final active = p.action == which;
    final color = _color(which);
    const gap = 2.5; // 조각 사이 틈 (도)
    final start = (startDeg + gap) * pi / 180, sweep = (120 - 2 * gap) * pi / 180;
    final outer = active ? r1 + 9 * u : r1;
    final inner = r0 + 3 * u;
    final path = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: outer), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: inner), start + sweep, -sweep, false)
      ..close();
    final dim = p.action == PressAction.cancel;
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: active ? 1 : (dim ? 0.7 : 0.85)));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (active ? 3.5 : 1.5) * u
        ..color = Colors.white.withValues(alpha: active ? 1 : 0.7),
    );

    // 그림: 조각 가운데에 하얀 동그라미 + 그림
    final mid = (startDeg + 60) * pi / 180;
    final rr = (inner + outer) / 2;
    final ic = c + Offset(cos(mid), sin(mid)) * rr;
    final disc = (active ? 25 : 21) * u;
    final blocked = active && p.blocked;
    canvas.drawCircle(ic, disc, Paint()..color = Colors.white.withValues(alpha: blocked ? 0.6 : 1));
    switch (which) {
      case PressAction.open:
        _text(canvas, '열기', ic - Offset(0, _textSize('열기', 15, u).height / 2), 15, blocked ? Colors.grey : _openColor, u);
      case PressAction.flag:
        drawFlagGlyph(canvas, ic + Offset(0, disc * 0.04), disc * 1.85, 1);
      case PressAction.question:
        _text(canvas, '?', ic - Offset(0, _textSize('?', 28, u).height / 2), 28, kQuestionColor, u,
            weight: FontWeight.w900);
      case PressAction.cancel:
        break;
    }
  }

  /// 글자를 고정 크기로 만들어 두고 캔버스 배율로 맞춰 그린다 (확대 배율이 바뀌어도 캐시가 겹치지 않게).
  /// [pos]는 글자 상자의 위쪽 가운데.
  void _text(Canvas canvas, String text, Offset pos, double px, Color color, double scale,
      {FontWeight weight = FontWeight.w800}) {
    final tp = _TextCache.glyph(text, 40, color, weight: weight);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale * px / 40);
    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  Size _textSize(String text, double px, double scale) {
    final tp = _TextCache.glyph(text, 40, Colors.white);
    return Size(tp.width, tp.height) * (scale * px / 40);
  }

  void _pill(Canvas canvas, Size size, double cx, double bottom, String text, Color color, double u, Rect cell) {
    final t = _textSize(text, 16, u);
    final w = t.width + 24 * u, h = t.height + 12 * u;
    var y = bottom - h;
    if (y < 2 * u) y = cell.bottom + 12 * u; // 위쪽이 모자라면 아래에 둔다
    final x = (cx - w / 2).clamp(2 * u, size.width - w - 2 * u).toDouble();
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(h / 2));
    canvas.drawRRect(box.shift(Offset(0, 2 * u)), Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawRRect(box, Paint()..color = color);
    _text(canvas, text, Offset(x + w / 2, y + (h - t.height) / 2), 16, Colors.white, u);
  }

  @override
  bool shouldRepaint(MinesPressPainter old) => old.layout != layout;
}
