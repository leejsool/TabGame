import 'package:flutter/material.dart';

import '../../../tutorial/tutorial.dart';
import '../core/park_rules.dart';
import '../ui/park_board.dart';

Widget _board(List<Walk> steps) => SizedBox(width: 300, height: 300, child: ParkBoard(stage: kParkStages[0], steps: steps));

const _r = Walk.right, _d = Walk.down;

/// 공원 길찾기 방법.
GameTutorial parkTutorial() => GameTutorial(
      title: '공원 길찾기',
      color: kParkColor,
      steps: [
        TutorialStep(
          title: 'A에서 B까지 걸어요',
          body: '선분이 산책로, 초록 ○가 숲이에요. A로 들어가서 가장 짧은 길(오른쪽·아래로만)로 B까지 걸어요.',
          art: (context, accent) => _board(const []),
        ),
        TutorialStep(
          title: '손가락으로 그어요',
          body: 'A에 손가락을 대고 산책로를 따라 그으면 길이 그려져요. 되돌아가면 지워져요.',
          art: (context, accent) => _board(const [_r, _d]),
        ),
        TutorialStep(
          title: '숲이 왼편? 오른편?',
          body: '걷는 방향을 바라볼 때 바로 왼편에 숲이 있으면 파란 "왼", 바로 오른편에 있으면 주황 "오"가 붙어요.',
          art: (context, accent) => _board(const [_r, _d, _d, _r]),
        ),
        TutorialStep(
          title: '둘 다 있어야 해요',
          body: '"왼" 구간과 "오" 구간이 모두 있는 길만 조건에 맞아요. 찾은 길은 아래(옆)에 모이고, 같은 길을 또 그으면 "이미 찾았던 길이에요"라고 알려 줘요.\n'
              '2×2, 3×3, 4×4 공원에서 조건에 맞는 길을 모두 찾아 보세요!',
          art: (context, accent) => _board(const [_d, _r, _r, _d]),
        ),
      ],
    );
