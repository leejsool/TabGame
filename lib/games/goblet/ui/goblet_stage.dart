import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../core/goblet_rules.dart';
import '../game/goblet_controller.dart';
import 'goblet_piece.dart';

/// 무대의 위치 계산 (칸 크기, 판 위치, 대기 말 자리).
class StageMetrics {
  StageMetrics._({
    required this.size,
    required this.cell,
    required this.landscape,
    required this.board,
    required this.trayBottomTeam,
    required this.trayOtherTeam,
  });

  /// [box] 안에 판과 양쪽 대기 말 칸을 가장 크게 넣는다. 가로가 넓으면 좌우 배치, 아니면 위아래 배치.
  factory StageMetrics.compute(Size box) {
    final landscape = box.width / box.height > 1.25;
    if (landscape) {
      const totalW = 3.2 + 2 * 1.35 + 2 * 0.22;
      final cell = min(box.height / 3.3, box.width / totalW);
      final x0 = (box.width - totalW * cell) / 2;
      final y0 = (box.height - 3.2 * cell) / 2;
      final tray = 1.35 * cell, gap = 0.22 * cell;
      return StageMetrics._(
        size: box,
        cell: cell,
        landscape: true,
        trayBottomTeam: Rect.fromLTWH(x0, y0, tray, 3.2 * cell),
        board: Rect.fromLTWH(x0 + tray + gap, y0, 3.2 * cell, 3.2 * cell),
        trayOtherTeam: Rect.fromLTWH(x0 + tray + 2 * gap + 3.2 * cell, y0, tray, 3.2 * cell),
      );
    }
    const totalH = 2 * 1.35 + 2 * 0.18 + 3.2;
    final cell = min(box.width / 3.3, box.height / totalH);
    final x0 = (box.width - 3.2 * cell) / 2;
    final y0 = (box.height - totalH * cell) / 2;
    final tray = 1.35 * cell, gap = 0.18 * cell;
    return StageMetrics._(
      size: box,
      cell: cell,
      landscape: false,
      trayOtherTeam: Rect.fromLTWH(x0, y0, 3.2 * cell, tray),
      board: Rect.fromLTWH(x0, y0 + tray + gap, 3.2 * cell, 3.2 * cell),
      trayBottomTeam: Rect.fromLTWH(x0, y0 + tray + 2 * gap + 3.2 * cell, 3.2 * cell, tray),
    );
  }

  final Size size;
  final double cell;
  final bool landscape;
  final Rect board;

  /// 아래(또는 왼쪽)에 놓이는 팀의 대기 말 칸 / 반대편 팀의 칸.
  final Rect trayBottomTeam;
  final Rect trayOtherTeam;

  Rect trayRect(Team team, Team bottomTeam) =>
      team == bottomTeam ? trayBottomTeam : trayOtherTeam;

  Rect tileRect(int c) {
    final inner = board.deflate(0.1 * cell);
    return Rect.fromLTWH(
      inner.left + (c % 3) * cell,
      inner.top + (c ~/ 3) * cell,
      cell,
      cell,
    ).deflate(0.025 * cell);
  }

  Offset cellCenter(int c) => tileRect(c).center;

  double pieceWidth(int size) => cell * kPieceScale[size - 1];

  /// 판 위에서 말이 놓이는 중심 (살짝 아래로 내려 바닥에 선 느낌).
  Offset boardPieceCenter(int c) => cellCenter(c) + Offset(0, 0.05 * cell);

  /// 대기 칸 안의 말 중심. [rank] 0은 맨 앞, 1은 그 뒤에 겹쳐진 말.
  Offset slotCenter(Team team, Team bottomTeam, int size, int rank) {
    final tray = trayRect(team, bottomTeam);
    final w = pieceWidth(size);
    Offset c;
    if (landscape) {
      final top = tray.top + 0.5 * cell;
      final slotH = (tray.height - 0.6 * cell) / 3;
      c = Offset(tray.center.dx, top + (size - 0.5) * slotH);
    } else {
      final slotW = tray.width / 3;
      c = Offset(tray.left + (size - 0.5) * slotW, tray.bottom - 0.1 * cell - w / 2);
    }
    if (rank > 0) c += Offset(-0.1 * cell, -0.13 * cell);
    return c;
  }

  /// [p]가 가리키는 칸 번호 (판 밖이면 null). 칸 사이 빈틈은 가장 가까운 칸으로 본다.
  int? cellAt(Offset p) {
    final inner = board.deflate(0.1 * cell);
    if (!board.inflate(0.1 * cell).contains(p)) return null;
    final col = ((p.dx - inner.left) / cell).floor().clamp(0, 2);
    final row = ((p.dy - inner.top) / cell).floor().clamp(0, 2);
    return row * 3 + col;
  }
}

/// 판 + 대기 말 칸 + 모든 말. 말 집기·끌기·놓기와 애니메이션을 처리한다.
class GobbletStage extends StatefulWidget {
  const GobbletStage({super.key, required this.controller});

  final GobbletController controller;

  @override
  State<GobbletStage> createState() => _GobbletStageState();
}

