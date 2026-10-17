import 'dart:math';

import 'package:flutter/material.dart';

import '../core/dot_rules.dart';
import '../game/dot_controller.dart';

/// 색을 어둡게(음수)/밝게(양수) 바꾼다.
Color shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

const Color _wood = Color(0xFF8C5A34);
const Color _woodLight = Color(0xFFB57C4A);
const Color _woodDark = Color(0xFF5C3A21);
const Color _belt = Color(0xFF3A4152);
const Color _beltSlat = Color(0xFF59627A);
const Color _paper = Color(0xFFF7F1E3);

/// 대포 하나를 그린다. [angle]은 포신이 향하는 방향(라디안, 0 = 오른쪽), [d]는 지름.
void paintCannon(
  Canvas canvas,
  Offset c,
  double d,
  Color color,
  double angle, {
  String? label,
  double alpha = 1,
  bool glow = false,
  bool dim = false,
}) {
  if (alpha <= 0) return;
  if (alpha < 1) canvas.saveLayer(Rect.fromCircle(center: c, radius: d), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  if (glow) {
    canvas.drawCircle(c, d * 0.62, Paint()..color = color.withValues(alpha: 0.35));
  }
  // 그림자
  canvas.drawCircle(c + Offset(0, d * 0.07), d * 0.44, Paint()..color = Colors.black.withValues(alpha: 0.28));
  // 포신
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  final barrel = RRect.fromRectAndRadius(Rect.fromLTWH(0, -d * 0.19, d * 0.66, d * 0.38), Radius.circular(d * 0.09));
  canvas.drawRRect(barrel, Paint()..color = const Color(0xFF2E323D));
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(d * 0.5, -d * 0.23, d * 0.17, d * 0.46), Radius.circular(d * 0.07)),
    Paint()..color = shade(color, -0.12),
  );
  canvas.restore();
  // 몸통
  final body = dim ? shade(color, -0.12) : color;
  canvas.drawCircle(
    c,
    d * 0.4,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        colors: [shade(body, 0.16), body, shade(body, -0.1)],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: d * 0.4)),
  );
  canvas.drawCircle(
    c,
    d * 0.4,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.06
      ..color = shade(color, -0.3),
  );
  if (label != null) {
    final big = label.length >= 2;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'NanumGothic',
          fontSize: d * (big ? 0.34 : 0.4),
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
  if (alpha < 1) canvas.restore();
}

/// 판(액자 + 벨트 + 그림 + 대포 + 탄)의 자리 계산.
class DotGeometry {
  DotGeometry(this.game, Size size) {
    final w = game.width, h = game.height;
    // 도트가 아주 작아도 벨트 위 대포와 숫자는 알아볼 수 있게, 벨트 띠는 [minBand]보다 얇아지지 않는다
    var cell = min(size.width / (w + 3), size.height / (h + 3));
    var bandWidth = cell;
    if (cell < minBand) {
      bandWidth = minBand;
      cell = max(2.0, min((size.width - 3 * bandWidth) / w, (size.height - 3 * bandWidth) / h));
    }
    u = cell;
    band = bandWidth;
    left = (size.width - (u * w + 3 * band)) / 2;
    top = (size.height - (u * h + 3 * band)) / 2;
  }

  /// 벨트 띠의 굵기가 이보다 작아지지 않게 한다.
  static const double minBand = 20;

  final DotGame game;

  /// 도트 한 칸의 크기.
  late final double u;

  /// 벨트 띠의 굵기 (도트 칸이 크면 도트 칸과 같다).
  late final double band;
  late final double left;
  late final double top;

  /// 액자 전체의 크기.
  double get frameWidth => u * game.width + 3 * band;
  double get frameHeight => u * game.height + 3 * band;

  /// 그림(도트가 놓이는 곳)의 왼쪽 위.
  Offset get picOrigin => Offset(left + 1.5 * band, top + 1.5 * band);

  double _axis(num v, int n, double start) {
    if (v < 0) return start - band / 2;
    if (v >= n) return start + n * u + band / 2;
    return start + (v + 0.5) * u;
  }

  /// 그림 칸 (x, y)의 가운데. 벨트 칸(-1..width, -1..height)에도 쓴다 (벨트 칸은 띠 한가운데).
  Offset center(num x, num y) => Offset(_axis(x, game.width, picOrigin.dx), _axis(y, game.height, picOrigin.dy));

  Offset ringCenter(int i) {
    final (x, y) = game.ringCell(i % game.ringLength);
    return center(x, y);
  }

