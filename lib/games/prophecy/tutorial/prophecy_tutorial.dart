import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/prophecy_examples.dart';
import '../core/prophecy_rules.dart';
import '../ui/prophecy_board.dart';

/// 예언 게임 방법.
GameTutorial prophecyTutorial() => GameTutorial(
      title: '예언',
      color: kProphColor,
      steps: [
        TutorialStep(
          title: '예언의 판',
          body: '두 사람이 서로 다른 색 펜을 들어요. 한 사람은 분홍, 다른 사람은 청록이에요.\n'
              '행 4~8개, 열 4~8개의 표 위에서 해요. 시작할 때 표의 크기를 직접 고를 수 있어요.',
          art: (context, accent) => _board(emptyBoard(), counts: false),
        ),
        TutorialStep(
          title: '번갈아 숫자나 X를 써요',
          body: '자기 차례에 빈칸 하나를 골라 숫자나 X를 써요. 칸을 톡 누르고, 아래에 나타나는 숫자판에서 고르면 돼요.\n'
              'X는 칸을 채우기만 하고, 그 칸에는 숫자가 나타나지 않게 해요.',
          art: (context, accent) => _board(startedBoard(), selected: 6, counts: false),
        ),
        TutorialStep(
          title: '숫자는 예언이에요',
          body: '쓰는 숫자는 "이 줄에 숫자가 모두 몇 개 나타날까?"에 대한 예언이에요.\n'
              '예를 들어 어떤 행에 4를 쓰면 "이 행에는 숫자가 결국 4개 있을 거야"라고 예언한 거예요. X는 숫자가 아니라서 세지 않아요.',
          art: (context, accent) => _board(startedBoard(), counts: true),
        ),
        TutorialStep(
          title: '같은 숫자는 한 줄에 한 번만',
          body: '한 행이나 열에는 같은 숫자를 두 번 쓸 수 없어요. 같은 예언을 되풀이하면 안 되니까요.\n'
              '여기서는 4행에 이미 4가 있어서, 같은 행의 맨 왼쪽 칸에는 4를 쓸 수 없어요.',
          art: (context, accent) => _board(repeatBoard(), flags: {kRepeatCell: const Color(0xFFD64545)}, counts: false),
        ),
        TutorialStep(
          title: '쓸 숫자가 없으면 저절로 X',
          body: '어떤 숫자를 써도 같은 행이나 열의 숫자와 겹쳐서 칸을 채울 수 없게 되면, 그 칸은 저절로 X가 돼요.\n'
              '이것은 누구의 차례도 쓰지 않아요. 오른쪽 그림처럼 0행 0열에서 1·2·3·4를 모두 쓸 수 없게 됐어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 300,
            child: Row(
              children: [
                Expanded(child: _boardIn(deadCellBefore(), flags: {0: const Color(0xFFD99A00)}, counts: false)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 28, color: kProphColor),
                const SizedBox(width: 6),
                Expanded(child: _boardIn(deadCellAfter(), counts: false)),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '다 채우면 줄마다 세어요',
          body: '표가 가득 차면 행마다, 열마다 숫자(X 빼고)가 몇 개인지 세어요. 표 오른쪽과 아래에 그 개수가 적혀 있어요.',
          art: (context, accent) => _board(bookBoard(), counts: true),
        ),
        TutorialStep(
          title: '맞힌 예언은 동그라미!',
          body: '줄의 숫자 개수와 같은 숫자를 쓴 사람이 맞힌 거예요. 맞힌 숫자에 동그라미를 쳐요.\n'
              '행에서 맞혔으면 동그라미 양옆에 좌우 화살표, 열에서 맞혔으면 위아래 화살표가 붙어요.',
          art: (context, accent) => _board(bookBoard(), counts: true, reveal: 1),
        ),
        TutorialStep(
          title: '점수는 맞힌 숫자만큼',
          body: '맞힌 숫자가 곧 점수예요. 5를 맞히면 5점, 3을 맞히면 3점!\n'
              '한 숫자가 행에서도 열에서도 맞으면 두 번 얻어요. 점수가 더 높은 사람이 이겨요.\n'
              '한 기기로 둘이서 하거나, CPU와 대결할 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 300,
            child: Column(
              children: [
                Expanded(child: _boardIn(bookBoard(), counts: true, reveal: 1)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ArtLabel('분홍 ${bookBoard().scores()[0]}점', color: kPenPink),
                    ArtLabel('청록 ${bookBoard().scores()[1]}점 · 승리', color: kPenTeal),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

Widget _boardIn(ProphState s, {Map<int, Color> flags = const {}, int selected = -1, bool counts = true, double reveal = 0}) =>
    ProphBoardView(state: s, flags: flags, selected: selected, showCounts: counts, reveal: reveal);

Widget _board(ProphState s, {Map<int, Color> flags = const {}, int selected = -1, bool counts = true, double reveal = 0}) {
  return ArtCanvas(
    width: 340,
    height: 300,
    child: _boardIn(s, flags: flags, selected: selected, counts: counts, reveal: reveal),
  );
}
