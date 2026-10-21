import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../pinball_icon.dart';

const Color _pinballColor = Color(0xFF1B998B);

/// 핀볼 게임 방법.
GameTutorial pinballTutorial() => GameTutorial(
      title: '핀볼',
      color: _pinballColor,
      steps: [
        TutorialStep(
          title: '시간 안에 목표 점수를 채워요',
          body: '라운드마다 목표 점수와 제한 시간이 있어요. 시간 안에 점수를 채우면 다음 라운드로, 못 채우면 도전이 끝나요.\n'
              '공(목숨)은 3개예요. 3개를 다 놓쳐도 끝나요.\n'
              '점수를 채운 순간 판이 멈추고 업그레이드를 고를 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 220,
            height: 170,
            child: Center(child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: _Icon()))),
          ),
        ),
        const TutorialStep(
          title: '공을 쏘고 플리퍼로 튕겨요',
          body: '공이 오른쪽 통로에서 기다리고 있으면, 화면 오른쪽 끝을 꾹 눌렀다 떼세요. 오래 누를수록 세게 나가요. (너무 약하면 다시 내려와요)\n'
              '화면 왼쪽을 누르면 왼쪽 플리퍼가, 오른쪽을 누르면 오른쪽 플리퍼가 올라가요. 두 손으로 같이 눌러도 돼요.',
          icon: Icons.touch_app_rounded,
        ),
        const TutorialStep(
          title: '연속으로 맞히면 점수가 불어나요',
          body: '범퍼, 슬링샷, 표적, 별 불빛, 스피너를 맞히면 점수가 올라가요. 쉬지 않고 연속으로 맞히면 콤보 배수가 커져요.\n'
              '아래 접시의 알약 4개를 모두 맞히면 잭팟! 양옆 표적 세 개씩을 다 맞히면 블랙홀(R 마크)에 불이 켜지고, 거기에 공이 들어가면 멀티볼이에요.',
          icon: Icons.stacked_line_chart_rounded,
        ),
        const TutorialStep(
          title: '공을 놓치면 목숨이 줄어요',
          body: '공이 아래로 빠지면 남은 공이 하나 줄고, 새 공이 통로에 나와요. 빨리 다시 쏘세요!\n'
              '"흔들기" 단추로 판을 흔들어 공의 방향을 바꿀 수 있어요. 너무 자주 흔들면 틸트가 나서 잠깐 플리퍼가 멈춰요.',
          icon: Icons.favorite_rounded,
        ),
        const TutorialStep(
          title: '업그레이드를 골라요',
          body: '라운드를 깨면 공짜 카드 3장 중 하나를 골라요. "상점"에서는 점수를 내고 카드를 더 살 수 있어요. 다 고르면 "다음 라운드 시작"을 누르세요.\n'
              '점수를 쓰면 다음 목표를 채우기가 그만큼 어려워지고, 상점 값은 살수록 빠르게 올라요. 점수가 붙는 방법은 첫 화면의 "점수 계산법"에 있어요.',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );

class _Icon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width);
    paintPinballIcon(canvas, size.width);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
