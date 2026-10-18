part of 'solitaire_screen.dart';

Future<void> showSolitaireRules(BuildContext context) {
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
      title: const Text('솔리테어 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 카드 52장을 무늬별로 A부터 K까지 위쪽 오른쪽 네 칸(완성 칸)에 모두 쌓아요.'),
            line('아래 7개 열에서는 다른 색이고 숫자가 하나 작은 카드를 이어 붙여요. (예: 검정 7 위에 빨강 6)'),
            line('앞면인 카드는 줄째로 한꺼번에 옮길 수 있어요. 맨 위 뒷면 카드는 위의 카드를 옮기면 저절로 뒤집혀요.'),
            line('빈 열에는 K(또는 K로 시작하는 줄)만 놓을 수 있어요.'),
            line('왼쪽 위 더미를 누르면 카드를 뽑아요. (1장 또는 3장씩) 더미가 비면 한 번 더 눌러서 다시 넘길 수 있어요.'),
            line('뽑은 카드는 맨 위 한 장만 쓸 수 있어요.'),
            line('카드를 끌어서 놓거나, 카드를 탭하면 알아서 갈 수 있는 곳으로 가요.'),
            line('번호가 같으면 항상 같은 판이에요. 모든 판이 풀리는 건 아니에요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            solitaireTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
