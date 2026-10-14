import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/goblet_rules.dart';
import '../ui/goblet_piece.dart';

const Color _gobletColor = Color(0xFF00798C);

/// 고블렛 고블러스 게임 방법.
GameTutorial gobletTutorial() => GameTutorial(
      title: '고블렛 고블러스',
      color: _gobletColor,
      steps: [
        TutorialStep(
          title: '세 개를 한 줄로!',
          body: '3×3 판에서 가로·세로·대각선으로 내 말 3개가 "위에서 보이게" 나란히 놓이면 이겨요.\n'
              '틱택토와 비슷하지만, 말을 덮어씌울 수 있다는 점이 크게 달라요.',
          art: (context, accent) => ArtCanvas(
            width: 304,
            height: 304,
            child: _board(
              const {
                0: [(Team.red, 2)],
                4: [(Team.red, 3)],
                8: [(Team.red, 1)],
                1: [(Team.blue, 2)],
                5: [(Team.blue, 1)],
              },
              win: const [0, 4, 8],
            ),
          ),
        ),
        TutorialStep(
          title: '말은 크기가 3가지',
          body: '말은 크기가 3가지예요. 아랫단의 점이 1개, 2개, 3개로 크기를 알려 줘요. 크기마다 2개씩, 모두 6개를 가져요.\n'
              '팀은 색과 귀 모양으로 구분해요: 빨강팀은 뾰족한 귀, 파랑팀은 둥근 귀예요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 330,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in Team.values) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var s = 1; s <= 3; s++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _piece(t, s, 34.0 + s * 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ArtLabel(
                    t == Team.red ? '빨강팀 (뾰족한 귀)' : '파랑팀 (둥근 귀)',
                    color: TeamPalette.of(t).dark,
                    filled: false,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '큰 말은 작은 말을 덮어요',
          body: '큰 말은 작은 말 위에 덮어씌울 수 있어요. 내 말도, 상대 말도요!\n'
              '덮인 말은 보이지 않고, 아래에 뭐가 깔려 있다는 표시도 없어요. 무엇을 덮었는지는 기억해야 해요! '
              '같은 크기끼리는 덮을 수 없어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 280,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _cell([(Team.red, 1)], 84),
                const Icon(Icons.add_rounded, size: 30, color: Color(0xFF3B2F2F)),
                _piece(Team.blue, 3, 84, lift: true),
                const Icon(Icons.arrow_forward_rounded, size: 30, color: Color(0xFF3B2F2F)),
                _cell([(Team.red, 1), (Team.blue, 3)], 84),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '내 차례에는 둘 중 하나',
          body: '내 차례에는 둘 중 하나를 해요.\n'
              '① 대기 중인 말을 판에 올리기\n'
              '② 판 위에 있는 내 말(맨 위에 보이는 것)을 다른 칸으로 옮기기\n'
              '말을 끌어서 칸에 놓거나, 말을 톡 누르고 칸을 톡 눌러요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 340,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _modeCard(
                  '대기 말 올리기',
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _piece(Team.red, 2, 56),
                      const Icon(Icons.arrow_downward_rounded, size: 30, color: Color(0xFF3B2F2F)),
                      _board(const {4: [(Team.blue, 1)]}, small: true),
                    ],
                  ),
                ),
                _modeCard(
                  '판 위의 말 옮기기',
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _board(const {0: [(Team.red, 2)], 8: [(Team.blue, 3)]}, small: true),
                      const Icon(Icons.arrow_downward_rounded, size: 30, color: Color(0xFF3B2F2F)),
                      _board(const {2: [(Team.red, 2)], 8: [(Team.blue, 3)]}, small: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '말을 들어 올릴 땐 조심!',
          body: '내 말을 들어 올렸을 때 그 아래에 깔려 있던 상대 말이 드러나면서 상대의 줄이 완성될 수 있어요. '
              '그러면 내가 막지 못하는 한 상대가 이겨요!\n'
              '같은 모양이 3번 반복되면 무승부예요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _modeCard(
                  '들어 올리기 전',
                  _board(
                    const {
                      0: [(Team.blue, 1)],
                      1: [(Team.blue, 2), (Team.red, 3)],
                      2: [(Team.blue, 1)],
                    },
                    small: true,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 34, color: Color(0xFF3B2F2F)),
                _modeCard(
                  '빨강 말을 옮기면…',
                  _board(
                    const {
                      0: [(Team.blue, 1)],
                      1: [(Team.blue, 2)],
                      2: [(Team.blue, 1)],
                      7: [(Team.red, 3)],
                    },
                    small: true,
                    win: const [0, 1, 2],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

Widget _modeCard(String title, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gobletColor.withValues(alpha: 0.5), width: 2),
          ),
          child: child,
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
      ],
    );

/// 말 하나 그림. [size] 1~3, [px]는 그림 한 변 (실제 말은 크기에 따라 줄여서 그린다).
Widget _piece(Team t, int size, double px, {bool lift = false}) {
  final w = px * kPieceScale[size - 1] / kPieceScale[2];
  return SizedBox(
    width: px,
    height: px,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: lift ? const Offset(0, -6) : Offset.zero,
        child: SizedBox(
          width: w,
          height: w,
          child: CustomPaint(painter: GobblerPainter(team: t, size: size)),
        ),
      ),
    ),
  );
}

/// 칸 하나: [stack]은 아래부터 쌓인 말들. 맨 위 말만 보이고, 덮인 말은 표시하지 않는다.
Widget _cell(List<(Team, int)> stack, double px) {
  return Container(
    width: px,
    height: px,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD9A55F), width: 2.5),
    ),
    child: Stack(
      children: [
        Positioned.fill(child: _piece(stack.last.$1, stack.last.$2, px - 8)),
      ],
    ),
  );
}

/// 3×3 판 그림. [pieces]: 칸 번호(0~8) → 아래부터 쌓인 말들.
Widget _board(Map<int, List<(Team, int)>> pieces, {List<int>? win, bool small = false}) {
  final cell = small ? 40.0 : 96.0;
  final gap = small ? 4.0 : 8.0;
  final side = cell * 3 + gap * 2;
  Widget one(int i) {
    final stack = pieces[i];
    final inWin = win?.contains(i) ?? false;
    if (stack == null || stack.isEmpty) {
      return Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(cell * 0.12),
          border: Border.all(color: const Color(0xFFD9A55F), width: small ? 1.5 : 2.5),
        ),
      );
    }
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cell * 0.12),
        border: Border.all(
          color: inWin ? const Color(0xFFE2A400) : const Color(0xFFD9A55F),
          width: inWin ? (small ? 3 : 4) : (small ? 1.5 : 2.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cell * 0.12),
        child: _cellContent(stack, cell),
      ),
    );
  }

  return SizedBox(
    width: side,
    height: side,
    child: Column(
      children: [
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Row(
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) SizedBox(width: gap),
                one(r * 3 + c),
              ],
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _cellContent(List<(Team, int)> stack, double px) {
  return Container(
    color: const Color(0xFFFFF7E8),
    child: Stack(
      children: [
        Positioned.fill(child: _piece(stack.last.$1, stack.last.$2, px - 4)),
      ],
    ),
  );
}
