import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/jigsaw_geometry.dart';

/// 퍼즐 그림의 출처. 이어하기 때 같은 그림을 다시 불러오는 데 쓴다.
class JigsawSource {
  const JigsawSource(this.kind, this.ref);

  /// 'sample' = 내장 샘플(ref = 샘플 id), 'file' = 갤러리에서 고른 사진(ref = 앱 안에 복사해 둔 파일 경로),
  /// 'none' = 다시 불러올 수 없음(이어하기 불가).
  final String kind;
  final String ref;

  Map<String, dynamic> toJson() => {'kind': kind, 'ref': ref};

  factory JigsawSource.fromJson(Map<String, dynamic> j) =>
      JigsawSource(j['kind'] as String, j['ref'] as String);

  static const none = JigsawSource('none', '');
}

class SampleInfo {
  const SampleInfo(this.id, this.name, this.width, this.height);

  final String id;
  final String name;
  final int width;
  final int height;
}

/// 직접 그린 샘플 그림들 (사진이 없어도 바로 퍼즐을 해볼 수 있게).
class SampleArt {
  SampleArt._();

  static const List<SampleInfo> all = [
    SampleInfo('sunset', '바다의 노을', 1200, 800),
    SampleInfo('garden', '꽃밭의 오후', 900, 1200),
    SampleInfo('space', '별이 쏟아지는 밤', 1000, 1000),
  ];

  static SampleInfo info(String id) => all.firstWhere((s) => s.id == id);

  /// 샘플 그림을 [scale]배 크기의 이미지로 그린다.
  static Future<ui.Image> render(String id, {double scale = 1}) async {
    final s = info(id);
    final w = s.width * scale, h = s.height * scale;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.scale(scale);
    final size = ui.Size(s.width.toDouble(), s.height.toDouble());
    switch (id) {
      case 'sunset':
        _sunset(canvas, size);
      case 'garden':
        _garden(canvas, size);
      default:
        _space(canvas, size);
    }
    return rec.endRecording().toImage(w.round(), h.round());
  }

  static ui.Paint _fill(ui.Color c) => ui.Paint()..color = c;

  static ui.Paint _grad(ui.Offset a, ui.Offset b, List<ui.Color> colors, [List<double>? stops]) =>
      ui.Paint()..shader = ui.Gradient.linear(a, b, colors, stops);

  static ui.Paint _radial(ui.Offset c, double r, List<ui.Color> colors, [List<double>? stops]) =>
      ui.Paint()..shader = ui.Gradient.radial(c, r, colors, stops);

