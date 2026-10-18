part of 'rhythm_screen.dart';

/// 리듬 화면의 위쪽 안내·카드·결과 같은 작은 위젯들 (화면 코드를 역할별로 나눈 파일)
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
