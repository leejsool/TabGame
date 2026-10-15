import 'dart:math';

import 'package:flutter/material.dart';

import '../core/prophecy_rules.dart';
import '../game/prophecy_controller.dart';

/// 예언의 대표 색 (허브 카드·교과학습 강조색).
const Color kProphColor = Color(0xFF4B5FC6);

/// 먼저 쓰는 쪽(분홍 펜)과 나중에 쓰는 쪽(청록 펜)의 색.
const Color kPenPink = Color(0xFFC2306B);
const Color kPenTeal = Color(0xFF0F7C86);

Color penColor(int side) => side == 0 ? kPenPink : kPenTeal;

/// 칸 안 숫자의 글씨: 분홍 펜은 세리프(로라) 글꼴, 청록 펜은 나눔고딕 아주 굵은 글씨라서 색을 못 알아봐도 구분된다.
TextStyle penDigitStyle(int side, double size) => side == 0
    ? TextStyle(
        fontFamily: 'Lora',
        fontFamilyFallback: const ['NanumGothic'],
        fontSize: size,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        color: kPenPink,
        height: 1.0,
      )
    : TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w800, color: kPenTeal, height: 1.0);

/// 숫자 한 글자를 [center]에 정중앙으로 그린다. 글꼴마다 줄 높이의 위아래 여백이 달라서 상자가 아니라
/// 글자 바닥선(baseline)과 숫자 높이(글자 크기의 약 0.72배)를 기준으로 맞춘다.
void paintPenDigit(Canvas canvas, String digit, Offset center, double size, int side) {
  final tp = TextPainter(text: TextSpan(text: digit, style: penDigitStyle(side, size)), textDirection: TextDirection.ltr)..layout();
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + size * 0.36 - baseline));
}

const Color _paper = Color(0xFFFFFDF6);
const Color _ink = Color(0xFF4A3B3B);

/// 표가 그려지는 자리: 칸 크기와 위치, 칸 ↔ 좌표 바꾸기. 그리기와 누르기가 같은 계산을 쓴다.
class ProphLayout {
  ProphLayout(Size size, this.rows, this.cols, {this.gutter = 26}) {
    final w = size.width - gutter - 4, h = size.height - gutter - 4;
    cell = max(8.0, min(min(w / cols, h / rows), 84.0));
    final totalW = cell * cols + gutter, totalH = cell * rows + gutter;
    origin = Offset((size.width - totalW) / 2, (size.height - totalH) / 2);
  }

  final int rows, cols;

  /// 줄 끝의 개수 표시를 위한 오른쪽·아래쪽 여백.
  final double gutter;
  late final double cell;
  late final Offset origin;

  Rect get grid => Rect.fromLTWH(origin.dx, origin.dy, cell * cols, cell * rows);

  Rect cellRect(int i) => Rect.fromLTWH(origin.dx + (i % cols) * cell, origin.dy + (i ~/ cols) * cell, cell, cell);

  /// 화면 좌표 [p]가 가리키는 칸 (표 밖이면 -1).
  int cellAt(Offset p) {
    final g = grid;
    if (!g.contains(p)) return -1;
    final c = ((p.dx - g.left) / cell).floor().clamp(0, cols - 1);
    final r = ((p.dy - g.top) / cell).floor().clamp(0, rows - 1);
    return r * cols + c;
  }
}

/// 예언 표 그림: 칸의 숫자·X, 줄 끝의 개수, 고른 칸, 점수 동그라미와 화살표.
class ProphBoardPainter extends CustomPainter {
  ProphBoardPainter({
    required this.state,
    this.selected = -1,
    this.lastCell = -1,
    this.reveal = 0,
    this.flags = const {},
    this.showCounts = true,
  });

  final ProphState state;

  /// 사람이 고른 칸 (-1이면 없음): 그 칸과 행·열이 옅게 물든다.
  final int selected;

  /// 방금 쓴 칸.
  final int lastCell;

  /// 점수 표시가 나타난 정도 0~1. 행에서 맞은 숫자(동그라미 + 좌우 화살표)가 먼저, 이어서 열(위아래 화살표)이 나타난다.
  final double reveal;

  /// 칸에 붙이는 표시 (안내 그림용): 칸 번호 → 색. 그 칸에 색 테두리가 그려진다.
  final Map<int, Color> flags;

  /// 줄 끝에 지금 숫자가 몇 개인지 보일지.
  final bool showCounts;

