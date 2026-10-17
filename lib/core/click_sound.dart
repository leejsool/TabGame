import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 버튼을 누를 때 나는 "딸깍" 소리 (assets/sfx/click.wav).
///
/// 앱 테마의 물결(splash) 효과를 이 소리가 나는 것으로 바꿔 두면, 머티리얼 버튼·아이콘 버튼·목록 항목 등
/// 눌러서 쓰는 거의 모든 단추가 따로 손대지 않아도 한 번 눌릴 때마다 소리를 낸다. (누르고 끌어서 취소한 건 소리가 나지 않는다)
/// 설정의 "효과음"을 끄면 나지 않는다.
class ClickSound {
  ClickSound._();

  /// 설정의 "효과음" 값 (앱이 설정이 바뀔 때마다 알려 준다).
  static bool soundOn = true;

  /// 소리를 내는가 (시험에서는 끈다). 시험 환경(위젯 시험 바인딩)에서는 따로 끄지 않아도 나지 않는다.
  static bool enabled = true;

  static const int _voiceCount = 3;
  static const String _asset = 'sfx/click.wav';

  static final List<AudioPlayer> _voices = [];
  static int _next = 0;
  static bool _ready = false;
  static bool _loading = false;

  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  /// 소리를 미리 불러 둔다 (첫 클릭이 늦지 않게). 여러 번 불러도 한 번만 한다.
  static Future<void> load() async {
    if (_ready || _loading || !enabled || _inTest) return;
    _loading = true;
    try {
      for (var i = 0; i < _voiceCount; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setAudioContext(_context);
        await p.setSource(AssetSource(_asset));
        _voices.add(p);
      }
      _ready = true;
    } catch (e) {
      debugPrint('클릭 소리를 불러오지 못했어요: $e');
    } finally {
      _loading = false;
    }
  }

  /// "딸깍" 한 번.
  static void play() {
    if (!soundOn || !enabled || _inTest) return;
    if (!_ready) {
      unawaited(load());
      return;
    }
    final p = _voices[_next++ % _voices.length];
    unawaited(_start(p));
  }

  static Future<void> _start(AudioPlayer p) async {
    try {
      if (p.state == PlayerState.playing) await p.stop();
      await p.resume();
    } catch (_) {}
  }
}

/// 눌러서 확정될 때([InkRipple.confirm]) 딸깍 소리를 내는 물결 효과. 모양은 보통 물결 효과([InkRipple])와 같다.
class ClickSplashFactory extends InteractiveInkFeatureFactory {
  const ClickSplashFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _ClickRipple(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
      textDirection: textDirection,
    );
  }
}

class _ClickRipple extends InkRipple {
  _ClickRipple({
    required super.controller,
    required super.referenceBox,
    required super.position,
    required super.color,
    required super.textDirection,
    super.containedInkWell,
    super.rectCallback,
    super.borderRadius,
    super.customBorder,
    super.radius,
    super.onRemoved,
  });

  @override
  void confirm() {
    ClickSound.play();
    super.confirm();
  }
}
