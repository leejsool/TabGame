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
