import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/dandelion_rules.dart';
import '../ui/dandelion_art.dart';

/// 민들레 게임 방법.
GameTutorial dandelionTutorial() => GameTutorial(
      title: '민들레',
      color: kDandelionColor,
      steps: [
        TutorialStep(
          title: '민들레와 바람',
          body: '한 사람은 민들레, 다른 한 사람은 바람이 돼요.\n'
              '민들레는 초원(5×5칸) 전체를 꽃과 씨앗으로 덮으면 이기고, '
              '바람은 한 칸이라도 덮이지 않게 하면 이겨요.',
          art: (context, accent) => _board(_cells(const [7, 6, 19, 5])),
        ),
        TutorialStep(
          title: '먼저 꽃을 심어요',
          body: '민들레가 먼저 아무 칸에나 꽃을 심어요. 칸을 톡 누르면 돼요.',
          art: (context, accent) => _board(_cells(const [7]), rings: const {7}, ringColor: kDandelionColor),
        ),
        TutorialStep(
          title: '바람이 불면 씨앗이 날아가요',
          body: '이번에는 바람 차례예요. 방향을 하나 고르면, 꽃에서 그 방향으로 씨앗이 날아가 길에 있는 빈칸을 채워요.\n'
              '여기서는 왼쪽으로 불어서 꽃 왼쪽 두 칸이 씨앗으로 덮였어요.',
          art: (context, accent) => _board(_cells(const [7, 6]), windDir: WindDir.left),
        ),
        TutorialStep(
          title: '같은 방향은 한 번뿐',
          body: '바람은 8방향 가운데 7방향만 불 수 있어요. 한 번 분 방향은 다시 못 불어요.\n'
              '나침반에서 흐려진 화살표가 이미 분 방향이에요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 340,
            child: Center(
              child: DandelionCompass(
                size: 280,
                usedMask: (1 << WindDir.left.index) | (1 << WindDir.downLeft.index),
                enabled: true,
                windsLeft: 5,
              ),
            ),
          ),
        ),
        TutorialStep(
          title: '꽃이 늘어나면 씨앗도 늘어나요',
          body: '번갈아 하면서 민들레는 꽃을 더 심어요. 빈칸 말고 씨앗이 있는 칸에도 심을 수 있어요.\n'
              '바람이 불면 모든 꽃에서 씨앗이 날아가요. 하지만 씨앗에서는 씨앗이 나오지 않아요.',
          art: (context, accent) => _board(
            _cells(const [7, 6, 19, 5]),
            windDir: WindDir.downLeft,
            rings: const {19},
            ringColor: kDandelionColor,
          ),
        ),
        TutorialStep(
          title: '일곱 번째 바람이 지나면 끝!',
          body: '바람이 일곱 번 불고 나면 게임이 끝나요.\n'
              '초원이 가득 찼으면 민들레의 승리, 빈칸이 하나라도 남았으면 바람의 승리예요.\n'
              '한 기기로 둘이서 하거나, CPU와 대결할 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 340,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mini(_full(), '민들레 승리', kDandelionColor),
                _mini(_full(hole: 14), '바람 승리', kWindColor),
              ],
            ),
          ),
        ),
      ],
    );

/// 수 목록(민들레: 칸 번호, 바람: 방향 번호)을 두고 난 뒤의 칸들.
List<int> _cells(List<int> moves) => DandState.fromMoves(moves).cells;

/// 책의 마지막 그림처럼 꽃 일곱 송이와 씨앗으로 가득 찬 초원 ([hole]이 있으면 그 칸만 비어 있다).
List<int> _full({int? hole}) {
  final cells = List<int>.filled(kSize * kSize, kSeed);
  for (final f in const [4, 7, 10, 18, 20, 21, 24]) {
    cells[f] = kFlower;
  }
  if (hole != null) cells[hole] = kEmpty;
  return cells;
}

Widget _board(
  List<int> cells, {
  WindDir? windDir,
  Set<int> rings = const {},
  Color ringColor = kWindColor,
}) {
  return ArtCanvas(
    width: 340,
    height: 340,
    child: CustomPaint(
      painter: DandScenePainter(
        cells: cells,
        windDir: windDir,
        streaksStatic: windDir != null,
        rings: rings,
        ringColor: ringColor,
      ),
    ),
  );
}

Widget _mini(List<int> cells, String label, Color color) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 150, height: 150, child: CustomPaint(painter: DandScenePainter(cells: cells))),
      const SizedBox(height: 10),
      ArtLabel(label, color: color),
    ],
  );
}
