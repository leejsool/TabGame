import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'settings_scope.dart';
import 'sfx_pool.dart';

/// 진동의 세기.
enum Haptic { select, light, medium, heavy, vibrate }

/// 알림 한 종류의 효과: 진동과 (있으면) 소리.
class Fx {
  const Fx({this.haptic, this.sound, this.volume = 1.0, this.minGap = Duration.zero});

  final Haptic? haptic;

  /// assets/ 아래 소리 파일 (예: `sfx/boom.wav`). 사용자가 고른 소리만 넣는다.
  final String? sound;
  final double volume;

  /// 이보다 촘촘하게는 소리를 내지 않는다 (잇달아 나면 난잡해지는 소리, 예: 도트 캐논의 레이저).
  final Duration minGap;
}

/// 게임 하나의 효과 표: 컨트롤러가 알리는 종류(kind) → 진동·소리.
///
/// 화면이 하나 만들어 들고 있다가 컨트롤러의 `onFeedback`에서 [play]를 부르고, 화면을 닫을 때 [dispose]한다.
/// 설정의 진동·효과음 스위치를 따르고, 소리는 미리 불러 두었다가 겹쳐도 끊기지 않게 튼다 ([SfxPool]).
/// 새 소리를 넣을 때는 그 게임의 표에 `sound:`만 더하면 된다.
class GameFx {
  GameFx(this.table) {
    for (final fx in table.values) {
      final s = fx.sound;
      if (s != null) _pools.putIfAbsent(s, () => SfxPool(s, volume: fx.volume)..load());
    }
  }

  final Map<String, Fx> table;
  final Map<String, SfxPool> _pools = {};
  final Map<String, DateTime> _lastSound = {};

  /// [kind] 알림의 진동·소리를 낸다. 표에 없는 종류는 아무것도 하지 않는다.
  void play(BuildContext context, String kind) {
    final fx = table[kind];
    if (fx == null) return;
    final settings = SettingsScope.of(context);
    final sound = fx.sound;
    if (sound != null && settings.sound) {
      final now = DateTime.now();
      final last = _lastSound[kind];
      if (last == null || now.difference(last) >= fx.minGap) {
        _lastSound[kind] = now;
        _pools[sound]!.play();
      }
    }
    if (settings.haptics) {
      switch (fx.haptic) {
        case Haptic.select:
          HapticFeedback.selectionClick();
        case Haptic.light:
          HapticFeedback.lightImpact();
        case Haptic.medium:
          HapticFeedback.mediumImpact();
        case Haptic.heavy:
          HapticFeedback.heavyImpact();
        case Haptic.vibrate:
          HapticFeedback.vibrate();
        case null:
          break;
      }
    }
  }

  void dispose() {
    for (final p in _pools.values) {
      p.dispose();
    }
  }
}
