
import 'package:flutter/material.dart';

import 'package:tabgame/hub/icon_kit.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_board.dart' show paintPenDigit, penColor;

// ── 예언: 게임이 끝났을 때의 채점 화면 ──
// 줄(행·열)마다 숫자(X 제외)가 몇 개인지 줄 끝에 센다. 그 개수와 같은 숫자는 동그라미를 치고,
// 행에서 맞았으면 좌우 화살표, 열에서 맞았으면 위아래 화살표를 단다 (둘 다 맞으면 네 방향, 점수도 두 번).
// 동그라미·화살표는 쓴 사람의 펜 색, 개수가 맞은 줄은 초록 동그라미로 표시한다. (게임 안 ProphBoardPainter와 같은 모양)
void paintProphecyIcon(Canvas c, double s) {
  const rows = 3, cols = 3;
  const x = -1; // X
  // 칸의 숫자(X는 -1)와 쓴 사람(0 = 분홍, 1 = 청록)
  const cells = [
    [2, 1, x],
    [1, 3, 2],
    [3, 2, x],
  ];
  const owners = [
    [0, 1, -1],
    [1, 1, 0],
    [0, 1, -1],
  ];
  const left = 0.07, top = 0.07, cell = 0.245;
  const gridW = cell * cols, gridH = cell * rows;
  final paper = RRect.fromRectAndRadius(const Rect.fromLTWH(left - 0.03, top - 0.03, gridW + 0.06, gridH + 0.06), const Radius.circular(0.04));
  iconShadow(c, Path()..addRRect(paper));
  c.drawRRect(paper, iconFill(const Color(0xFFFFFDF6)));
  const inkLine = Color(0xFF4A3B3B);
  final grid = iconLine(inkLine, 0.014);
  for (var k = 0; k <= 3; k++) {
    c.drawLine(Offset(left + cell * k, top), Offset(left + cell * k, top + gridH), grid);
    c.drawLine(Offset(left, top + cell * k), Offset(left + gridW, top + cell * k), grid);
  }
  Offset at(int r, int col) => Offset(left + cell * (col + 0.5), top + cell * (r + 0.5));

  // 줄마다 숫자 개수
  final rowCount = [for (var r = 0; r < rows; r++) cells[r].where((v) => v > 0).length];
  final colCount = [for (var k = 0; k < cols; k++) [for (var r = 0; r < rows; r++) cells[r][k]].where((v) => v > 0).length];

  // 글자는 그림 좌표(0~1)에 바로 못 그리니 100배 키운 크기로 그려서 줄여 붙인다.
  void big(Offset p, void Function() draw) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(0.01);
    draw();
    c.restore();
  }

  // 칸 안: 숫자(쓴 사람의 펜)와 X
  for (var r = 0; r < rows; r++) {
    for (var k = 0; k < cols; k++) {
      final v = cells[r][k];
      if (v == x) {
        final m = at(r, k);
        const d = cell * 0.3;
        final cross = Path()
          ..moveTo(m.dx - d, m.dy - d)
          ..lineTo(m.dx + d, m.dy + d)
          ..moveTo(m.dx + d, m.dy - d)
          ..lineTo(m.dx - d, m.dy + d);
        c.drawPath(cross, iconLine(inkLine.withValues(alpha: 0.85), 0.014));
      } else {
        big(at(r, k), () => paintPenDigit(c, '$v', Offset.zero, cell * 100 * 0.58, owners[r][k]));
      }
    }
  }

  // 점수: 동그라미 + 행이면 좌우, 열이면 위아래 화살표
  void arrows(Offset m, Color color, {required bool horizontal}) {
    const r0 = cell * 0.3, r1 = cell * 0.5, head = cell * 0.11;
    final pen = iconLine(color, 0.02);
    for (final dir in const [-1.0, 1.0]) {
      final d = horizontal ? Offset(dir, 0) : Offset(0, dir);
      final n = horizontal ? const Offset(0, 1) : const Offset(1, 0);
      final from = m + d * r0, to = m + d * r1;
      c.drawLine(from, to, pen);
      c.drawLine(to, to - d * head + n * head * 0.8, pen);
      c.drawLine(to, to - d * head - n * head * 0.8, pen);
    }
  }

  final rowOk = <int>{}, colOk = <int>{};
  for (var r = 0; r < rows; r++) {
    for (var k = 0; k < cols; k++) {
      final v = cells[r][k];
      if (v <= 0) continue;
      final byRow = rowCount[r] == v, byCol = colCount[k] == v;
      if (!byRow && !byCol) continue;
      if (byRow) rowOk.add(r);
      if (byCol) colOk.add(k);
      final color = penColor(owners[r][k]);
      c.drawCircle(at(r, k), cell * 0.3, iconLine(color, 0.02));
      if (byRow) arrows(at(r, k), color, horizontal: true);
      if (byCol) arrows(at(r, k), color, horizontal: false);
    }
  }

  // 줄 끝의 개수 (맞은 줄은 초록)
  void count(Offset p, int n, bool ok) {
    c.drawCircle(p, 0.05, iconFill(ok ? const Color(0xFF2E9E4F) : Colors.white.withValues(alpha: 0.28)));
    big(p, () => iconText(c, '$n', Offset.zero, 7.5, Colors.white));
  }

  for (var r = 0; r < rows; r++) {
    count(Offset(left + gridW + 0.085, top + cell * (r + 0.5)), rowCount[r], rowOk.contains(r));
  }
  for (var k = 0; k < cols; k++) {
    count(Offset(left + cell * (k + 0.5), top + gridH + 0.085), colCount[k], colOk.contains(k));
  }
}
