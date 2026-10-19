import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// 짧은 효과음 플레이어를 "처음부터 다시" 틀어 주는 도우미 ([SfxPool]과 리듬 검사단의 `PoolSfx`가 같이 쓴다).
///
/// 저지연(SoundPool) 플레이어는 한 번 튼 뒤에 `stop`을 거쳐야 다시 소리가 난다. 그런데 `stop`·`resume`은 각각 안드로이드와 주고받는
/// 비동기 호출이라, 같은 플레이어에 소리가 잇달아 오면 앞 호출이 끝나기 전에 다음 호출이 끼어들어 "이미 재생 중"으로 보고 소리를 삼켰다.
/// 그래서 플레이어마다 호출을 한 줄로 세워(앞 일이 끝나야 다음 일) 순서를 지키고, 줄이 너무 길어지면(너무 촘촘한 소리) 더 쌓지 않고 버린다
/// (한참 뒤에야 나는 소리보다 그냥 빠지는 편이 낫다).
class SfxRestarter {
  /// 한 플레이어에 기다리게 둘 수 있는 일의 수 (지금 하는 일 포함).
  static const _maxPending = 2;

  final Map<AudioPlayer, int> _pending = {};
  final Map<AudioPlayer, Future<void>> _tail = {};

  /// 지금 하는 일이 없는 플레이어인가.
  bool isIdle(AudioPlayer p) => (_pending[p] ?? 0) == 0;

  /// [voices] 중에서 쉬고 있는 것을 [from]부터 돌아가며 찾아 그 위치를 돌려준다. 다 바쁘면 [from] 그대로.
  int pick(List<AudioPlayer> voices, int from) {
    for (var off = 0; off < voices.length; off++) {
      final i = (from + off) % voices.length;
      if (isIdle(voices[i])) return i;
    }
    return from % voices.length;
  }

  /// [p]를 처음부터 다시 튼다. 줄이 가득 차서 버리면 false.
  bool restart(AudioPlayer p) {
    final n = _pending[p] ?? 0;
    if (n >= _maxPending) return false;
    _pending[p] = n + 1;
    final next = (_tail[p] ?? Future<void>.value())
        .then((_) async {
          try {
            await p.stop();
            await p.resume();
          } catch (_) {}
        })
        .whenComplete(() {
          final k = (_pending[p] ?? 1) - 1;
          if (k <= 0) {
            _pending.remove(p);
            _tail.remove(p);
          } else {
            _pending[p] = k;
          }
        });
    _tail[p] = next;
    return true;
  }

  /// 플레이어를 없애기 전에 부른다.
  void forget(AudioPlayer p) {
    _pending.remove(p);
    _tail.remove(p);
  }
}
