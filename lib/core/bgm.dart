import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'settings_scope.dart';

/// 사용자가 고른 배경음악 곡 (원본은 F:/MyApp/bgm). 쓰는 게임: 바둑돌 옮기기, 지뢰찾기.
const String kBgmMed = 'bgm/med.m4a';

/// 게임 배경음악 재생기 (앱에 하나). 한 곡씩 반복해서 튼다.
///
/// 게임 화면은 [GameBgm]으로 감싸 두기만 하면 된다. 들어오면 곡이 시작되고 나가면 멈춘다.
/// 같은 곡이 겹쳐 요청되면(메뉴 위에 게임 화면이 쌓일 때) 다시 시작하지 않고 이어서 튼다.
/// 설정의 "배경음악"이 꺼져 있거나 앱이 뒤로 가면 멈춘다. 소리가 안 나는 기기여도 게임은 계속 돌아가도록 오류는 삼킨다.
/// 시험 환경(위젯 시험 바인딩)에서는 실제로 틀지 않고 [playing]만 바뀐다.
class Bgm {
  Bgm._();

  static final Bgm instance = Bgm._();

  /// 배경음악 소리 크기 (효과음보다 한참 작게).
  static const double volume = 0.35;

  final List<String> _stack = [];
  bool _enabled = true;
  bool _paused = false;
  AudioPlayer? _player;

  /// 지금 틀고 있는 곡 (assets/ 아래 경로). 없으면 null.
  String? playing;

  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// 곡 [asset]을 쓰는 게임 화면이 들어왔다 (가장 나중에 들어온 곡이 흐른다).
  void enter(String asset) {
    _stack.add(asset);
    _sync();
  }

  /// 곡 [asset]을 쓰던 게임 화면이 나갔다.
  void leave(String asset) {
    _stack.remove(asset);
    _sync();
  }

  /// 설정의 배경음악 스위치.
  void setEnabled(bool v) {
    if (_enabled == v) return;
    _enabled = v;
    _sync();
  }

  /// 앱이 뒤로 갔다가 돌아올 때.
  void setPaused(bool v) {
    if (_paused == v) return;
    _paused = v;
    _sync();
  }

  void _sync() {
    final target = _enabled && !_paused && _stack.isNotEmpty ? _stack.last : null;
    if (target == playing) return;
    playing = target;
    if (_inTest) return;
    _apply(target);
  }

  Future<void> _apply(String? target) async {
    try {
      final p = _player ??= AudioPlayer();
      if (target == null) {
        await p.stop();
        return;
      }
      await p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none, // 다른 앱 소리를 끊거나 줄이지 않는다
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.music,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume);
      // (기다리는 사이 다른 곡이나 멈춤으로 바뀌었으면 틀지 않는다)
      if (playing != target) return;
      await p.play(AssetSource(target));
    } catch (_) {}
  }
}

/// 이 화면(과 그 위에 쌓이는 화면들)이 열려 있는 동안 [asset] 곡을 배경음악으로 튼다.
///
/// 설정의 배경음악 스위치를 따르고, 앱이 뒤로 가면 멈췄다가 돌아오면 이어서 튼다.
class GameBgm extends StatefulWidget {
  const GameBgm({super.key, required this.asset, required this.child});

  /// assets/ 아래 곡 경로 (예: `bgm/med.m4a`).
  final String asset;
  final Widget child;

  @override
  State<GameBgm> createState() => _GameBgmState();
}

class _GameBgmState extends State<GameBgm> with WidgetsBindingObserver {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Bgm.instance.setEnabled(SettingsScope.of(context).bgm); // (스위치를 바꾸면 여기로 다시 온다)
    // 스위치를 읽은 다음에 들어와야, 꺼 둔 사람에게 소리가 잠깐 새지 않는다
    if (!_entered) {
      _entered = true;
      Bgm.instance.enter(widget.asset);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Bgm.instance.setPaused(state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_entered) Bgm.instance.leave(widget.asset);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
