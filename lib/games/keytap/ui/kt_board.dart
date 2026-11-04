import 'dart:math';

import 'package:flutter/material.dart';

import '../core/kt_run.dart';

/// 건반 톡톡의 대표 색.
const Color kKeytapColor = Color(0xFF5A54D6);

/// 4줄 판: 블록을 그리고, 누른 곳을 (칸, 세로 좌표)로 알려 준다. 여러 손가락으로 동시에 눌러도 된다.
///
/// 다시 그리는 것은 부모가 정한다 (매 화면마다 [clock]을 바꿔 새로 만든다).
class KtBoard extends StatelessWidget {
  const KtBoard({super.key, required this.run, required this.hitAt, required this.clock, required this.onTap, this.rows = 4, this.startLabel = '시작'});

  final KtRun run;

  /// 줄 번호 → 친 때 ([clock] 기준). 친 블록이 옅어지는 연출에 쓴다.
  final Map<int, double> hitAt;

  /// 연출용 시계 (초).
  final double clock;
  final void Function(int lane, double y) onTap;

  /// 화면에 보이는 줄 수.
  final int rows;

  /// 시작 블록에 쓰는 글자 (곡 완주·무한). 경주는 null.
  final String? startLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          final lane = (e.localPosition.dx / size.width * 4).floor().clamp(0, 3);
          final rowH = size.height / rows;
          onTap(lane, run.pos + (size.height - e.localPosition.dy) / rowH);
        },
        child: CustomPaint(size: size, painter: KtBoardPainter(run: run, hitAt: hitAt, clock: clock, rows: rows, startLabel: startLabel)),
      );
    });
  }
}

class KtBoardPainter extends CustomPainter {
  KtBoardPainter({required this.run, required this.hitAt, required this.clock, required this.rows, this.startLabel});

  final KtRun run;
  final Map<int, double> hitAt;
  final double clock;
  final int rows;
  final String? startLabel;

  static const _paper = Color(0xFFFBF7EE);
  static const _paperDeep = Color(0xFFF1EADB);
  static const _line = Color(0xFFDCD3C1);
  static const _ink = Color(0xFF23243A);
  static const _inkTop = Color(0xFF3A3C5C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 4, rowH = size.height / rows;
    canvas.clipRect(Offset.zero & size);
    // 바탕: 아래로 갈수록 살짝 진해지는 종이색 + 칸 사이 선
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_paper, _paperDeep]).createShader(Offset.zero & size),
    );
    final line = Paint()
      ..color = _line
      ..strokeWidth = 1.2;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), line);
    }

    final p = run.viewPos;
    double yOf(double row) => size.height - (row - p) * rowH; // 줄 좌표 → 화면 y (줄의 아래쪽)
    final first = max(0, p.floor() - 1);
    final last = (p + rows + 1).ceil();
    for (var i = first; i <= last && i < run.totalRows; i++) {
      final bottom = yOf(i.toDouble());
      final rect = Rect.fromLTRB(run.lane(i) * w + 3, bottom - rowH + 3, run.lane(i) * w + w - 3, bottom - 3);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(min(w, rowH) * 0.12));
      if (i < run.next) {
        if (run.missedRows.contains(i)) {
          canvas.drawRRect(rr, Paint()..color = const Color(0xFFF2B8B5).withValues(alpha: 0.7));
          continue;
        }
        // 친 블록: 잠깐 빛나다 옅은 남색으로 남는다
        final age = clock - (hitAt[i] ?? -10);
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFD9DAEC));
        if (age < 0.25) {
          final k = 1 - age / 0.25;
          canvas.drawRRect(rr.inflate(6 * k), Paint()..color = kKeytapColor.withValues(alpha: 0.35 * k));
        }
        continue;
      }
      canvas.drawRRect(
        rr,
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_inkTop, _ink]).createShader(rect),
      );
      // 위쪽 반짝임
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 6, rect.top + 5, rect.width - 12, max(2, rowH * 0.05)), const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
      if (i == 0 && !run.started && startLabel != null) _label(canvas, rect, startLabel!);
    }

    // 잘못 누른 칸 · 놓친 블록 (곡 완주·무한: 끝난 칸이 깜빡인다)
    final fr = run.failRow, fl = run.failLane;
    if (run.over && fr != null && fl != null) {
      final on = (clock * 4).floor().isEven;
      final b = yOf(fr.toDouble());
      canvas.drawRect(Rect.fromLTRB(fl * w, b - rowH, fl * w + w, b), Paint()..color = (on ? const Color(0xFFE5484D) : const Color(0xFFF6B3B5)));
    }
    final wr = run.wrongRow, wl = run.wrongLane;
    if (wr != null && wl != null && run.t - run.wrongAt < 0.45) {
      final k = 1 - (run.t - run.wrongAt) / 0.45;
      final b = yOf(wr.toDouble());
      canvas.drawRect(Rect.fromLTRB(wl * w, b - rowH, wl * w + w, b), Paint()..color = const Color(0xFFE5484D).withValues(alpha: 0.75 * k));
    }
  }

  void _label(Canvas canvas, Rect rect, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: 'NanumGothic', color: Colors.white, fontSize: min(rect.width * 0.24, 30), fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(KtBoardPainter old) => true;
}
