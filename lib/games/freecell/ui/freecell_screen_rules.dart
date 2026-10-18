part of 'freecell_screen.dart';

Future<void> showFreecellRules(BuildContext context) {
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
      title: const Text('프리셀 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 카드 52장을 무늬별로 A부터 K까지 위쪽 오른쪽 네 칸(완성 칸)에 모두 쌓아요.'),
            line('아래 8개 열에서는 맨 위 카드를 옮겨요. 다른 색이고 숫자가 하나 큰 카드 위에 올릴 수 있어요. (예: 빨강 7 위에 검정 6)'),
            line('위쪽 왼쪽 네 칸(프리셀)은 카드 한 장씩 잠깐 맡아두는 곳이에요.'),
            line('빈 프리셀과 빈 열이 많을수록 여러 장을 한꺼번에 옮길 수 있어요.'),
            line('빈 열에는 아무 카드나(줄째로) 올릴 수 있어요.'),
            line('카드를 끌어서 놓거나, 카드를 탭하면 알아서 갈 수 있는 곳으로 가요.'),
            line('번호가 같으면 항상 같은 판이에요 (1~32000번). 11982번만 풀 수 없는 판이라 제외돼요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            freecellTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
