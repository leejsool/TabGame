import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 리듬 검사단에서 쓰는 효과음 (tool/make_rhythm_sounds.dart 로 만든 assets/rhythm/*.wav).
enum Sfx {
  // 좌우 공격음: 직접 고른 검 베기 소리 (왼쪽 = 퐉, 오른쪽 = 쉭). 앞사람(NPC)은 같은 소리를 작게.
  hitLeft('slash_left'),
  hitRight('slash_right'),
  npcLeft('slash_left', volume: 0.62),
  npcRight('slash_right', volume: 0.62),
  // 가로로 긋는(횡베기) 소리: 직접 고른 베기 소리. 앞사람(NPC)은 같은 소리를 작게.
  swipeLeft('slash_side'),
  swipeRight('slash_side'),
  npcSwipeLeft('slash_side', volume: 0.62),
  npcSwipeRight('slash_side', volume: 0.62),
  kick('kick'),
  hat('hat'),
  tick('tick'),
  tickHi('tick_hi'),
  chime('chime'),
  charge('charge'),
  miss('miss'),
  stageClear('stage_clear'),
  allClear('all_clear');

  const Sfx(this.file, {this.volume = 1.0});

  /// assets/rhythm/ 안의 wav 파일 이름 (확장자 빼고). 지연에 민감해서, 앞 무음을 미리 자른 wav를 쓴다.
  final String file;

  /// 틀 때 소리 크기 (0~1). 합성한 wav는 크기가 이미 반영돼 있어 1이다.
  final double volume;

  String get asset => 'rhythm/$file.wav';
}

/// 소리를 내는 쪽. 테스트나 소리 끔 상태에서는 [SilentSfx]를 쓴다.
abstract class RhythmSfx {
  Future<void> load();

  /// 곧 첫 소리가 날 테니 오디오 출력을 미리 깨워 둔다. (소리는 나지 않는다)
  ///
  /// 안드로이드는 한동안 소리가 없으면 출력 장치를 재우는데, 깨어나는 데 0.1초 안팎이 걸려서 맨 처음 소리만
  /// 늦게 들린다. 그러면 첫 음과 둘째 음 사이가 짧게 느껴진다. 게임을 시작하는 순간(첫 박자 0.9초 전)에 부른다.
  Future<void> warmUp();
  void play(Sfx sfx);
  Future<void> dispose();
}

class SilentSfx implements RhythmSfx {
  const SilentSfx();
  @override
  Future<void> load() async {}
  @override
  Future<void> warmUp() async {}
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
///
/// 앱 전체에서 [shared] 하나만 쓰고 화면이 바뀌어도 없애지 않는다. 안드로이드 SoundPool은 같은 소리 파일을 여러 플레이어가 나눠 쓰는데,
/// 이전 화면의 플레이어를 없애는 중에 새 화면이 같은 소리를 불러오면 "불러왔다"는 신호를 못 받아 영영 준비가 안 되고
/// (게임이 "준비 중…"에서 멈추고 소리도 안 난다) 앱을 다시 켜야 풀렸다. 한 번만 불러 두고 계속 쓰면 그런 겹침이 없다.
class PoolSfx implements RhythmSfx {
  PoolSfx._() : _isShared = true;

  /// 앱 전체에서 함께 쓰는 하나. 화면이 [dispose]해도 없어지지 않는다.
  static final PoolSfx shared = PoolSfx._();

  /// (시험용) 따로 쓰는 새 것. [dispose]하면 정말 없어진다.
  @visibleForTesting
  PoolSfx.separate() : _isShared = false;

  final bool _isShared;
  final Map<Sfx, List<AudioPlayer>> _voices = {};
  final Map<Sfx, int> _next = {};
  final List<AudioPlayer> _all = [];
  AudioPlayer? _warm;
  bool _ready = false;
  Future<void>? _loading;

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// 소리 하나를 불러오는 데 기다리는 시간 (기본 30초는 너무 길어서, 꼬였을 때 빨리 알아채고 다시 시도한다).
  static const _prepareTimeout = Duration(seconds: 6);

  /// 다 불러오지 못했을 때 처음부터 다시 시도하는 횟수.
  static const _attempts = 3;

  static int _voiceCount(Sfx s) => switch (s) {
        Sfx.hitLeft || Sfx.hitRight || Sfx.npcLeft || Sfx.npcRight => 3,
        Sfx.swipeLeft || Sfx.swipeRight || Sfx.npcSwipeLeft || Sfx.npcSwipeRight => 3,
        Sfx.kick || Sfx.hat || Sfx.tick || Sfx.chime || Sfx.charge => 2,
        _ => 1,
      };

  /// 소리를 불러온다. 이미 불러왔으면 바로 끝나고, 불러오는 중이면 그 끝을 같이 기다리고, 지난번에 실패했으면 다시 시도한다.
  @override
  Future<void> load() {
    if (_ready) return Future.value();
    return _loading ??= _loadWithRetry().whenComplete(() => _loading = null);
  }

  Future<void> _loadWithRetry() async {
    AudioPlayer.preparationTimeout = _prepareTimeout;
    for (var attempt = 0; attempt < _attempts && !_ready; attempt++) {
      if (attempt > 0) {
        await _teardown(); // 꼬인 플레이어를 모두 없애고 잠깐 쉰 뒤 처음부터
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      _ready = await _loadOnce();
    }
    if (!_ready) {
      await _teardown();
      debugPrint('리듬 효과음을 불러오지 못했어요');
    }
  }

  /// 모든 소리를 한 번 불러본다. 하나라도 못 불러오면 false.
  Future<bool> _loadOnce() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
    } catch (e) {
      debugPrint('리듬 효과음 설정 실패: $e');
      return false;
    }
    Future<bool> loadOne(Sfx s) async {
      try {
        final list = <AudioPlayer>[];
        for (var i = 0; i < _voiceCount(s); i++) {
          final p = AudioPlayer();
          _all.add(p);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setAudioContext(_context);
          await p.setSource(AssetSource(s.asset));
          if (s.volume != 1.0) await p.setVolume(s.volume);
          list.add(p);
        }
        _voices[s] = list;
        return true;
      } catch (e) {
        debugPrint('리듬 효과음 ${s.file} 불러오기 실패: $e');
        return false;
      }
    }

    final results = await Future.wait([for (final s in Sfx.values) loadOne(s)]);
    if (results.contains(false)) return false;
    try {
      // 출력 깨우기용: 소리 크기 0으로 짧은 틱을 틀기만 하는 전용 플레이어
      final warm = AudioPlayer();
      _all.add(warm);
      await warm.setPlayerMode(PlayerMode.lowLatency);
      await warm.setReleaseMode(ReleaseMode.stop);
      await warm.setAudioContext(_context);
      await warm.setSource(AssetSource(Sfx.tick.asset));
      await warm.setVolume(0);
      _warm = warm;
      return true;
    } catch (e) {
      debugPrint('리듬 효과음 깨우기 준비 실패: $e');
      return false;
    }
  }

  /// 만들어 둔 플레이어를 모두 없앤다.
  Future<void> _teardown() async {
    _ready = false;
    final all = [..._all];
    _all.clear();
    _voices.clear();
    _warm = null;
    for (final p in all) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> warmUp() async {
    final p = _warm;
    if (!_ready || p == null) return;
    await _start(p);
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

  /// 화면이 나갈 때 부른다. 함께 쓰는 [shared]는 없애지 않는다 (다음 화면이 그대로 쓴다).
  @override
  Future<void> dispose() async {
    if (_isShared) return;
    await _teardown();
  }
}
