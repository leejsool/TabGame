import 'dart:math';

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

  void _flag(Canvas canvas, Rect rect, double scale) {
    final s = layout.cell;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    final u = s;
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
