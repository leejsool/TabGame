import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/kt_icon.dart';

const Color _color = Color(0xFF5A54D6);

/// 건반 톡톡 게임 방법.
GameTutorial keytapTutorial() => GameTutorial(
      title: '건반 톡톡',
      color: _color,
      steps: [
        TutorialStep(
          title: '내려오는 검은 블록을 톡!',
          body: '네 줄 위로 검은 블록이 내려와요. 아래쪽부터 차례로 눌러요.\n'
              '블록을 칠 때마다 피아노 소리가 한 음씩 나서, 끝까지 치면 곡 하나가 돼요.\n'
              '여러 손가락으로 번갈아 치면 더 빨리 칠 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 220,
            height: 170,
            child: Center(child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: _Icon()))),
          ),
        ),
        const TutorialStep(
          title: '흰 칸을 누르거나 놓치면 끝',
          body: '블록이 없는 흰 칸을 누르거나, 블록이 화면 아래로 빠져나갈 때까지 못 치면 그 판은 끝나요.\n'
              '맨 아래 "시작" 블록을 누르는 순간부터 내려오기 시작해요.',
          icon: Icons.touch_app_rounded,
        ),
        const TutorialStep(
          title: '곡 완주: 바퀴마다 별 하나',
          body: '곡을 한 번 끝까지 치면 별 1개! 곡은 다시 처음부터 이어지고, 바퀴마다 더 빨라져요.\n'
              '세 바퀴를 모두 돌면 별 3개로 완주예요. 무한 모드는 여러 곡이 이어지고, 틀릴 때까지 점점 빨라져요.',
          icon: Icons.star_rounded,
        ),
        const TutorialStep(
          title: '같은 Wi‑Fi로 경주',
          body: '친구 2~4명(빈자리는 CPU)이 같은 곡, 같은 블록으로 동시에 쳐요.\n'
              '경주에서는 틀려도 끝나지 않아요. 흰 칸을 누르면 0.5초 동안 못 누르니 조심! 두 바퀴가 끝났을 때 가장 많이 친 사람이 1등이에요.\n'
              '누가 나가면 CPU가 대신 치다가, 돌아오면 다시 이어서 쳐요.',
          icon: Icons.wifi_rounded,
        ),
      ],
    );

class _Icon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width);
    paintKeytapIcon(canvas, size.width);
  }

  @override
  bool shouldRepaint(_Icon old) => false;
}
