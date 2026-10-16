import 'dart:math';

import 'package:flutter/material.dart';

import '../core/sprouts_geometry.dart';
import '../game/sprouts_controller.dart';
import 'sprouts_painter.dart';

/// 콩나물 판: 손가락으로 점에서 점으로 곡선을 긋는다.
class SproutsBoardView extends StatefulWidget {
  const SproutsBoardView({super.key, required this.controller});

  final SproutsController controller;

  @override
  State<SproutsBoardView> createState() => _SproutsBoardViewState();
}

class _SproutsBoardViewState extends State<SproutsBoardView> with TickerProviderStateMixin {
  SproutsController get c => widget.controller;

  /// 지금 긋고 있는 궤적 (판 좌표).
  List<P> _stroke = [];
  int? _pointer;

  /// 안 된다고 판정된 궤적과 사라지는 정도.
  List<P> _rejected = [];
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 0);

  /// CPU의 곡선이 그려지는 정도 / 새 점이 나타나는 정도.
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450), value: 1);

  /// 점과 선이 밀려서 옮겨 가는 정도 (자리가 좁아서 기존 모양을 살짝 밀 때).
  late final AnimationController _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);

  int _serial = 0;
  int _msgCount = 0;

  @override
  void initState() {
    super.initState();
    _serial = c.moveSerial;
    c.addListener(_onChanged);
    _draw.addStatusListener((s) {
      if (s == AnimationStatus.completed && c.moveCount > 0) _pop.forward(from: 0);
    });
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _fade.dispose();
    _draw.dispose();
    _pop.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_serial != c.moveSerial) {
      _serial = c.moveSerial;
      if (c.moveCount == 0 || c.board.curves.isEmpty) {
        _draw.value = 1;
        _pop.value = 1;
      } else if (c.morphFrom != null) {
        // 자리를 만드느라 점과 선이 밀렸다: 먼저 옮겨 가고, 그 뒤에 새 곡선이 나타난다
        _draw.value = 1;
        _pop.value = 1;
        // (선 정리하기는 새 곡선이 없으니 옮겨 가기만 한다)
        _morph.forward(from: 0).whenComplete(() {
          if (!c.lastWasTidy) _showNewCurve();
        });
      } else {
        _showNewCurve();
      }
    }
    setState(() {});
  }

  /// 방금 둔 수의 곡선과 새 점을 나타낸다 (사람이 그은 선은 이미 보였으니 새 점만 튀어나온다).
  ///
  /// 상대 기기에서 온 선은 길이에 맞춰 천천히 그린다 (짧은 선은 금방, 긴 선은 길게: 0.65~1.6초). 펜 끝이 빛나며 지나가고
  /// 출발·도착 점에서 물결이 퍼진다 ([SproutsPainter.remoteCue]).
  void _showNewCurve() {
    if (!mounted) return;
    if (c.lastByHuman) {
      _draw.value = 1;
      _pop.forward(from: 0);
    } else {
      _pop.value = 0;
      _draw.duration = c.lastRemote && c.board.curves.isNotEmpty
          ? Duration(milliseconds: (500 + pathLength(c.board.curves.last.pts) * 2.4).clamp(650, 1600).round())
          : const Duration(milliseconds: 650);
      _draw.forward(from: 0);
    }
  }

  P _toBoard(Offset local, Size size) {
    final b = c.board.bounds;
    final scale = min(size.width / b.width, size.height / b.height);
    final dx = (size.width - b.width * scale) / 2;
    final dy = (size.height - b.height * scale) / 2;
    return P(b.x0 + (local.dx - dx) / scale, b.y0 + (local.dy - dy) / scale);
  }

  void _down(PointerDownEvent e, Size size) {
    if (_pointer != null || !c.humanCanAct) return;
    c.cancelRepair(); // 새로 긋기 시작하면 앞선 선을 바로잡는 일은 그만둔다
    final p = _toBoard(e.localPosition, size);
    if (c.board.nearestDot(p) < 0) {
      c.tryStroke([p, p]); // "점에서 시작해 주세요" 안내
      return;
    }
    _pointer = e.pointer;
    _fade.value = 0;
    setState(() => _stroke = [p]);
  }

  void _move(PointerMoveEvent e, Size size) {
    if (e.pointer != _pointer) return;
    final p = _toBoard(e.localPosition, size);
    if (_stroke.isEmpty || _stroke.last.dist(p) >= 1.5) setState(() => _stroke.add(p));
  }

  void _up(PointerEvent e, Size size) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final stroke = _stroke;
    setState(() => _stroke = []);
    if (e is PointerCancelEvent || stroke.length < 2) return;
    final before = c.message;
    if (!c.tryStroke(stroke)) {
      // 안 된 선은 잠깐 빨갛게 보여 준다
      _rejected = stroke;
      _fade.value = 1;
      _fade.animateTo(0, curve: Curves.easeIn);
      _msgCount++;
      if (before == c.message) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = sproutsColor(c.turn);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, size),
          onPointerMove: (e) => _move(e, size),
          onPointerUp: (e) => _up(e, size),
          onPointerCancel: (e) => _up(e, size),
          child: AnimatedBuilder(
            animation: Listenable.merge([_fade, _draw, _pop, _morph]),
            builder: (context, _) => CustomPaint(
              size: size,
              painter: SproutsPainter(
                board: c.board,
                drawing: _stroke,
                drawingColor: color,
                rejected: _rejected,
                rejectedFade: _fade.value,
                hint: c.hintPath,
                morphFrom: _morph.value < 1 ? c.morphFrom : null,
                morphT: _morph.value,
                lastCurveT: Curves.easeInOut.transform(_draw.value),
                popT: _pop.value,
                remoteCue: c.lastRemote && !c.lastWasTidy,
                highlightDots: _stroke.isEmpty
                    ? const {}
                    : {
                        for (var i = 0; i < c.board.dots.length; i++)
                          if (c.board.dots[i].lives > 0) i,
                      },
              ),
              key: ValueKey('sprouts-board-$_msgCount'),
            ),
          ),
        );
      },
    );
  }
}
