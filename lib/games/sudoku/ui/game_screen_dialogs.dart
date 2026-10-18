part of 'game_screen.dart';

// 실수·완성 대화상자 (파일을 역할별로 나눈 것)

class _MistakeDialog extends StatelessWidget {
  const _MistakeDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_rounded, color: scheme.error),
          const SizedBox(width: 8),
          const Text('실수 3번!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('틀린 숫자를 3번 넣었어요. 어떻게 할까요?'),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, _MistakeChoice.restart),
            child: const Text('처음부터 다시하기'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, _MistakeChoice.keepGoing),
            child: const Text('그래도 계속하기'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, _MistakeChoice.newGame),
            child: const Text('다른 판으로 시작'),
          ),
        ],
      ),
    );
  }
}

class _CompleteDialog extends StatelessWidget {
  const _CompleteDialog({required this.game, required this.isBest});

  final SudokuGame game;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('완성! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${game.puzzle.difficulty.label} · ${formatTime(game.elapsed.value)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('실수 ${game.mistakes}번 · 힌트 ${game.hintsUsed}번'),
          if (isBest) ...[
            const SizedBox(height: 8),
            Text('새 최고 기록이에요!',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('메뉴로'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('같은 난이도로 새 판'),
        ),
      ],
    );
  }
}
