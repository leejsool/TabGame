import 'dart:math';

import 'package:flutter/material.dart';

import '../core/grid.dart';
import '../game/hint.dart';
import '../game/sudoku_game.dart';
import 'sudoku_colors.dart';

/// 글자 그리기 객체를 재사용해 매 프레임 비용을 줄인다.
class TextCache {
  final Map<int, TextPainter> _m = {};

  TextPainter get(String s, double size, Color color, FontWeight weight) {
    final key = Object.hash(s, size, color.toARGB32(), weight.value);
    return _m.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: size,
            color: color,
            fontWeight: weight,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void clear() => _m.clear();
}

/// 9×9 보드. 터치(쓸기 포함)를 받아 [SudokuGame]에 전달한다.
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({super.key, required this.game});

  final SudokuGame game;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  final TextCache _cache = TextCache();
  int _serial = 0;
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _serial = widget.game.placeSerial;
    _wasCompleted = widget.game.completed;
    widget.game.addListener(_onGame);
  }

  @override
  void didUpdateWidget(SudokuBoard old) {
    super.didUpdateWidget(old);
    if (old.game != widget.game) {
      old.game.removeListener(_onGame);
      widget.game.addListener(_onGame);
      _serial = widget.game.placeSerial;
      _wasCompleted = widget.game.completed;
    }
  }

  void _onGame() {
    final g = widget.game;
    if (g.placeSerial != _serial) {
      _serial = g.placeSerial;
      _pop.forward(from: 0);
    }
    if (g.completed && !_wasCompleted) {
      _wave.forward(from: 0);
    } else if (!g.completed && _wasCompleted) {
      _wave.value = 0;
    }
    _wasCompleted = g.completed;
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGame);
    _pop.dispose();
    _wave.dispose();
    super.dispose();
  }

  int _cellAt(Offset p, double size) {
    final cs = size / 9;
    final c = (p.dx / cs).floor().clamp(0, 8);
    final r = (p.dy / cs).floor().clamp(0, 8);
    return r * 9 + c;
  }

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => widget.game.strokeDown(_cellAt(e.localPosition, size)),
          onPointerMove: (e) => widget.game.strokeMove(_cellAt(e.localPosition, size)),
          onPointerUp: (_) => widget.game.strokeEnd(),
          onPointerCancel: (_) => widget.game.strokeEnd(),
          child: CustomPaint(
            size: Size.square(size),
            painter: BoardPainter(
              game: widget.game,
              colors: colors,
              pop: _pop,
              wave: _wave,
              cache: _cache,
            ),
          ),
        );
      },
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.game,
    required this.colors,
    required this.pop,
    required this.wave,
    required this.cache,
  }) : super(repaint: Listenable.merge([game, pop, wave]));

  final SudokuGame game;
  final SudokuColors colors;
  final Animation<double> pop;
  final Animation<double> wave;
  final TextCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 9;
    final hd = game.highlightDigit;
    final sel = game.selected;
    final hint = game.hint;
    final fill = Paint();

    // 1) 칸 배경
    for (var i = 0; i < 81; i++) {
      fill.color = _background(i, sel, hd, hint);
      canvas.drawRect(Rect.fromLTWH(colOf[i] * cs, rowOf[i] * cs, cs, cs), fill);
    }

    // 2) 완성 물결
    if (wave.value > 0 && wave.value < 1) {
      final origin = game.lastPlaced >= 0 ? game.lastPlaced : 40;
      for (var i = 0; i < 81; i++) {
        final dr = (rowOf[i] - rowOf[origin]).toDouble();
        final dc = (colOf[i] - colOf[origin]).toDouble();
        final t = wave.value * 17 - sqrt(dr * dr + dc * dc);
        if (t <= 0 || t >= 4) continue;
        fill.color = colors.accent.withValues(alpha: sin(t / 4 * pi) * 0.6);
        canvas.drawRect(Rect.fromLTWH(colOf[i] * cs, rowOf[i] * cs, cs, cs), fill);
      }
    }

    // 3) 격자선
    final thin = Paint()
      ..color = colors.lineThin
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = colors.lineThick
      ..strokeWidth = max(2.0, cs * 0.05)
      ..strokeCap = StrokeCap.square;
    for (var k = 1; k < 9; k++) {
      if (k % 3 == 0) continue;
      canvas.drawLine(Offset(k * cs, 0), Offset(k * cs, size.height), thin);
      canvas.drawLine(Offset(0, k * cs), Offset(size.width, k * cs), thin);
    }
    for (var k = 0; k <= 9; k += 3) {
      canvas.drawLine(Offset(k * cs, 0), Offset(k * cs, size.height), thick);
      canvas.drawLine(Offset(0, k * cs), Offset(size.width, k * cs), thick);
    }

    // 4) 선택 칸 테두리
    if (sel >= 0) {
      final r = Rect.fromLTWH(colOf[sel] * cs, rowOf[sel] * cs, cs, cs).deflate(1.2);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = colors.accent,
      );
    }

    // 5) 숫자와 메모
    for (var i = 0; i < 81; i++) {
      final x = colOf[i] * cs, y = rowOf[i] * cs;
      final v = game.values[i];
      if (v != 0) {
        _drawValue(canvas, i, v, x, y, cs);
      } else if (hint != null && hint.cands.containsKey(i)) {
        _drawHintCands(canvas, i, hint, x, y, cs);
      } else if (game.notes[i] != 0 && i != hint?.placeCell) {
        _drawNotes(canvas, game.notes[i], x, y, cs, hd);
      }
    }

    // 6) 힌트가 알려주는 숫자
    if (hint != null && hint.placeCell >= 0) {
      final i = hint.placeCell;
      _text(
        canvas,
        '${hint.placeDigit}',
        Offset(colOf[i] * cs + cs / 2, rowOf[i] * cs + cs / 2),
        cs * 0.58,
        colors.place,
        FontWeight.w800,
      );
    }
  }

  Color _background(int i, int sel, int hd, ActiveHint? h) {
    if (h != null) {
      if (h.targetCells.contains(i)) return colors.hintTarget;
      if (h.causeCells.contains(i)) return colors.hintCause;
    }
    if (game.isWrong(i)) return colors.wrongBg;
    if (i == sel) return colors.selected;
    if (hd != 0 && game.values[i] == hd) return colors.sameDigit;
    if (h != null && h.regionCells.contains(i)) return colors.hintRegion;
    if (sel >= 0 &&
        (rowOf[i] == rowOf[sel] || colOf[i] == colOf[sel] || boxOf[i] == boxOf[sel])) {
      return colors.peer;
    }
    return colors.cell;
  }

  void _drawValue(Canvas canvas, int i, int v, double x, double y, double cs) {
    final color = game.isWrong(i)
        ? colors.wrong
        : game.isGiven(i)
            ? colors.given
            : colors.user;
    final center = Offset(x + cs / 2, y + cs / 2);
    final popping = i == game.lastPlaced && pop.value < 1;
    if (popping) {
      final s = 0.5 + 0.5 * Curves.easeOutBack.transform(pop.value);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(s);
      canvas.translate(-center.dx, -center.dy);
    }
    _text(canvas, '$v', center, cs * 0.6, color, FontWeight.w700);
    if (popping) canvas.restore();
  }

  Offset _noteCenter(int d, double x, double y, double cs) =>
      Offset(x + ((d - 1) % 3 + 0.5) * cs / 3, y + ((d - 1) ~/ 3 + 0.5) * cs / 3);

  void _drawNotes(Canvas canvas, int mask, double x, double y, double cs, int hd) {
    final fs = cs * 0.26;
    final hi = Paint()..color = colors.noteHighlight;
    for (var d = 1; d <= 9; d++) {
      if (mask & bit(d) == 0) continue;
      final c = _noteCenter(d, x, y, cs);
      if (d == hd) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: cs / 3 * 0.86, height: cs / 3 * 0.86),
            Radius.circular(cs * 0.04),
          ),
          hi,
        );
      }
      _text(canvas, '$d', c, fs, colors.note, FontWeight.w400);
    }
  }

  void _drawHintCands(Canvas canvas, int i, ActiveHint h, double x, double y, double cs) {
    final mask = h.cands[i]!;
    final removeMask = h.removeMask[i] ?? 0;
    final fs = cs * 0.28;
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      if (mask & b == 0) continue;
      final c = _noteCenter(d, x, y, cs);
      if (removeMask & b != 0) {
        _text(canvas, '$d', c, fs, colors.remove, FontWeight.w800);
        canvas.drawLine(
          c + Offset(-fs * 0.45, fs * 0.45),
          c + Offset(fs * 0.45, -fs * 0.45),
          Paint()
            ..color = colors.remove
            ..strokeWidth = max(1.6, cs * 0.035),
        );
      } else if (h.patternDigits & b != 0 && h.causeCells.contains(i)) {
        _text(canvas, '$d', c, fs, colors.accent, FontWeight.w800);
      } else {
        _text(canvas, '$d', c, fs, colors.note, FontWeight.w400);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset center, double size, Color color, FontWeight w) {
    final tp = cache.get(s, size, color, w);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