  @override
  void paint(Canvas canvas, Size size) {
    final L = ProphLayout(size, state.rows, state.cols, gutter: showCounts ? 26 : 0);
    final cell = L.cell;
    final grid = L.grid;

    // 종이
    final paper = RRect.fromRectAndRadius(grid.inflate(5), const Radius.circular(6));
    canvas.drawRRect(paper.shift(const Offset(0, 2)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(paper, Paint()..color = _paper);

    // 고른 칸의 행·열 (옅게)
    if (selected >= 0) {
      final tint = Paint()..color = kProphColor.withValues(alpha: 0.09);
      final r = selected ~/ state.cols, c = selected % state.cols;
      canvas.drawRect(Rect.fromLTWH(grid.left, grid.top + r * cell, grid.width, cell), tint);
      canvas.drawRect(Rect.fromLTWH(grid.left + c * cell, grid.top, cell, grid.height), tint);
      canvas.drawRect(L.cellRect(selected).deflate(1), Paint()..color = kProphColor.withValues(alpha: 0.24));
    }

    // 방금 쓴 칸
    if (lastCell >= 0 && state.cells[lastCell] != kBlank) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(L.cellRect(lastCell).deflate(2.5), const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kProphColor.withValues(alpha: 0.55),
      );
    }

    // 줄 (손으로 그린 듯 두꺼운 선)
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.6, cell * 0.04)
      ..color = _ink;
    for (var r = 0; r <= state.rows; r++) {
      canvas.drawLine(Offset(grid.left, grid.top + r * cell), Offset(grid.right, grid.top + r * cell), line);
    }
    for (var c = 0; c <= state.cols; c++) {
      canvas.drawLine(Offset(grid.left + c * cell, grid.top), Offset(grid.left + c * cell, grid.bottom), line);
    }

    // 칸 안: 숫자와 X
    for (var i = 0; i < state.cells.length; i++) {
      final v = state.cells[i];
      if (v == kBlank) continue;
      final rect = L.cellRect(i);
      if (v == kCross) {
        final own = state.owners[i];
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = max(1.6, cell * 0.04)
          ..color = (own == kNoOwner ? _ink.withValues(alpha: 0.45) : _ink.withValues(alpha: 0.85));
        final m = rect.deflate(cell * 0.18);
        canvas.drawLine(m.topLeft, m.bottomRight, p);
        canvas.drawLine(m.topRight, m.bottomLeft, p);
      } else {
        paintPenDigit(canvas, '$v', rect.center, cell * 0.56, state.owners[i] == 1 ? 1 : 0);
      }
    }

    // 안내 그림용 표시
    flags.forEach((cellIndex, color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(L.cellRect(cellIndex).deflate(3), Radius.circular(cell * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
    });

    // 줄 끝의 개수
    final hits = reveal > 0 ? state.hits() : const <ProphHit>[];
    if (showCounts) {
      final rowHit = {for (final h in hits) if (h.byRow) state.rowOf(h.cell)};
      final colHit = {for (final h in hits) if (h.byCol) state.colOf(h.cell)};
      for (var r = 0; r < state.rows; r++) {
        final ok = rowHit.contains(r) && reveal >= 1;
        _count(canvas, Offset(grid.right + 15, grid.top + (r + 0.5) * cell), state.rowCount(r), ok);
      }
      for (var c = 0; c < state.cols; c++) {
        final ok = colHit.contains(c) && reveal >= 1;
        _count(canvas, Offset(grid.left + (c + 0.5) * cell, grid.bottom + 16), state.colCount(c), ok);
      }
    }

    // 점수: 동그라미, 행이면 좌우 화살표, 열이면 위아래 화살표
    if (hits.isNotEmpty) _paintHits(canvas, L, hits);
  }

  void _paintHits(Canvas canvas, ProphLayout L, List<ProphHit> hits) {
    final rowHits = [for (final h in hits) if (h.byRow) h]
      ..sort((a, b) => a.cell.compareTo(b.cell));
    final colHits = [for (final h in hits) if (h.byCol) h]
      ..sort((a, b) {
        final c = state.colOf(a.cell).compareTo(state.colOf(b.cell));
        return c != 0 ? c : a.cell.compareTo(b.cell);
      });
    final total = rowHits.length + colHits.length;
    double f(int i) => (reveal * total - i).clamp(0.0, 1.0);

    // 동그라미는 그 칸의 첫 번째(행이 먼저) 득점과 함께 나타난다
    final circleAt = <int, double>{};
    for (var i = 0; i < rowHits.length; i++) {
      circleAt.putIfAbsent(rowHits[i].cell, () => f(i));
    }
    for (var i = 0; i < colHits.length; i++) {
      circleAt.putIfAbsent(colHits[i].cell, () => f(rowHits.length + i));
    }
    final cell = L.cell;
    for (final h in hits) {
      final a = circleAt[h.cell] ?? 0;
      if (a <= 0) continue;
      final color = penColor(h.owner);
      final center = L.cellRect(h.cell).center;
      final r = cell * 0.30 * (0.7 + 0.3 * a);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, cell * 0.06)
          ..color = color.withValues(alpha: a),
      );
    }
    for (var i = 0; i < rowHits.length; i++) {
      final a = f(i);
      if (a > 0) _arrows(canvas, L.cellRect(rowHits[i].cell).center, cell, penColor(rowHits[i].owner), a, horizontal: true);
    }
    for (var i = 0; i < colHits.length; i++) {
      final a = f(rowHits.length + i);
      if (a > 0) _arrows(canvas, L.cellRect(colHits[i].cell).center, cell, penColor(colHits[i].owner), a, horizontal: false);
    }
  }

