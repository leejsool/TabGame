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
