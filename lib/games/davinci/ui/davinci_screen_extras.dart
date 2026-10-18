part of 'davinci_screen.dart';

/// 규칙 설명.
Future<void> showDavinciRules(BuildContext context) {
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
      title: const Text('다빈치 코드 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('타일은 검정·흰색 0~11, 그리고 조커(‑) 두 장이에요. 각자 타일을 받아 숫자가 작은 쪽부터 왼쪽에서 오른쪽으로 늘어놓아요. 같은 숫자는 검정이 먼저예요.'),
            line('내 타일은 나만 볼 수 있고, 남의 타일은 색과 자리만 보여요.'),
            line('내 차례에 검정이나 흰색 더미에서 타일을 한 장 뽑아요 (순서에 맞는 자리에 저절로 끼워져요).'),
            line('그다음 상대의 숨은 타일 하나를 골라 숫자를 맞혀요.'),
            line('맞히면 그 타일이 공개돼요. 계속 맞히거나, 멈추고 차례를 넘길 수 있어요.'),
            line('틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어가요.'),
            line('조커는 뽑았을 때 내가 놓을 자리를 골라요. 맞힐 때는 "‑"를 골라요.'),
            line('숨은 타일이 모두 공개되면 탈락이에요. 마지막까지 남은 사람이 이겨요.'),
            line('더미가 다 떨어지면 뽑지 않고 바로 맞혀요. 이때 틀리면 내 숨은 타일 하나를 직접 공개해요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            davinciTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}

/// 날아가는 타일 한 장. [from]에서 [via](손패 한가운데)를 거쳐 [to](제 자리)로 간다.
/// [via]가 없으면 곧장 [to]로 가고, [to]가 없으면 [via]에서 멈춰 떠 있는다.
class _Fly {
  _Fly({required this.from, this.via, this.to, required this.tile, required this.faceUp, required this.width, required this.duration, required this.serial, required this.onEnd})
      : assert(via != null || to != null);

  final Offset from;
  final Offset? via, to;
  final int tile;
  final bool faceUp;
  final double width;
  final Duration duration;
  final int serial;
  final VoidCallback onEnd;

  /// 시간 [t](0~1)의 위치와 떠오른 높이, 커진 정도(0~1).
  ({Offset pos, double lift, double pop}) at(double t) {
    final v = via, d = to;
    var a = from, b = (v ?? d)!;
    var u = t, arc = 30.0;
    if (v != null && d != null) {
      // 먼저 한가운데로 (앞 절반), 잠깐 머물렀다가 (조금), 제 자리로 (뒤쪽)
      if (t < 0.5) {
        u = t / 0.5;
      } else if (t < 0.62) {
        return (pos: v, lift: 0, pop: 0);
      } else {
        a = v;
        b = d;
        u = (t - 0.62) / 0.38;
        arc = 12;
      }
    }
    final e = Curves.easeInOutCubic.transform(u.clamp(0.0, 1.0));
    return (pos: Offset.lerp(a, b, e)!, lift: sin(pi * u) * arc, pop: sin(pi * u));
  }
}
