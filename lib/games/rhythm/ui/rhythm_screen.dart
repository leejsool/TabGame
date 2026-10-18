import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/settings_scope.dart';
import '../../../core/win_sound.dart';
import '../audio/rhythm_audio.dart';
import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';
import '../data/rhythm_storage.dart';
import '../game/rhythm_controller.dart';
import 'camp_painter.dart';
import 'rhythm_art.dart';
import 'stage_painter.dart';

part 'rhythm_screen_panels.dart';
part 'rhythm_screen_cards.dart';

const _gold = Color(0xFFFFD21F);
const _ink = Color(0xFF1A1523);

/// 훈련소 튜토리얼 플레이 화면.
class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key, this.controller, this.autoStart = false, this.art, this.course = 0});

  /// 몇 번째 코스인지 (RhythmCourse.all의 번호).
  final int course;

  /// (테스트용) 미리 만든 그림. 없으면 에셋에서 불러온다.
  final RhythmArt? art;

  /// (테스트용) 미리 만든 컨트롤러.
  final RhythmController? controller;

  /// (테스트용) 시작 안내 없이 바로 시작.
  final bool autoStart;

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// 시작을 누른 뒤 첫 박자까지의 여유 시간(초).
  static const _lead = 0.9;

  RhythmController? _c;
  RhythmController get c => _c!;
  RhythmCourse get _course => RhythmCourse.all[widget.course];
  late final Ticker _ticker;
  final Stopwatch _song = Stopwatch();
  final Stopwatch _wallClock = Stopwatch()..start();
  bool _paused = false;
  bool _audioReady = false;
  RhythmArt? _art;
  bool _isBest = false;
  RhythmSfx? _sfx;

  /// 꾹 누르기를 시작한 손가락.
  int? _holdPointer;

  /// 옆으로 긋기를 하는 손가락과 시작 위치 (기다리는 동안만 값이 있다).
  int? _swipePointer;
  Offset _swipeFrom = Offset.zero;

  double _songTime() => _song.elapsedMicroseconds / 1e6 - _lead;
  double _wall() => _wallClock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final soundOn = SettingsScope.of(context).sound;
    final sfx = widget.controller?.sfx ?? (soundOn ? PoolSfx() : const SilentSfx());
    _sfx = sfx;
    _c = widget.controller ?? RhythmController(chart: RhythmChart.course(widget.course), sfx: sfx);
    c.onJudged = _onJudged;
    c.onFinished = _onFinished;
    _art = widget.art;
    if (_art == null) {
      RhythmArt.load().then((a) {
        if (mounted) setState(() => _art = a);
      });
    }
    if (widget.autoStart) _begin();
    if (widget.controller == null) {
      _loadAudioAndOffset(sfx);
    } else {
      _audioReady = true;
    }
  }

  Future<void> _loadAudioAndOffset(RhythmSfx sfx) async {
    try {
      final ms = await RhythmStorage.loadOffsetMs();
      if (!mounted) return;
      c.inputOffset = ms / 1000.0;
      await sfx.load();
    } finally {
      if (mounted) setState(() => _audioReady = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    final ctrl = _c;
    if (ctrl != null) {
      ctrl.onJudged = null;
      ctrl.onFinished = null;
      ctrl.dispose();
    }
    _sfx?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _onTick(Duration _) {
    if (_c == null || !mounted) return;
    if (c.status == RhythmStatus.playing && !_paused) {
      c.update(_songTime());
    } else {
      c.ping();
    }
  }

  void _begin() {
    // 첫 박자(0.9초 뒤)의 소리가 늦지 않도록 오디오 출력을 미리 깨운다
    unawaited(c.sfx.warmUp());
    _song
      ..reset()
      ..start();
    _paused = false;
    _isBest = false;
    c.start();
    setState(() {});
  }

  void _pause() {
    if (_c == null || c.status != RhythmStatus.playing || _paused) return;
    _song.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    _song.start();
    setState(() => _paused = false);
  }

  void _restart() {
    _song
      ..stop()
      ..reset();
    _holdPointer = null;
    _swipePointer = null;
    c.restart();
    _begin();
  }

  void _onDown(PointerDownEvent e, double width) {
    if (_c == null || _paused || c.status != RhythmStatus.playing) return;
    // 지금 해야 할 박자가 "옆으로 긋기"면 탭으로 치지 않고, 손가락이 충분히 움직일 때까지 기다린다
    if (_swipePointer == null && c.beginSwipe(_songTime())) {
      _swipePointer = e.pointer;
      _swipeFrom = e.localPosition;
      return;
    }
    final side = e.localPosition.dx < width / 2 ? Side.left : Side.right;
    if (c.tap(side, _songTime())) _holdPointer = e.pointer;
  }

  void _onMove(PointerMoveEvent e, double width, double height) {
    if (_c == null || e.pointer != _swipePointer || _paused) return;
    final d = e.localPosition - _swipeFrom;
    if (c.armedGuard) {
      // 막기: 어느 손이든 위로 화면 높이의 9%(최소 55px) 이상, 가로보다 세로로 더 많이 밀면 성공
      final need = (height * 0.09).clamp(55.0, 170.0);
      if (-d.dy < need || -d.dy < d.dx.abs() * 1.0) return;
      _swipePointer = null;
      c.guard(_songTime());
      return;
    }
    // 가로로 화면 너비의 14%(최소 70px) 이상, 세로보다 가로로 더 많이 움직이면 "그었다"
    final need = (width * 0.14).clamp(70.0, 220.0);
    if (d.dx.abs() < need || d.dx.abs() < d.dy.abs() * 1.0) return;
    _swipePointer = null;
    c.swipe(d.dx > 0 ? Side.right : Side.left, _songTime());
  }

  void _onUp(PointerEvent e) {
    if (_c != null && e.pointer == _swipePointer) {
      _swipePointer = null;
      c.cancelSwipe();
      return;
    }
    if (_c == null || e.pointer != _holdPointer) return;
    _holdPointer = null;
    if (_paused) return;
    c.release(_songTime());
  }

  void _onJudged(Judged j) {
    if (!SettingsScope.of(context).haptics) return;
    if (j.rating == Rating.perfect) {
      HapticFeedback.lightImpact();
    } else if (j.rating == Rating.good) {
      HapticFeedback.selectionClick();
    }
  }

  void _next() {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RhythmScreen(course: widget.course + 1)));
  }

  Future<void> _onFinished() async {
    // 하트를 다 잃은 판은 점수·별과 상관없이 실패: 기록도 다음 코스 열림도 없다
    if (c.gameOver) {
      if (mounted) setState(() => _isBest = false);
      return;
    }
    final j = c.judge;
    if (j.stars >= RhythmCourse.passStars) WinSound.play(context); // 합격했을 때 "짜잔"
    final best = await RhythmStorage.record(
      RhythmResult(stars: j.stars, accuracy: j.accuracy, score: j.score, maxCombo: j.maxCombo),
      widget.course,
    );
    if (!mounted) return;
    setState(() => _isBest = best);
  }

  @override
  Widget build(BuildContext context) {
    final art = _art ?? RhythmArt.empty();
    return Scaffold(
      backgroundColor: const Color(0xFFE8C98E),
      body: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return Stack(
            children: [
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BackgroundPainter(art, name: _course.background)))),
              Positioned.fill(child: CustomPaint(painter: StagePainter(c, art: art, clock: _songTime, wall: _wall, foe: _course.foe, iron: _course.ironSword))),
              // 화면 전체가 탭 영역: 왼쪽 절반 / 오른쪽 절반
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onDown(e, width),
                  onPointerMove: (e) => _onMove(e, width, box.maxHeight),
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(child: _Hud(c: c, welcome: _course.welcome, songTime: _songTime, onBack: () => Navigator.of(context).maybePop(), onPause: _pause)),
              AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  if (c.status == RhythmStatus.ready) return _ReadyCard(course: widget.course, onStart: _audioReady && _art != null ? _begin : null);
                  if (c.status == RhythmStatus.finished && c.gameOver) {
                    return _GameOverCard(onAgain: _restart, onExit: () => Navigator.of(context).pop());
                  }
                  if (c.status == RhythmStatus.finished) {
                    return _ResultCard(
                      c: c,
                      isBest: _isBest,
                      hasNext: widget.course + 1 < RhythmCourse.all.length,
                      onNext: _next,
                      onAgain: _restart,
                      onExit: () => Navigator.of(context).pop(),
                    );
                  }
                  if (_paused) return _PauseCard(quitLabel: _course.foe == Foe.dummy ? '훈련 그만두기' : '그만두기', onResume: _resume, onRestart: _restart, onExit: () => Navigator.of(context).pop());
                  return const SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
