import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 스프라이트 한 장의 정보 (tool/prepare_rhythm_art.py 가 만든 art.json).
class SpriteInfo {
  const SpriteInfo({required this.w, required this.h, required this.footX, required this.footY, required this.scale, this.tipX, this.tipY});

  final double w;
  final double h;

  /// 발 가운데 위치(그림 안 좌표).
  final double footX;
  final double footY;

  /// 다른 자세와 크기를 맞추는 배율.
  final double scale;

  /// 칼끝 위치(준비 자세에만 있음).
  final double? tipX;
  final double? tipY;
}

/// 리듬 검사단의 그림 모음 (배경, 허수아비, 검사 4명 × 기본/준비/타격).
class RhythmArt {
  RhythmArt._(this._images, this._info);

  /// 그림이 하나도 없는 상태 (테스트용). 그림 없이도 게임이 돌아간다.
  factory RhythmArt.empty() => RhythmArt._({}, {});

  final Map<String, ui.Image> _images;
  final Map<String, SpriteInfo> _info;

  bool get isEmpty => _images.isEmpty;

  ui.Image? image(String name) => _images[name];
  SpriteInfo? info(String name) => _info[name];

  /// 검사 [actor](0~3)의 자세 그림 이름. kind: idle / windup / strike.
  static String actorSprite(int actor, String kind) => 'c${actor}_$kind';

  static Future<RhythmArt>? _loading;

  /// 한 번만 불러와서 계속 쓴다.
  static Future<RhythmArt> load() => _loading ??= _load();

  static Future<RhythmArt> _load() async {
    final meta = jsonDecode(await rootBundle.loadString('assets/rhythm/art/art.json')) as Map<String, dynamic>;
    final names = <String>['bg', 'dummy'];
    for (var i = 0; i < 4; i++) {
      for (final k in ['idle', 'windup', 'strike']) {
        names.add(actorSprite(i, k));
      }
    }
    final images = <String, ui.Image>{};
    await Future.wait([
      for (final n in names)
        () async {
          final data = await rootBundle.load('assets/rhythm/art/$n.png');
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          images[n] = (await codec.getNextFrame()).image;
        }(),
    ]);
    final info = <String, SpriteInfo>{};
    meta.forEach((key, value) {
      final m = value as Map<String, dynamic>;
      final name = key.replaceAll('.png', '');
      info[name] = SpriteInfo(
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
        footX: ((m['footX'] ?? (m['w'] as num) / 2) as num).toDouble(),
        footY: ((m['footY'] ?? (m['h'] as num) * 0.97) as num).toDouble(),
        scale: ((m['scale'] ?? 1.0) as num).toDouble(),
        tipX: (m['tipX'] as num?)?.toDouble(),
        tipY: (m['tipY'] as num?)?.toDouble(),
      );
    });
    return RhythmArt._(images, info);
  }
}
