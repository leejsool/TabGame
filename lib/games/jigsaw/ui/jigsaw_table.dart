import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/jigsaw_controller.dart';
import 'jigsaw_images.dart';

part 'jigsaw_table_painter.dart';

/// 퍼즐 탁자: 조각 끌기 / 두 손가락 확대·축소 / 한 손가락으로 화면 밀기를 처리하고 그린다.
class JigsawTable extends StatefulWidget {
  const JigsawTable({
    super.key,
    required this.controller,
    required this.pieces,
    required this.image,
  });

  final JigsawController controller;
  final PieceImages pieces;
  final ui.Image image;

  @override
  State<JigsawTable> createState() => _JigsawTableState();
}

class _JigsawTableState extends State<JigsawTable> with TickerProviderStateMixin {
  JigsawController get c => widget.controller;

  // 화면 보기 상태: 화면좌표 = 탁자좌표 * _scale + _offset
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _fit = 1;
  Size _view = Size.zero;
  final ValueNotifier<int> _viewTick = ValueNotifier(0);

  final Map<int, Offset> _pointers = {};
  int? _dragPointer;
  double _pinchDist0 = 1;
  double _pinchScale0 = 1;
  Offset _pinchTable0 = Offset.zero;
  DateTime _lastTap = DateTime(2000);
  Offset _downPos = Offset.zero;

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Path _slotLines = _buildSlotLines();
  int _placeSerial = 0;
  int _hintSerial = 0;
  bool _wasCompleted = false;
  Timer? _hintTimer;

  /// 끌고 있는 덩어리를 한 장으로 합쳐 둔 그림 (끄는 동안 그림자·조각마다 다시 그리지 않으려고).
  _DragLayer? _dragLayer;

  Path _buildSlotLines() {
    final all = Path();
    for (var i = 0; i < c.geometry.count; i++) {
      all.addPath(c.geometry.paths[i], c.targetPos(i));
    }
    return all;
  }

  @override
  void initState() {
    super.initState();
    _placeSerial = c.placeSerial;
    _hintSerial = c.hintSerial;
    _wasCompleted = c.completed;
    if (c.completed) _reveal.value = 1;
    c.addListener(_onController);
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _dragLayer?.dispose();
    _hintTimer?.cancel();
    _pop.dispose();
    _reveal.dispose();
    _pulse.dispose();
    _viewTick.dispose();
    super.dispose();
  }

  void _onController() {
    if (c.placeSerial != _placeSerial) {
      _placeSerial = c.placeSerial;
      _pop.forward(from: 0);
    }
    if (c.completed && !_wasCompleted) _reveal.forward(from: 0);
    _wasCompleted = c.completed;
    if (c.hintSerial != _hintSerial) {
      _hintSerial = c.hintSerial;
      _pulse.repeat(reverse: true);
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(seconds: 5), c.clearHint);
    }
    if (c.hintPiece == null && _pulse.isAnimating) _pulse.stop();
  }

  // ── 보기(확대/이동) ──

  Offset _toTable(Offset screen) => (screen - _offset) / _scale;

  void _fitView(Size view) {
    final t = c.tableSize;
    _fit = min(view.width / t.width, view.height / t.height);
    _scale = _fit;
    _offset = Offset((view.width - t.width * _scale) / 2, (view.height - t.height * _scale) / 2);
    _viewTick.value++;
  }

  void _clampView() {
    final t = c.tableSize;
    final w = t.width * _scale, h = t.height * _scale;
    final dx = w <= _view.width ? (_view.width - w) / 2 : _offset.dx.clamp(_view.width - w, 0.0);
    final dy = h <= _view.height ? (_view.height - h) / 2 : _offset.dy.clamp(_view.height - h, 0.0);
    _offset = Offset(dx, dy);
  }

  void _zoomAt(Offset focal, double newScale) {
    final s = newScale.clamp(_fit, _fit * 5);
    final tablePoint = _toTable(focal);
    _scale = s;
    _offset = focal - tablePoint * s;
    _clampView();
    _viewTick.value++;
  }

  // ── 터치 ──

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downPos = e.localPosition;
      final p = _toTable(e.localPosition);
      final i = c.pieceAt(p);
      if (i != null) {
        c.beginDrag(i, p);
        if (c.dragging != null) {
          _dragPointer = e.pointer;
          _dragLayer = _DragLayer.build(c, widget.pieces);
        }
      }
    } else if (_pointers.length == 2) {
      // 두 번째 손가락: 끌던 조각은 놓고, 확대·축소 시작
      if (_dragPointer != null) {
        _endDrag();
        _dragPointer = null;
      }
      _startPinch();
    }
  }

  void _endDrag() {
    c.endDrag();
    _dragLayer?.dispose();
    _dragLayer = null;
  }

  void _startPinch() {
    final pts = _pointers.values.toList();
    final mid = (pts[0] + pts[1]) / 2;
    _pinchDist0 = max(1.0, (pts[0] - pts[1]).distance);
    _pinchScale0 = _scale;
    _pinchTable0 = _toTable(mid);
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    final prev = _pointers[e.pointer]!;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      final pts = _pointers.values.toList();
      final mid = (pts[0] + pts[1]) / 2;
      final dist = max(1.0, (pts[0] - pts[1]).distance);
      _scale = (_pinchScale0 * dist / _pinchDist0).clamp(_fit, _fit * 5);
      _offset = mid - _pinchTable0 * _scale;
      _clampView();
      _viewTick.value++;
    } else if (_dragPointer == e.pointer) {
      c.dragTo(_toTable(e.localPosition));
    } else {
      _offset += e.localPosition - prev;
      _clampView();
      _viewTick.value++;
    }
  }

  void _up(PointerEvent e) {
    final wasDragging = _dragPointer == e.pointer;
    final moved = (e.localPosition - _downPos).distance;
    _pointers.remove(e.pointer);
    if (wasDragging) {
      _endDrag();
      _dragPointer = null;
    } else if (_pointers.isEmpty && moved < 10 && e is PointerUpEvent) {
      // 빈 곳을 두 번 두드리면 화면에 맞춘다
      final now = DateTime.now();
      if (now.difference(_lastTap) < const Duration(milliseconds: 350)) {
        _fitView(_view);
        _lastTap = DateTime(2000);
      } else {
        _lastTap = now;
      }
    }
    if (_pointers.length == 1) {
      // 핀치가 끝나고 한 손가락만 남으면 화면 밀기로 이어간다
      _downPos = _pointers.values.first;
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _zoomAt(e.localPosition, _scale * exp(-e.scrollDelta.dy / 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (size != _view) {
          _view = size;
          _fitView(size);
        }
        return ClipRect(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            onPointerSignal: _signal,
            child: CustomPaint(
              size: size,
              painter: _TablePainter(
                c: c,
                pieces: widget.pieces,
                image: widget.image,
                slotLines: _slotLines,
                getScale: () => _scale,
                getOffset: () => _offset,
                getDragLayer: () => _dragLayer,
                pop: _pop,
                reveal: _reveal,
                pulse: _pulse,
                viewTick: _viewTick,
              ),
            ),
          ),
        );
      },
    );
  }
}
