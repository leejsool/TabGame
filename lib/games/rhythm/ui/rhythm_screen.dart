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
    c.restart();
    _begin();
  }

  void _onDown(PointerDownEvent e, double width) {
    if (_c == null || _paused || c.status != RhythmStatus.playing) return;
    final side = e.localPosition.dx < width / 2 ? Side.left : Side.right;
    if (c.tap(side, _songTime())) _holdPointer = e.pointer;
  }

  void _onUp(PointerEvent e) {
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
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BackgroundPainter(art)))),
              Positioned.fill(child: CustomPaint(painter: StagePainter(c, art: art, clock: _songTime, wall: _wall))),
              // 화면 전체가 탭 영역: 왼쪽 절반 / 오른쪽 절반
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onDown(e, width),
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(child: _Hud(c: c, songTime: _songTime, onBack: () => Navigator.of(context).maybePop(), onPause: _pause)),
              AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  if (c.status == RhythmStatus.ready) return _ReadyCard(course: widget.course, onStart: _audioReady && _art != null ? _begin : null);
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
                  if (_paused) return _PauseCard(onResume: _resume, onExit: () => Navigator.of(context).pop());
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
  const _Hud({required this.c, required this.songTime, required this.onBack, required this.onPause});

  final RhythmController c;
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
                  Expanded(child: IgnorePointer(child: _HintPanel(c: c, playing: playing))),
                  const SizedBox(width: 10),
                  _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
                ],
              ),
            ),
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
  const _HintPanel({required this.c, required this.playing});
  final RhythmController c;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final n = c.chart.stages.length;
    final text = playing ? c.stageInfo.hint : '훈련소에 온 걸 환영한다!';
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
    final tips = course == 0
        ? const [
            _HowTo(icon: Icons.keyboard_double_arrow_left_rounded, title: '왼쪽 탭', sub: '화면 왼쪽 절반'),
            _HowTo(icon: Icons.keyboard_double_arrow_right_rounded, title: '오른쪽 탭', sub: '화면 오른쪽 절반'),
            _HowTo(icon: Icons.touch_app_rounded, title: '2연속', sub: '같은 쪽 빠르게 두 번'),
          ]
        : const [
            _HowTo(icon: Icons.touch_app_rounded, title: '탭', sub: '짧게 눌러 바로 내려치기'),
            _HowTo(icon: Icons.bolt_rounded, title: '꾹 누르기', sub: '누르고 있으면 힘이 모여요'),
            _HowTo(icon: Icons.back_hand_rounded, title: '떼기', sub: '손을 떼면 내려쳐요'),
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
              child: Text(onStart == null ? '준비 중…' : '훈련 시작!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

class _PauseCard extends StatelessWidget {
  const _PauseCard({required this.onResume, required this.onExit});
  final VoidCallback onResume;
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
          TextButton(onPressed: onExit, child: const Text('훈련 그만두기')),
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
