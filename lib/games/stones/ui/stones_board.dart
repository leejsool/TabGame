import 'package:flutter/material.dart';

import '../core/stones_rules.dart';

const Color kStonesColor = Color(0xFF6D7F45);

/// 3행 × 12칸 판. 위에 칸 번호, 왼쪽에 행 번호, (켜면) 오른쪽에 행마다 빈칸 수.
///
/// 칸을 누르면 [onTapCell]. 내 돌을 누른 행([selectedRow])은 갈 수 있는 칸에 점이 찍힌다.
class StonesBoard extends StatelessWidget {
  const StonesBoard({
    super.key,
    required this.state,
    required this.onTapCell,
    this.selectedRow,
    this.lastMove,
    this.showGaps = false,
  });

  final StonesState state;
  final void Function(int row, int col)? onTapCell;
  final int? selectedRow;

  /// 방금 옮긴 돌 (행, 칸) — 고리를 그린다.
  final (int, int)? lastMove;
  final bool showGaps;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // 머리 칸(번호) 1개 + 12칸 + (빈칸 수 칸 1.6개)
      final extraCols = 1 + (showGaps ? 1.6 : 0.4);
      final cell = [box.maxWidth / (kCols + extraCols), box.maxHeight / (kRows + 1), 72.0].reduce((a, b) => a < b ? a : b);
      final size = Size(cell * (kCols + extraCols), cell * (kRows + 1));
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: GestureDetector(
          onTapUp: onTapCell == null
              ? null
              : (d) {
                  final col = (d.localPosition.dx / cell - 1).floor();
                  final row = (d.localPosition.dy / cell - 1).floor();
                  if (row >= 0 && row < kRows && col >= 0 && col < kCols) onTapCell!(row, col);
                },
          child: CustomPaint(
            size: size,
            painter: _BoardPainter(
              state: state,
              cell: cell,
              selectedRow: selectedRow,
              lastMove: lastMove,
              showGaps: showGaps,
              dark: dark,
            ),
          ),
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.state, required this.cell, required this.selectedRow, required this.lastMove, required this.showGaps, required this.dark});

  final StonesState state;
  final double cell;
  final int? selectedRow;
  final (int, int)? lastMove;
  final bool showGaps;
  final bool dark;

  Color get _ink => dark ? const Color(0xFFE6E8DD) : const Color(0xFF3C4A35);

  void _text(Canvas c, String s, Offset center, double size, Color color, {FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  Rect _cellRect(int r, int col) => Rect.fromLTWH(cell * (col + 1), cell * (r + 1), cell, cell);

  @override
  void paint(Canvas canvas, Size size) {
    final numColor = _ink.withValues(alpha: 0.7);
    for (var col = 0; col < kCols; col++) {
      _text(canvas, '${col + 1}', Offset(cell * (col + 1.5), cell * 0.55), cell * 0.36, numColor, weight: FontWeight.w400);
    }
    for (var r = 0; r < kRows; r++) {
      _text(canvas, '${r + 1}', Offset(cell * 0.55, cell * (r + 1.5)), cell * 0.36, numColor, weight: FontWeight.w400);
    }

    // 칸 바탕: 두 돌 사이 빈칸은 연한 초록, 밖은 흰 바탕
    final targets = selectedRow == null ? const <int>[] : state.targets(selectedRow!);
    for (var r = 0; r < kRows; r++) {
      for (var col = 0; col < kCols; col++) {
        final between = col > state.white[r] && col < state.black[r];
        final base = dark ? (between ? const Color(0xFF34402C) : const Color(0xFF262A22)) : (between ? const Color(0xFFEAF2DC) : Colors.white);
        canvas.drawRect(_cellRect(r, col), Paint()..color = base);
      }
    }
    if (selectedRow != null) {
      final band = Rect.fromLTWH(cell, cell * (selectedRow! + 1), cell * kCols, cell);
      canvas.drawRect(band, Paint()..color = const Color(0xFFFFD54F).withValues(alpha: dark ? 0.16 : 0.22));
    }

    // 격자
    final grid = Paint()
      ..color = _ink.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var r = 0; r <= kRows; r++) {
      canvas.drawLine(Offset(cell, cell * (r + 1)), Offset(cell * (kCols + 1), cell * (r + 1)), grid);
    }
    for (var col = 0; col <= kCols; col++) {
      canvas.drawLine(Offset(cell * (col + 1), cell), Offset(cell * (col + 1), cell * (kRows + 1)), grid);
    }
    canvas.drawRect(Rect.fromLTWH(cell, cell, cell * kCols, cell * kRows), grid..style = PaintingStyle.stroke..strokeWidth = 2);

    // 갈 수 있는 칸
    for (final col in targets) {
      canvas.drawCircle(_cellRect(selectedRow!, col).center, cell * 0.11, Paint()..color = const Color(0xFFE09B00));
    }

    for (var r = 0; r < kRows; r++) {
      _stone(canvas, _cellRect(r, state.white[r]).center, Side.white);
      _stone(canvas, _cellRect(r, state.black[r]).center, Side.black);
    }

    final last = lastMove;
    if (last != null) {
      canvas.drawCircle(
        _cellRect(last.$1, last.$2).center,
        cell * 0.43,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06
          ..color = const Color(0xFFE53935),
      );
    }

    if (showGaps) {
      for (var r = 0; r < kRows; r++) {
        _text(canvas, '${state.gap(r)}', Offset(cell * (kCols + 1.8), cell * (r + 1.5)), cell * 0.42, kStonesColor, weight: FontWeight.w800);
      }
      _text(canvas, '빈칸', Offset(cell * (kCols + 1.8), cell * 0.55), cell * 0.3, numColor, weight: FontWeight.w400);
    }
  }

  void _stone(Canvas c, Offset p, Side side) {
    final r = cell * 0.36;
    final rect = Rect.fromCircle(center: p, radius: r);
    c.drawCircle(p + Offset(0, r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.25));
    final colors = side == Side.white ? const [Colors.white, Color(0xFFD6D6D6)] : const [Color(0xFF5A5A5A), Color(0xFF111111)];
    c.drawCircle(p, r, Paint()..shader = RadialGradient(center: const Alignment(-0.35, -0.4), colors: colors).createShader(rect));
    c.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.03
        ..color = side == Side.white ? const Color(0xFF555555) : Colors.black,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
