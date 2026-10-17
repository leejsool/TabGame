import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wi‑Fi 방을 열어 두었거나 다른 기기와 이어져 있는 동안 화면이 저절로 꺼지지 않게 한다.
///
/// 늦게 오는 사람을 기다리거나 상대 차례를 지켜보는 동안에는 화면을 안 만져서 기기 화면이 꺼지기 쉬운데,
/// 화면이 꺼지면 안드로이드가 앱의 네트워크를 늦추거나 끊어서 방이 깨진다. 그래서 방과 연결이 살아 있는 동안만 화면을 켜 둔다.
/// 여러 곳에서 동시에 요청해도 괜찮게, 요청한 수를 세어서 하나도 안 남았을 때만 푼다.
/// (안드로이드가 아닌 곳이나 시험에서는 아무 일도 하지 않는다)
class KeepAwake {
  KeepAwake._();

  static const MethodChannel _channel = MethodChannel('tabgame/awake');

  static int _holders = 0;

  /// 지금 화면을 켜 두라고 요청한 곳의 수 (시험에서 확인용).
  @visibleForTesting
  static int get holders => _holders;

  /// 화면을 켜 둔다. 반드시 같은 수만큼 [release]를 불러야 한다.
  static void acquire() {
    if (_holders++ == 0) _set(true);
  }

  /// [acquire]한 것을 푼다. 더 요청한 곳이 없으면 화면이 다시 저절로 꺼질 수 있다.
  static void release() {
    if (_holders == 0) return;
    if (--_holders == 0) _set(false);
  }

  static Future<void> _set(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', {'on': on});
    } catch (_) {
      // 안드로이드가 아니거나(시험·웹) 기기가 못 하면 그냥 넘어간다
    }
  }
}
