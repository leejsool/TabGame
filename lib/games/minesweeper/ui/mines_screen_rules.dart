part of 'mines_screen.dart';

Future<void> showMinesRules(BuildContext context) {
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
      title: const Text('지뢰찾기 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 지뢰가 없는 칸을 모두 열면 이겨요. 지뢰를 밟으면 져요.'),
            line('칸을 눌러서 열어요. 첫 칸은 늘 안전해요.'),
            line('숫자는 그 칸 둘레 8칸에 지뢰가 몇 개 있는지 알려줘요.'),
            line('칸을 톡 치면 열려요.'),
            line('칸을 꾹 누르면 동그란 메뉴가 떠요. 손가락을 그대로 밀었다 떼세요: 위쪽은 열기, 오른쪽 아래는 깃발, 왼쪽 아래는 물음표(?)예요. 가운데에서 떼면 취소돼요.'),
            line('물음표는 "잘 모르겠어요" 표시라서 지뢰 수에 들어가지 않고, 눌러서 열 수도 있어요.'),
            line('열린 숫자 둘레에 깃발이 숫자만큼 꽂혀 있으면, 그 숫자를 눌러서 나머지 칸을 한꺼번에 열 수 있어요.'),
            line('힌트 버튼은 지금 보이는 숫자로 "확실한" 칸과 그 이유를 알려줘요.'),
            line('두 손가락으로 벌리면 판을 확대하고, 두 손가락으로 움직여 판을 옮길 수 있어요. (한 손가락 끌기는 깃발·물음표예요)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            minesTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