class _GobbletStageState extends State<GobbletStage> with SingleTickerProviderStateMixin {
  GobbletController get c => widget.controller;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  StageMetrics? _m;
  PieceId? _dragId;
  Offset _dragCenter = Offset.zero;
  Offset _grab = Offset.zero;
  int? _hover;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Offset _local(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);

  Offset _pieceCenter(StageMetrics m, PieceId id) {
    final team = teamOfPiece(id), size = sizeOfPiece(id);
    final loc = c.loc[id];
    return loc >= 0
        ? m.boardPieceCenter(loc)
        : m.slotCenter(team, c.humanTeam, size, c.reserveRank(id));
  }

  // ── 입력 ──

  void _onPieceTap(PieceId id) {
    if (c.selected == id) {
      c.clearSelection();
    } else if (c.isSelectable(id)) {
      c.select(id);
    } else if (c.selected != null && c.loc[id] >= 0 && c.targets.contains(c.loc[id])) {
      c.moveSelectedTo(c.loc[id]);
    } else {
      c.clearSelection();
    }
  }

  void _onCellTap(int cell) {
    if (c.selected != null && c.targets.contains(cell)) {
      c.moveSelectedTo(cell);
      return;
    }
    final top = c.topAt(cell);
    if (top != null && c.isSelectable(top)) {
      c.select(top);
    } else {
      c.clearSelection();
    }
  }

