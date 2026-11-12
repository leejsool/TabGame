import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/sfx_pool.dart';

/// 주사위 굴리는 소리.
///
/// 굴리는 주사위 개수만큼 "주사위 한 개" 소리 9가지 중 서로 다른 것을 뽑아, 주사위가 던져지는 순간에 맞춰 조금씩 어긋나게 겹쳐 튼다
/// (한 개면 한 소리, 다섯 개면 다섯 소리). 예전에는 4개 이상이면 따로 녹음한 "여러 개" 소리를 썼는데, 소리의 느낌이 달라서
/// 몇 개를 굴리든 같은 한 개 소리들을 섞는다. 주사위가 많을수록 손에서 떨어지는 시간이 조금 더 퍼진다.
///
/// 소리는 미리 불러 두고, 겹쳐도 끊기지 않게 소리마다 따로 재생기를 쓴다 ([SfxPool]). 시험 환경에서는 소리가 나지 않는다.
class YachtDiceSound {
  YachtDiceSound({Random? rng}) : _rng = rng ?? Random() {
    if (kIsWeb) {
      // 웹에서는 소리를 한꺼번에 준비하면 화면이 열리는 동안 몇 초씩 끊긴다: 화면이 뜬 뒤 하나씩 천천히 준비한다
      unawaited(_loadSlowly());
    } else {
      for (final p in _singles) {
        p.load();
      }
    }
  }

  Future<void> _loadSlowly() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    for (final p in _singles) {
      if (_disposed) return;
      await p.load();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  /// 한 개 소리의 가짓수 (assets/sfx/dice_one_1.wav ~ dice_one_9.wav).
  static const int singleVariants = 9;

  /// 한 개 소리들을 겹쳐 틀 때 소리마다 조금씩 어긋나게 하는 최대 간격(밀리초, 3개 이하). 완전히 같은 순간에 시작하면 한 덩어리로 들린다.
  static const int maxStaggerMs = 70;

  /// 4개 이상일 때의 최대 간격 (한 손에 많이 쥐면 떨어지는 시간이 더 퍼진다).
  static const int maxStaggerManyMs = 110;

  final Random _rng;
  final List<SfxPool> _singles = [
    // (웹은 재생기 하나씩: 한 번 굴릴 때 같은 소리를 두 번 쓰지 않으니 충분하다)
    for (var i = 1; i <= singleVariants; i++) SfxPool('sfx/dice_one_$i.wav', voices: kIsWeb ? 1 : 2),
  ];
  final List<Timer> _timers = [];
  bool _disposed = false;

  /// 한 개 소리 [count]개를 서로 다르게 뽑는다 (0~[singleVariants]-1 번호).
  List<int> pickSingles(int count) {
    if (count <= 0) return const [];
    final all = [for (var i = 0; i < singleVariants; i++) i]..shuffle(_rng);
    return all.sublist(0, min(count, singleVariants));
  }

  /// [count]개의 주사위가 던져지기 시작하는 순간들(밀리초): 첫 주사위는 바로(0), 나머지는 15ms~최대 간격만큼 늦게.
  /// 소리와 주사위 움직임이 같은 값을 쓰도록 굴리기 시작할 때 한 번 정해서 [play]와 주사위 줄에 함께 넘긴다.
  List<int> launchDelays(int count) {
    final most = count >= 4 ? maxStaggerManyMs : maxStaggerMs;
    return [for (var k = 0; k < count; k++) k == 0 ? 0 : 15 + _rng.nextInt(most - 15)];
  }

  /// [count]개의 주사위를 굴릴 때의 소리를 낸다. [delays]는 [launchDelays]에서 받은 값 (없으면 새로 정한다).
  void play(int count, {List<int>? delays}) {
    if (_disposed || count <= 0) return;
    final picks = pickSingles(count);
    final starts = delays ?? launchDelays(count);
    for (var k = 0; k < picks.length; k++) {
      final pool = _singles[picks[k]];
      final at = k < starts.length ? starts[k] : 0;
      if (at == 0) {
        pool.play();
      } else {
        // 다른 주사위 소리는 그 주사위가 던져지는 순간에 맞춰 조금 늦게 (손이 완전히 같을 수 없으니)
        late final Timer t;
        t = Timer(Duration(milliseconds: at), () {
          _timers.remove(t);
          if (!_disposed) pool.play();
        });
        _timers.add(t);
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final p in _singles) {
      p.dispose();
    }
  }
}
