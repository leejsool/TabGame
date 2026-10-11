import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/jigsaw_controller.dart';
import 'jigsaw_images.dart';

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
        if (c.dragging != null) _dragPointer = e.pointer;
      }
    } else if (_pointers.length == 2) {
      // 두 번째 손가락: 끌던 조각은 놓고, 확대·축소 시작
      if (_dragPointer != null) {
        c.endDrag();
        _dragPointer = null;
      }
      _startPinch();
    }
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
      c.endDrag();
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

class _TablePainter extends CustomPainter {
  _TablePainter({
    required this.c,
    required this.pieces,
    required this.image,
    required this.slotLines,
    required this.getScale,
    required this.getOffset,
    required this.pop,
    required this.reveal,
    required this.pulse,
    required this.viewTick,
  }) : super(repaint: Listenable.merge([c, pop, reveal, pulse, viewTick]));

  final JigsawController c;
  final PieceImages pieces;
  final ui.Image image;
  final Path slotLines;
  final double Function() getScale;
  final Offset Function() getOffset;
  final Animation<double> pop;
  final Animation<double> reveal;
  final Animation<double> pulse;
  final Listenable viewTick;

  static const _outside = Color(0xFF244B57);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = getScale(), offset = getOffset();
    canvas.drawRect(Offset.zero & size, Paint()..color = _outside);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final table = c.tableSize;
    final tableRect = Offset.zero & table;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(36)),
      Paint()
        ..shader = ui.Gradient.radial(
          tableRect.center,
          table.longestSide * 0.7,
          const [Color(0xFF4A8696), Color(0xFF2F5E6B)],
        ),
    );

    // 판(그림 자리)
    final board = c.boardRect;
    canvas.drawRect(board.inflate(6), Paint()..color = const Color(0x33000000));
    canvas.drawRect(board, Paint()..color = const Color(0x26FFFFFF));
    if (c.ghost && !c.completed) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        board,
        Paint()
          ..color = const Color(0x38FFFFFF)
          ..filterQuality = FilterQuality.medium,
      );
    }
    canvas.drawPath(
      slotLines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale.clamp(0.2, 4)
        ..color = Color(c.ghost ? 0x40FFFFFF : 0x18FFFFFF),
    );
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale.clamp(0.2, 4)
        ..color = const Color(0x66FFFFFF),
    );

    // 붙은 조각 → 안 붙은 조각 순서로 (order 가 이미 그 순서)
    final dragging = c.dragging;
    for (final i in c.order) {
      if (i == dragging) continue;
      _drawPiece(canvas, i, c.pos[i]);
    }

    // 방금 붙은 조각 반짝임
    if (c.lastPlaced >= 0 && pop.value < 1 && !c.completed) {
      final i = c.lastPlaced;
      final t = pop.value;
      canvas.drawPath(
        c.geometry.paths[i].shift(c.pos[i]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (6 + 10 * t) / scale.clamp(0.2, 4)
          ..color = Colors.white.withValues(alpha: (1 - t) * 0.9),
      );
    }

    // 완성: 그림 전체가 이음매 없이 나타난다
    if (c.completed) {
      final t = Curves.easeInOut.transform(reveal.value);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        board,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, t)
          ..filterQuality = FilterQuality.medium,
      );
      canvas.drawRect(
        board.inflate(4 + 10 * sin(reveal.value * pi)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 / scale.clamp(0.2, 4)
          ..color = const Color(0xFFFFE26B).withValues(alpha: 0.4 + 0.6 * sin(reveal.value * pi)),
      );
    }

    // 힌트: 그 조각과 제자리를 깜빡여 알려준다
    final hint = c.hintPiece;
    if (hint != null && !c.completed) {
      final glow = 0.45 + 0.55 * pulse.value;
      final w = (7 + 5 * pulse.value) / scale.clamp(0.2, 4);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = const Color(0xFFFFD84D).withValues(alpha: glow);
      canvas.drawPath(c.geometry.paths[hint].shift(c.targetPos(hint)), paint);
      canvas.drawPath(c.geometry.paths[hint].shift(c.pos[hint]), paint);
      canvas.drawPath(
        c.geometry.paths[hint].shift(c.targetPos(hint)),
        Paint()..color = const Color(0xFFFFD84D).withValues(alpha: 0.18 * glow),
      );
    }

    // 지금 끌고 있는 조각은 맨 위에, 그림자와 함께
    if (dragging != null) {
      final img = pieces.images[dragging];
      final p = c.pos[dragging];
      canvas.drawImage(
        img,
        p + const Offset(10, 14),
        Paint()
          ..colorFilter = const ColorFilter.mode(Color(0x66000000), BlendMode.srcIn)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      final center = p + Offset(img.width / 2, img.height / 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1.04);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawImage(img, p, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawPiece(Canvas canvas, int i, Offset p) {
    canvas.drawImage(pieces.images[i], p, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_TablePainter old) => true;
}
