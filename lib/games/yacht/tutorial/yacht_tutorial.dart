import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/yacht_look.dart';

/// 야추 게임 방법.
GameTutorial yachtTutorial() => GameTutorial(
      title: '야추',
      color: kYachtColor,
      steps: [
        TutorialStep(
          title: '주사위 5개로 점수를 모아요',
          body: '차례마다 주사위 5개를 굴려서 점수판의 한 칸을 채워요.\n'
              '12칸을 모두 채웠을 때 합계가 가장 높은 사람이 이겨요.',
          art: (context, accent) => _art([
            _DiceRow([6, 6, 6, 2, 5]),
          ], label: '12번의 차례, 12개의 칸'),
        ),
        TutorialStep(
          title: '한 차례에 3번까지 굴려요',
          body: '굴린 뒤에 남기고 싶은 주사위를 눌러서 잡아요. 잡은 주사위는 그대로 두고 나머지만 다시 굴려요.\n'
              '마음에 들면 3번을 다 굴리지 않고 바로 적어도 돼요.',
          art: (context, accent) => _art([
            _DiceRow([6, 6, 6, 2, 5], held: [true, true, true, false, false]),
          ], label: '6 세 개를 잡고 나머지만 다시!'),
        ),
        TutorialStep(
          title: '빈 칸 하나에 점수를 적어요',
          body: '점수판에서 적을 칸을 누르고 "적기"를 눌러요. 한 칸에는 한 번만 적을 수 있어요.\n'
              '맞는 칸이 없으면 아무 칸에나 0점을 적어야 하니, 어느 칸을 버릴지도 잘 골라야 해요.',
          art: (context, accent) => _art([
            _DiceRow([6, 6, 6, 6, 3], caption: '6 칸에 적으면 24점'),
            _DiceRow([6, 6, 6, 6, 3], caption: '포카드 칸에 적으면 27점'),
          ], label: '같은 주사위도 칸마다 점수가 달라요'),
        ),
        TutorialStep(
          title: '숫자 칸과 보너스',
          body: '1~6 칸은 그 숫자가 나온 주사위만 더해요.\n'
              '여섯 칸의 합이 63점 이상이면 보너스 35점! 숫자마다 3개씩 모으면 딱 63점이에요.',
          art: (context, accent) => _art([
            _DiceRow([4, 4, 4, 1, 6], caption: '4 칸 → 12점'),
            _DiceRow([5, 5, 2, 3, 3], caption: '5 칸 → 10점'),
          ], label: '합이 63점 이상이면 +35점'),
        ),
        TutorialStep(
          title: '족보 칸',
          body: '초이스: 눈 5개의 합 · 포카드: 같은 눈 4개 · 풀하우스: 같은 눈 3개 + 2개\n'
              '스몰 스트레이트: 이어진 눈 4개(15점) · 라지 스트레이트: 이어진 눈 5개(30점) · 야추: 같은 눈 5개(50점)',
          art: (context, accent) => _art([
            _DiceRow([3, 3, 3, 5, 5], caption: '풀하우스 19점', size: 38),
            _DiceRow([2, 3, 4, 5, 5], caption: '스몰 스트레이트 15점', size: 38),
            _DiceRow([2, 3, 4, 5, 6], caption: '라지 스트레이트 30점', size: 38),
            _DiceRow([4, 4, 4, 4, 4], caption: '야추 50점', size: 38),
          ], label: '어려운 족보일수록 점수가 커요'),
        ),
      ],
    );

Widget _art(List<Widget> rows, {required String label}) {
  return ArtCanvas(
    width: 340,
    height: 380,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: r),
        const SizedBox(height: 12),
        ArtLabel(label, color: kYachtColor),
      ],
    ),
  );
}

class _DiceRow extends StatelessWidget {
  const _DiceRow(this.dice, {this.held, this.caption, this.size = 56});

  final List<int> dice;
  final List<bool>? held;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < dice.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: YachtDie(value: dice[i], size: size, held: held?[i] ?? false),
              ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
