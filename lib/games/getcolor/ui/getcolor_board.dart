import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/getcolor_controller.dart';
import 'getcolor_painter.dart';

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
      _pour.duration = Duration(milliseconds: 620 + 130 * p.count);
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

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.c,
    required this.layout,
    required this.pour,
    required this.lift,
    required this.pulse,
    required this.win,
    required this.drag,
    required this.dropStart,
    required this.selected,
    required this.prevSelected,
  }) : super(repaint: Listenable.merge([c, pour, lift, pulse, win, drag]));

  final GetColorController c;
  final GcLayout layout;
  final Animation<double> pour;
  final Animation<double> lift;
  final Animation<double> pulse;
  final Animation<double> win;
  final ValueListenable<_Drag?> drag;
  final _DropStart? Function() dropStart;
  final int? Function() selected;
  final int? Function() prevSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = layout.w;
    if (w <= 0) return;
    final state = c.state;
    final n = min(state.count, layout.rects.length);
    final last = c.lastPour;
    final pr = (last != null && pour.value < 1 && last.from < n && last.to < n) ? last : null;
    final pouring = pr != null;
    final t = pour.value;
    final sel = selected(), prev = prevSelected();
    final glow = 0.45 + 0.55 * pulse.value;
    final hint = c.hint;
    final dragInfo = drag.value;

    double liftOf(int i) {
      var l = 0.0;
      if (i == sel) l += lift.value;
      if (i == prev && i != sel) l += 1 - lift.value;
      return l * w * 0.38;
    }

    double hopOf(int i) {
      if (!c.completed) return 0;
      final ph = (win.value * 2.4 - i * 0.07).clamp(0.0, 1.0);
      return sin(ph * pi) * w * 0.28;
    }

    // 붓는 애니메이션의 단계
    var pourP = 0.0, move = 0.0, tilt = 0.0, side = 1.0, approach = 0.0, back = 0.0;
    final ds = (pr != null && dropStart()?.serial == pr.serial) ? dropStart() : null;
    if (pr != null) {
      pourP = ((t - 0.25) / 0.55).clamp(0.0, 1.0);
      approach = Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0));
      back = Curves.easeIn.transform(((t - 0.8) / 0.2).clamp(0.0, 1.0));
      move = approach * (1 - back);
      side = layout.rects[pr.to].center.dx >= layout.rects[pr.from].center.dx ? 1.0 : -1.0;
      if (ds != null) {
        // 끌어서 놓은 병은 이미 기울어 있다: 놓을 때의 기울기에서 시작해 붓는 기울기로 이어진다
        final start = ds.tilt.abs();
        tilt = side * (start + (0.50 - start) * approach + 0.62 * pourP) * (1 - back);
      } else {
        tilt = side * (0.50 + 0.62 * pourP) * move;
      }
    }

    // 그림자 + 가만히 있는 병들
    for (var i = 0; i < n; i++) {
      final r = layout.rects[i];
      canvas.save();
      canvas.translate(r.left, r.top);
      paintBottleShadow(canvas, w);
      canvas.restore();
    }
    for (var i = 0; i < n; i++) {
      if (pr != null && i == pr.from) continue;
      if (dragInfo != null && i == dragInfo.from) {
        // 병을 들고 간 자리: 어디서 왔는지 보이도록 흐릿한 빈 병 윤곽만 남긴다
        final r = layout.rects[i];
        canvas.saveLayer(r.inflate(w * 0.2), Paint()..color = Colors.white.withValues(alpha: 0.28));
        canvas.translate(r.left, r.top);
        paintBottle(canvas, w, const []);
        canvas.restore();
        continue;
      }
      final r = layout.rects[i];
      var layers = layersOf(state.bottles[i]);
      var done = state.isDone(i);
      if (pr != null && i == pr.to) {
        // 받는 병: 새로 들어온 칸이 천천히 차오른다
        final base = state.bottles[i].sublist(0, state.bottles[i].length - pr.count);
        layers = [...layersOf(base), (pr.color, pr.count * pourP)];
        done = state.isDone(i) && pourP >= 1;
      }
      var g = 0.0;
      Color gc = const Color(0xFFFFD84D);
      if (hint != null) {
        if (i == hint.from) g = glow;
        if (i == hint.to) {
          g = glow;
          gc = const Color(0xFF7CF0A0);
        }
      }
      if (dragInfo != null && i != dragInfo.from) {
        // 끄는 동안: 부을 수 있는 병은 은은하게, 손가락 아래 병은 강하게 (부을 수 없으면 붉게)
        if (i == dragInfo.target) {
          g = 1.0;
          gc = dragInfo.legal ? const Color(0xFF3DDC84) : const Color(0xFFFF6B6B);
        } else if (state.canPour(dragInfo.from, i)) {
          g = 0.38;
          gc = const Color(0xFF7CF0A0);
        }
      }
      canvas.save();
      canvas.translate(r.left, r.top - liftOf(i) - hopOf(i));
      paintBottle(canvas, w, layers, done: done, glow: g, glowColor: gc);
      canvas.restore();
    }

    // 붓는 병은 맨 위에: 입구를 받는 병 위로 옮겨 기울인다
    if (pr != null) {
      final src = layout.rects[pr.from];
      final dst = layout.rects[pr.to];
      final mouthLocal = bottleMouth(w);
      final restMouth = src.topLeft + mouthLocal - Offset(0, liftOf(pr.from));
      final targetMouth = Offset(
        dst.center.dx - side * bottleNeckHalf(w) * cos(tilt),
        dst.top - w * 0.42,
      );
      final Offset mouth;
      if (ds != null) {
        // 놓은 자리에서 받는 병 위로 모이고, 다 붓고 나면 제자리로 돌아간다
        mouth = back > 0 ? Offset.lerp(targetMouth, restMouth, back)! : Offset.lerp(ds.mouth, targetMouth, approach)!;
      } else {
        mouth = Offset.lerp(restMouth, targetMouth, move)!;
      }

      final remaining = [
        ...layersOf(state.bottles[pr.from]),
        (pr.color, pr.count * (1 - pourP)),
      ];
      // 같은 색이 이어지면 한 덩어리로
      final merged = <WaterLayer>[];
      for (final l in remaining) {
        if (merged.isNotEmpty && merged.last.$1 == l.$1) {
          merged[merged.length - 1] = (l.$1, merged.last.$2 + l.$2);
        } else {
          merged.add(l);
        }
      }

      // 물줄기
      if (pourP > 0 && pourP < 1 && move > 0.95) {
        final lip = mouth + Offset(side * bottleNeckHalf(w) * cos(tilt), side * bottleNeckHalf(w) * sin(tilt));
        final dstUnits = (state.bottles[pr.to].length - pr.count) + pr.count * pourP;
        final surface = dst.top + surfaceY(w, dstUnits);
        final streamX = dst.center.dx;
        final color = waterColor(pr.color);
        canvas.drawLine(
          Offset(streamX, lip.dy),
          Offset(streamX, surface),
          Paint()
            ..color = color
            ..strokeWidth = w * 0.13
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(lip.dx, lip.dy),
          Offset(streamX, lip.dy + w * 0.02),
          Paint()
            ..color = color
            ..strokeWidth = w * 0.13
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.save();
      canvas.translate(mouth.dx, mouth.dy);
      canvas.rotate(tilt);
      canvas.translate(-mouthLocal.dx, -mouthLocal.dy);
      paintBottle(canvas, w, merged);
      canvas.restore();
    }

    // 끌고 있는 병: 들었던 병이 기울어진 채 손가락을 따라온다
    if (dragInfo != null && dragInfo.from < n) {
      final (mouth, dragTilt) = _dragPose(layout, dragInfo);
      final mouthLocal = bottleMouth(w);
      // 부을 수 있는 병 위에서는 그림자처럼 받는 병 위에 걸쳐 보인다
      canvas.save();
      canvas.translate(mouth.dx, mouth.dy);
      canvas.rotate(dragTilt);
      canvas.translate(-mouthLocal.dx, -mouthLocal.dy);
      paintBottle(canvas, w, layersOf(state.bottles[dragInfo.from]));
      canvas.restore();
    }

    // 힌트: 받는 병 위에 아래 화살표
    if (hint != null && hint.to < n && !pouring) {
      final r = layout.rects[hint.to];
      final bob = sin(pulse.value * pi) * w * 0.10;
      final cx = r.center.dx;
      final y = r.top - w * 0.18 - bob - liftOf(hint.to);
      final arrow = Path()
        ..moveTo(cx - w * 0.16, y - w * 0.18)
        ..lineTo(cx + w * 0.16, y - w * 0.18)
        ..lineTo(cx, y + w * 0.06)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0xFF3DDC84));
      canvas.drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..color = Colors.white,
      );
    }

    // 완성: 반짝이
    if (c.completed && win.value < 1) {
      final rng = Random(7);
      final fade = (1 - win.value).clamp(0.0, 1.0);
      for (var k = 0; k < 34; k++) {
        final x = rng.nextDouble() * size.width;
        final y0 = size.height * (0.4 + 0.6 * rng.nextDouble());
        final speed = 0.25 + 0.5 * rng.nextDouble();
        final y = y0 - win.value * size.height * speed;
        final s = w * (0.07 + 0.10 * rng.nextDouble());
        _star(canvas, Offset(x, y), s, waterColor(rng.nextInt(12)).withValues(alpha: fade));
      }
    }
  }

  void _star(Canvas canvas, Offset c0, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rad = i.isEven ? r : r * 0.4;
      final a = i * pi / 4;
      final pt = Offset(c0.dx + cos(a) * rad, c0.dy + sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
