import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 리듬 검사단에서 쓰는 효과음 (tool/make_rhythm_sounds.dart 로 만든 assets/rhythm/*.wav).
enum Sfx {
  hitLeft('hit_left'),
  hitRight('hit_right'),
  npcLeft('npc_left'),
  npcRight('npc_right'),
  kick('kick'),
  hat('hat'),
  tick('tick'),
  tickHi('tick_hi'),
  chime('chime'),
  charge('charge'),
  miss('miss'),
  stageClear('stage_clear'),
  allClear('all_clear');

  const Sfx(this.file);
  final String file;
}

/// 소리를 내는 쪽. 테스트나 소리 끔 상태에서는 [SilentSfx]를 쓴다.
abstract class RhythmSfx {
  Future<void> load();
  void play(Sfx sfx);
  Future<void> dispose();
}

class SilentSfx implements RhythmSfx {
  const SilentSfx();
  @override
  Future<void> load() async {}
  @override
  void play(Sfx sfx) {}
  @override
  Future<void> dispose() async {}
}

/// 안드로이드 SoundPool(저지연) 방식으로 효과음을 낸다.
///
/// 효과음마다 플레이어를 몇 개씩 만들어 두고 돌아가며 쓴다. (같은 소리가 겹쳐도 끊기지 않고,
/// 재생할 때마다 새로 만들지 않아 오래 해도 오디오 자원이 새지 않는다.)
/// 소리가 안 나는 기기여도 게임은 계속 돌아가도록 모든 오류는 삼킨다.
class PoolSfx implements RhythmSfx {
  final Map<Sfx, List<AudioPlayer>> _voices = {};
  final Map<Sfx, int> _next = {};
  bool _ready = false;

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static int _voiceCount(Sfx s) => switch (s) {
        Sfx.hitLeft || Sfx.hitRight || Sfx.npcLeft || Sfx.npcRight => 3,
        Sfx.kick || Sfx.hat || Sfx.tick || Sfx.chime || Sfx.charge => 2,
        _ => 1,
      };

  @override
  Future<void> load() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
      await Future.wait([
        for (final s in Sfx.values)
          () async {
            final list = <AudioPlayer>[];
            for (var i = 0; i < _voiceCount(s); i++) {
              final p = AudioPlayer();
              await p.setPlayerMode(PlayerMode.lowLatency);
              await p.setReleaseMode(ReleaseMode.stop);
              await p.setAudioContext(_context);
              await p.setSource(AssetSource('rhythm/${s.file}.wav'));
              list.add(p);
            }
            _voices[s] = list;
          }(),
      ]);
      _ready = true;
    } catch (e) {
      debugPrint('리듬 효과음을 불러오지 못했어요: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_ready) return;
    final list = _voices[sfx];
    if (list == null || list.isEmpty) return;
    final i = (_next[sfx] ?? 0) % list.length;
    _next[sfx] = i + 1;
    unawaited(_start(list[i]));
  }

  Future<void> _start(AudioPlayer p) async {
    try {
      if (p.state == PlayerState.playing) await p.stop();
      await p.resume();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _ready = false;
    for (final list in _voices.values) {
      for (final p in list) {
        try {
          await p.dispose();
        } catch (_) {}
      }
    }
    _voices.clear();
  }
}
