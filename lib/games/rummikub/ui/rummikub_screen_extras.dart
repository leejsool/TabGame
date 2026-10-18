part of 'rummikub_screen.dart';

/// 규칙 설명.
Future<void> showRummikubRules(BuildContext context) {
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
      title: const Text('루미큐브 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('손의 타일을 먼저 모두 판에 내려놓는 사람이 이겨요.'),
            line('그룹: 같은 숫자, 서로 다른 색 3~4장 (예: 파랑 7, 빨강 7, 주황 7).'),
            line('런: 같은 색, 이어지는 숫자 3장 이상 (예: 파랑 4-5-6). 13 다음에 1은 이어지지 않아요.'),
            line('조커는 어떤 타일 대신으로도 쓸 수 있어요.'),
            line('처음 내려놓을 때는 내 타일로만 묶음을 만들어 숫자 합이 30점 이상이어야 해요. 이때는 판 위의 묶음을 건드릴 수 없어요.'),
            line('그다음부터는 판 위 타일을 옮기고 쪼개서 새로 맞춰도 돼요. 끝낼 때 판 위의 모든 묶음이 올바르고, 내 타일을 한 장 이상 내려놓았어야 해요.'),
            line('판 위의 타일을 손으로 가져올 수는 없어요.'),
            line('낼 수 없으면 바닥에 엎어 둔 타일 중 한 장을 직접 골라 뽑고 차례를 넘겨요. 바닥이 비었는데 모두 낼 수 없으면, 손에 남은 타일의 숫자 합이 가장 작은 사람이 이겨요 (조커는 30점).'),
            line('상대가 손에 몇 장 가졌는지는 알 수 없어요. 판이 끝나야 남은 타일의 점수가 드러나요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            rummikubTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}

/// 날아가는 타일 한 장의 연출 정보 (화면 좌표).
class _Fly {
  const _Fly({required this.from, required this.to, required this.width, required this.duration, required this.serial, this.onEnd});

  final Offset from, to;
  final double width;
  final Duration duration;
  final int serial;
  final VoidCallback? onEnd;
}
