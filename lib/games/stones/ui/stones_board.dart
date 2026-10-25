import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/stones_rules.dart';

const Color kStonesColor = Color(0xFF6D7F45);

/// 3행 × 12칸 판. 위에 칸 번호, 왼쪽에 행 번호.
/// [showGaps]를 켜면 오른쪽에 행마다 빈칸 수 (그 아래에 [onMoreHint]가 있으면 "힌트 더보기" 단추),
/// [showBinary]까지 켜면 빈칸 수의 2진법(8·4·2·1 자리) 표와 아래 줄에 자리마다 1의 개수.
///
/// 칸을 누르면 [onTapCell]. 내 돌을 누른 행([selectedRow])은 갈 수 있는 칸에 점이 찍힌다.
/// [canDrag]면 차례인 사람의 돌을 끌어서 옮길 수도 있다: 끄는 동안 돌이 떠서 손가락을 따라오고,
/// 갈 수 있는 칸에 놓으면 [onTapCell](행, 칸)으로 알린다.
class StonesBoard extends StatefulWidget {
  const StonesBoard({
    super.key,
    required this.state,
    required this.onTapCell,
    this.selectedRow,
    this.lastMove,
    this.showGaps = false,
    this.showBinary = false,
    this.onMoreHint,
    this.canDrag = false,
    this.highlightMovable = false,
  });

  final StonesState state;
  final void Function(int row, int col)? onTapCell;
  final int? selectedRow;

  /// 방금 옮긴 돌 (행, 칸) — 고리를 그린다.
  final (int, int)? lastMove;
  final bool showGaps;
  final bool showBinary;
  final VoidCallback? onMoreHint;
  final bool canDrag;

  /// 차례인 사람의 돌 중 지금 움직일 수 있는 돌 둘레를 밝게 보여 준다 (어느 돌을 눌러야 하는지 알려 주려고).
  final bool highlightMovable;

  @override
  State<StonesBoard> createState() => _StonesBoardState();
}

class _StonesBoardState extends State<StonesBoard> {
  /// 끌고 있는 돌의 행과 손가락 위치 (판 안 좌표).
  int? _dragRow;
  Offset _dragPos = Offset.zero;

  StonesState get state => widget.state;

  (int, int)? _cellAt(Offset p, double cell) {
    final col = (p.dx / cell - 1).floor();
    final row = (p.dy / cell - 1).floor();
    return row >= 0 && row < kRows && col >= 0 && col < kCols ? (row, col) : null;
  }

  void _dragStart(Offset p, double cell) {
    final hit = _cellAt(p, cell);
    if (!widget.canDrag || widget.onTapCell == null || hit == null) return;
    final (row, col) = hit;
    if (state.stonesOf(state.turn)[row] != col) return;
    setState(() {
      _dragRow = row;
      _dragPos = p;
    });
  }

  void _dragEnd(double cell) {
    final row = _dragRow;
    if (row == null) return;
    // 같은 행 안에서만 옮기니 손가락의 가로 위치로 칸을 정한다
    final col = (_dragPos.dx / cell - 1).floor();
    setState(() => _dragRow = null);
    if (state.targets(row).contains(col)) widget.onTapCell!(row, col);
  }

