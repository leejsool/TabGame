part of 'quoridor_screen.dart';

/// 규칙 설명.
Future<void> showQuoridorRules(BuildContext context) {
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
      title: const Text('쿼리도 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('2명 또는 4명이 해요. 각자 판 가장자리 가운데에서 시작해서, 맞은편 줄에 가장 먼저 닿으면 이겨요.'),
            line('자기 차례에 말을 한 칸 옮기거나(앞뒤 양옆), 벽을 하나 세워요.'),
            line('바로 옆에 다른 말이 있으면 그 말을 뛰어넘어요. 뒤가 벽이나 판 끝이면 그 말의 양옆으로 비껴 갈 수 있어요.'),
            line('벽은 두 칸 길이예요. 말은 벽을 넘거나 뚫고 갈 수 없어요.'),
            line('벽은 겹치거나 십자로 엇갈리게 세울 수 없어요. 그리고 어느 말이든 도착 줄로 가는 길이 하나는 꼭 남아 있어야 해요.'),
            line('벽은 2명이면 10개씩, 4명이면 5개씩 가져요. 다 쓰면 말만 옮길 수 있어요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            quoridorTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
