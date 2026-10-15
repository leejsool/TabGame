import 'package:flutter/material.dart';

import '../core/prophecy_rules.dart';
import 'prophecy_board.dart';

/// 표 크기 고르개 (한글·워드의 "표 만들기" 칸 고르기처럼): 칸 격자 위를 누르거나 끌면
/// 왼쪽 위에서 그 칸까지가 파랗게 물들고, 위에 "행 × 열"이 보인다.
///
/// [kMinSide]~[kMaxSide]개의 행과 열을 고른다. 4×4보다 작은 칸을 눌러도 4×4로 맞춘다.
class TablePicker extends StatelessWidget {
  const TablePicker({super.key, required this.rows, required this.cols, required this.onChanged});

  final int rows, cols;
  final void Function(int rows, int cols) onChanged;

  static const double _label = 22; // 위·왼쪽의 번호 칸

  void _pick(Offset p, double cell) {
    final c = ((p.dx - _label) / cell).floor() + 1;
    final r = ((p.dy - _label) / cell).floor() + 1;
    final nr = r.clamp(kMinSide, kMaxSide), nc = c.clamp(kMinSide, kMaxSide);
    if (nr != rows || nc != cols) onChanged(nr, nc);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = ((box.maxWidth.clamp(0, 420) - _label) / kMaxSide).floorToDouble().clamp(24.0, 44.0);
        final side = _label + cell * kMaxSide;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kProphColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$rows행 × $cols열  ·  칸 ${rows * cols}개',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kProphColor),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: side + 16,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _pick(e.localPosition, cell),
                onPointerMove: (e) => _pick(e.localPosition, cell),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: CustomPaint(painter: _PickerPainter(rows: rows, cols: cols, cell: cell, scheme: scheme)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '칸을 누르거나 끌어서 표의 크기를 골라요 (4×4 ~ 8×8)',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
          ],
        );
      },
    );
  }
}

class _PickerPainter extends CustomPainter {
  _PickerPainter({required this.rows, required this.cols, required this.cell, required this.scheme});

  final int rows, cols;
  final double cell;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const label = TablePicker._label;
    final blue = kProphColor;
    for (var r = 0; r < kMaxSide; r++) {
      for (var c = 0; c < kMaxSide; c++) {
        final rect = Rect.fromLTWH(label + c * cell, label + r * cell, cell, cell).deflate(1.5);
        final on = r < rows && c < cols;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = on ? blue.withValues(alpha: 0.85) : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        );
        // 가장 작은 표(4×4) 자리는 테두리로 알려 준다
        if (r < kMinSide && c < kMinSide) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = on ? Colors.white.withValues(alpha: 0.55) : blue.withValues(alpha: 0.45),
          );
        }
      }
    }
    // 번호 (열은 위, 행은 왼쪽)
    for (var i = 0; i < kMaxSide; i++) {
      _num(canvas, '${i + 1}', Offset(label + (i + 0.5) * cell, label / 2), i < cols);
      _num(canvas, '${i + 1}', Offset(label / 2, label + (i + 0.5) * cell), i < rows);
    }
  }

  void _num(Canvas canvas, String s, Offset at, bool on) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: 12,
          fontWeight: on ? FontWeight.w900 : FontWeight.w600,
          color: on ? kProphColor : scheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PickerPainter old) => old.rows != rows || old.cols != cols || old.cell != cell;
}
