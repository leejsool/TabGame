import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/mines_rules.dart';
import '../core/mines_solver.dart';
import '../game/mines_controller.dart';

const numberColors = [
  Colors.transparent,
  Color(0xFF3E7BFA), // 1
  Color(0xFF2E9E5B), // 2
  Color(0xFFE5484D), // 3
  Color(0xFF7E57C2), // 4
  Color(0xFFB5483A), // 5
  Color(0xFF1E9AA3), // 6
  Color(0xFF3A3F4B), // 7
  Color(0xFF8A8F99), // 8
];

/// 보드가 놓이는 자리 계산. 화면이 세로인데 판이 가로로 길면(고급) 판을 돌려서 더 크게 보여준다.
class MinesLayout {
  MinesLayout(Size area, this.rows, this.cols) {
    // 판 둘레의 테두리(칸 크기의 0.2배)까지 들어가도록 여유를 둔다
    final a = min(area.width / (cols + 0.4), area.height / (rows + 0.4));
    final b = min(area.width / (rows + 0.4), area.height / (cols + 0.4));
    transposed = b > a * 1.02;
    dispCols = transposed ? rows : cols;
    dispRows = transposed ? cols : rows;
    cell = min(transposed ? b : a, 76.0);
    boardSize = Size(cell * dispCols, cell * dispRows);
    origin = Offset((area.width - boardSize.width) / 2, (area.height - boardSize.height) / 2);
  }

  final int rows, cols;
  late final bool transposed;
  late final int dispCols, dispRows;
  late final double cell;
  late final Size boardSize;
  late final Offset origin;

  /// 칸 번호의 화면상 왼쪽 위.
  Offset topLeft(int i) {
    final r = i ~/ cols, c = i % cols;
    final dc = transposed ? r : c, dr = transposed ? c : r;
    return origin + Offset(dc * cell, dr * cell);
  }

  Rect rect(int i) => topLeft(i) & Size(cell, cell);

  /// 화면 좌표의 칸 번호 (판 밖이면 null).
  int? cellAt(Offset p) {
    final q = p - origin;
    if (q.dx < 0 || q.dy < 0 || q.dx >= boardSize.width || q.dy >= boardSize.height) return null;
    final dc = (q.dx / cell).floor(), dr = (q.dy / cell).floor();
    final r = transposed ? dc : dr, c = transposed ? dr : dc;
    return r * cols + c;
  }
}

class _TextCache {
  static final Map<int, TextPainter> _m = {};

  static TextPainter glyph(String text, double size, Color color, {FontWeight weight = FontWeight.w900}) {
    final key = Object.hash(text, size.round(), color.toARGB32(), weight.value);
    return _m.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: weight, color: color, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  static TextPainter number(int n, double size) {
    final key = Object.hash(n, size.round());
    return _m.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: numberColors[n],
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

double _easeOutBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// 깃발 그림. [u]는 칸 크기, [scale]은 등장 효과 배율.
void drawFlagGlyph(Canvas canvas, Offset center, double u, double scale) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  // 받침
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, u * 0.3), width: u * 0.42, height: u * 0.12),
    Paint()..color = const Color(0xFF3B2F2F),
  );
  // 깃대
  canvas.drawLine(
    Offset(-u * 0.02, u * 0.3),
    Offset(-u * 0.02, -u * 0.32),
    Paint()
      ..color = const Color(0xFF3B2F2F)
      ..strokeWidth = u * 0.06
      ..strokeCap = StrokeCap.round,
  );
  // 깃발
  final path = Path()
    ..moveTo(-u * 0.02, -u * 0.32)
    ..lineTo(u * 0.3, -u * 0.18)
    ..quadraticBezierTo(u * 0.1, -u * 0.12, -u * 0.02, -u * 0.04)
    ..close();
  canvas.drawPath(path, Paint()..color = const Color(0xFFE5484D));
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.025
      ..color = const Color(0xFF9E2A2F),
  );
  canvas.restore();
}

const Color kQuestionColor = Color(0xFF7E57C2);

/// 물음표(?) 표시: 보라색 동그라미 안의 하얀 물음표. [u]는 칸 크기.
void drawQuestionBadge(Canvas canvas, Offset center, double u, double scale) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.drawCircle(Offset(0, u * 0.03), u * 0.33, Paint()..color = const Color(0xFF4A2F8A));
  canvas.drawCircle(Offset.zero, u * 0.33, Paint()..color = kQuestionColor);
  final tp = _TextCache.glyph('?', u * 0.5, Colors.white);
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  canvas.restore();
}

/// 지뢰찾기 판 그리기: 풀밭 같은 타일, 열릴 때 톡 튀는 효과, 깃발, 귀여운 폭탄, 폭발.
class MinesPainter extends CustomPainter {
  MinesPainter({required this.c, required this.layout, required Listenable repaint}) : super(repaint: repaint);

  final MinesController c;
  final MinesLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final now = c.clockMs;
    final b = c.board;
    final s = layout.cell;

