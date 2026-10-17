import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'settings_scope.dart';

/// 이겼을 때(또는 퍼즐을 풀었을 때) 모든 게임이 같이 쓰는 "짜잔" 소리 (assets/sfx/win.mp3).
///
/// 설정의 "효과음"이 꺼져 있으면 나지 않는다. 소리가 안 나는 기기여도 게임은 계속 돌아가도록 오류는 삼킨다.
class WinSound {
  WinSound._();

  /// 소리를 내는가 (시험에서는 끈다). 시험 환경(위젯 시험 바인딩)에서는 따로 끄지 않아도 나지 않는다.
  static bool enabled = true;

  static AudioPlayer? _player;
  static DateTime? _last;

  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// 이겼을 때 한 번 부른다. 같은 순간에 여러 번 불려도 한 번만 난다.
  static Future<void> play(BuildContext context) async {
    if (!enabled || _inTest || !SettingsScope.of(context).sound) return;
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) return;
    _last = now;
    try {
      final p = _player ??= AudioPlayer();
      await p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
      await p.setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource('sfx/win.mp3'));
    } catch (_) {}
  }
}
