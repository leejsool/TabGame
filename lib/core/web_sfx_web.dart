import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

/// 웹 효과음: 오디오 엔진 하나를 모든 소리가 같이 쓰고, 소리 파일은 한 번만 풀어 둔다.
class WebSfx {
  static const bool supported = true;

  static web.AudioContext? _ctx;
  static final Map<String, Future<void>> _loading = {};
  static final Map<String, web.AudioBuffer> _ready = {};

  static web.AudioContext get _context => _ctx ??= web.AudioContext();

  /// [asset](assets/ 아래 경로, 예: `sfx/click.wav`)을 미리 풀어 둔다. 여러 번 불러도 한 번만 한다.
  static Future<void> load(String asset) => _loading.putIfAbsent(asset, () async {
        try {
          final data = await rootBundle.load('assets/$asset');
          // (decodeAudioData는 넘긴 버퍼를 가져가 버리니 복사본을 넘긴다)
          final bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
          final buffer = await _context.decodeAudioData(bytes.buffer.toJS).toDart;
          _ready[asset] = buffer;
        } catch (_) {
          // 소리가 안 나도 게임은 계속된다
        }
      });

  /// 한 번 튼다. 아직 안 풀어 뒀으면 지금은 조용히 풀기만 한다.
  static void play(String asset, {double volume = 1.0}) {
    final buffer = _ready[asset];
    if (buffer == null) {
      load(asset);
      return;
    }
    try {
      final ctx = _context;
      if (ctx.state == 'suspended') ctx.resume();
      final src = ctx.createBufferSource()..buffer = buffer;
      if (volume == 1.0) {
        src.connect(ctx.destination);
      } else {
        final gain = ctx.createGain()..gain.value = volume;
        src.connect(gain);
        gain.connect(ctx.destination);
      }
      src.start();
    } catch (_) {}
  }
}
