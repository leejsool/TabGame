import 'dart:math';

import 'package:flutter/material.dart';

import '../core/quoridor_rules.dart';

/// 게임 색 (허브 카드 색).
const Color kQuoridorColor = Color(0xFFC2417F);

/// 자리별 말 색: 빨강, 파랑, 금색, 초록.
const List<Color> kPawnColors = [Color(0xFFD1495B), Color(0xFF3F7CAC), Color(0xFFE0A100), Color(0xFF2E9E4F)];

const Color _boardColor = Color(0xFFB98C52);
const Color _cellColor = Color(0xFFEBD3A3);
const Color _wallColor = Color(0xFF6F4524);
const Color _wallDark = Color(0xFF4A2D14);
const Color _wallLight = Color(0xFF9A6A3A);

/// 쿼리도 판 그림. 눌러서 칸을 고르거나, (벽 고르기 중이면) 벽을 세울 격자점을 고른다.
///
/// 판은 정사각형으로 가능한 한 크게 그려진다. 설명 그림에서는 [onCell]/[onAnchor]를 주지 않으면 누를 수 없는 그림이 된다.
class QBoardView extends StatelessWidget {
  const QBoardView({
    super.key,
    required this.state,
    this.targets = const [],
    this.lastMove = -1,
    this.wallMode = false,
    this.wallOrient = 0,
    this.pickRow = -1,
    this.pickCol = -1,
    this.pickOk = true,
    this.onCell,
    this.onAnchor,
    this.onWallDrop,
    this.onWallCancel,
    this.onRotate,
    this.onConfirm,
    this.onCancel,
    this.confirmEnabled = false,
    this.highlightCells = const {},
    this.showGoals = true,
  });

  final QState state;

  /// 갈 수 있는 칸들 (점으로 표시).
  final List<int> targets;

  /// 방금 둔 수 (그 말이 옮겨 온 칸이나 방금 세운 벽을 살짝 표시).
  final int lastMove;

  /// 벽 고르는 중: 격자점이 보이고, 고른 자리([pickRow], [pickCol])에 [wallOrient] 방향의 벽 미리보기가 뜬다.
  final bool wallMode;
  final int wallOrient;
  final int pickRow, pickCol;

  /// 미리보기 벽을 세울 수 있는가 (못 세우면 빨갛게).
  final bool pickOk;

  final ValueChanged<int>? onCell;
  final void Function(int r, int c)? onAnchor;

  /// 나무막대를 끌어다 판에 놓았을 때 (가장 가까운 격자점 r, c). 이 값이 있어야 판이 막대를 받는다.
  final void Function(int r, int c)? onWallDrop;

  /// 놓아 둔(아직 확정 전인) 막대를 판 밖으로 끌어내려 놓았을 때 (취소).
  final VoidCallback? onWallCancel;

  /// 놓아 둔 막대에 뜨는 회전 / 확정(체크) / 취소 아이콘을 눌렀을 때. [confirmEnabled]가 아니면 체크는 눌리지 않는다.
  final VoidCallback? onRotate, onConfirm, onCancel;
  final bool confirmEnabled;

  /// (설명 그림용) 눈에 띄게 강조할 칸들: 칸 번호 → 색.
  final Map<int, Color> highlightCells;

  /// 말마다 도착 줄을 그 말 색으로 가장자리에 표시하는가.
  final bool showGoals;

  @override
  Widget build(BuildContext context) => _BoardBody(view: this);

