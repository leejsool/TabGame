import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/settings_scope.dart';
import '../audio/rhythm_audio.dart';
import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';
import '../data/rhythm_storage.dart';
import '../game/rhythm_controller.dart';
import 'camp_painter.dart';
import 'rhythm_art.dart';
import 'stage_painter.dart';

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

// ── 위쪽 안내 ──

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.welcome, required this.songTime, required this.onBack, required this.onPause});

  final RhythmController c;
  final String welcome;
  final double Function() songTime;
  final VoidCallback onBack;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final playing = c.status == RhythmStatus.playing;
        final t = playing ? songTime() : -1.0;
        final countIn = c.chart.countInBeats * c.chart.beat;
        final inCount = playing && t < countIn;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                  const SizedBox(width: 10),
                  Expanded(child: IgnorePointer(child: _HintPanel(c: c, welcome: welcome, playing: playing))),
                  const SizedBox(width: 10),
                  _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
                ],
              ),
            ),
            if (playing && c.hasHearts) Positioned(left: 14, top: 96, child: IgnorePointer(child: _Hearts(c: c, t: t))),
            if (playing && c.judge.combo >= 2)
              Positioned(
                right: 14,
                top: 96,
                child: IgnorePointer(child: _ComboBadge(combo: c.judge.combo)),
              ),
            if (inCount) IgnorePointer(child: _CountIn(c: c, t: t)),
            if (playing && !inCount && t - c.stageBannerAt < 1.7 && c.stage > 0)
              IgnorePointer(child: _StageBanner(c: c, age: t - c.stageBannerAt)),
          ],
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: _ink, width: 3.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, color: _ink, size: 26)),
      ),
    );
  }
}

/// 위쪽 안내판: 단계 표시 점 + 교관의 한마디.
class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.c, required this.welcome, required this.playing});
  final RhythmController c;
  final String welcome;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final n = c.chart.stages.length;
    final text = playing ? c.stageInfo.hint : welcome;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ink, width: 3.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < n; i++)
                    Container(
                      width: 11,
                      height: 11,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.status == RhythmStatus.finished || (playing && i < c.stage)
                            ? _gold
                            : (playing && i == c.stage ? const Color(0xFFFF7A2F) : Colors.white),
                        border: Border.all(color: _ink, width: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  text,
                  key: ValueKey(text),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 19, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.combo});
  final int combo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFFF7A2F), borderRadius: BorderRadius.circular(16), border: Border.all(color: _ink, width: 3)),
      child: Text('콤보 $combo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
    );
  }
}

class _CountIn extends StatelessWidget {
  const _CountIn({required this.c, required this.t});
  final RhythmController c;
  final double t;

  @override
  Widget build(BuildContext context) {
    final b = c.beatIndex(t);
    final phase = c.beatPhase(t);
    final scale = 1.0 + 0.5 * pow(1 - phase, 3).toDouble();
    final text = b < 0 ? '준비…' : '${b + 1}';
    return Align(
      alignment: const Alignment(0, -0.1),
      child: Transform.scale(
        scale: scale,
        child: Stack(
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: b < 0 ? 40 : 110,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 12
                  ..strokeJoin = StrokeJoin.round
                  ..color = _ink,
              ),
            ),
            Text(text, style: TextStyle(fontSize: b < 0 ? 40 : 110, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.c, required this.age});
  final RhythmController c;
  final double age;

  @override
  Widget build(BuildContext context) {
    final a = age < 0.2 ? age / 0.2 : (age > 1.3 ? max(0.0, 1 - (age - 1.3) / 0.4) : 1.0);
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Opacity(
        opacity: a,
        child: Transform.scale(
          scale: 0.9 + 0.1 * a,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _ink, width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${c.stage + 1}단계', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(c.stageInfo.title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 28)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 카드들 ──

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _ink, width: 4.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 7))],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.course, required this.onStart});

  final int course;

  /// null이면 소리·그림을 아직 준비 중.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final sound = SettingsScope.of(context).sound;
    final info = RhythmCourse.all[course];
    final tips = course >= 3
        ? const [
            _HowTo(icon: Icons.swipe_up_rounded, title: '위로 쓱 = 막기', sub: '슬라임이 덮칠 때, 어느 손이든'),
            _HowTo(icon: Icons.favorite_rounded, title: '하트 3개', sub: '막지 못하면 하나씩 깎여요'),
            _HowTo(icon: Icons.heart_broken_rounded, title: '다 잃으면 끝', sub: '점수와 상관없이 게임 오버'),
          ]
        : course == 0
        ? const [
            _HowTo(icon: Icons.keyboard_double_arrow_left_rounded, title: '왼쪽 탭', sub: '화면 왼쪽 절반'),
            _HowTo(icon: Icons.keyboard_double_arrow_right_rounded, title: '오른쪽 탭', sub: '화면 오른쪽 절반'),
            _HowTo(icon: Icons.touch_app_rounded, title: '2연속', sub: '같은 쪽 빠르게 두 번'),
          ]
        : course == 1
            ? const [
                _HowTo(icon: Icons.touch_app_rounded, title: '탭', sub: '짧게 눌러 바로 내려치기'),
                _HowTo(icon: Icons.bolt_rounded, title: '꾹 누르기', sub: '누르고 있으면 힘이 모여요'),
                _HowTo(icon: Icons.back_hand_rounded, title: '떼기', sub: '손을 떼면 내려쳐요'),
              ]
            : const [
                _HowTo(icon: Icons.swipe_rounded, title: '옆으로 긋기', sub: '화면을 쓱 그으면 베어요'),
                _HowTo(icon: Icons.touch_app_rounded, title: '방향', sub: '화살표 쪽으로 그어요'),
                _HowTo(icon: Icons.bolt_rounded, title: '탭·꾹', sub: '배운 것도 섞여 나와요'),
              ];
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 4),
          const Text('앞사람이 내려치면, 한 박 뒤에 따라 해요', style: TextStyle(fontSize: 15, color: _ink)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < tips.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tips[i]),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            sound ? '🔊 소리를 켜고 박자를 들으면서 해 봐요!' : '🔇 지금 소리가 꺼져 있어요. 설정에서 켜면 더 재밌어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            '별 ${RhythmCourse.passStars}개 이상이면 다음 코스로 가요',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A2F),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _ink, width: 3.5)),
              ),
              child: Text(onStart == null ? '준비 중…' : (info.foe == Foe.dummy ? '훈련 시작!' : '출발!'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo({required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: const Color(0xFFFFF0B3), borderRadius: BorderRadius.circular(16), border: Border.all(color: _ink, width: 2.5)),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFFFF7A2F)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: _ink)),
        ],
      ),
    );
  }
}

