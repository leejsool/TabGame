part of 'pinball_painter.dart';

// 공·보호막·점수 팝업·배너·디버그 벽 그리기 (파일을 역할별로 나눈 것)

extension _PinballOverlayLayers on PinballPainter {
  void _balls(Canvas canvas) {
    final r = _e.ballR;
    final a = art;
    for (final b in _e.balls) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(
        c + const Offset(2, 4),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      if (a != null) {
        final img = a['ball1'];
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: c, width: r * 2.1, height: r * 2.1),
          _smooth,
        );
      } else {
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFC3CCDA));
      }
    }
  }

  /// 3·2·1 동안 판을 어둡게 덮고 공만 밝게, 둘레에 번쩍이는 고리를 그려서 공이 어디 있는지 알려 준다.
  /// 판이 서서히 움직이기 시작하면(2부터) 어두운 막도 같이 걷힌다.
  void _spotlightBalls(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(-600, -600, kTableW + 1200, kTableH + 1200),
      Paint()..color = Colors.black.withValues(alpha: 0.55 * (1 - run.countdownSpeed)),
    );
    final r = _e.ballR;
    final pulse = 0.5 + 0.5 * sin(run.clock * 9);
    for (final b in _e.balls) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(
        c,
        r * (2.6 + pulse * 0.8),
        Paint()
          ..color = const Color(0xFFFFD84D)
              .withValues(alpha: 0.18 + 0.12 * pulse),
      );
      canvas.drawCircle(
        c,
        r * (1.9 + pulse * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD84D),
      );
    }
    _balls(canvas);
    for (final b in _e.balls) {
      final tp = _text('공', 30, const Color(0xFFFFD84D));
      final y = b.y - r * 3.2 - tp.height - 6 * pulse;
      // 통로 안 공은 오른쪽 끝에 붙어 있어서 글자가 판 밖으로 나가지 않게 안쪽으로 당긴다.
      final x = min(b.x - tp.width / 2, kTableW - tp.width - 4);
      tp.paint(canvas, Offset(x, y));
    }
  }

  void _shield(Canvas canvas) {
    final n = _e.shields;
    if (n <= 0) return;
    final p = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final y = 1318.0 + i * 9;
      canvas.drawLine(Offset(70, y), Offset(546, y), p);
    }
  }

  void _popups(Canvas canvas) {
    for (final p in run.popups) {
      if (p.banner) continue;
      final t = p.age / 1.1;
      final tp = _text(
        p.text,
        p.text.length > 5 ? 40 : 28,
        p.color.withValues(alpha: 1 - t * t),
      );
      tp.paint(
        canvas,
        Offset(p.x - tp.width / 2, p.y - tp.height / 2 - 60 * t),
      );
    }
  }

  /// 잭팟·틸트 같은 큰 알림은 화면 가운데 (판이 움직여도 늘 같은 자리).
  void _banners(Canvas canvas, Size size) {
    var row = 0;
    for (final p in run.popups) {
      if (!p.banner) continue;
      final t = p.age / 1.1;
      final grow = 1 + 0.25 * (1 - min(1.0, p.age * 6));
      final tp = _text(p.text, 46 * grow, p.color.withValues(alpha: 1 - t * t));
      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          size.height * 0.36 + row * 54 - tp.height / 2,
        ),
      );
      row++;
    }
  }

  TextPainter _text(String text, double size, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 5)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _debugWalls(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xCC00E5FF)
      ..strokeWidth = 2;
    for (final w in _table.walls) {
      canvas.drawLine(
        Offset(w.ax, w.ay),
        Offset(w.bx, w.by),
        w.sling >= 0
            ? (Paint()
                ..color = const Color(0xFFFF4081)
                ..strokeWidth = 3)
            : p,
      );
    }
    for (final d in [..._table.bumpers, ..._table.posts, _table.saucer]) {
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFFEB3B)
          ..strokeWidth = 2,
      );
    }
    for (final t in _table.targets) {
      canvas.drawCircle(
        Offset(t.x, t.y),
        t.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF76FF03)
          ..strokeWidth = 2,
      );
    }
    for (final s in _table.sensors) {
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFF9100)
          ..strokeWidth = 2,
      );
    }
  }
}