  @override
  Widget build(BuildContext context) {
    final showGaps = widget.showGaps, onMoreHint = widget.onMoreHint, onTapCell = widget.onTapCell;
    return LayoutBuilder(
      builder: (context, box) {
        // 머리 칸(번호) 1개 + 12칸 + (빈칸 수 칸 또는 2진법 표), 아래에 "1의 개수" 줄이나 힌트 단추 줄
        final binary = showGaps && widget.showBinary;
        final extraCols = 1 + (binary ? _kTableCols : (showGaps ? 1.6 : 0.4));
        final rows = kRows + (binary || (showGaps && onMoreHint != null) ? 2 : 1);
        final cell = [box.maxWidth / (kCols + extraCols), box.maxHeight / rows, 72.0].reduce((a, b) => a < b ? a : b);
        final size = Size(cell * (kCols + extraCols), cell * rows);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final more = showGaps && !binary && onMoreHint != null;
        final dragging = _dragRow != null && widget.canDrag;
        final board = GestureDetector(
          onTapUp: onTapCell == null
              ? null
              : (d) {
                  final hit = _cellAt(d.localPosition, cell);
                  if (hit != null) onTapCell(hit.$1, hit.$2);
                },
          // 손가락을 댄 곳에서 끌기를 시작한다 (조금 움직인 뒤의 위치로 돌을 찾으면 옆 칸이 잡힌다)
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: widget.canDrag ? (d) => _dragStart(d.localPosition, cell) : null,
          onPanUpdate: widget.canDrag ? (d) => _dragRow == null ? null : setState(() => _dragPos = d.localPosition) : null,
          onPanEnd: widget.canDrag ? (_) => _dragEnd(cell) : null,
          onPanCancel: widget.canDrag ? () => setState(() => _dragRow = null) : null,
          child: CustomPaint(
            size: size,
            painter: _BoardPainter(
              state: state,
              cell: cell,
              selectedRow: dragging ? _dragRow : widget.selectedRow,
              lastMove: dragging ? null : widget.lastMove,
              showGaps: showGaps,
              binary: binary,
              dark: dark,
              drag: dragging ? (_dragRow!, _dragPos) : null,
              movableRows: widget.highlightMovable && !dragging
                  ? [for (var r = 0; r < kRows; r++) if (r != widget.selectedRow && state.targets(r).isNotEmpty) r]
                  : const [],
            ),
          ),
        );
        return Center(
          child: !more
              ? board
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    board,
                    Positioned(
                      right: 0,
                      top: cell * (kRows + 1) + cell * 0.12,
                      height: cell * 0.76,
                      child: FilledButton.tonalIcon(
                        onPressed: onMoreHint,
                        icon: Icon(Icons.lightbulb_outline_rounded, size: cell * 0.32),
                        label: const Text('힌트 더보기'),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: cell * 0.2),
                          visualDensity: VisualDensity.compact,
                          textStyle: TextStyle(
                            fontFamily: 'NanumGothic',
                            fontSize: (cell * 0.26).clamp(11.0, 16.0),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// 오른쪽 표의 폭 (칸 단위): 띄움 0.3 + 빈칸 수 1.2 + 2진법 네 자리 × 0.75.
const double _kTableCols = 0.3 + 1.2 + 4 * 0.75;

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.state,
    required this.cell,
    required this.selectedRow,
    required this.lastMove,
    required this.showGaps,
    required this.binary,
    required this.dark,
    this.drag,
    this.movableRows = const [],
  });

  final StonesState state;
  final double cell;
  final int? selectedRow;
  final (int, int)? lastMove;
  final bool showGaps;
  final bool binary;
  final bool dark;

  /// 끌고 있는 돌: (행, 손가락 위치). 그 돌은 제자리에 흐리게, 손가락 위에 떠서 그린다.
  final (int, Offset)? drag;

  /// 둘레를 밝게 보여 줄 돌의 행 (차례인 쪽의 돌).
  final List<int> movableRows;

  Color get _ink => dark ? const Color(0xFFE6E8DD) : const Color(0xFF3C4A35);

  /// [at]을 가운데로 (오른쪽 맞춤이면 [at]이 글자의 오른쪽 끝) 글자를 쓴다.
  void _text(
    Canvas c,
    String s,
    Offset at,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    TextAlign align = TextAlign.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, color: color, fontWeight: weight, height: 1.1),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.right ? tp.width : tp.width / 2;
    tp.paint(c, at - Offset(dx, tp.height / 2));
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
        final base = dark
            ? (between ? const Color(0xFF34402C) : const Color(0xFF262A22))
            : (between ? const Color(0xFFEAF2DC) : Colors.white);
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
    canvas.drawRect(
      Rect.fromLTWH(cell, cell, cell * kCols, cell * kRows),
      grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 갈 수 있는 칸
    for (final col in targets) {
      canvas.drawCircle(_cellRect(selectedRow!, col).center, cell * 0.11, Paint()..color = const Color(0xFFE09B00));
    }

    // 지금 움직일 수 있는 돌 둘레: 은은한 노랑 빛과 고리 (돌 밑에 깔린다)
    for (final r in movableRows) {
      final center = _cellRect(r, state.stonesOf(state.turn)[r]).center;
      canvas.drawCircle(center, cell * 0.5, Paint()..color = const Color(0xFFFFC107).withValues(alpha: dark ? 0.38 : 0.45));
      canvas.drawCircle(
        center,
        cell * 0.49,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05
          ..color = const Color(0xFFE09B00),
      );
    }

    final drag = this.drag;
    for (var r = 0; r < kRows; r++) {
      for (final side in Side.values) {
        final ghost = drag != null && drag.$1 == r && side == state.turn;
        _stone(canvas, _cellRect(r, state.stonesOf(side)[r]).center, side, ghost: ghost);
      }
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

    if (drag != null) {
      // 놓을 수 있는 칸이면 초록 고리, 그리고 손가락 위에 떠 있는 돌
      final (row, pos) = drag;
      final col = (pos.dx / cell - 1).floor();
      if (state.targets(row).contains(col)) {
        canvas.drawCircle(
          _cellRect(row, col).center,
          cell * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.07
            ..color = const Color(0xFF2E8B3E),
        );
      }
      _stone(canvas, pos - Offset(0, cell * 0.2), state.turn, lifted: true);
    }

    if (showGaps && binary) {
      _table(canvas, numColor);
    } else if (showGaps) {
      for (var r = 0; r < kRows; r++) {
        _text(
          canvas,
          '${state.gap(r)}',
          Offset(cell * (kCols + 1.8), cell * (r + 1.5)),
          cell * 0.42,
          kStonesColor,
          weight: FontWeight.w800,
        );
      }
      _text(canvas, '빈칸', Offset(cell * (kCols + 1.8), cell * 0.55), cell * 0.3, numColor, weight: FontWeight.w400);
    }
  }

  /// 빈칸 수와 2진법 표: 행마다 "빈칸 | 8 4 2 1", 맨 아래 줄은 자리마다 1의 개수 (짝수면 초록, 홀수면 빨강).
  void _table(Canvas canvas, Color numColor) {
    const good = Color(0xFF2E8B3E);
    const bad = Color(0xFFD84315);
    final x0 = cell * (kCols + 1.3);
    final decX = x0 + cell * 0.6;
    double bitX(int i) => x0 + cell * (1.2 + 0.75 * (i + 0.5));
    double rowY(int r) => cell * (r + 1.5);
    final tableRect = Rect.fromLTRB(x0, cell * 0.12, x0 + cell * (1.2 + 3), cell * (kRows + 1.88));
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, Radius.circular(cell * 0.18)),
      Paint()..color = kStonesColor.withValues(alpha: dark ? 0.16 : 0.08),
    );
    final line = Paint()
      ..color = _ink.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x0 + cell * 1.2, tableRect.top + cell * 0.1), Offset(x0 + cell * 1.2, tableRect.bottom - cell * 0.1), line);
    canvas.drawLine(Offset(x0 + cell * 0.1, cell * (kRows + 1)), Offset(tableRect.right - cell * 0.1, cell * (kRows + 1)), line);

    _text(canvas, '빈칸', Offset(decX, cell * 0.55), cell * 0.3, numColor, weight: FontWeight.w400);
    for (var i = 0; i < kBits.length; i++) {
      _text(canvas, '${kBits[i]}', Offset(bitX(i), cell * 0.55), cell * 0.32, numColor);
    }
    for (var r = 0; r < kRows; r++) {
      final g = state.gap(r);
      _text(canvas, '$g', Offset(decX, rowY(r)), cell * 0.42, kStonesColor, weight: FontWeight.w800);
      for (var i = 0; i < kBits.length; i++) {
        final on = g & kBits[i] != 0;
        if (on) {
          canvas.drawCircle(Offset(bitX(i), rowY(r)), cell * 0.27, Paint()..color = kStonesColor.withValues(alpha: dark ? 0.45 : 0.22));
        }
        _text(
          canvas,
          on ? '1' : '0',
          Offset(bitX(i), rowY(r)),
          cell * 0.36,
          on ? _ink : _ink.withValues(alpha: 0.35),
          weight: on ? FontWeight.w800 : FontWeight.w400,
        );
      }
    }

    // 맨 아래 줄: 자리마다 1의 개수
    final counts = state.bitCounts;
    final y = rowY(kRows);
    _text(canvas, '1의\n개수', Offset(decX, y), cell * 0.24, numColor, weight: FontWeight.w400);
    for (var i = 0; i < kBits.length; i++) {
      final even = counts[i].isEven;
      final color = even ? good : bad;
      canvas.drawCircle(Offset(bitX(i), y), cell * 0.3, Paint()..color = color.withValues(alpha: 0.16));
      canvas.drawCircle(
        Offset(bitX(i), y),
        cell * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      );
      _text(canvas, '${counts[i]}', Offset(bitX(i), y), cell * 0.36, color, weight: FontWeight.w800);
    }
    final allEven = counts.every((c) => c.isEven);
    _text(
      canvas,
      allEven ? '8·4·2·1 자리의 1이 모두 짝수 개예요 →' : '1이 홀수 개인 자리(빨강)가 있어요 →',
      Offset(cell * (kCols + 1) - cell * 0.1, y),
      cell * 0.3,
      allEven ? good : bad,
      align: TextAlign.right,
    );
  }

  /// 바둑돌. [lifted]면 크게, 그림자를 멀리 떨어뜨려 떠 있는 듯이. [ghost]면 끌려 나간 자리라 흐리게.
  void _stone(Canvas c, Offset p, Side side, {bool lifted = false, bool ghost = false}) {
    final r = cell * (lifted ? 0.43 : 0.36);
    final rect = Rect.fromCircle(center: p, radius: r);
    if (ghost) c.saveLayer(rect.inflate(r), Paint()..color = Colors.black.withValues(alpha: 0.28));
    if (lifted) {
      c.drawCircle(
        p + Offset(0, r * 0.5),
        r * 0.95,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
      );
    } else {
      c.drawCircle(p + Offset(0, r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.25));
    }
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
    if (ghost) c.restore();
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
