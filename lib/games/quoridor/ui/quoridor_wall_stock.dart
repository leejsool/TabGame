import 'dart:math';

import 'package:flutter/material.dart';

import 'quoridor_board.dart';

/// 플레이어 앞에 쌓여 있는 나무막대(벽) 더미.
///
/// 막대 하나를 판으로 끌어다 놓으면 가장 가까운 격자점에 붙고, 그 막대에 뜨는 돌리기·확정 아이콘으로 세운다.
/// 더미의 막대 수 = 남은 벽 수. 지금 차례인 사람의 더미만 끌 수 있다 ([active]).
class QWallStock extends StatelessWidget {
  const QWallStock({
    super.key,
    required this.seat,
    required this.count,
    required this.boardSide,
    required this.vertical,
    required this.active,
    required this.orient,
  });

  /// 이 더미의 주인 자리 (색 띠).
  final int seat;

  /// 남은 막대 수.
  final int count;

  /// 판 한 변의 길이 (막대 크기를 판에 맞추려고).
  final double boardSide;

  /// true면 판 왼쪽·오른쪽에 놓여서 막대가 가로로 쌓이고, false면 위·아래에 놓여서 막대가 세로로 늘어선다.
  final bool vertical;

  /// 지금 끌어서 쓸 수 있는가.
  final bool active;

  /// 끌어 낼 때 막대의 방향 (0 가로 / 1 세로).
  final int orient;

  @override
  Widget build(BuildContext context) {
    final color = kPawnColors[seat];
    final stock = _stock(color, count);
    if (!active || count <= 0) return Opacity(opacity: count <= 0 ? 0.55 : 0.85, child: stock);
    final size = wallDragSize(boardSide, orient);
    return Draggable<QWallDrag>(
      data: const QWallDrag(),
      dragAnchorStrategy: (d, ctx, pos) => Offset(size.width / 2, size.height / 2),
      feedback: WoodStick(size: size, cap: color),
      childWhenDragging: _stock(color, count - 1, dragging: true),
      child: stock,
    );
  }

  Widget _stock(Color color, int n, {bool dragging = false}) {
    final wall = wallSizeFor(boardSide);
    final length = wall.length * 0.78;
    final thick = max(6.0, wall.thickness * 1.5);
    final stick = vertical ? Size(length, thick) : Size(thick, length);
    final sticks = [for (var i = 0; i < n; i++) WoodStick(size: stick, cap: color)];
    final empty = SizedBox(width: vertical ? length : thick * 2, height: vertical ? thick * 2 : length);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: active ? 0.9 : 0.35), width: active ? 2.2 : 1.2),
      ),
      child: n <= 0
          ? empty
          : vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: [for (final s in sticks) Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: s)])
              : Row(mainAxisSize: MainAxisSize.min, children: [for (final s in sticks) Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: s)]),
    );
  }
}