  /// 동그라미 양옆(행) 또는 위아래(열)로 뻗는 화살표 두 개.
  void _arrows(Canvas canvas, Offset center, double cell, Color color, double a, {required bool horizontal}) {
    final r0 = cell * 0.30, r1 = cell * 0.30 + (cell * 0.5 - cell * 0.30) * a;
    final head = max(3.0, cell * 0.09);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(2.0, cell * 0.055)
      ..color = color;
    for (final dir in const [-1, 1]) {
      final d = horizontal ? Offset(dir.toDouble(), 0) : Offset(0, dir.toDouble());
      final n = horizontal ? const Offset(0, 1) : const Offset(1, 0);
      final from = center + d * r0, to = center + d * r1;
      canvas.drawLine(from, to, p);
      canvas.drawLine(to, to - d * head + n * head * 0.8, p);
      canvas.drawLine(to, to - d * head - n * head * 0.8, p);
    }
  }

  void _count(Canvas canvas, Offset at, int n, bool ok) {
    final r = ok ? 11.0 : 10.0;
    canvas.drawCircle(at, r, Paint()..color = ok ? const Color(0x332E9E4F) : const Color(0x14000000));
    _text(canvas, '$n', at, 13, ok ? const Color(0xFF1E7A3A) : const Color(0xFF7A6B6B), ok ? FontWeight.w900 : FontWeight.w700);
  }

  void _text(Canvas canvas, String s, Offset center, double size, Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: weight, color: color, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(ProphBoardPainter old) => true;
}

/// 눌러서 칸을 고르는 예언 표.
class ProphBoard extends StatefulWidget {
  const ProphBoard({super.key, required this.controller});

  final ProphecyController controller;

  @override
  State<ProphBoard> createState() => _ProphBoardState();
}

class _ProphBoardState extends State<ProphBoard> with SingleTickerProviderStateMixin {
  ProphecyController get c => widget.controller;

  /// 판이 끝났을 때 점수 표시가 차례로 나타나는 정도.
  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    c.addListener(_onChanged);
    if (c.isOver) _reveal.value = 1;
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _reveal.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (c.isOver) {
      if (!_reveal.isAnimating && _reveal.value < 1) _reveal.forward();
    } else if (_reveal.value != 0) {
      _reveal.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = c.rows, cols = c.cols;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final layout = ProphLayout(size, rows, cols);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final cell = layout.cellAt(d.localPosition);
            if (cell >= 0) c.select(cell);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([c, _reveal]),
            builder: (context, _) => CustomPaint(
              size: size,
              painter: ProphBoardPainter(
                state: c.state,
                selected: c.humanCanAct ? c.selected : -1,
                lastCell: c.lastCell,
                reveal: Curves.easeInOut.transform(_reveal.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 움직이지 않는 예언 표 그림 (안내·교과학습용).
class ProphBoardView extends StatelessWidget {
  const ProphBoardView({
    super.key,
    required this.state,
    this.reveal = 0,
    this.flags = const {},
    this.selected = -1,
    this.showCounts = true,
  });

  final ProphState state;
  final double reveal;
  final Map<int, Color> flags;
  final int selected;
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ProphBoardPainter(state: state, reveal: reveal, flags: flags, selected: selected, showCounts: showCounts),
      size: Size.infinite,
    );
  }
}
