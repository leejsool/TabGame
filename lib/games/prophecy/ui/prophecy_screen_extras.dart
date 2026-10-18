part of 'prophecy_screen.dart';

// 점수판·규칙 (파일을 역할별로 나눈 것)

/// 판이 끝난 뒤 점수 풀이: 누가 어떤 예언을 맞혀 몇 점을 얻었는지.
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.controller, required this.name, required this.onAgain, required this.onMenu, this.againLabel = '한 판 더'});

  final ProphecyController controller;
  final String Function(int side) name;

  /// null이면 "한 판 더"를 누를 수 없다 (상대를 기다리는 중이거나 상대가 나갔을 때).
  final VoidCallback? onAgain;
  final String againLabel;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final parts = s.scoreParts();
    final sc = s.scores();
    final scheme = Theme.of(context).colorScheme;
    Widget row(int side) {
      final color = penColor(side);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(Icons.edit_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(name(side), style: TextStyle(fontWeight: FontWeight.w800, color: color))),
            Text('행 ${parts.rowPts[side]} + 열 ${parts.colPts[side]}', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text('${sc[side]}점', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(0),
          row(1),
          const SizedBox(height: 4),
          Text(
            '동그라미: 맞힌 예언 · 좌우 화살표는 행, 위아래 화살표는 열에서 맞힌 거예요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: onMenu, child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onAgain, child: Text(againLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 규칙 설명.
Future<void> showProphecyRules(BuildContext context) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('예언 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('두 사람이 번갈아 빈칸에 숫자나 X를 써요.'),
            line('숫자는 "이 줄(행·열)에 숫자가 모두 몇 개 나타날까"에 대한 예언이에요. X는 칸을 채우기만 하고 숫자가 아니에요.'),
            line('쓸 수 있는 숫자는 1부터 가장 긴 줄의 칸 수까지예요.'),
            line('한 행이나 열에는 같은 숫자를 두 번 쓸 수 없어요.'),
            line('어떤 숫자도 쓸 수 없는 칸은 저절로 X가 돼요. 이건 차례로 세지 않아요.'),
            line('표가 가득 차면 행마다 숫자가 몇 개인지 세요. 그 개수와 같은 숫자를 쓴 사람이 그 숫자만큼 점수를 얻어요. 열도 똑같이 세요.'),
            line('한 숫자가 행과 열에서 모두 맞으면 두 번 점수가 돼요. 점수가 더 높은 사람이 이겨요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            prophecyTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
