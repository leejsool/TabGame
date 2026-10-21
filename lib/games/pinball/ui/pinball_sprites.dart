import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 핀볼 판 그림과 부품 그림 모음 (`assets/pinball/`). 한 번 불러 두고 모든 판이 같이 쓴다.
class PinballArt {
  PinballArt._(this._images);

  final Map<String, ui.Image> _images;

  static const List<String> _names = [
    'board',
    'bumper_red',
    'bumper_yellow',
    'bumper_green',
    'bumper_blue',
    'bumper_purple',
    'flipper_l',
    'flipper_r',
    'ball1',
    'pokeball_ring',
    'medal_pikachu',
    'star',
  ];

  static PinballArt? cached;
  static Future<PinballArt>? _loading;

  /// 그림을 불러온다 (이미 불러왔으면 바로 돌려준다).
  static Future<PinballArt> load() {
    final done = cached;
    if (done != null) return Future.value(done);
    return _loading ??= _read();
  }

  static Future<PinballArt> _read() async {
    final images = <String, ui.Image>{};
    for (final n in _names) {
      final data = await rootBundle.load('assets/pinball/$n.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      images[n] = (await codec.getNextFrame()).image;
    }
    return cached = PinballArt._(images);
  }

  ui.Image operator [](String name) => _images[name]!;
}
