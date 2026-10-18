part of 'getcolor_board.dart';

// 판 그림 (파일을 역할별로 나눈 것)

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
