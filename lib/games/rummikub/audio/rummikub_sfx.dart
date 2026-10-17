import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 루미큐브의 타일 소리 (패를 뽑거나, 놓거나, 옮길 때 나는 "딸깍"): assets/rummikub/tile.wav.
///
/// 빠르게 여러 장을 옮겨도 소리가 끊기지 않게 플레이어를 몇 개 만들어 두고 돌아가며 쓴다.
/// 소리가 안 나는 기기여도 게임은 계속 돌아가도록 모든 오류는 삼킨다. (리듬 검사단의 효과음과 같은 방식)
class RkTileSound {
  static const int _voiceCount = 3;
  static const String _asset = 'rummikub/tile.wav';

  final List<AudioPlayer> _voices = [];
  int _next = 0;
  bool _ready = false;
  bool _disposed = false;

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> load() async {
    try {
      for (var i = 0; i < _voiceCount; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setAudioContext(_context);
        await p.setSource(AssetSource(_asset));
        if (_disposed) {
          await p.dispose();
          return;
        }
        _voices.add(p);
      }
      _ready = true;
    } catch (e) {
      debugPrint('루미큐브 타일 소리를 불러오지 못했어요: $e');
    }
  }

  /// "딸깍" 한 번.
  void play() {
    if (!_ready || _voices.isEmpty) return;
    final p = _voices[_next++ % _voices.length];
    unawaited(_start(p));
  }

  Future<void> _start(AudioPlayer p) async {
    try {
      if (p.state == PlayerState.playing) await p.stop();
      await p.resume();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    for (final p in _voices) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _voices.clear();
  }
}
