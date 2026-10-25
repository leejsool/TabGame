part of 'rhythm_screen.dart';

// 결과창과 그 단추 (파일을 역할별로 나눈 것)

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
