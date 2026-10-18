import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/getcolor_controller.dart';
import 'getcolor_painter.dart';

part 'getcolor_board_painter.dart';

/// 병들을 놓는 자리. 화면 크기와 병 수에 맞춰 한 줄~세 줄로 가장 크게 나눈다.
class GcLayout {
  const GcLayout(this.w, this.rects);

  /// 병 너비.
  final double w;

  /// 병마다 놓인 자리 (가만히 있을 때).
  final List<Rect> rects;

  static const double gapRatio = 0.30;
  static const double liftRoom = 0.5;

  /// 맨 아래 줄 병 밑의 그림자가 들어갈 여백.
  static const double bottomRoom = 0.2;

  static GcLayout compute(Size area, int n) {
    if (n <= 0 || area.isEmpty) return const GcLayout(0, []);
    var bestW = 0.0;
    var bestRows = 1;
    for (var rows = 1; rows <= min(3, n); rows++) {
      final cols = (n / rows).ceil();
      final byWidth = area.width / (cols + (cols - 1) * gapRatio);
      final byHeight = area.height / (rows * (kBottleAspect + liftRoom) + (rows - 1) * 0.25 + bottomRoom);
      final cand = min(min(byWidth, byHeight), 150.0);
      if (cand > bestW) {
        bestW = cand;
        bestRows = rows;
      }
    }
    final w = bestW;
    final cols = (n / bestRows).ceil();
    final rowH = w * (kBottleAspect + liftRoom);
    final totalH = bestRows * rowH + (bestRows - 1) * w * 0.25 + w * bottomRoom;
    final top0 = (area.height - totalH) / 2;
    final rects = <Rect>[];
    for (var i = 0; i < n; i++) {
      final r = i ~/ cols;
      final inRow = min(cols, n - r * cols);
      final rowW = inRow * w + (inRow - 1) * w * gapRatio;
      final left = (area.width - rowW) / 2 + (i % cols) * w * (1 + gapRatio);
      final top = top0 + r * (rowH + w * 0.25) + w * liftRoom;
      rects.add(Rect.fromLTWH(left, top, w, w * kBottleAspect));
    }
    return GcLayout(w, rects);
  }

  /// 화면 좌표 [p]에서 가장 가까운 병. 병 사이 틈이나 위아래 빈 곳을 눌러도 가까운 병으로 잡아 준다
  /// (병이 들어 올려진 높이까지 포함하고, 병 너비의 0.45배 안이면 인정한다).
  int? hit(Offset p) {
    int? best;
    var bestD = double.infinity;
    var bestC = double.infinity;
    for (var i = 0; i < rects.length; i++) {
      final r = Rect.fromLTRB(rects[i].left, rects[i].top - w * liftRoom, rects[i].right, rects[i].bottom + w * 0.05);
      final dx = max(max(r.left - p.dx, p.dx - r.right), 0.0);
      final dy = max(max(r.top - p.dy, p.dy - r.bottom), 0.0);
      final d = sqrt(dx * dx + dy * dy);
      if (d > w * 0.45) continue;
      final cd = (rects[i].center - p).distance;
      if (d < bestD - 1e-6 || ((d - bestD).abs() <= 1e-6 && cd < bestC)) {
        bestD = d;
        bestC = cd;
        best = i;
      }
    }
    return best;
  }
}

/// 끌고 있는 중의 정보: 어느 병에서, 손가락이 어디, 어느 병 위에 있는지.
class _Drag {
  const _Drag(this.from, this.pos, this.target, this.legal);

  final int from;
  final Offset pos;

  /// 손가락 아래의 병 (없으면 null).
  final int? target;

  /// 그 병에 부을 수 있는가.
  final bool legal;
}

/// 끌고 있는 병의 자세: 입구가 손가락 위쪽에 오고, 가려는 쪽으로 기울어진다
/// (부을 수 있는 병 위에서는 더 많이 기울인다). 기울기는 오른쪽이 +.
(Offset mouth, double tilt) _dragPose(GcLayout layout, _Drag d) {
  final w = layout.w;
  final src = layout.rects[d.from].center.dx;
  final toward = d.target != null ? layout.rects[d.target!].center.dx : d.pos.dx;
  final side = toward >= src ? 1.0 : -1.0;
  return (d.pos + Offset(0, -w * 0.45), side * (d.legal ? 0.62 : 0.45));
}

/// 끌다가 부을 수 있는 병 위에서 놓았을 때, 붓는 모습이 병을 놓은 자리에서 이어 시작하도록 기억해 둔다.
class _DropStart {
  const _DropStart(this.serial, this.mouth, this.tilt);

  /// 이 붓기([GcPour.serial])에만 쓴다.
  final int serial;
  final Offset mouth;
  final double tilt;
}

/// 병들이 놓인 판: 누르면 바로 고르고, 다른 병을 누르거나 병에서 병으로 끌어서 붓는다.
/// 끄는 동안 부을 수 있는 병을 밝게 보여 주고, 손가락 아래 병은 더 강하게 표시한다.
class GetColorBoard extends StatefulWidget {
  const GetColorBoard({super.key, required this.controller});

