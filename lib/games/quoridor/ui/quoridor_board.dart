import 'dart:math';

import 'package:flutter/material.dart';

import '../core/quoridor_rules.dart';

part 'quoridor_board_parts.dart';

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
    this.animate = false,
    this.moveCount = 0,
    this.lastMover = -1,
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

  /// 새로 세워진 벽을 날아와서 세워지는 모습으로 보여 주는가. 이때 [moveCount](지금까지 둔 수)와 [lastMover](방금 둔 자리)도 준다.
  /// 수가 하나 늘면서 벽이 세워졌을 때만 움직인다 (되돌리기·새 판에서는 움직이지 않는다).
  final bool animate;
  final int moveCount, lastMover;

  @override
  Widget build(BuildContext context) => _BoardBody(view: this);

  /// 판 그림과 그 위의 막대·아이콘을 만든다. [boardKey]는 판 좌표로 바꿀 때 쓰는 열쇠로, 판이 다시 그려져도 같은 것을 써야 끌던 막대가 끊기지 않는다.
  Widget buildBody(BuildContext context, GlobalKey boardKey, {QWallFly? fly, QPawnSlide? slide}) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth, box.maxHeight);
        final g = _Geometry(side);
        final painter = _QBoardPainter(this, hideMove: fly?.move ?? -1, slide: slide);

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

        if (fly != null) overlay.add(_flyingWall(g, side, fly));

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

  /// 날아가는 벽 하나: 쌓여 있던 더미(판 바깥)에서 떠올라 호를 그리며 와서 제자리에 내려앉는다.
  /// 내가 놓아 둔 막대를 확정한 때는 그 자리에서 살짝 떠올랐다가 내려앉는다.
  Widget _flyingWall(_Geometry g, double side, QWallFly f) {
    final o = _orientOf(f.move);
    final target = g.wallRect(o, wallRow(f.move), wallCol(f.move));
    final seat = f.seat.clamp(0, kPawnColors.length - 1);
    final mid = Offset(side / 2, side / 2);
    final reach = side / 2 + 30; // 더미는 판 바로 바깥에 있다
    var from = target.center;
    var startAngle = 0.0;
    if (!f.fromTarget && f.seat >= 0) {
      final four = state.players == 4;
      final (Offset dir, int stockOrient) = f.seat == 0
          ? (const Offset(0, 1), 1)
          : (!four || f.seat == 2)
              ? (const Offset(0, -1), 1)
              : (f.seat == 1 ? (const Offset(-1, 0), 0) : (const Offset(1, 0), 0));
      from = mid + dir * reach;
      startAngle = stockOrient == o ? 0.0 : pi / 2; // 위·아래 더미는 막대가 세로로, 옆 더미는 가로로 쌓여 있다
    }
    final drag = wallDragSize(side, o);
    return AnimatedBuilder(
      animation: f.anim,
      builder: (context, _) {
        final t = f.anim.value;
        final e = Curves.easeInOutCubic.transform(t);
        final lift = sin(pi * e);
        final center = Offset.lerp(from, target.center, e)! - Offset(0, lift * side * (f.fromTarget ? 0.03 : 0.07));
        final k = Curves.easeIn.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));
        final w = drag.width + (target.width - drag.width) * k;
        final h = drag.height + (target.height - drag.height) * k;
        return Positioned(
          left: center.dx - w / 2,
          top: center.dy - h / 2,
          width: w,
          height: h,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: startAngle * (1 - e),
              child: Transform.scale(scale: 1 + 0.45 * lift, child: WoodStick(size: Size(w, h), cap: kPawnColors[seat])),
            ),
          ),
        );
      },
    );
  }
}

int _orientOf(int move) => wallOrient(move); // (QBoardView 안에서는 같은 이름의 필드가 가린다)

/// 옮겨 가는 중인 말의 정보: [seat]의 말이 [from]칸에서 지금 있는 칸으로 미끄러져 간다.
class QPawnSlide {
  const QPawnSlide({required this.seat, required this.from, required this.anim});

  final int seat, from;
  final Animation<double> anim;
}

/// 날아가는 중인 벽의 정보.
class QWallFly {
  const QWallFly({required this.move, required this.seat, required this.fromTarget, required this.anim});

  final int move, seat;

  /// 내가 놓아 둔 막대를 확정한 것이라 더미가 아니라 제자리에서 내려앉는가.
  final bool fromTarget;
  final Animation<double> anim;
}

class _BoardBody extends StatefulWidget {
  const _BoardBody({required this.view});

  final QBoardView view;

  @override
  State<_BoardBody> createState() => _BoardBodyState();
}

class _BoardBodyState extends State<_BoardBody> with TickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  late final AnimationController _fly = AnimationController(vsync: this);
  late final AnimationController _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  int _flyMove = -1, _flySeat = -1;
  bool _flyFromTarget = false;
  int _slideSeat = -1, _slideFrom = -1;

  /// 직전에 그렸을 때의 말 자리 (상태 객체는 그대로 고쳐 쓰이니, 어디서 왔는지 알려고 따로 기억한다).
  late List<int> _pawns = [...widget.view.state.pawn];

  @override
  void initState() {
    super.initState();
    _slide.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _slideSeat = -1);
    });
    _fly.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _flyMove = -1);
    });
  }

  @override
  void didUpdateWidget(_BoardBody old) {
    super.didUpdateWidget(old);
    final n = widget.view, o = old.view;
    final before = _pawns;
    _pawns = [...n.state.pawn];
    // 말이 한 칸(또는 뛰어넘어) 옮겨 갔으면 천천히 미끄러져 간다
    if (n.animate && !isWallMove(n.lastMove) && n.moveCount == o.moveCount + 1 && n.lastMover >= 0 && n.lastMover < before.length && before.length == _pawns.length && before[n.lastMover] != _pawns[n.lastMover]) {
      _slideSeat = n.lastMover;
      _slideFrom = before[n.lastMover];
      _slide.forward(from: 0);
    }
    if (!n.animate || n.lastMove == o.lastMove || !isWallMove(n.lastMove) || n.moveCount != o.moveCount + 1) return;
    _flyMove = n.lastMove;
    _flySeat = n.lastMover;
    // 내가 놓아 둔 막대를 확정한 것이면 그 자리에서 내려앉는다
    _flyFromTarget = o.wallMode && o.pickRow == wallRow(n.lastMove) && o.pickCol == wallCol(n.lastMove) && o.wallOrient == wallOrient(n.lastMove);
    _fly.duration = Duration(milliseconds: _flyFromTarget ? 380 : 800);
    _fly.forward(from: 0);
  }

  @override
  void dispose() {
    _slide.dispose();
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.view.buildBody(
        context,
        _key,
        fly: _flyMove >= 0 ? QWallFly(move: _flyMove, seat: _flySeat, fromTarget: _flyFromTarget, anim: _fly) : null,
        slide: _slideSeat >= 0 ? QPawnSlide(seat: _slideSeat, from: _slideFrom, anim: _slide) : null,
      );
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
