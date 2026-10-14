import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/mines_rules.dart' show CellMark;
import '../game/mines_controller.dart';
import 'mines_painter.dart';

/// 지뢰찾기 판: 칸을 톡 치면 열기(숫자는 코드). 꾹 누르면 원형 메뉴가 뜬다: 가운데에서 떼면 취소,
/// 위쪽 120도는 열기, 오른쪽 아래 120도는 깃발, 왼쪽 아래 120도는 물음표(?). 두 손가락으로 확대/이동.
/// 확대한 상태에서는 이미 열린 칸을 한 손가락으로 잡고 끌어도 화면이 움직인다 (톡 치면 코드).
class MinesBoardView extends StatefulWidget {
  const MinesBoardView({super.key, required this.controller});

  final MinesController controller;

  @override
  State<MinesBoardView> createState() => _MinesBoardState();
}

class _MinesBoardState extends State<MinesBoardView> with SingleTickerProviderStateMixin {
  MinesController get c => widget.controller;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final TransformationController _zoom = TransformationController();

  // 누르고 있는 손가락 (한 손가락은 칸 누르기, 두 손가락은 확대/이동)
  final Set<int> _pointers = {};
  int? _pressPointer;
  Offset _pressStart = Offset.zero;
  Timer? _showTimer;
  final ValueNotifier<MinesPress?> _press = ValueNotifier(null);

  /// 두 손가락일 때만 InteractiveViewer가 판을 옮긴다 (한 손가락 끌기는 깃발·물음표에 쓰이므로).
  bool _panOk = false;

  // 확대했을 때 이미 열린 칸을 한 손가락으로 끌어서 화면을 옮기는 중
  int? _panPointer;
  Offset _panLast = Offset.zero;
  double _panMoved = 0;
  Offset _panAccum = Offset.zero; // 끌기로 인정되기 전까지 움직인 만큼 (인정되면 한꺼번에 옮겨서 끊김이 없게)
  bool _panning = false;
  Size _area = Size.zero;

  /// 이만큼 움직여야 "끌기"로 본다 (손가락이 조금 떨리는 것은 톡 치기).
  static const _panSlop = 10.0;

  bool get _zoomed => _zoom.value.getMaxScaleOnAxis() > 1.01;

  /// 이만큼 눌러야 안내가 나타난다 (톡 치는 탭에서는 번쩍이지 않게).
  static const _showDelay = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    _onController();
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _ticker.dispose();
    _showTimer?.cancel();
    _press.dispose();
    _frame.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// 애니메이션이 필요한 동안만 프레임을 돌린다.
  bool get _needsFrames => c.clockMs < c.animEndMs + 50 || c.hint != null || c.status == MinesStatus.won && c.clockMs - c.winAt < 5200;

