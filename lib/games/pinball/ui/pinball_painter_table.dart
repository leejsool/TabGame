part of 'pinball_painter.dart';

// 바닥판 위의 부품 그리기: 범퍼·표적·플리퍼·플런저 (파일을 역할별로 나눈 것)

extension _PinballTableLayers on PinballPainter {
  void _bumpers(Canvas canvas) {
    final a = art;
    for (var i = 0; i < _table.bumpers.length; i++) {
      final d = _table.bumpers[i];
      final g = run.glow['b$i'] ?? 0;
      final o = Offset(d.x, d.y);
      if (g > 0)
        canvas.drawCircle(
          o,
          d.r + 14 + 12 * g,
          Paint()..color = Color.fromRGBO(255, 235, 130, 0.5 * g),
        );
      if (a != null && i < _domes.length) {
        final size = (d.r * 2 + 10) * (1 + 0.12 * g);
        canvas.drawImageRect(
          a[_domes[i]],
          Rect.fromLTWH(
            0,
            0,
            a[_domes[i]].width.toDouble(),
            a[_domes[i]].height.toDouble(),
          ),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a != null && i == 5) {
        final size = (d.r * 2 + 10) * (1 + 0.12 * g);
        canvas.drawImageRect(
          a['bumper_purple'],
          Rect.fromLTWH(
            0,
            0,
            a['bumper_purple'].width.toDouble(),
            a['bumper_purple'].height.toDouble(),
          ),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a != null && (i == 6 || i == 7)) {
        final img = a[i == 6 ? 'pokeball' : 'pokeball_ring'];
        final size = d.r * 2.1 * (1 + 0.12 * g);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: o, width: size, height: size),
          _smooth,
        );
      } else if (a == null) {
        canvas.drawCircle(
          o,
          d.r,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFE5484D),
              const Color(0xFFFFF176),
              g,
            )!,
        );
      } else if (g > 0) {
        // 그림에 그려진 큰 공은 맞으면 하얗게 반짝인다
        canvas.drawCircle(
          o,
          d.r,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.45 * g),
        );
      }
    }
  }

  void _targets(Canvas canvas) {
    final a = art;
    for (var i = 0; i < _table.targets.length; i++) {
      final t = _table.targets[i];
      final down = _e.targetDown[i];
      final o = Offset(t.x, t.y);
      if (t.bank == 0) {
        if (a != null) {
          const targetAssets = [
            'target_red',
            'target_yellow',
            'target_blue',
            'target_green',
          ];
          const targetAngles = [-0.32, 0.32, -0.32, 0.32];
          final img = a[targetAssets[i % targetAssets.length]];
          final scale = down ? 0.58 : 1.0;
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(targetAngles[i % targetAngles.length]);
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(
              center: Offset.zero,
              width: 36 * scale,
              height: 72 * scale,
            ),
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Color.fromRGBO(255, 255, 255, down ? 0.5 : 1),
          );
          canvas.restore();
        }
        if (down) {
          canvas.drawCircle(
            o,
            t.r + 12,
            Paint()..color = const Color(0x55FFEB3B),
          );
          canvas.drawCircle(
            o,
            t.r - 2,
            Paint()..color = const Color(0xCCFFEE58),
          );
        }
        continue;
      }
      if (a == null) {
        canvas.drawCircle(
          o,
          down ? t.r * 0.45 : t.r,
          Paint()
            ..color = down ? const Color(0xFF55607A) : const Color(0xFFFFC107),
        );
        continue;
      }
      final img = a[t.bank == 1 ? 'pokeball_ring' : 'medal_pikachu'];
      final size = down ? t.r * 1.0 : t.r * 2.4;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, down ? 0.4 : 1),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: o, width: size, height: size),
        _smooth,
      );
      canvas.restore();
    }
    for (final d in _table.posts) {
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r,
        Paint()..color = const Color(0xFFB0BEC5),
      );
      canvas.drawCircle(
        Offset(d.x - d.r * 0.25, d.y - d.r * 0.25),
        d.r * 0.32,
        Paint()..color = const Color(0xFFDCE4EA),
      );
    }
  }

  void _flippers(Canvas canvas) {
    final a = art;
    for (final f in _e.flippers) {
      final left = f.spec.left;
      final (tx, ty) = _e.flipperTip(f);
      if (a == null) {
        canvas.drawLine(
          Offset(f.spec.px, f.spec.py),
          Offset(tx, ty),
          Paint()
            ..color = const Color(0xFFFFB400)
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final img = a[left ? 'flipper_l' : 'flipper_r'];
      final m = left ? _flipL : _flipR;
      final spriteLen = (m.tip - m.pivot).distance;
      final spriteAngle = atan2(m.tip.dy - m.pivot.dy, m.tip.dx - m.pivot.dx);
      // 긴 플리퍼는 길이 방향으로만 늘린다 (두께는 그대로).
      final k = f.spec.length / spriteLen;
      canvas.save();
      canvas.translate(f.spec.px, f.spec.py);
      canvas.rotate(f.angle);
      canvas.scale(k * _e.flipperLenMul, k);
      canvas.rotate(-spriteAngle);
      canvas.drawImage(img, -m.pivot, _smooth);
      canvas.restore();
    }
  }

  void _plunger(Canvas canvas) {
    final pull = charge * 52;
    final spring = Paint()
      ..color = const Color(0xFF9AA7C4)
      ..strokeWidth = 3;
    for (var y = kLaneFloorY + 4 + pull; y < kTableH - 6; y += 8) {
      canvas.drawLine(
        Offset(kLaneX - 11, y),
        Offset(kLaneX + 11, y + 4),
        spring,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(kLaneX, kLaneFloorY + 3 + pull),
          width: 24,
          height: 9,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF7043),
    );
  }
}