  /// 벨트 위 연속 위치 (정수 + 소수).
  Offset ringPoint(double t) {
    final len = game.ringLength;
    final i = t.floor();
    final f = t - i;
    return Offset.lerp(ringCenter(i % len), ringCenter((i + 1) % len), f)!;
  }

  /// 벨트 자리 [pos]에서 대포가 향하는 방향 (라디안).
  double angleAt(int pos) {
    final len = game.ringLength;
    final f = game.facing(pos % len) ?? game.facing((pos + 1) % len) ?? game.facing((pos + len - 1) % len) ?? (0, 1);
    return atan2(f.$2.toDouble(), f.$1.toDouble());
  }
}

/// 도트 캐논 판 그림. [controller.frame]이 바뀔 때마다 다시 그린다.
class DotBoardPainter extends CustomPainter {
  DotBoardPainter(this.c, this.palette) : super(repaint: c.frame);

  final DotController c;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final g = c.game;
    final geo = DotGeometry(g, size);
    final u = geo.u;
    final w = g.width, h = g.height;

    // 액자
    final band = geo.band;
    final outer = Rect.fromLTWH(geo.left, geo.top, geo.frameWidth, geo.frameHeight);
    final outerR = RRect.fromRectAndRadius(outer, Radius.circular(band * 0.4));
    canvas.drawRRect(outerR.shift(Offset(0, band * 0.12)), Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawRRect(
      outerR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_woodLight, _wood, _woodDark],
        ).createShader(outer),
    );
    canvas.drawRRect(
      outerR.deflate(band * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * 0.05
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // 벨트 바탕
    final ring = Rect.fromLTWH(geo.left + 0.5 * band, geo.top + 0.5 * band, u * w + 2 * band, u * h + 2 * band);
    canvas.drawRRect(RRect.fromRectAndRadius(ring, Radius.circular(band * 0.3)), Paint()..color = _belt);

    // 움직이는 발판 (벨트가 도는 것처럼 보이게)
    final f = c.stepFraction;
    final slat = Paint()
      ..color = _beltSlat
      ..style = PaintingStyle.stroke
      ..strokeWidth = band * 0.07
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < g.ringLength; i++) {
      final p = geo.ringPoint(i + f + 0.5);
      final ahead = geo.ringPoint(i + f + 0.55);
      final dir = ahead - p;
      if (dir.distance == 0) continue;
      final nrm = Offset(-dir.dy, dir.dx) / dir.distance;
      canvas.drawLine(p - nrm * band * 0.34, p + nrm * band * 0.34, slat);
    }

    // 그림 바탕 (종이)
    final pic = Rect.fromLTWH(geo.picOrigin.dx, geo.picOrigin.dy, u * w, u * h);
    canvas.drawRRect(RRect.fromRectAndRadius(pic.inflate(u * 0.12), Radius.circular(u * 0.18)), Paint()..color = const Color(0xFF2A2F3C));
    canvas.drawRRect(RRect.fromRectAndRadius(pic.inflate(u * 0.06), Radius.circular(u * 0.12)), Paint()..color = _paper);

    // 연한 격자 점 (칸이 아주 작으면 생략한다)
    if (u >= 9) {
      final dot = Paint()..color = const Color(0xFFE3D8C2);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          canvas.drawCircle(geo.center(x, y), u * 0.06, dot);
        }
      }
    }

    // 도트
    final pad = u * 0.07;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final col = g.grid[y * w + x];
        if (col == kDotEmpty) continue;
        _pixel(canvas, geo.center(x, y), u - pad * 2, palette[col]);
      }
    }

    // 맞은 도트: 탄이 닿을 때까지 남아 있다가 터진다
    for (final e in c.fx) {
      final age = c.clock - e.at;
      final col = palette[e.shot.color];
      final center = geo.center(e.shot.tx, e.shot.ty);
      if (age < DotController.flightSeconds) {
        _pixel(canvas, center, u - pad * 2, col);
      } else {
        final t = ((age - DotController.flightSeconds) / DotController.popSeconds).clamp(0.0, 1.0);
        if (t < 1) _burst(canvas, center, u, col, t);
      }
    }

    // 탄
    for (final e in c.fx) {
      final age = c.clock - e.at;
      if (age < 0 || age >= DotController.flightSeconds) continue;
      final t = age / DotController.flightSeconds;
      final from = geo.ringCenter(e.shot.from);
      final to = geo.center(e.shot.tx, e.shot.ty);
      final p = Offset.lerp(from, to, Curves.easeIn.transform(t))!;
      final tail = Offset.lerp(from, to, Curves.easeIn.transform((t - 0.25).clamp(0.0, 1.0)))!;
      final col = palette[e.shot.color];
      canvas.drawLine(
        tail,
        p,
        Paint()
          ..color = col.withValues(alpha: 0.55)
          ..strokeWidth = u * 0.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(p, u * 0.17, Paint()..color = Colors.white);
      canvas.drawCircle(p, u * 0.12, Paint()..color = col);
    }

    // 입구 표시 (왼쪽 아래 모서리에서 대포가 벨트에 오른다)
    final entry = geo.ringCenter(g.entryPos);
    final arrow = Path()
      ..moveTo(entry.dx, entry.dy - band * 0.34)
      ..lineTo(entry.dx - band * 0.26, entry.dy + band * 0.1)
      ..lineTo(entry.dx + band * 0.26, entry.dy + band * 0.1)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white.withValues(alpha: 0.35));

    // 다 쓴 대포는 그 자리에서 사라진다
    for (final (cn, at) in c.spent) {
      final a = 1 - ((c.clock - at) / 0.35).clamp(0.0, 1.0);
      final pos = geo.ringCenter(cn.pos);
      paintCannon(canvas, pos, band * 0.96, palette[cn.color], geo.angleAt(cn.pos), label: '0', alpha: a * 0.8);
    }

    // 벨트 위 대포
    for (final cn in g.belt) {
      final p = geo.ringPoint(cn.pos + f);
      paintCannon(canvas, p, band * 0.98, palette[cn.color], geo.angleAt(cn.pos), label: '${cn.ammo}');
    }
  }

  void _pixel(Canvas canvas, Offset center, double s, Color color) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: s, height: s), Radius.circular(s * 0.2));
    canvas.drawRRect(r, Paint()..color = color);
    if (s < 7) return; // (칸이 아주 작으면 윤곽과 반사광은 생략한다)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + s * 0.1, r.top + s * 0.1, s * 0.8, s * 0.22),
        Radius.circular(s * 0.12),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..color = shade(color, -0.16),
    );
  }

  void _burst(Canvas canvas, Offset center, double u, Color color, double t) {
    final ease = Curves.easeOut.transform(t);
    final a = 1 - t;
    // 커지며 사라지는 도트
    final s = (u * 0.86) * (1 + 0.35 * ease);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: s, height: s), Radius.circular(s * 0.2)),
      Paint()..color = color.withValues(alpha: a * 0.7),
    );
    // 사방으로 튀는 조각
    for (var i = 0; i < 6; i++) {
      final ang = i * pi / 3 + 0.4;
      final p = center + Offset(cos(ang), sin(ang)) * (u * 0.9 * ease);
      canvas.drawCircle(p, u * 0.1 * (1 - t) + 1, Paint()..color = color.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(DotBoardPainter old) => old.c != c || old.palette != palette;
}

/// 작은 도트 그림 (단계 고르는 화면·기록·안내에 쓴다). [fog]가 true면 색을 지운 그림자 모양.
class DotArtPainter extends CustomPainter {
  DotArtPainter(this.pixels, this.width, this.height, this.palette, {this.fog = false});

  final List<int> pixels;
  final int width;
  final int height;
  final List<Color> palette;
  final bool fog;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / width, size.height / height);
    final ox = (size.width - s * width) / 2, oy = (size.height - s * height) / 2;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = pixels[y * width + x];
        if (c == kDotEmpty) continue;
        final rect = Rect.fromLTWH(ox + x * s, oy + y * s, s, s).deflate(s * 0.04);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s * 0.18)),
          Paint()..color = fog ? const Color(0x33808080) : palette[c],
        );
      }
    }
  }

  @override
  bool shouldRepaint(DotArtPainter old) =>
      old.pixels != pixels || old.fog != fog || old.palette != palette || old.width != width;
}

/// 대기열의 대포 한 대를 그리는 작은 위젯.
class CannonTile extends StatelessWidget {
  const CannonTile({super.key, required this.color, required this.ammo, this.size = 52, this.glow = false, this.dim = false});

  final Color color;
  final int ammo;
  final double size;
  final bool glow;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CannonTilePainter(color, ammo, glow, dim)),
    );
  }
}

class _CannonTilePainter extends CustomPainter {
  _CannonTilePainter(this.color, this.ammo, this.glow, this.dim);

  final Color color;
  final int ammo;
  final bool glow;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    paintCannon(canvas, size.center(Offset.zero) + Offset(0, size.height * 0.1), size.width * 0.9, color, -pi / 2,
        label: '$ammo', glow: glow, dim: dim);
  }

  @override
  bool shouldRepaint(_CannonTilePainter old) =>
      old.color != color || old.ammo != ammo || old.glow != glow || old.dim != dim;
}