/// 하트를 다 잃어서 끝났을 때.
class _GameOverCard extends StatelessWidget {
  const _GameOverCard({required this.onAgain, required this.onExit});

  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.heart_broken_rounded, size: 64, color: Color(0xFFE5484D)),
          const SizedBox(height: 6),
          const Text('게임 오버', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 8),
          const Text(
            '하트를 모두 잃었다!\n점수는 소용없다. 슬라임이 힘을 모을 때 위로 쓱 밀어서 막아라!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onExit, child: const Padding(padding: EdgeInsets.all(10), child: Text('나가기')))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onAgain,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A2F)),
                  child: const Padding(padding: EdgeInsets.all(10), child: Text('다시 도전!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 남은 하트 (보스 코스). 잃은 하트는 비고, 방금 잃었다면 잠깐 흔들린다.
class _Hearts extends StatelessWidget {
  const _Hearts({required this.c, required this.t});

  final RhythmController c;
  final double t;

  @override
  Widget build(BuildContext context) {
    final lostAgo = t - c.heartLostAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < c.chart.hearts; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.translate(
                // 방금 깎인 하트(맨 오른쪽 남은 것의 바로 다음)는 흔들린다
                offset: Offset(i == c.hearts && lostAgo >= 0 && lostAgo < 0.4 ? sin(lostAgo * 90) * 4 : 0, 0),
                child: Icon(
                  i < c.hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 30,
                  color: i < c.hearts ? const Color(0xFFE5484D) : const Color(0xFFB9A9A9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({required this.quitLabel, required this.onResume, required this.onRestart, required this.onExit});
  final String quitLabel;
  final VoidCallback onResume;

  /// 이 스테이지를 처음부터 다시 한다.
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('잠깐 쉬어요', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onResume, child: const Padding(padding: EdgeInsets.all(10), child: Text('계속하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Padding(padding: EdgeInsets.all(8), child: Text('처음부터 다시', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onExit, child: Text(quitLabel)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.c,
    required this.isBest,
    required this.hasNext,
    required this.onNext,
    required this.onAgain,
    required this.onExit,
  });

  final RhythmController c;
  final bool isBest;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final j = c.judge;
    final passed = j.stars >= RhythmCourse.passStars;
    final msg = switch (j.stars) {
      3 => '훌륭하다! 완벽에 가까운 솜씨다!',
      2 => '합격이다! 꽤 하는군!',
      1 => '아깝다! 별 2개를 넘겨야 합격이다.',
      _ => '박자는 천천히 익히면 된다. 다시 도전해 보자!',
    };
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(passed ? '합격!' : '아직이다!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 350 + i * 250),
                  curve: Curves.elasticOut,
                  builder: (context, v, _) => Transform.scale(
                    scale: i < j.stars ? v : 1,
                    child: Icon(Icons.star_rounded, size: 64, color: i < j.stars ? _gold : const Color(0xFFD9CDB5)),
                  ),
                ),
            ],
          ),
          if (isBest) const Text('🎉 새 최고 기록!', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE2793A))),
          const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: '완벽', value: '${j.perfect}', color: const Color(0xFFE2A400)),
              _Stat(label: '좋아요', value: '${j.good}', color: const Color(0xFF3FA06A)),
              _Stat(label: '놓침', value: '${j.miss}', color: const Color(0xFFB0B7C3)),
              _Stat(label: '최고 콤보', value: '${j.maxCombo}', color: const Color(0xFFE2793A)),
            ],
          ),
          const SizedBox(height: 6),
          Text('점수 ${j.score}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onExit, child: const Padding(padding: EdgeInsets.all(10), child: Text('나가기')))),
              const SizedBox(width: 10),
              if (passed && hasNext) ...[
                Expanded(child: OutlinedButton(onPressed: onAgain, child: const Padding(padding: EdgeInsets.all(10), child: Text('다시 하기')))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A2F)),
                    child: const Padding(padding: EdgeInsets.all(10), child: Text('다음 코스 ▶', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                  ),
                ),
              ] else
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onAgain,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7A2F)),
                    child: Padding(padding: const EdgeInsets.all(10), child: Text(passed ? '다시 하기' : '다시 도전!', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: _ink)),
        ],
      ),
    );
  }
}
