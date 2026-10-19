part of 'rhythm_screen.dart';

// 카드·결과 화면 (파일을 역할별로 나눈 것)

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 7),
                ),
              ],
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
    // 하트가 있는 코스(보스전)만 막기 안내를 보여 준다. 보스 이름은 코스의 적에 맞춘다
    final tips = info.hearts > 0
        ? [
            _HowTo(
              icon: Icons.swipe_up_rounded,
              title: '위로 쓱 = 막기',
              sub: '${info.foe.label}이 덮칠 때, 어느 손이든',
            ),
            _HowTo(
              icon: Icons.favorite_rounded,
              title: '하트 ${info.hearts}개',
              sub: '막지 못하면 하나씩 깎여요',
            ),
            const _HowTo(
              icon: Icons.heart_broken_rounded,
              title: '다 잃으면 끝',
              sub: '점수와 상관없이 게임 오버',
            ),
          ]
        : course == 0
        ? const [
            _HowTo(
              icon: Icons.keyboard_double_arrow_left_rounded,
              title: '왼쪽 탭',
              sub: '화면 왼쪽 절반',
            ),
            _HowTo(
              icon: Icons.keyboard_double_arrow_right_rounded,
              title: '오른쪽 탭',
              sub: '화면 오른쪽 절반',
            ),
            _HowTo(
              icon: Icons.touch_app_rounded,
              title: '2연속',
              sub: '같은 쪽 빠르게 두 번',
            ),
          ]
        : course == 1
        ? const [
            _HowTo(
              icon: Icons.touch_app_rounded,
              title: '탭',
              sub: '짧게 눌러 바로 내려치기',
            ),
            _HowTo(
              icon: Icons.bolt_rounded,
              title: '꾹 누르기',
              sub: '누르고 있으면 힘이 모여요',
            ),
            _HowTo(
              icon: Icons.back_hand_rounded,
              title: '떼기',
              sub: '손을 떼면 내려쳐요',
            ),
          ]
        : const [
            _HowTo(
              icon: Icons.swipe_rounded,
              title: '옆으로 긋기',
              sub: '화면을 쓱 그으면 베어요',
            ),
            _HowTo(
              icon: Icons.touch_app_rounded,
              title: '방향',
              sub: '화살표 쪽으로 그어요',
            ),
            _HowTo(icon: Icons.bolt_rounded, title: '탭·꾹', sub: '배운 것도 섞여 나와요'),
          ];
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '앞사람이 내려치면, 한 박 뒤에 따라 해요',
            style: TextStyle(fontSize: 15, color: _ink),
          ),
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
            sound
                ? '🔊 소리를 켜고 박자를 들으면서 해 봐요!'
                : '🔇 지금 소리가 꺼져 있어요. 설정에서 켜면 더 재밌어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            '별 ${RhythmCourse.passStars}개 이상이면 다음 코스로 가요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A2F),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: _ink, width: 3.5),
                ),
              ),
              child: Text(
                onStart == null
                    ? '준비 중…'
                    : (info.foe == Foe.dummy ? '훈련 시작!' : '출발!'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0B3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ink, width: 2.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFFFF7A2F)),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: _ink),
          ),
        ],
      ),
    );
  }
}

/// 하트를 다 잃어서 끝났을 때.
class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.foe,
    required this.onAgain,
    required this.onExit,
  });

  /// 막아야 했던 보스 (글에 이름이 들어간다).
  final Foe foe;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.heart_broken_rounded,
            size: 64,
            color: Color(0xFFE5484D),
          ),
          const SizedBox(height: 6),
          const Text(
            '게임 오버',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '하트를 모두 잃었다!\n점수는 소용없다. 슬라임이 힘을 모을 때 위로 쓱 밀어서 막아라!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExit,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('나가기'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A2F),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      '다시 도전!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
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
                offset: Offset(
                  i == c.hearts && lostAgo >= 0 && lostAgo < 0.4
                      ? sin(lostAgo * 90) * 4
                      : 0,
                  0,
                ),
                child: Icon(
                  i < c.hearts
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 30,
                  color: i < c.hearts
                      ? const Color(0xFFE5484D)
                      : const Color(0xFFB9A9A9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({
    required this.quitLabel,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });
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
          const Text(
            '잠깐 쉬어요',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onResume,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  '계속하기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '처음부터 다시',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
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
          Text(
            passed ? '합격!' : '아직이다!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
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
                    child: Icon(
                      Icons.star_rounded,
                      size: 64,
                      color: i < j.stars ? _gold : const Color(0xFFD9CDB5),
                    ),
                  ),
                ),
            ],
          ),
          if (isBest)
            const Text(
              '🎉 새 최고 기록!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFE2793A),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: _ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                label: '완벽',
                value: '${j.perfect}',
                color: const Color(0xFFE2A400),
              ),
              _Stat(
                label: '좋아요',
                value: '${j.good}',
                color: const Color(0xFF3FA06A),
              ),
              _Stat(
                label: '놓침',
                value: '${j.miss}',
                color: const Color(0xFFB0B7C3),
              ),
              _Stat(
                label: '최고 콤보',
                value: '${j.maxCombo}',
                color: const Color(0xFFE2793A),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '점수 ${j.score}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 16),
          // 폰처럼 좁은 화면에서도 글자가 줄바꿈되지 않도록: 버튼 안쪽 여백을 줄이고 글자는 한 줄로 (모자라면 살짝 작아진다)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onExit,
                  style: _resultButtonPad,
                  child: _resultLabel('나가기'),
                ),
              ),
              const SizedBox(width: 8),
              if (passed && hasNext) ...[
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onAgain,
                    style: _resultButtonPad,
                    child: _resultLabel('다시 하기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: onNext,
                    style: _resultButtonPad.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(
                        Color(0xFFFF7A2F),
                      ),
                    ),
                    child: _resultLabel('다음 코스 ▶', bold: true),
                  ),
                ),
              ] else
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: onAgain,
                    style: _resultButtonPad.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(
                        Color(0xFFFF7A2F),
                      ),
                    ),
                    child: _resultLabel(
                      passed ? '다시 하기' : '다시 도전!',
                      bold: true,
                    ),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: _ink)),
        ],
      ),
    );
  }
}

/// 결과창 아래 버튼들의 안쪽 여백 (기본 여백이 커서 좁은 화면에서 글자가 줄바꿈되던 것을 막는다).
final ButtonStyle _resultButtonPad = ButtonStyle(
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 6, vertical: 14),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
);

/// 버튼 글자: 한 줄로 두고, 자리가 모자라면 살짝 줄여서 맞춘다.
Widget _resultLabel(String text, {bool bold = false}) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(
    text,
    maxLines: 1,
    softWrap: false,
    style: TextStyle(
      fontWeight: bold ? FontWeight.w900 : null,
      fontSize: bold ? 17 : null,
    ),
  ),
);
