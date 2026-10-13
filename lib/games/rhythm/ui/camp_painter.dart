import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'rhythm_art.dart';

/// 훈련소 장면의 배치.
class CampLayout {
  CampLayout(this.size)
      : landscape = size.width / size.height >= 1.15,
        feetY = size.height * (size.width / size.height >= 1.15 ? 0.925 : 0.86),
        unit = size.width / size.height >= 1.15 ? min(size.height * 0.42, size.width * 0.25) : min(size.height * 0.3, size.width * 0.34);

  final Size size;
  final bool landscape;

  /// 검사들이 서 있는 줄 (발 위치).
  final double feetY;

  /// 서 있는 검사의 화면 속 키(px).
  final double unit;

  /// 그림 한 픽셀이 화면에서 차지하는 크기 (서 있는 그림 높이 ≈ 430px 기준).
  double get charScale => unit / 430;

  /// 허수아비 그림 배율.
  double get dummyScale => unit * 0.66 / 327;

  /// 슬라임 그림 배율 (기본 자세 그림 가로 402px 기준 — 한 칸에 몸이 넉넉히 들어가도록).
  double get slimeScale => unit * 0.6 / 402;

  /// 허수아비 받침대 바닥 y.
  double get dummyBaseY => feetY - unit * 1.1;

  /// 허수아비 높이(px).
  double get dummyHeight => 327 * dummyScale;

  /// 네 명(과 허수아비·슬라임)의 가운데 x.
  double actorX(int i) => size.width * (landscape ? 0.14 + 0.24 * i : 0.13 + 0.245 * i);
}

/// 움직이지 않는 배경 그림 (성·천막·깃발·흙바닥). 화면을 꽉 채우도록 가운데 기준으로 자른다.
class BackgroundPainter extends CustomPainter {
  const BackgroundPainter(this.art, {this.name = 'bg'});

  final RhythmArt art;

  /// 배경 그림 이름 ('bg' = 훈련장, 'bg_forest' = 숲길).
  final String name;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE8C98E));
    final img = art.image(name);
    if (img == null) return;
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final s = max(size.width / iw, size.height / ih);
    final dw = iw * s, dh = ih * s;
    final dst = Rect.fromLTWH((size.width - dw) / 2, size.height - dh, dw, dh);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), dst, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(BackgroundPainter old) => old.art != art || old.name != name;
}

/// 그림 한 장을 발 위치 기준으로 그린다.
///
/// [foot]은 화면 속 발 위치, [scale]은 그림 한 픽셀의 화면 크기. [mirror]면 좌우 반전.
void drawSprite(
  Canvas canvas,
  RhythmArt art,
  String name,
  Offset foot,
  double scale, {
  bool mirror = false,
  double squashX = 1,
  double squashY = 1,
  double rotate = 0,
  Paint? paint,
}) {
  final img = art.image(name);
  final info = art.info(name);
  if (img == null || info == null) return;
  canvas.save();
  canvas.translate(foot.dx, foot.dy);
  if (rotate != 0) canvas.rotate(rotate);
  canvas.scale((mirror ? -1 : 1) * squashX * scale * info.scale, squashY * scale * info.scale);
  canvas.translate(-info.footX, -info.footY);
  canvas.drawImage(img, Offset.zero, paint ?? (Paint()..filterQuality = FilterQuality.high));
  canvas.restore();
}

/// 화면 위에 올려 쓰는 단순 이미지 위젯용: 그림 한 장을 위젯 크기에 맞춰 그린다.
class SpritePreviewPainter extends CustomPainter {
  SpritePreviewPainter(this.art, this.name);

  final RhythmArt art;
  final String name;

  @override
  void paint(Canvas canvas, Size size) {
    final img = art.image(name);
    if (img == null) return;
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final s = min(size.width / iw, size.height / ih);
    final dst = Rect.fromLTWH((size.width - iw * s) / 2, size.height - ih * s, iw * s, ih * s);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), dst, Paint()..filterQuality = ui.FilterQuality.high);
  }

  @override
  bool shouldRepaint(SpritePreviewPainter old) => old.art != art || old.name != name;
}

/// 메뉴에서 네 명을 같은 배율로 나란히 세운다. (그림마다 크기가 달라 따로 맞추면 키가 들쭉날쭉해진다)
class SquadPainter extends CustomPainter {
  SquadPainter(this.art);

  final RhythmArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.height * 0.97 / 480, size.width / (4 * 250));
    for (var i = 0; i < 4; i++) {
      drawSprite(canvas, art, RhythmArt.actorSprite(i, 'idle'), Offset(size.width * (0.125 + 0.25 * i), size.height * 0.97), scale);
    }
  }

  @override
  bool shouldRepaint(SquadPainter old) => old.art != art;
}
