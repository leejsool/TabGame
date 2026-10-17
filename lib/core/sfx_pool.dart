import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// 짧은 효과음 하나를 빠르게 여러 번 틀 수 있게 해 주는 재생기 (게임마다 자기 소리를 하나씩 쓴다).
///
/// 소리마다 플레이어를 몇 개 만들어 두고 돌아가며 쓴다. (같은 소리가 겹쳐도 끊기지 않고, 틀 때마다 새로 만들지 않아
/// 오래 해도 오디오 자원이 새지 않는다.) 소리가 안 나는 기기여도 게임은 계속 돌아가도록 모든 오류는 삼킨다.
/// 시험 환경(위젯 시험 바인딩)에서는 불러오지도 틀지도 않는다.
class SfxPool {
  SfxPool(this.asset, {this.voices = 3, this.volume = 1.0});

  /// assets/ 아래 파일 경로 (예: `goblet/clack.wav`). 앞부분 무음은 미리 잘라 둔 파일을 쓴다.
  final String asset;
  final int voices;
  final double volume;

  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _ready = false;
  bool _loading = false;
  bool _disposed = false;

  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// 소리를 미리 불러 둔다 (첫 소리가 늦지 않게). 여러 번 불러도 한 번만 한다.
  Future<void> load() async {
    if (_ready || _loading || _disposed || _inTest) return;
    _loading = true;
    try {
      for (var i = 0; i < voices; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setAudioContext(_context);
        await p.setSource(AssetSource(asset));
        if (volume != 1.0) await p.setVolume(volume);
        if (_disposed) {
          await p.dispose();
          return;
        }
        _players.add(p);
      }
      _ready = true;
    } catch (e) {
      debugPrint('효과음($asset)을 불러오지 못했어요: $e');
    } finally {
      _loading = false;
    }
  }

  /// 소리 한 번. 아직 못 불러왔으면 지금 불러 두기만 한다.
  void play() {
    if (_disposed || _inTest) return;
    if (!_ready) {
      unawaited(load());
      return;
    }
    final p = _players[_next++ % _players.length];
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
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