  final GetColorController controller;

  @override
  State<GetColorBoard> createState() => _GetColorBoardState();
}

class _GetColorBoardState extends State<GetColorBoard> with TickerProviderStateMixin {
  GetColorController get c => widget.controller;

  late final AnimationController _pour = AnimationController(vsync: this, value: 1);
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: 1,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// 끌기 상태 (판이 다시 그려지도록 ValueNotifier).
  final ValueNotifier<_Drag?> _drag = ValueNotifier(null);
  _DropStart? _dropStart;
  int? _pointer;
  Offset _downPos = Offset.zero;
  int? _downBottle;
  bool _selectedOnDown = false;
  bool _dragging = false;

  int _seenPour = 0;
  int? _selected;
  int? _prevSelected;
  bool _wasCompleted = false;
  GcLayout _layout = const GcLayout(0, []);

  @override
  void initState() {
    super.initState();
    _seenPour = c.lastPour?.serial ?? 0;
    _selected = c.selected;
    _wasCompleted = c.completed;
    if (c.completed) _win.value = 1;
    c.addListener(_onController);
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _drag.dispose();
    _pour.dispose();
    _lift.dispose();
    _pulse.dispose();
    _win.dispose();
    super.dispose();
  }

  void _onController() {
    final p = c.lastPour;
    if (p == null) {
      _pour.value = 1; // 되돌리기·다시 하기: 붓던 모습은 멈춘다
      _seenPour = 0;
    } else if (p.serial != _seenPour) {
      _seenPour = p.serial;
      // 붓는 시간 (예전의 70%)
      _pour.duration = Duration(milliseconds: ((620 + 130 * p.count) * 0.7).round());
      _pour.forward(from: 0);
    }
    if (c.selected != _selected) {
      _prevSelected = _selected;
      _selected = c.selected;
      _lift.forward(from: 0);
    }
    if (c.hint != null && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (c.hint == null && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (c.completed && !_wasCompleted) {
      _win.forward(from: 0);
    } else if (!c.completed && _wasCompleted) {
      _win.value = 0;
    }
    _wasCompleted = c.completed;
  }

  // ── 터치: 누르는 순간 반응하고(탭 인식기를 거치지 않아 손가락이 조금 움직여도 씹히지 않는다),
  //    붓는 애니메이션 중에도 입력을 받는다. 병에서 병으로 끌어서 붓는 것도 같은 길로 처리한다. ──

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || !c.canAct) return;
    _pointer = e.pointer;
    _downPos = e.localPosition;
    _downBottle = _layout.hit(e.localPosition);
    _dragging = false;
    _selectedOnDown = false;
    final i = _downBottle;
    // 아무것도 안 골랐을 때는 누르는 즉시 들어 올린다 (손을 뗄 때까지 기다리지 않는다)
    if (i != null && c.selected == null) _selectedOnDown = c.selectBottle(i);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || !c.canAct) return;
    final from = _downBottle;
    if (!_dragging) {
      if (from == null || c.state.isEmpty(from) || c.state.isDone(from)) return;
      final slop = max(10.0, _layout.w * 0.18);
      if ((e.localPosition - _downPos).distance < slop) return;
      _dragging = true;
      c.selectBottle(from); // 다른 병이 골라져 있었어도 끌기 시작한 병으로 옮긴다
    }
    _updateDrag(e.localPosition);
  }

  void _updateDrag(Offset pos) {
    final from = _downBottle;
    if (from == null) return;
    var target = _layout.hit(pos);
    if (target == from) target = null;
    _drag.value = _Drag(from, pos, target, target != null && c.state.canPour(from, target));
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final from = _downBottle;
    if (_dragging && from != null) {
      _updateDrag(e.localPosition);
      final d = _drag.value;
      _drag.value = null;
      _dragging = false;
      if (d != null && d.legal && d.target != null && c.selected == from) {
        final pose = _dragPose(_layout, d);
        if (c.pourTo(from, d.target!)) _dropStart = _DropStart(c.lastPour!.serial, pose.$1, pose.$2);
      } else {
        c.clearSelection(); // 부을 수 없는 곳이나 빈 곳에 놓으면 내려놓는다
      }
      return;
    }
    // 그냥 눌렀다 뗀 것: 방금 눌러서 이미 들어 올렸다면 끝, 아니면 (부을 곳 누르기 등) 탭으로 처리
    if (_selectedOnDown) return;
    final i = _layout.hit(e.localPosition) ?? from;
    if (i != null) c.tapBottle(i);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_dragging) c.clearSelection();
    _dragging = false;
    _drag.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _layout = GcLayout.compute(box.biggest, c.state.count);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: CustomPaint(
            size: box.biggest,
            painter: _BoardPainter(
              c: c,
              layout: _layout,
              pour: _pour,
              lift: _lift,
              pulse: _pulse,
              win: _win,
              drag: _drag,
              dropStart: () => _dropStart,
              selected: () => _selected,
              prevSelected: () => _prevSelected,
            ),
          ),
        );
      },
    );
  }
}
