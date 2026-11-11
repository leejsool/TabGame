import 'dart:async';
import 'dart:math';

import '../../../core/sfx_pool.dart';

/// 주사위 굴리는 소리.
///
/// - 4개 이상을 한꺼번에 굴리면 "여러 개 던지는 소리" 하나를 튼다.
/// - 3개 이하를 굴리면 "주사위 한 개" 소리 9가지 중 서로 다른 것을 개수만큼 뽑아 거의 동시에 튼다
///   (한 개면 한 소리, 세 개면 세 소리가 겹쳐서 난다).
///
/// 소리는 미리 불러 두고, 겹쳐도 끊기지 않게 소리마다 따로 재생기를 쓴다 ([SfxPool]). 시험 환경에서는 소리가 나지 않는다.
class YachtDiceSound {
  YachtDiceSound({Random? rng}) : _rng = rng ?? Random() {
    for (final p in [..._singles, _multi]) {
      p.load();
    }
  }

  /// 한 개 소리의 가짓수 (assets/sfx/dice_one_1.wav ~ dice_one_9.wav).
  static const int singleVariants = 9;

  /// 이 개수 이상을 굴리면 "여러 개" 소리를 쓴다.
  static const int multiFrom = 4;

  /// 한 개 소리들을 겹쳐 틀 때 소리마다 조금씩 어긋나게 하는 최대 간격(밀리초). 완전히 같은 순간에 시작하면 한 덩어리로 들린다.
  static const int maxStaggerMs = 70;

  final Random _rng;
  final List<SfxPool> _singles = [
    for (var i = 1; i <= singleVariants; i++) SfxPool('sfx/dice_one_$i.wav', voices: 2),
  ];
  final SfxPool _multi = SfxPool('sfx/dice_multi.wav', voices: 2);
  final List<Timer> _timers = [];
  bool _disposed = false;

  /// 한 개 소리 [count]개를 서로 다르게 뽑는다 (0~[singleVariants]-1 번호). [count]가 [multiFrom] 이상이면 비어 있다.
  List<int> pickSingles(int count) {
    if (count <= 0 || count >= multiFrom) return const [];
    final all = [for (var i = 0; i < singleVariants; i++) i]..shuffle(_rng);
    return all.sublist(0, count);
  }

  /// [count]개의 주사위가 던져지기 시작하는 순간들(밀리초): 첫 주사위는 바로(0), 나머지는 15~[maxStaggerMs]ms씩 늦게.
  /// 소리와 주사위 움직임이 같은 값을 쓰도록 굴리기 시작할 때 한 번 정해서 [play]와 주사위 줄에 함께 넘긴다.
  List<int> launchDelays(int count) => [
        for (var k = 0; k < count; k++) k == 0 ? 0 : 15 + _rng.nextInt(maxStaggerMs - 15),
      ];

  /// [count]개의 주사위를 굴릴 때의 소리를 낸다. [delays]는 [launchDelays]에서 받은 값 (없으면 새로 정한다).
  void play(int count, {List<int>? delays}) {
    if (_disposed || count <= 0) return;
    if (count >= multiFrom) {
      _multi.play();
      return;
    }
    final picks = pickSingles(count);
    final starts = delays ?? launchDelays(count);
    for (var k = 0; k < picks.length; k++) {
      final pool = _singles[picks[k]];
      if (starts[k] == 0) {
        pool.play();
      } else {
        // 두 번째 · 세 번째 소리는 주사위가 던져지는 순간에 맞춰 조금 늦게 (손이 완전히 같을 수 없으니)
        final delay = Duration(milliseconds: starts[k]);
        late final Timer t;
        t = Timer(delay, () {
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
    for (final p in [..._singles, _multi]) {
      p.dispose();
    }
  }
}
