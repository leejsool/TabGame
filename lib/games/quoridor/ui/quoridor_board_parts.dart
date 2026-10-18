part of 'quoridor_board.dart';

// 나무 막대·기하·판 그림 (파일을 역할별로 나눈 것)

/// 눈에 띄는 동그란 아이콘 단추 (놓아 둔 막대 옆에 뜨는 회전·확정·취소).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.color, required this.onTap});

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? color : Colors.grey.shade400,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
        elevation: on ? 3 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

/// 나무막대 한 개의 모습 (끌어서 옮길 때와 더미에서 쓴다). [cap]은 주인 색의 끝 띠.
class WoodStick extends StatelessWidget {
  const WoodStick({super.key, required this.size, required this.cap});

  final Size size;
  final Color cap;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(size: size, child: CustomPaint(painter: _WoodPainter(cap)));
}

class _WoodPainter extends CustomPainter {
  const _WoodPainter(this.cap);

  final Color cap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(min(size.width, size.height) * 0.4));
    canvas.drawRRect(r.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawRRect(r, Paint()..color = _wallColor);
    // 나뭇결: 긴 쪽을 따라 밝은 줄 하나
    final horizontal = size.width >= size.height;
    final grain = Paint()
      ..color = _wallLight.withValues(alpha: 0.75)
      ..strokeWidth = max(1.0, min(size.width, size.height) * 0.22)
      ..strokeCap = StrokeCap.round;
    if (horizontal) {
      canvas.drawLine(Offset(size.width * 0.12, size.height * 0.34), Offset(size.width * 0.88, size.height * 0.34), grain);
    } else {
      canvas.drawLine(Offset(size.width * 0.34, size.height * 0.12), Offset(size.width * 0.34, size.height * 0.88), grain);
    }
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _wallDark);
    // 주인 색 띠 (한쪽 끝)
    final t = min(size.width, size.height);
    final capRect = horizontal ? Rect.fromLTWH(0, 0, t * 0.9, size.height) : Rect.fromLTWH(0, 0, size.width, t * 0.9);
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(capRect, Paint()..color = cap);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WoodPainter old) => old.cap != cap;
}

/// 판 크기에서 칸·홈의 위치를 계산한다.
class _Geometry {
  _Geometry(this.side) {
    margin = side * 0.035;
    final inner = side - margin * 2;
    cell = inner / (kBoard + (kBoard - 1) * 0.24);
    gap = cell * 0.24;
    pitch = cell + gap;
  }

  final double side;
  late final double margin, cell, gap, pitch;

  Rect cellRect(int r, int c) => Rect.fromLTWH(margin + c * pitch, margin + r * pitch, cell, cell);

  Offset cellCenter(int cellNo) => cellRect(cellNo ~/ kBoard, cellNo % kBoard).center;

  /// 격자점 (r, c)의 한가운데 (r행 아래, c열 오른쪽 모서리가 만나는 곳).
  Offset anchorCenter(int r, int c) => Offset(margin + (c + 1) * cell + c * gap + gap / 2, margin + (r + 1) * cell + r * gap + gap / 2);

  Rect wallRect(int orient, int r, int c) {
    if (orient == 0) {
      return Rect.fromLTWH(margin + c * pitch, margin + (r + 1) * cell + r * gap, cell * 2 + gap, gap);
    }
    return Rect.fromLTWH(margin + (c + 1) * cell + c * gap, margin + r * pitch, gap, cell * 2 + gap);
  }

  /// 누른 자리가 속한 칸 번호 (홈 위를 눌러도 가장 가까운 칸). 판 밖이면 -1.
  int cellAt(Offset p) {
    final x = (p.dx - margin + gap / 2) / pitch, y = (p.dy - margin + gap / 2) / pitch;
    final c = x.floor(), r = y.floor();
    if (r < 0 || r >= kBoard || c < 0 || c >= kBoard) return -1;
    return r * kBoard + c;
  }