  void _onController() {
    if (c.status == MinesStatus.ready && !_zoom.value.isIdentity()) _zoom.value = Matrix4.identity();
    if (_needsFrames && !_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    _frame.value++;
    if (!_needsFrames) _ticker.stop();
  }

  void _pointerDown(PointerDownEvent e, MinesLayout layout) {
    _pointers.add(e.pointer);
    if (_pointers.length >= 2) {
      _cancelPress();
      _panPointer = null;
      _panning = false;
      if (!_panOk) setState(() => _panOk = true);
      return;
    }
    final i = layout.cellAt(e.localPosition);
    // 확대한 판에서 이미 열린 칸(또는 끝난 판의 아무 칸)을 잡으면, 끌었을 때 화면이 움직이게 준비한다
    if (_zoomed && (i == null || !c.canAct || c.board.marks[i] == CellMark.revealed)) {
      _panPointer = e.pointer;
      _panLast = e.position;
      _panMoved = 0;
      _panAccum = Offset.zero;
      _panning = false;
    }
    if (!c.canAct) return;
    if (i == null) return;
    _pressPointer = e.pointer;
    _pressStart = e.position;
    _press.value = MinesPress(
      cell: i,
      mark: c.board.marks[i],
      canMark: c.canMark(i),
      anchor: e.localPosition,
      // 누른 자리는 원의 가운데(취소). 원이 뜨기 전에 톡 치고 떼면 열기로 친다 (MinesPress.result)
      action: c.canMark(i) ? PressAction.cancel : PressAction.open,
    );
    _showTimer?.cancel();
    _showTimer = Timer(_showDelay, () {
      final p = _press.value;
      if (p != null && _pressPointer != null) _press.value = p.copyWith(visible: true);
    });
  }

  /// 화면(확대한 판)을 [d]만큼 옮긴다. 판 가장자리 밖으로는 못 간다.
  void _panBy(Offset d) {
    final m = _zoom.value.clone();
    final s = m.getMaxScaleOnAxis();
    final tx = (m.entry(0, 3) + d.dx).clamp(_area.width * (1 - s), 0.0);
    final ty = (m.entry(1, 3) + d.dy).clamp(_area.height * (1 - s), 0.0);
    m
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _zoom.value = m;
  }

  void _pointerMove(PointerMoveEvent e) {
    if (e.pointer == _panPointer && _pointers.length < 2) {
      final d = e.position - _panLast;
      _panLast = e.position;
      _panMoved += d.distance;
      _panAccum += d;
      if (!_panning && _panMoved > _panSlop) {
        // 끌기가 시작됐다: 칸 누르기(코드)는 취소하고, 지금까지 움직인 만큼 화면을 옮긴다
        _panning = true;
        _cancelPress();
        _panBy(_panAccum);
        return;
      }
      if (_panning) {
        _panBy(d);
        return;
      }
    }
    final p = _press.value;
    if (p == null || e.pointer != _pressPointer) return;
    final d = e.position - _pressStart;
    final action = p.actionFor(d);
    // 가운데(취소 영역)를 벗어나 끌기 시작하면 바로 원을 보여준다
    final left = p.left || d.distance >= kPressDeadRadius;
    final visible = p.visible || left || d.distance > 12;
    if (action != p.action || visible != p.visible || left != p.left) {
      _press.value = p.copyWith(action: action, visible: visible, left: left);
    }
  }

  void _pointerUp(PointerEvent e) {
    final removed = _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _panOk) setState(() => _panOk = false);
    if (e.pointer == _panPointer) {
      final wasPanning = _panning;
      _panPointer = null;
      _panning = false;
      if (wasPanning) return; // 끌기였으니 칸은 누르지 않은 것으로 한다
    }
    final p = _press.value;
    if (!removed || p == null || e.pointer != _pressPointer) return;
    final cancelled = e is PointerCancelEvent;
    final result = p.result;
    final blocked = p.blocked;
    _cancelPress();
    if (cancelled || blocked) return;
    switch (result) {
      case PressAction.open:
        c.tap(p.cell);
      case PressAction.flag:
        c.flag(p.cell);
      case PressAction.question:
        c.question(p.cell);
      case PressAction.cancel:
        break;
    }
  }

  void _cancelPress() {
    _showTimer?.cancel();
    _pressPointer = null;
    _press.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final area = box.biggest;
        _area = area;
        final layout = MinesLayout(area, c.board.rows, c.board.cols);
        final repaint = Listenable.merge([c, _frame]);
        return InteractiveViewer(
          transformationController: _zoom,
          panEnabled: _panOk,
          minScale: 1,
          maxScale: 3.5,
          // 확대하지 않았을 때는 판이 화면 밖으로 끌려가지 않는다
          boundaryMargin: EdgeInsets.zero,
          child: SizedBox(
            width: area.width,
            height: area.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _pointerDown(e, layout),
                    onPointerMove: _pointerMove,
                    onPointerUp: _pointerUp,
                    onPointerCancel: _pointerUp,
                    child: CustomPaint(painter: MinesPainter(c: c, layout: layout, repaint: repaint)),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: MinesConfettiPainter(c: c, repaint: repaint))),
                ),
                // 누르고 있는 칸의 원형 메뉴 (취소 / 열기 / 깃발 / 물음표)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: MinesPressPainter(layout: layout, press: _press, zoom: _zoom)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
