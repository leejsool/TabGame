import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/snake_icon.dart';

const Color _snakeColor = Color(0xFF2ED1A2);

/// 지렁이의 모험 게임 방법.
GameTutorial snakeTutorial() => GameTutorial(
      title: '지렁이의 모험',
      color: _snakeColor,
      steps: [
        TutorialStep(
          title: '먹고 자라서 1등을 노려요',
          body: '필드에 흩어진 빛나는 먹이를 먹으면 지렁이가 길어지고, 아주 조금씩 굵어져요.\n'
              '한 필드에 지렁이 30마리가 있어요. 오른쪽 위 순위표에 1~5등과 내 순위·점수가 늘 보여요.',
          art: (context, accent) => ArtCanvas(
            width: 220,
            height: 170,
            child: Center(child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: _Icon()))),
          ),
        ),
        const TutorialStep(
          title: '왼쪽은 방향, 오른쪽은 부스터',
          body: '화면 왼쪽을 누른 채 끌면 그쪽으로 머리를 돌려요. 손을 떼도 그 방향으로 계속 가요.\n'
              '화면 오른쪽을 꾹 누르고 있으면 부스터! 두 배로 빨라지지만, 누르는 동안 몸이 조금씩 줄어서 꼬리 뒤에 먹이로 떨어져요.',
          icon: Icons.bolt_rounded,
        ),
        const TutorialStep(
          title: '머리를 박으면 끝나요',
          body: '다른 지렁이의 몸에 내 머리가 닿거나, 필드 끝의 빨간 벽에 박으면 끝나요. (내 몸에는 부딪히지 않아요)\n'
              '끝난 지렁이는 몸을 따라 큰 먹이로 흩어져요. 거꾸로, 남의 앞을 가로막아 내 몸에 박게 만들면 그 먹이를 차지할 수 있어요!',
          icon: Icons.warning_amber_rounded,
        ),
        const TutorialStep(
          title: '똑똑한 CPU를 조심해요',
          body: 'CPU 중에는 어리숙한 지렁이도 있지만, 내 앞을 가로막거나 커다란 몸으로 빙 둘러싸서 가두려는 영리한 지렁이도 있어요.\n'
              '갇혔다면 서두르지 말고 둘레를 돌며 기다려 보세요. 영리한 지렁이도 언젠가는 실수로 틈을 열어요.',
          icon: Icons.psychology_alt_rounded,
        ),
        const TutorialStep(
          title: '친구는 언제든 들어올 수 있어요',
          body: '"바로 시작하기"를 누르면 내 기기에 방이 열리고 CPU들과 바로 시작해요.\n'
              '같은 Wi‑Fi의 친구가 "친구 판에 들어가기"로 들어오면 사람이 한 명 늘고, 그만큼 CPU가 다시 태어나지 않아 늘 30마리 정도가 돼요.\n'
              '친구가 잠깐 나가면 CPU가 대신 움직이다가, 돌아오면 자기 지렁이를 다시 몰아요.',
          icon: Icons.wifi_rounded,
        ),
      ],
    );

class _Icon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width);
    paintSnakeIcon(canvas, size.width);
  }

  @override
  bool shouldRepaint(_Icon old) => false;
}
