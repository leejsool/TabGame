import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/quoridor_rules.dart';
import '../ui/quoridor_board.dart';

int _c(int r, int c) => r * kBoard + c;

/// 쿼리도 게임 방법.
GameTutorial quoridorTutorial() => GameTutorial(
      title: '쿼리도',
      color: kQuoridorColor,
      steps: [
        TutorialStep(
          title: '맞은편 줄에 먼저 닿으면 이겨요',
          body: '9×9 판의 아래쪽 가운데에서 내 말이, 위쪽 가운데에서 상대 말이 시작해요.\n'
              '내 말을 맞은편 줄(맨 위 줄)까지 먼저 데려가는 사람이 이겨요.',
          art: (context, accent) => _art(QState.start(2), label: '아래 빨강이 맨 위 줄로!'),
        ),
        TutorialStep(
          title: '자기 차례에는 둘 중 하나',
          body: '말을 한 칸 옮기거나(앞뒤 양옆), 벽을 하나 세워요.\n'
              '말을 옮길 때는 점이 찍힌 칸 중에서 눌러요.',
          art: (context, accent) {
            final s = QState.start(2);
            return _art(s, targets: s.legalPawnMoves(0), label: '갈 수 있는 칸에 점이 찍혀요');
          },
        ),
        TutorialStep(
          title: '벽을 세워 길을 막아요',
          body: '벽은 두 칸 길이예요. 말은 벽을 넘거나 뚫고 갈 수 없어서, 벽을 세우면 상대가 돌아가야 해요.\n'
              '내 앞에 쌓인 나무막대를 판으로 끌어다 놓으면 가장 가까운 점에 붙어요. 막대 위에 뜨는 돌리기 아이콘으로 방향을 바꾸고, 체크(✓)를 눌러 세워요.',
          art: (context, accent) {
            final s = QState.start(2)
              ..pawn[0] = _c(5, 4)
              ..pawn[1] = _c(2, 4);
            s.h[2 * kAnchors + 3] = true; // 2행 아래, 3~4열
            s.h[2 * kAnchors + 5] = true; // 2행 아래, 5~6열
            return _art(s, wallMode: true, pickRow: 2, pickCol: 1, wallOrient: 0, label: '막힌 만큼 상대가 더 걸어요');
          },
        ),
        TutorialStep(
          title: '말을 뛰어넘어요',
          body: '바로 옆에 다른 말이 있으면 그 말을 뛰어넘어서 한 번에 두 칸을 가요.',
          art: (context, accent) {
            final s = QState.start(2)
              ..pawn[0] = _c(5, 4)
              ..pawn[1] = _c(4, 4);
            return _art(s, targets: [_c(3, 4)], label: '파랑 말을 뛰어넘기');
          },
        ),
        TutorialStep(
          title: '뒤가 막히면 옆으로 비껴 가요',
          body: '뛰어넘을 칸 뒤에 벽이나 판 끝, 또 다른 말이 있으면 그 말의 양옆 칸으로 비껴 갈 수 있어요.',
          art: (context, accent) {
            final s = QState.start(2)
              ..pawn[0] = _c(5, 4)
              ..pawn[1] = _c(4, 4);
            s.h[3 * kAnchors + 4] = true; // 3행 아래(= 파랑 말 뒤), 4~5열
            return _art(s, targets: [_c(4, 3), _c(4, 5)], label: '양옆 칸으로');
          },
        ),
        TutorialStep(
          title: '길을 완전히 막으면 안 돼요',
          body: '벽을 세워도 모든 말에게 도착 줄로 가는 길이 하나는 남아 있어야 해요.\n'
              '길을 완전히 막아 버리는 벽은 세울 수 없어요. (빨갛게 보여요)',
          art: (context, accent) {
            final s = QState.start(2)..pawn[1] = _c(0, 0);
            s.h[0] = true; // 0행 아래, 0~1열
            return _art(s, wallMode: true, pickRow: 0, pickCol: 0, wallOrient: 1, pickOk: false, label: '여기에 세우면 갇혀요');
          },
        ),
        TutorialStep(
          title: '4명이 할 때',
          body: '4명이면 네 쪽에서 시작해요 (아래 → 왼쪽 → 위 → 오른쪽 차례). 각자 맞은편 가장자리가 도착 줄이에요.\n'
              '벽은 5개씩만 가져서, 아껴 쓰는 게 중요해요.',
          art: (context, accent) => _art(QState.start(4), label: '네 색깔이 맞은편으로'),
        ),
        TutorialStep(
          title: '누구와 하나요?',
          body: 'CPU와 2명 또는 4명이 할 수 있고, 한 기기를 돌려 가며 함께 할 수도 있어요.\n'
              '같은 Wi‑Fi에 연결된 기기끼리도 2명 또는 4명이 할 수 있어요. 한 사람이 방을 만들고 나머지가 들어오면 시작해요.',
          icon: Icons.wifi_rounded,
        ),
      ],
    );

Widget _art(
  QState s, {
  List<int> targets = const [],
  bool wallMode = false,
  int pickRow = -1,
  int pickCol = -1,
  int wallOrient = 0,
  bool pickOk = true,
  required String label,
}) {
  return ArtCanvas(
    width: 340,
    height: 380,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 320,
          height: 320,
          child: QBoardView(state: s, targets: targets, wallMode: wallMode, pickRow: pickRow, pickCol: pickCol, wallOrient: wallOrient, pickOk: pickOk),
        ),
        const SizedBox(height: 10),
        ArtLabel(label, color: kQuoridorColor),
      ],
    ),
  );
}