  // ── 바다의 노을 ──
  static void _sunset(ui.Canvas c, ui.Size s) {
    final w = s.width, h = s.height;
    final rng = Random(11);
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h * 0.66),
      _grad(const ui.Offset(0, 0), ui.Offset(0, h * 0.66), const [
        ui.Color(0xFF2B1B5A),
        ui.Color(0xFF8E3B8F),
        ui.Color(0xFFFF7E5F),
        ui.Color(0xFFFFD27A),
      ], const [0, 0.35, 0.72, 1]),
    );
    for (var i = 0; i < 70; i++) {
      c.drawCircle(
        ui.Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.3),
        0.6 + rng.nextDouble() * 1.6,
        _fill(const ui.Color(0xFFFFFFFF).withValues(alpha: 0.3 + rng.nextDouble() * 0.5)),
      );
    }
    final sun = ui.Offset(w * 0.5, h * 0.6);
    c.drawCircle(
      sun,
      h * 0.42,
      _radial(sun, h * 0.42,
          [const ui.Color(0xAAFFE9A8), const ui.Color(0x00FFE9A8)]),
    );
    c.drawCircle(sun, h * 0.115, _fill(const ui.Color(0xFFFFF3C4)));
    // 구름
    for (final cl in [(0.18, 0.2, 1.0), (0.72, 0.3, 1.3), (0.4, 0.38, 0.8), (0.9, 0.14, 0.7)]) {
      final cx = w * cl.$1, cy = h * cl.$2, k = cl.$3;
      final p = _fill(const ui.Color(0xFFFFC4A8).withValues(alpha: 0.75));
      for (final o in [(-60.0, 8.0, 50.0), (0.0, 0.0, 66.0), (64.0, 10.0, 46.0), (20.0, 14.0, 52.0)]) {
        c.drawOval(
          ui.Rect.fromCenter(
            center: ui.Offset(cx + o.$1 * k, cy + o.$2 * k),
            width: o.$3 * 2.4 * k,
            height: o.$3 * 0.9 * k,
          ),
          p,
        );
      }
    }
    // 바다
    c.drawRect(
      ui.Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      _grad(ui.Offset(0, h * 0.62), ui.Offset(0, h), const [
        ui.Color(0xFFFF9A6B),
        ui.Color(0xFFB04A86),
        ui.Color(0xFF2B1B5A),
      ], const [0, 0.45, 1]),
    );
    for (var i = 0; i < 16; i++) {
      final y = h * 0.64 + i * h * 0.021;
      final ww = (w * 0.22) * (1 - i / 18) + 20;
      c.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
              center: ui.Offset(w * 0.5 + sin(i * 1.7) * 14, y), width: ww, height: 5 + i * 0.5),
          const ui.Radius.circular(8),
        ),
        _fill(const ui.Color(0xFFFFF3C4).withValues(alpha: 0.55 - i * 0.025)),
      );
    }
    // 멀리 있는 섬과 가까운 섬
    final island = ui.Path()
      ..moveTo(w * 0.04, h * 0.64)
      ..quadraticBezierTo(w * 0.16, h * 0.5, w * 0.3, h * 0.64)
      ..close();
    c.drawPath(island, _fill(const ui.Color(0xFF4A2A6E)));
    final shore = ui.Path()
      ..moveTo(w * 0.62, h)
      ..quadraticBezierTo(w * 0.8, h * 0.72, w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    c.drawPath(shore, _fill(const ui.Color(0xFF1E123F)));
    // 야자수
    final trunk = ui.Paint()
      ..color = const ui.Color(0xFF140C2E)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = ui.StrokeCap.round;
    final base = ui.Offset(w * 0.86, h * 0.8);
    c.drawPath(
      ui.Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx - 28, base.dy - 90, base.dx - 6, base.dy - 170),
      trunk,
    );
    final top = ui.Offset(base.dx - 6, base.dy - 170);
    for (final a in [-2.6, -2.1, -1.5, -0.9, -0.4]) {
      c.drawPath(
        ui.Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(top.dx + cos(a) * 60, top.dy + sin(a) * 60 - 20,
              top.dx + cos(a) * 110, top.dy + sin(a) * 110 + 30),
        trunk..strokeWidth = 7,
      );
    }
    // 새
    final bird = ui.Paint()
      ..color = const ui.Color(0xFF3A1F5C)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = ui.StrokeCap.round;
    for (final b in [(0.3, 0.26), (0.36, 0.22), (0.25, 0.3)]) {
      final p = ui.Offset(w * b.$1, h * b.$2);
      c.drawPath(
        ui.Path()
          ..moveTo(p.dx - 16, p.dy)
          ..quadraticBezierTo(p.dx - 8, p.dy - 12, p.dx, p.dy)
          ..quadraticBezierTo(p.dx + 8, p.dy - 12, p.dx + 16, p.dy),
        bird,
      );
    }
  }

  // ── 꽃밭의 오후 ──
  static void _garden(ui.Canvas c, ui.Size s) {
    final w = s.width, h = s.height;
    final rng = Random(5);
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h * 0.7),
      _grad(const ui.Offset(0, 0), ui.Offset(0, h * 0.7),
          const [ui.Color(0xFF7EC8F2), ui.Color(0xFFD8F1FF), ui.Color(0xFFFFF4D6)],
          const [0, 0.6, 1]),
    );
    final sun = ui.Offset(w * 0.8, h * 0.13);
    c.drawCircle(sun, 170, _radial(sun, 170, [const ui.Color(0x88FFF3B0), const ui.Color(0x00FFF3B0)]));
    c.drawCircle(sun, 58, _fill(const ui.Color(0xFFFFE26B)));
    for (final cl in [(0.2, 0.1, 1.0), (0.55, 0.22, 0.8), (0.1, 0.3, 0.7)]) {
      final cx = w * cl.$1, cy = h * cl.$2, k = cl.$3;
      final p = _fill(const ui.Color(0xFFFFFFFF).withValues(alpha: 0.92));
      for (final o in [(-50.0, 6.0, 42.0), (0.0, 0.0, 56.0), (54.0, 8.0, 40.0)]) {
        c.drawOval(
          ui.Rect.fromCenter(
              center: ui.Offset(cx + o.$1 * k, cy + o.$2 * k), width: o.$3 * 2.3 * k, height: o.$3 * 1.1 * k),
          p,
        );
      }
    }
    void hill(double y, double amp, ui.Color col, double phase) {
      final p = ui.Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 20) {
        p.lineTo(x, y + sin(x / w * pi * 2 + phase) * amp);
      }
      p
        ..lineTo(w, h)
        ..close();
      c.drawPath(p, _fill(col));
    }

    hill(h * 0.58, 50, const ui.Color(0xFFB9E8A6), 0.4);
    hill(h * 0.66, 45, const ui.Color(0xFF8ED88A), 2.2);
    hill(h * 0.76, 40, const ui.Color(0xFF5FC070), 4.1);
    // 꽃들 (멀리 있는 것부터)
    const petals = [
      ui.Color(0xFFFF8FB1), ui.Color(0xFFFFD166), ui.Color(0xFFFFFFFF),
      ui.Color(0xFFC59BFF), ui.Color(0xFFFF9F6B), ui.Color(0xFF8FD3FF),
    ];
    final flowers = [
      for (var i = 0; i < 44; i++) (rng.nextDouble(), 0.7 + rng.nextDouble() * 0.28, i % petals.length),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final f in flowers) {
      final x = w * f.$1, y = h * f.$2;
      final k = 0.5 + (f.$2 - 0.7) * 3.2;
      c.drawLine(
        ui.Offset(x, y),
        ui.Offset(x + sin(x) * 6, y + 90 * k),
        ui.Paint()
          ..color = const ui.Color(0xFF2E8B4A)
          ..strokeWidth = 6 * k
          ..strokeCap = ui.StrokeCap.round,
      );
      final pc = petals[f.$3];
      for (var p = 0; p < 6; p++) {
        final a = p * pi / 3;
        c.drawCircle(ui.Offset(x + cos(a) * 20 * k, y + sin(a) * 20 * k), 17 * k, _fill(pc));
      }
      c.drawCircle(ui.Offset(x, y), 13 * k, _fill(const ui.Color(0xFFFFB02E)));
    }
    // 나비
    for (final b in [(0.3, 0.45), (0.68, 0.5), (0.5, 0.36)]) {
      final p = ui.Offset(w * b.$1, h * b.$2);
      for (final sx in [-1.0, 1.0]) {
        c.drawOval(ui.Rect.fromCenter(center: p + ui.Offset(sx * 18, -8), width: 34, height: 44),
            _fill(const ui.Color(0xFFFF8FB1).withValues(alpha: 0.9)));
        c.drawOval(ui.Rect.fromCenter(center: p + ui.Offset(sx * 14, 14), width: 24, height: 28),
            _fill(const ui.Color(0xFFFFD166).withValues(alpha: 0.9)));
      }
      c.drawRRect(
        ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(center: p, width: 7, height: 34), const ui.Radius.circular(4)),
        _fill(const ui.Color(0xFF4A3A5C)),
      );
    }
  }

  // ── 별이 쏟아지는 밤 ──
  static void _space(ui.Canvas c, ui.Size s) {
    final w = s.width, h = s.height;
    final rng = Random(23);
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      _radial(ui.Offset(w * 0.5, h * 0.45), w * 0.85,
          const [ui.Color(0xFF2A1A6B), ui.Color(0xFF0E0A30), ui.Color(0xFF04020F)], const [0, 0.55, 1]),
    );
    for (final n in [
      (0.2, 0.25, 0.5, ui.Color(0xFFFF4FA3)),
      (0.8, 0.3, 0.45, ui.Color(0xFF3AD1FF)),
      (0.35, 0.8, 0.5, ui.Color(0xFF8E5BFF)),
      (0.85, 0.85, 0.35, ui.Color(0xFFFF8A4F)),
    ]) {
      final o = ui.Offset(w * n.$1, h * n.$2);
      c.drawCircle(o, w * n.$3, _radial(o, w * n.$3, [n.$4.withValues(alpha: 0.35), n.$4.withValues(alpha: 0)]));
    }
    for (var i = 0; i < 320; i++) {
      final r = 0.5 + pow(rng.nextDouble(), 3) * 3.2;
      final p = ui.Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      c.drawCircle(p, r * 2.6, _fill(const ui.Color(0xFFFFFFFF).withValues(alpha: 0.06)));
      c.drawCircle(p, r, _fill(const ui.Color(0xFFFFFFFF).withValues(alpha: 0.5 + rng.nextDouble() * 0.5)));
    }
    // 고리 있는 행성
    final pc = ui.Offset(w * 0.62, h * 0.58);
    final r = w * 0.19;
    ui.Path ring(double rx, double ry) =>
        ui.Path()..addOval(ui.Rect.fromCenter(center: pc, width: rx * 2, height: ry * 2));
    c.save();
    c.translate(pc.dx, pc.dy);
    c.rotate(-0.35);
    c.translate(-pc.dx, -pc.dy);
    final ringPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = const ui.Color(0xFFFFD9A0).withValues(alpha: 0.75);
    // 고리 뒤쪽
    c.save();
    c.clipRect(ui.Rect.fromLTWH(0, 0, w, pc.dy));
    c.drawPath(ring(r * 1.75, r * 0.5), ringPaint);
    c.restore();
    c.drawCircle(
      pc,
      r,
      _grad(pc + ui.Offset(-r, -r), pc + ui.Offset(r, r),
          const [ui.Color(0xFFFFB86B), ui.Color(0xFFFF6B9D), ui.Color(0xFF6B3FA0)],
          const [0, 0.55, 1]),
    );
    for (var i = 0; i < 4; i++) {
      c.drawArc(
        ui.Rect.fromCenter(center: pc, width: r * 2 * (0.5 + i * 0.12), height: r * 2),
        0.3,
        2.5,
        false,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.12),
      );
    }
    // 고리 앞쪽
    c.save();
    c.clipRect(ui.Rect.fromLTWH(0, pc.dy, w, h));
    c.drawPath(ring(r * 1.75, r * 0.5), ringPaint);
    c.restore();
    c.restore();
    // 달
    final moon = ui.Offset(w * 0.2, h * 0.7);
    c.drawCircle(moon, w * 0.07, _grad(moon + const ui.Offset(-40, -40), moon + const ui.Offset(40, 40),
        const [ui.Color(0xFFF1F1FF), ui.Color(0xFF9A9AC8)]));
    for (final cr in [(-12.0, -8.0, 11.0), (14.0, 12.0, 9.0), (6.0, -20.0, 6.0)]) {
      c.drawCircle(moon + ui.Offset(cr.$1, cr.$2), cr.$3, _fill(const ui.Color(0x33000030)));
    }
    // 별똥별
    for (final m in [(0.12, 0.1), (0.55, 0.12)]) {
      final p = ui.Offset(w * m.$1, h * m.$2);
      c.drawLine(
        p,
        p + const ui.Offset(120, 60),
        ui.Paint()
          ..shader = ui.Gradient.linear(p, p + const ui.Offset(120, 60),
              const [ui.Color(0xFFFFFFFF), ui.Color(0x00FFFFFF)])
          ..strokeWidth = 4
          ..strokeCap = ui.StrokeCap.round,
      );
    }
  }
}