  (int, int) nearestAnchor(Offset p) {
    var best = (0, 0);
    var bestD = double.infinity;
    for (var r = 0; r < kAnchors; r++) {
      for (var c = 0; c < kAnchors; c++) {
        final d = (anchorCenter(r, c) - p).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = (r, c);
        }
      }
    }
    return best;
  }
}

class _QBoardPainter extends CustomPainter {
  _QBoardPainter(this.v, {this.hideMove = -1, this.slide}) : super(repaint: slide?.anim);

  /// 옮겨 가는 중인 말 (없으면 null).
  final QPawnSlide? slide;

  final QBoardView v;

  /// 날아오는 중이라 아직 그리지 않을 벽의 수 (없으면 -1).
  final int hideMove;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometry(size.width);
    final s = v.state;

    // 판
    final board = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.04));
    canvas.drawRRect(board, Paint()..color = _boardColor);

    // 도착 줄 (말 색으로 가장자리에 띠)
    if (v.showGoals) {
      for (var p = 0; p < s.players; p++) {
        final color = kPawnColors[p].withValues(alpha: 0.75);
        final side = s.players == 2 ? (p == 0 ? 0 : 2) : p;
        final t = g.margin * 0.5;
        final inner = Rect.fromLTWH(g.margin, g.margin, size.width - g.margin * 2, size.height - g.margin * 2);
        final strip = switch (side) {
          0 => Rect.fromLTWH(inner.left, 0, inner.width, t),
          1 => Rect.fromLTWH(size.width - t, inner.top, t, inner.height),
          2 => Rect.fromLTWH(inner.left, size.height - t, inner.width, t),
          _ => Rect.fromLTWH(0, inner.top, t, inner.height),
        };
        canvas.drawRRect(RRect.fromRectAndRadius(strip, Radius.circular(t / 2)), Paint()..color = color);
      }
    }

    // 칸
    final cellPaint = Paint()..color = _cellColor;
    for (var r = 0; r < kBoard; r++) {
      for (var c = 0; c < kBoard; c++) {
        canvas.drawRRect(RRect.fromRectAndRadius(g.cellRect(r, c), Radius.circular(g.cell * 0.14)), cellPaint);
      }
    }
    v.highlightCells.forEach((cellNo, color) {
      final rect = g.cellRect(cellNo ~/ kBoard, cellNo % kBoard);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(g.cell * 0.14)), Paint()..color = color.withValues(alpha: 0.4));
    });

    // 방금 둔 수
    final lm = v.lastMove;
    if (lm >= 0 && !isWallMove(lm) && lm < kCells) {
      final rect = g.cellRect(lm ~/ kBoard, lm % kBoard);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular(g.cell * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFF2A900),
      );
    }

    // 세워진 벽
    final wallPaint = Paint()..color = _wallColor;
    // 나무막대 모양: 바탕 + 긴 쪽을 따라 밝은 나뭇결 한 줄
    void wood(RRect rr, Rect rect, {double alpha = 1, int owner = -1}) {
      canvas.drawRRect(rr, wallPaint..color = _wallColor.withValues(alpha: alpha));
      final grain = Paint()
        ..color = _wallLight.withValues(alpha: 0.7 * alpha)
        ..strokeWidth = max(1.0, g.gap * 0.25)
        ..strokeCap = StrokeCap.round;
      if (rect.width >= rect.height) {
        canvas.drawLine(Offset(rect.left + g.gap * 0.5, rect.top + rect.height * 0.35), Offset(rect.right - g.gap * 0.5, rect.top + rect.height * 0.35), grain);
      } else {
        canvas.drawLine(Offset(rect.left + rect.width * 0.35, rect.top + g.gap * 0.5), Offset(rect.left + rect.width * 0.35, rect.bottom - g.gap * 0.5), grain);
      }
      // 주인 색 띠 (한쪽 끝): 끌어서 놓기 전의 막대와 똑같은 모양이라 누구 벽인지 알 수 있다
      if (owner >= 0 && owner < kPawnColors.length) {
        final t = g.gap * 2.4;
        final cap = rect.width >= rect.height ? Rect.fromLTWH(rect.left, rect.top, t, rect.height) : Rect.fromLTWH(rect.left, rect.top, rect.width, t);
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(cap, Paint()..color = kPawnColors[owner].withValues(alpha: alpha));
        canvas.restore();
      }
    }

    void drawWall(int o, int r, int c, {bool last = false}) {
      final rect = g.wallRect(o, r, c);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(g.gap / 2));
      wood(rr, rect, owner: (o == 0 ? s.hOwner : s.vOwner)[r * kAnchors + c]);
      if (last) {
        canvas.drawRRect(
          rr.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFF2A900),
        );
      }
    }

    for (var r = 0; r < kAnchors; r++) {
      for (var c = 0; c < kAnchors; c++) {
        final isLast = lm >= kWallBase && wallRow(lm) == r && wallCol(lm) == c;
        bool hidden(int o) => hideMove >= kWallBase && wallOrient(hideMove) == o && wallRow(hideMove) == r && wallCol(hideMove) == c;
        if (s.hWallAt(r, c) && !hidden(0)) drawWall(0, r, c, last: isLast && wallOrient(lm) == 0);
        if (s.vWallAt(r, c) && !hidden(1)) drawWall(1, r, c, last: isLast && wallOrient(lm) == 1);
      }
    }

    // 벽 고르는 중: 격자점 + 미리보기
    if (v.wallMode) {
      final dot = Paint()..color = _wallColor.withValues(alpha: 0.35);
      for (var r = 0; r < kAnchors; r++) {
        for (var c = 0; c < kAnchors; c++) {
          canvas.drawCircle(g.anchorCenter(r, c), g.gap * 0.55, dot);
        }
      }
      if (v.pickRow >= 0) {
        // 놓아 둔 막대: 나무 모양 그대로, 세울 수 있으면 초록 / 없으면 빨강 테두리
        final color = v.pickOk ? const Color(0xFF2E9E4F) : const Color(0xFFD64545);
        final rect = g.wallRect(v.wallOrient, v.pickRow, v.pickCol);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(g.gap / 2));
        wood(rr, rect, alpha: 0.92, owner: s.turn);
        canvas.drawRRect(
          rr.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color,
        );
      }
    }

    // 갈 수 있는 칸
    for (final t in v.targets) {
      final center = g.cellCenter(t);
      canvas.drawCircle(center, g.cell * 0.2, Paint()..color = kPawnColors[s.turn].withValues(alpha: 0.75));
      canvas.drawCircle(
        center,
        g.cell * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kPawnColors[s.turn].withValues(alpha: 0.5),
      );
    }

    // 말
    for (var p = 0; p < s.players; p++) {
      var center = g.cellCenter(s.pawn[p]);
      var r = g.cell * 0.37;
      final sl = slide;
      if (sl != null && sl.seat == p) {
        final e = Curves.easeInOutCubic.transform(sl.anim.value);
        center = Offset.lerp(g.cellCenter(sl.from), center, e)!;
        r *= 1 + 0.18 * sin(pi * e); // 살짝 떠올랐다 내려앉는다
      }
      canvas.drawCircle(center + Offset(0, r * 0.18), r, Paint()..color = Colors.black.withValues(alpha: 0.28));
      canvas.drawCircle(center, r, Paint()..color = kPawnColors[p]);
      canvas.drawCircle(center - Offset(r * 0.28, r * 0.3), r * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.35));
      final isTurn = !s.isOver && s.turn == p;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isTurn ? 3.2 : 1.6
          ..color = isTurn ? Colors.white : Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_QBoardPainter old) => true;
}
