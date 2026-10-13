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

/// 리듬 검사단의 그림 모음 (배경, 허수아비, 슬라임 4자세, 검사 4명 × 기본/준비/타격/옆 준비/옆 휘두르기).
class RhythmArt {
  RhythmArt._(this._images, this._info);

  /// 그림이 하나도 없는 상태 (테스트용). 그림 없이도 게임이 돌아간다.
  factory RhythmArt.empty() => RhythmArt._({}, {});

  final Map<String, ui.Image> _images;
  final Map<String, SpriteInfo> _info;

  bool get isEmpty => _images.isEmpty;

  ui.Image? image(String name) => _images[name];
  SpriteInfo? info(String name) => _info[name];

  /// 검사 [actor](0~3)의 자세 그림 이름. kind: idle / windup / strike / side_ready / side_swing.
  static String actorSprite(int actor, String kind) => 'c${actor}_$kind';

  /// 슬라임의 자세 그림 이름. kind: idle(기본) / ready(공격 준비) / attack(공격) / hit(피격).
  static String slimeSprite(String kind) => 'slime_$kind';

  static Future<RhythmArt>? _loading;

  /// 한 번만 불러와서 계속 쓴다.
  static Future<RhythmArt> load() => _loading ??= _load();

  static Future<RhythmArt> _load() async {
    final meta = jsonDecode(await rootBundle.loadString('assets/rhythm/art/art.json')) as Map<String, dynamic>;
    // 옆으로 휘두르는 자세 (tool/prepare_rhythm_side_art.py)
    meta.addAll(jsonDecode(await rootBundle.loadString('assets/rhythm/art/art_side.json')) as Map<String, dynamic>);
    final slimeMeta = jsonDecode(await rootBundle.loadString('assets/rhythm/art/art_slime.json')) as Map<String, dynamic>;
    final names = <String>['bg', 'dummy', for (final k in ['idle', 'ready', 'attack', 'hit']) slimeSprite(k)];
    for (var i = 0; i < 4; i++) {
      for (final k in ['idle', 'windup', 'strike', 'side_ready', 'side_swing']) {
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
    // 슬라임은 바닥에 닿는 점(baseX/baseY)을 발 위치로 쓴다 (tool/prepare_rhythm_slime_art.py)
    slimeMeta.forEach((key, value) {
      final m = value as Map<String, dynamic>;
      info[key.replaceAll('.png', '')] = SpriteInfo(
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
        footX: (m['baseX'] as num).toDouble(),
        footY: (m['baseY'] as num).toDouble(),
        scale: 1.0,
      );
    });
    return RhythmArt._(images, info);
  }
}
