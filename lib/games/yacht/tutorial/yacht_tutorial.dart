import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/yacht_look.dart';
import 'yacht_tutorial_pages.dart';

/// 야추 게임 방법.
GameTutorial yachtTutorial() => GameTutorial(
      title: '야추',
      color: kYachtColor,
      steps: [
        TutorialStep(
          title: '주사위 5개로 점수를 모아요',
          body: '차례마다 주사위 5개를 굴려서 점수판의 한 칸을 채워요.\n'
              '12칸(쓰리카드 칸을 넣으면 13칸)을 모두 채웠을 때 합계가 가장 높은 사람이 이겨요.',
          art: (context, accent) => const YachtTutorialSheetArt(),
        ),
        TutorialStep(
          title: '한 차례에 3번까지 굴려요',
          body: '굴린 뒤에 남기고 싶은 주사위를 눌러서 고정해요(한 번 더 누르면 풀려요). 고정한 주사위는 그대로 두고 나머지만 다시 굴려요.\n'
              '마음에 들면 3번을 다 굴리지 않고 바로 적어도 돼요.',
          art: (context, accent) => _art([
            YachtTutorialDice([6, 6, 6, 2, 5], held: [true, true, true, false, false]),
          ], label: '6 세 개를 고정하고 나머지만 다시!'),
        ),
        TutorialStep(
          title: '빈 칸 하나에 점수를 적어요',
          body: '점수판에서 적을 칸을 누르고 아래의 "○○ · ○점 적기" 단추를 눌러요. 한 칸에는 한 번만 적을 수 있어요.\n'
              '맞는 칸이 없으면 아무 칸에나 0점을 적어야 하니, 어느 칸을 버릴지도 잘 골라야 해요.\n'
              '점수판의 칸 이름(에이스, 풀하우스 …)을 누르면 그 칸의 설명이 나와요.',
          art: (context, accent) => const YachtTutorialPickArt(),
        ),
        TutorialStep(
          title: '숫자 칸과 보너스',
          body: '에이스(1)~식스(6) 칸은 그 숫자가 나온 주사위만 더해요.\n'
              '여섯 칸의 합이 63점 이상이면 보너스 35점! 숫자마다 3개씩 모으면 딱 63점이에요.',
          art: (context, accent) => const YachtTutorialUpperArt(),
        ),
        TutorialStep(
          title: '족보 칸',
          body: '모양을 맞추면 정해진 점수를 받아요. 찬스는 모양 없이 눈 5개의 합이에요.\n'
              '야추 칸에 50점을 적은 뒤 야추를 또 굴려서 아무 칸에 적으면 보너스 100점!',
          art: (context, accent) => _art(height: 416, gap: 3, [
            YachtTutorialDice([3, 3, 3, 5, 5], marks: const [true, true, true, true, true], caption: '풀하우스 25점', rule: '같은 눈 3개 + 다른 같은 눈 2개', size: 34),
            YachtTutorialDice([2, 3, 4, 5, 5], marks: const [true, true, true, true, false], caption: '스몰 스트레이트 30점', rule: '이어진 눈 4개 (예: 2-3-4-5)', size: 34),
            YachtTutorialDice([2, 3, 4, 5, 6], marks: const [true, true, true, true, true], caption: '라지 스트레이트 40점', rule: '이어진 눈 5개 (1~5 또는 2~6)', size: 34),
            YachtTutorialDice([4, 4, 4, 4, 4], marks: const [true, true, true, true, true], caption: '야추 50점', rule: '같은 눈 5개', size: 34),
          ], label: '어려운 족보일수록 점수가 커요'),
        ),
        TutorialStep(
          title: '힌트로 확률을 봐요',
          body: '한 번 굴린 뒤 아래의 "힌트"를 누르면, 어떤 주사위를 고정하면 좋을지(또는 어느 칸에 적으면 좋을지) 추천해 줘요.\n'
              '족보마다 완성될 확률도 분수로 나오고, 분수를 누르면 경우를 하나씩 센 풀이를 볼 수 있어요.\n'
              '확률을 더 배우고 싶으면 "교과학습"을 열어 보세요.',
          art: (context, accent) => _art([
            YachtTutorialDice([3, 3, 3, 3, 5], held: [true, true, true, true, false]),
          ], label: '야추가 될 확률 11/36'),
        ),
      ],
    );

Widget _art(List<Widget> rows, {required String label, double height = 380, double gap = 7}) {
  return ArtCanvas(
    width: 340,
    height: height,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final r in rows) Padding(padding: EdgeInsets.symmetric(vertical: gap), child: r),
        const SizedBox(height: 12),
        ArtLabel(label, color: kYachtColor),
      ],
    ),
  );
}

