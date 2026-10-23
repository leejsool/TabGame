import 'package:flutter/material.dart';

import '../../../tutorial/tutorial.dart';
import '../core/stones_rules.dart';
import '../ui/stones_board.dart';

Widget _board(StonesState s, {int? selectedRow, bool showGaps = false}) => SizedBox(
      width: 360,
      height: 130,
      child: StonesBoard(state: s, onTapCell: null, selectedRow: selectedRow, showGaps: showGaps),
    );

/// 바둑돌 옮기기 게임 방법.
GameTutorial stonesTutorial() => GameTutorial(
      title: '바둑돌 옮기기',
      color: kStonesColor,
      steps: [
        TutorialStep(
          title: '갑은 흰 돌, 을은 검은 돌',
          body: '3줄짜리 판의 줄마다 흰 돌 하나와 검은 돌 하나가 있어요.\n'
              '갑은 흰 돌, 을은 검은 돌을 움직이고, 갑부터 번갈아 둬요.',
          art: (context, accent) => _board(kStartBoard.start()),
        ),
        TutorialStep(
          title: '같은 줄에서 옮겨요',
          body: '자기 돌 하나를 같은 줄의 다른 빈칸으로 옮겨요. 상대 쪽으로 다가가도 되고, 뒤로 물러나도 돼요.\n'
              '하지만 상대 돌을 건너뛸 수는 없어요. 점이 찍힌 칸이 갈 수 있는 칸이에요.',
          art: (context, accent) => _board(kStartBoard.start(), selectedRow: 2),
        ),
        TutorialStep(
          title: '못 움직이면 져요',
          body: '자기 차례에 움직일 수 있는 돌이 하나도 없으면 져요.\n'
              '모든 줄에서 두 돌이 딱 붙고, 내 돌이 벽에 닿아 있으면 더 움직일 수 없어요.',
          art: (context, accent) => _board(StonesState([0, 0, 0], [1, 1, 1])),
        ),
        TutorialStep(
          title: '빈칸 수를 세어 보세요',
          body: '"빈칸 수 보기"를 누르면 줄마다 두 돌 사이 빈칸 수가 보여요.\n'
              '이 수들을 어떻게 맞춰 두면 이길 수 있을지 생각해 보세요!',
          art: (context, accent) => _board(kStartBoard.start(), showGaps: true),
        ),
      ],
    );