/// 사진 파일 바이트를 그림으로 읽는다. 긴 변이 [maxSide]보다 길면 줄여서 읽는다 (메모리 절약).
Future<ui.Image> decodeImageBytes(Uint8List bytes, {int maxSide = 1600}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final desc = await ui.ImageDescriptor.encoded(buffer);
    try {
      final longSide = max(desc.width, desc.height);
      final k = min(1.0, maxSide / longSide);
      final codec = await desc.instantiateCodec(
        targetWidth: max(1, (desc.width * k).round()),
        targetHeight: max(1, (desc.height * k).round()),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } finally {
      desc.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// 조각마다 그림을 조각 모양으로 오려낸 이미지.
class PieceImages {
  PieceImages._(this.images);

  final List<ui.Image> images;

  static Future<PieceImages> build(
    ui.Image source,
    JigsawGeometry g, {
    void Function(double progress)? onProgress,
  }) async {
    final imageRect = ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble());
    final out = <ui.Image>[];
    for (var i = 0; i < g.count; i++) {
      final box = g.boxes[i];
      final w = max(1, box.width.ceil()), h = max(1, box.height.ceil());
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      final path = g.paths[i];

      canvas.save();
      canvas.clipPath(path, doAntiAlias: true);
      final src = box.intersect(imageRect);
      final dst = ui.Rect.fromLTWH(src.left - box.left, src.top - box.top, src.width, src.height);
      canvas.drawImageRect(source, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
      // 안쪽에 은은한 입체감 (가장자리가 살짝 밝게)
      canvas.drawPath(
        path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const ui.Color(0x26FFFFFF),
      );
      canvas.restore();
      // 바깥 윤곽선
      canvas.drawPath(
        path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..isAntiAlias = true
          ..color = const ui.Color(0x80000000),
      );

      out.add(await rec.endRecording().toImage(w, h));
      if (i % 6 == 5) {
        onProgress?.call((i + 1) / g.count);
        await Future<void>.delayed(Duration.zero); // 화면이 멈추지 않게 숨 돌리기
      }
    }
    onProgress?.call(1);
    return PieceImages._(out);
  }

  void dispose() {
    for (final i in images) {
      i.dispose();
    }
  }
}
