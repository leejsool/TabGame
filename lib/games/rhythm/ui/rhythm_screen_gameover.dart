part of 'rhythm_screen.dart';

// 게임 오버 카드와 남은 하트 (파일을 역할별로 나눈 것)

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