  void _dragStart(PieceId id, DragStartDetails d) {
    final m = _m;
    if (m == null || !c.isSelectable(id)) return;
    c.select(id);
    final center = _pieceCenter(m, id);
    _grab = center - _local(d.globalPosition);
    setState(() {
      _dragId = id;
      _dragCenter = center + Offset(0, -m.cell * 0.2);
      _hover = null;
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    final m = _m;
    if (m == null || _dragId == null) return;
    final center = _local(d.globalPosition) + _grab + Offset(0, -m.cell * 0.2);
    setState(() {
      _dragCenter = center;
      _hover = m.cellAt(center + Offset(0, m.cell * 0.12));
    });
  }

  void _dragEnd(DragEndDetails d) {
    final id = _dragId;
    final cell = _hover;
    setState(() {
      _dragId = null;
      _hover = null;
    });
    if (id == null) return;
    if (cell != null && c.targets.contains(cell)) {
      c.dropPiece(id, cell);
    } else {
      c.clearSelection();
    }
  }

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final m = StageMetrics.compute(box.biggest);
        _m = m;
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ..._trays(m),
                ..._boardWidgets(m),
                ..._pieces(m),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _trays(StageMetrics m) {
    return [
      for (final team in Team.values)
        _TrayPanel(
          rect: m.trayRect(team, c.humanTeam),
          team: team,
          cell: m.cell,
          active: c.turn == team && !c.isOver,
          pulse: _pulse,
          flipped: c.mode == PlayMode.local2p && team != c.humanTeam && !m.landscape,
          caption: _caption(team),
        ),
    ];
  }

  String _caption(Team team) {
    if (c.isOver) return team.label;
    if (c.turn != team) return team.label;
    if (c.vsCpu && team == c.cpuTeam) return '${team.label} · CPU 차례';
    return '${team.label} · 내 차례';
  }

  List<Widget> _boardWidgets(StageMetrics m) {
    final win = c.result?.line.toSet() ?? const <int>{};
    return [
      Positioned.fromRect(
        rect: m.board,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.cell * 0.26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7D9A8), Color(0xFFEBC083)],
            ),
            border: Border.all(color: const Color(0xFFD9A55F), width: m.cell * 0.04),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withValues(alpha: 0.25),
                blurRadius: m.cell * 0.18,
                offset: Offset(0, m.cell * 0.07),
              ),
            ],
          ),
        ),
      ),
      for (var cell = 0; cell < 9; cell++)
        Positioned.fromRect(
          rect: m.tileRect(cell),
          child: _Tile(
            cell: m.cell,
            isTarget: c.targets.contains(cell) && (_dragId != null || c.selected != null),
            covers: c.topAt(cell) != null,
            hovered: _hover == cell,
            winning: win.contains(cell),
            stack: [for (final id in c.stackAt(cell)) id],
            pulse: _pulse,
            onTap: () => _onCellTap(cell),
          ),
        ),
    ];
  }

  List<Widget> _pieces(StageMetrics m) {
    final win = c.result?.line.toSet() ?? const <int>{};
    final entries = <(double, Widget)>[];
    for (var id = 0; id < 12; id++) {
      final team = teamOfPiece(id), size = sizeOfPiece(id);
      final loc = c.loc[id];
      final dragging = _dragId == id;
      final center = dragging ? _dragCenter : _pieceCenter(m, id);
      final w = m.pieceWidth(size);
      final rect = Rect.fromCenter(center: center, width: w, height: w);

      double z;
      if (dragging) {
        z = 1000;
      } else if (loc >= 0) {
        z = 100 + c.heightOf(id) * 10 + (c.lastMoved == id ? 5 : 0);
      } else {
        z = 10 - c.reserveRank(id).toDouble();
      }
      if (c.lastMoved == id) z += 400; // 방금 움직인 말은 이동 중에도 위에 보이게
      if (c.selected == id) z += 600; // 집어 든 말은 맨 위에

      final selectable = c.isSelectable(id);
      final isWinner = loc >= 0 && win.contains(loc) && c.topAt(loc) == id &&
          c.result?.winner == team;
      final covered = loc >= 0 && c.isCovered(id);

      entries.add((
        z,
        PieceView(
          key: ValueKey('piece-$id'),
          team: team,
          size: size,
          rect: rect,
          cell: m.cell,
          animate: !dragging,
          lifted: dragging || c.selected == id,
          bob: selectable && c.selected != id,
          mood: isWinner ? PieceMood.happy : PieceMood.normal,
          pulse: _pulse,
          ignorePointer: covered,
          onTap: () => _onPieceTap(id),
          onDragStart: selectable ? (d) => _dragStart(id, d) : null,
          onDragUpdate: selectable ? _dragUpdate : null,
          onDragEnd: selectable ? _dragEnd : null,
        ),
      ));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in entries) e.$2];
  }
}

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.rect,
    required this.team,
    required this.cell,
    required this.active,
    required this.pulse,
    required this.flipped,
    required this.caption,
  });

  final Rect rect;
  final Team team;
  final double cell;
  final bool active;
  final Animation<double> pulse;
  final bool flipped;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final pal = TeamPalette.of(team);
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fromRect(
      rect: rect,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final glow = active ? 0.5 + 0.5 * sin(pulse.value * 2 * pi) : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cell * 0.24),
              color: Color.alphaBlend(
                pal.main.withValues(alpha: active ? 0.20 : 0.10),
                scheme.surface,
              ),
              border: Border.all(
                color: pal.main.withValues(alpha: active ? 0.6 + 0.4 * glow : 0.25),
                width: active ? cell * 0.045 : cell * 0.025,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: pal.main.withValues(alpha: 0.25 + 0.2 * glow),
                        blurRadius: cell * (0.15 + 0.1 * glow),
                      ),
                    ]
                  : null,
            ),
            child: Align(
              // 가로로 긴 대기 칸은 라벨을 왼쪽 위 빈 곳에 둔다 (큰 말의 귀를 가리지 않게)
              alignment: rect.width > rect.height ? Alignment.topLeft : Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: cell * 0.06, left: rect.width > rect.height ? cell * 0.12 : 0),
                child: Transform.rotate(
                  angle: flipped ? pi : 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: rect.width - cell * 0.2),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: cell * 0.14, vertical: cell * 0.03),
                      decoration: BoxDecoration(
                        color: pal.main,
                        borderRadius: BorderRadius.circular(cell),
                      ),
                      // 라벨이 길어도 한 줄로 줄어든다
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          caption,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: max(11.0, cell * 0.16),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.cell,
    required this.isTarget,
    required this.covers,
    required this.hovered,
    required this.winning,
    required this.stack,
    required this.pulse,
    required this.onTap,
  });

  final double cell;
  final bool isTarget;

  /// 이미 말이 있는 칸(덮게 되는 칸).
  final bool covers;
  final bool hovered;
  final bool winning;
  final List<PieceId> stack;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = covers ? const Color(0xFFFFA726) : const Color(0xFF34C38F);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final p = 0.5 + 0.5 * sin(pulse.value * 2 * pi);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cell * 0.16),
                  color: winning
                      ? Color.lerp(const Color(0xFFFFF1B8), const Color(0xFFFFD84D), p)
                      : isTarget
                          ? Color.alphaBlend(
                              ringColor.withValues(alpha: hovered ? 0.45 : 0.18),
                              const Color(0xFFFFF7E8),
                            )
                          : const Color(0xFFFFF7E8),
                  border: isTarget
                      ? Border.all(
                          color: ringColor.withValues(alpha: hovered ? 1 : 0.55 + 0.35 * p),
                          width: cell * (hovered ? 0.06 : 0.04),
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withValues(alpha: 0.12),
                      offset: Offset(0, cell * 0.025),
                    ),
                  ],
                ),
              ),
              // 덮여 있는 말 표시 (작은 점)
              if (stack.length > 1) _CoverDots(cell: cell, covered: stack.sublist(0, stack.length - 1)),
            ],
          );
        },
      ),
    );
  }
}

/// 맨 위 말 아래에 깔린 말들을 작은 점으로 보여준다 (팀 색, 크기 순).
class _CoverDots extends StatelessWidget {
  const _CoverDots({required this.cell, required this.covered});

  final double cell;
  final List<PieceId> covered;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: cell * 0.07,
      bottom: cell * 0.06,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final id in covered)
            Container(
              margin: EdgeInsets.only(right: cell * 0.03),
              width: cell * (0.06 + 0.035 * sizeOfPiece(id)),
              height: cell * (0.06 + 0.035 * sizeOfPiece(id)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeamPalette.of(teamOfPiece(id)).main,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
        ],
      ),
    );
  }
}