    // 폭발할 때 판이 흔들린다
    canvas.save();
    if (c.boomAt >= 0 && now - c.boomAt < 520) {
      final t = (now - c.boomAt) / 520;
      final amp = s * 0.22 * (1 - t);
      canvas.translate(sin(now * 0.09) * amp, cos(now * 0.13) * amp);
    }

    // 판 바탕
    final panel = RRect.fromRectAndRadius(
      (layout.origin & layout.boardSize).inflate(s * 0.12),
      Radius.circular(s * 0.28),
    );
    canvas.drawRRect(panel.shift(Offset(0, s * 0.06)), Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF6B4F3A));
    canvas.drawRRect(
      panel.deflate(s * 0.06),
      Paint()..color = const Color(0xFFCDBB97),
    );

    for (var i = 0; i < b.size; i++) {
      _paintCell(canvas, i, now);
    }

    _paintHint(canvas, now);
    _paintBoom(canvas, now);
    canvas.restore();
  }

  void _paintCell(Canvas canvas, int i, int now) {
    final b = c.board;
    final s = layout.cell;
    final rect = layout.rect(i).deflate(s * 0.03);
    final r = i ~/ b.cols, col = i % b.cols;
    final alt = (r + col).isOdd;
    final lost = c.status == MinesStatus.lost;
    final exploded = b.explodedCell == i;

    final shown = c.shownRevealed(i, now) || (exploded && now >= (c.revealAt[i] ?? 0));
    final mineOut = c.mineShown(i, now);

    final revealedBg = exploded
        ? const Color(0xFFFF8A80)
        : alt
            ? const Color(0xFFE6D9BC)
            : const Color(0xFFEDE1C7);

    if (shown || mineOut) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14)), Paint()..color = revealedBg);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.14)),
        Paint()..color = const Color(0xFFD5C5A2),
      );
    }

    // 열리는 중이면 타일이 사라지면서 값이 톡 나타난다
    final at = c.revealAt[i];
    final p = at == null ? 1.0 : ((now - at) / 240).clamp(0.0, 1.0);
    final popping = c.board.marks[i] == CellMark.revealed && at != null && now >= at && p < 1;

    if (!shown && !mineOut) {
      _tile(canvas, rect, alt, 1);
    } else if (popping) {
      _tile(canvas, rect.inflate(s * 0.05 * p), alt, 1 - p);
    }

    if (shown) {
      final scale = p < 1 ? 0.5 + 0.5 * _easeOutBack(p) : 1.0;
      if (exploded) {
        _mine(canvas, rect.center, s * 0.34 * scale, now, angry: true);
      } else if (b.adj[i] > 0) {
        final tp = _TextCache.number(b.adj[i], s * 0.62);
        canvas.save();
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.scale(scale);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }

    if (mineOut && !exploded) {
      final t = ((now - (c.mineShowAt[i] ?? 0)) / 260).clamp(0.0, 1.0);
      _mine(canvas, rect.center, s * 0.34 * (0.4 + 0.6 * _easeOutBack(t)), now);
      if (t < 1) {
        canvas.drawCircle(rect.center, s * 0.5 * t, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06 * (1 - t)
          ..color = const Color(0xFFFFB74D).withValues(alpha: 1 - t));
      }
    }

    // 깃발
    if (b.marks[i] == CellMark.flagged) {
      final at = c.flagAt[i];
      final t = at == null ? 1.0 : ((now - at) / 300).clamp(0.0, 1.0);
      if (t > 0 || at == null) {
        final wrong = lost && !b.mine[i];
        final sc = at != null && now < at ? 0.0 : 0.3 + 0.7 * _easeOutBack(t);
        if (sc > 0) _flag(canvas, rect, sc);
        if (wrong) {
          final cc = rect.center;
          final d = s * 0.28;
          final paint = Paint()
            ..color = const Color(0xFFD32F2F)
            ..strokeWidth = s * 0.09
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(cc + Offset(-d, -d), cc + Offset(d, d), paint);
          canvas.drawLine(cc + Offset(d, -d), cc + Offset(-d, d), paint);
        }
      }
    }

    // 물음표
    if (b.marks[i] == CellMark.question) {
      final at = c.flagAt[i];
      final t = at == null ? 1.0 : ((now - at) / 300).clamp(0.0, 1.0);
      if (at == null || now >= at) _question(canvas, rect, 0.3 + 0.7 * _easeOutBack(t));
    }
  }

  /// 풀밭 같은 둥근 타일 (위는 밝고 아래 가장자리는 어둡게).
  void _tile(Canvas canvas, Rect rect, bool alt, double opacity) {
    if (opacity <= 0) return;
    final s = layout.cell;
    final face = alt ? const Color(0xFF86CC62) : const Color(0xFF92D46E);
    final edge = const Color(0xFF4F9A3A);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.16));
    canvas.drawRRect(rr.shift(Offset(0, s * 0.07)), Paint()..color = edge.withValues(alpha: opacity));
    canvas.drawRRect(rr, Paint()..color = face.withValues(alpha: opacity));
    // 위쪽 하이라이트
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + s * 0.08, rect.top + s * 0.07, rect.width - s * 0.16, rect.height * 0.3),
        Radius.circular(s * 0.1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22 * opacity),
    );
  }

  void _flag(Canvas canvas, Rect rect, double scale) => drawFlagGlyph(canvas, rect.center, layout.cell, scale);

  void _question(Canvas canvas, Rect rect, double scale) => drawQuestionBadge(canvas, rect.center, layout.cell, scale);

  /// 귀여운 폭탄: 둥근 몸통, 반짝이는 하이라이트, 눈, 심지와 불꽃.
  void _mine(Canvas canvas, Offset center, double radius, int now, {bool angry = false}) {
    final body = Paint()..color = const Color(0xFF2B2D42);
    // 가시
    final spike = Paint()
      ..color = const Color(0xFF2B2D42)
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * pi / 4;
      canvas.drawLine(center + Offset(cos(a), sin(a)) * radius * 0.8, center + Offset(cos(a), sin(a)) * radius * 1.22, spike);
    }
    canvas.drawCircle(center, radius, body);
    canvas.drawCircle(center + Offset(-radius * 0.35, -radius * 0.38), radius * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.75));
    // 눈
    for (final dx in [-1.0, 1.0]) {
      final e = center + Offset(dx * radius * 0.34, radius * 0.08);
      canvas.drawCircle(e, radius * 0.2, Paint()..color = Colors.white);
      canvas.drawCircle(e + Offset(0, radius * 0.03), radius * 0.1, Paint()..color = const Color(0xFF2B2D42));
    }
    if (angry) {
      final brow = Paint()
        ..color = Colors.white
        ..strokeWidth = radius * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center + Offset(-radius * 0.6, -radius * 0.2), center + Offset(-radius * 0.15, -radius * 0.05), brow);
      canvas.drawLine(center + Offset(radius * 0.6, -radius * 0.2), center + Offset(radius * 0.15, -radius * 0.05), brow);
    }
    // 심지
    final fuseBase = center + Offset(radius * 0.55, -radius * 0.85);
    final fuseTip = center + Offset(radius * 0.95, -radius * 1.3);
    canvas.drawLine(
      fuseBase,
      fuseTip,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = radius * 0.14
        ..strokeCap = StrokeCap.round,
    );
    final flick = 0.8 + 0.25 * sin(now * 0.03);
    canvas.drawCircle(fuseTip, radius * 0.26 * flick, Paint()..color = const Color(0xFFFFC107));
    canvas.drawCircle(fuseTip, radius * 0.13 * flick, Paint()..color = const Color(0xFFFF5722));
  }

  void _paintHint(Canvas canvas, int now) {
    final h = c.hint;
    if (h == null) return;
    final s = layout.cell;
    final pulse = 0.5 + 0.5 * sin(now * 0.008);
    void ring(int i, Color color, double width) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.rect(i).deflate(s * 0.02), Radius.circular(s * 0.18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.55 + 0.45 * pulse),
      );
    }

    for (final i in h.reasons) {
      ring(i, const Color(0xFF3E7BFA), s * 0.1);
    }
    final target = h.kind == HintKind.safe ? const Color(0xFF00C853) : const Color(0xFFFF1744);
    for (final i in h.targets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(layout.rect(i).deflate(s * 0.03), Radius.circular(s * 0.16)),
        Paint()..color = target.withValues(alpha: 0.18 + 0.2 * pulse),
      );
      ring(i, target, s * 0.1);
    }
  }

  /// 터지는 순간의 불꽃.
  void _paintBoom(Canvas canvas, int now) {
    final hit = c.board.explodedCell;
    if (hit == null || c.boomAt < 0) return;
    final t = (now - c.boomAt) / 800;
    if (t < 0 || t > 1) return;
    final s = layout.cell;
    final center = layout.rect(hit).center;
    final r = s * (0.4 + 2.6 * Curves.easeOut.transform(t));
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.55 * (1 - t)));
    canvas.drawCircle(center, r * 0.7, Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.6 * (1 - t)));
    canvas.drawCircle(center, r * 0.38, Paint()..color = const Color(0xFFFF5722).withValues(alpha: 0.7 * (1 - t)));
    final ray = Paint()
      ..color = const Color(0xFFFFF176).withValues(alpha: 1 - t)
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 14; k++) {
      final a = k * 2 * pi / 14 + 0.3;
      final d1 = s * (0.5 + 2.0 * t), d2 = s * (0.9 + 3.2 * t);
      canvas.drawLine(center + Offset(cos(a), sin(a)) * d1, center + Offset(cos(a), sin(a)) * d2, ray);
    }
  }

  @override
  bool shouldRepaint(MinesPainter old) => true;
}

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