  /// 판 그림과 그 위의 막대·아이콘을 만든다. [boardKey]는 판 좌표로 바꿀 때 쓰는 열쇠로, 판이 다시 그려져도 같은 것을 써야 끌던 막대가 끊기지 않는다.
  Widget buildBody(BuildContext context, GlobalKey boardKey) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth, box.maxHeight);
        final g = _Geometry(side);
        final painter = _QBoardPainter(this);

        // 놓아 둔(확정 전) 막대: 끌어서 옮기고, 위에 회전·확정 아이콘이 뜬다
        final overlay = <Widget>[];
        if (wallMode && pickRow >= 0 && onWallDrop != null) {
          final rect = g.wallRect(wallOrient, pickRow, pickCol);
          final feedbackSize = wallDragSize(side, wallOrient);
          overlay.add(Positioned.fromRect(
            rect: rect.inflate(g.gap * 1.1),
            child: Draggable<QWallDrag>(
              data: const QWallDrag(pending: true),
              dragAnchorStrategy: (d, ctx, pos) => Offset(feedbackSize.width / 2, feedbackSize.height / 2),
              feedback: WoodStick(size: feedbackSize, cap: kPawnColors[state.turn]),
              childWhenDragging: const SizedBox.shrink(),
              onDraggableCanceled: (_, _) => onWallCancel?.call(),
              child: const ColoredBox(color: Color(0x00000000), child: SizedBox.expand()), // (칠하지 않은 빈 상자는 손가락에 반응하지 않아서 투명한 색을 깐다)
            ),
          ));
          const btn = 34.0, gapB = 6.0;
          final count = onCancel == null ? 2 : 3;
          final rowW = count * btn + (count - 1) * gapB;
          final center = rect.center;
          var top = rect.top - btn - 10;
          if (top < 0) top = rect.bottom + 10;
          final left = (center.dx - rowW / 2).clamp(0.0, max(0.0, side - rowW)).toDouble();
          overlay.add(Positioned(
            left: left,
            top: top,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundIcon(icon: Icons.rotate_90_degrees_cw_rounded, tooltip: '돌리기', color: const Color(0xFF455A64), onTap: onRotate),
                const SizedBox(width: gapB),
                _RoundIcon(icon: Icons.check_rounded, tooltip: '여기에 세우기', color: const Color(0xFF2E9E4F), onTap: confirmEnabled ? onConfirm : null),
                if (onCancel != null) ...[
                  const SizedBox(width: gapB),
                  _RoundIcon(icon: Icons.close_rounded, tooltip: '취소', color: const Color(0xFFD64545), onTap: onCancel),
                ],
              ],
            ),
          ));
        }

        Widget boardLayer = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (onCell == null && onAnchor == null)
              ? null
              : (d) {
                  if (wallMode) {
                    final a = g.nearestAnchor(d.localPosition);
                    onAnchor?.call(a.$1, a.$2);
                  } else {
                    final cell = g.cellAt(d.localPosition);
                    if (cell >= 0) onCell?.call(cell);
                  }
                },
          child: CustomPaint(painter: painter, size: Size(side, side)),
        );

        Widget content = SizedBox(
          key: boardKey,
          width: side,
          height: side,
          child: Stack(clipBehavior: Clip.none, children: [Positioned.fill(child: boardLayer), ...overlay]),
        );

        if (onWallDrop != null) {
          final inner = content; // (builder 안에서 content를 쓰면 자기 자신을 다시 부르게 된다)
          content = DragTarget<QWallDrag>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              final rb = boardKey.currentContext?.findRenderObject() as RenderBox?;
              if (rb == null) return;
              // 끌어 온 막대의 한가운데가 있는 곳에서 가장 가까운 격자점에 붙는다 (막대 가운데 = 격자점)
              final size = wallDragSize(side, wallOrient);
              final center = rb.globalToLocal(d.offset + Offset(size.width / 2, size.height / 2));
              final a = g.nearestAnchor(center);
              onWallDrop!(a.$1, a.$2);
            },
            builder: (context, candidate, _) => inner,
          );
        }
        return Center(child: content);
      },
    );
  }
}

class _BoardBody extends StatefulWidget {
  const _BoardBody({required this.view});

  final QBoardView view;

  @override
  State<_BoardBody> createState() => _BoardBodyState();
}

class _BoardBodyState extends State<_BoardBody> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) => widget.view.buildBody(context, _key);
}

/// 끌어서 판에 놓는 나무막대 하나가 가진 정보.
class QWallDrag {
  const QWallDrag({this.pending = false});

  /// 이미 판에 놓아 둔(확정 전) 막대를 다시 끄는 것인가 (아니면 내 앞의 더미에서 새로 꺼낸 막대).
  final bool pending;
}

/// 판 한 변이 [side]일 때 벽(나무막대) 하나의 실제 크기: 길이는 칸 두 개 + 홈, 두께는 홈.
({double length, double thickness}) wallSizeFor(double side) {
  final g = _Geometry(side);
  return (length: g.cell * 2 + g.gap, thickness: g.gap);
}

/// 끌고 있는 막대의 크기 ([orient] 0 가로 / 1 세로). 손가락에 가리지 않게 실제 벽보다 조금 두껍게 그린다.
Size wallDragSize(double side, int orient) {
  final w = wallSizeFor(side);
  final t = max(w.thickness, 10.0);
  return orient == 0 ? Size(w.length, t) : Size(t, w.length);
}

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
  _QBoardPainter(this.v) : super();

  final QBoardView v;

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
    void wood(RRect rr, Rect rect, {double alpha = 1}) {
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
    }

    void drawWall(int o, int r, int c, {bool last = false}) {
      final rect = g.wallRect(o, r, c);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(g.gap / 2));
      wood(rr, rect);
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
        if (s.hWallAt(r, c)) drawWall(0, r, c, last: isLast && wallOrient(lm) == 0);
        if (s.vWallAt(r, c)) drawWall(1, r, c, last: isLast && wallOrient(lm) == 1);
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
        wood(rr, rect, alpha: 0.92);
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
      final center = g.cellCenter(s.pawn[p]);
      final r = g.cell * 0.37;
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
