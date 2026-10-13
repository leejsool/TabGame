import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/getcolor_rules.dart';
import '../ui/getcolor_painter.dart';

const Color _gcColor = Color(0xFF8E4EC6);

/// 겟 컬러 게임 방법.
GameTutorial getColorTutorial() => GameTutorial(
      title: '겟 컬러',
      color: _gcColor,
      steps: [
        TutorialStep(
          title: '같은 색끼리 한 병에 모아요',
          body: '병마다 여러 가지 색 물이 섞여 담겨 있어요. 물을 이 병 저 병으로 옮겨 부어서, '
              '한 병에는 한 가지 색만 가득 차게 모으면 이겨요.\n'
              '병 하나에는 물이 4칸까지 들어가요.',
          art: (context, accent) => _row(
            const [
              [0, 1, 0, 1],
              [1, 0, 1, 0],
              [],
            ],
            label: '섞여 있는 병들',
          ),
        ),
        TutorialStep(
          title: '병을 눌러 고르고, 다른 병에 부어요',
          body: '옮기고 싶은 병을 톡 누르면 위로 올라와요. 이어서 물을 받을 병을 누르면 맨 위 물이 그쪽으로 부어져요.\n'
              '고른 병을 다시 누르면 고름이 풀려요.',
          art: (context, accent) => _row(
            const [
              [0, 1, 2],
              [1, 2, 1],
              [],
            ],
            lift: {0},
            glow: {2},
            label: '고른 병 → 빈 병에 붓기',
          ),
        ),
        TutorialStep(
          title: '붓는 규칙',
          body: '받는 병이 비었거나, 맨 위 색이 부으려는 색과 같을 때만 부을 수 있어요. 자리가 모자라면 들어갈 만큼만 부어져요.\n'
              '맨 위에 같은 색이 여러 칸 이어져 있으면 한꺼번에 옮겨져요.',
          art: (context, accent) => _row(
            const [
              [2, 0, 1, 1],
              [0, 1],
              [1, 2, 2, 0],
            ],
            lift: {0},
            glow: {1},
            label: '맨 위가 같은 색(파랑)일 때 부어져요',
          ),
        ),
        TutorialStep(
          title: '한 가지 색으로 가득 차면 마개!',
          body: '병 하나가 한 가지 색으로 가득 차면 마개가 씌워져요. 모든 색의 병에 마개를 씌우면 클리어예요.\n'
              '푸는 데 걸린 시간과 부은 횟수가 기록돼요.',
          art: (context, accent) => _row(
            const [
              [0, 0, 0, 0],
              [1, 1, 1, 1],
              [2, 2, 2, 2],
              [],
            ],
            label: '다 모은 병은 마개로 막혀요',
          ),
        ),
        TutorialStep(
          title: '막혔을 땐?',
          body: '더 부을 곳이 없으면 아래 버튼을 써요.\n'
              '• 되돌리기: 마지막 수를 취소해요 (몇 번이든).\n'
              '• 병 더하기: 빈 병 하나를 추가해요 (한 판에 한 번).\n'
              '• 힌트: 지금 판을 끝까지 풀어 보고 다음 한 수를 알려 줘요. 이미 막힌 판이면 막혔다고 알려 줘요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ArtBadge(icon: Icons.undo_rounded, color: accent, label: '되돌리기'),
                ArtBadge(icon: Icons.add_circle_outline_rounded, color: accent, label: '병 더하기'),
                ArtBadge(icon: Icons.lightbulb_rounded, color: accent, label: '힌트'),
              ],
            ),
          ),
        ),
      ],
    );

/// 병 몇 개를 한 줄로 늘어놓은 그림. [lift]는 위로 올라온 병, [glow]는 반짝이는 병.
Widget _row(
  List<List<int>> bottles, {
  Set<int> lift = const {},
  Set<int> glow = const {},
  String? label,
}) {
  const bw = 56.0, gap = 22.0;
  final width = bottles.length * bw + (bottles.length - 1) * gap + 60;
  const height = bw * kBottleAspect + 70;
  return ArtCanvas(
    width: width < 300 ? 300 : width,
    height: height + (label == null ? 0 : 56),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: _RowPainter(bottles, lift, glow, bw, gap)),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          ArtLabel(label, color: _gcColor),
        ],
      ],
    ),
  );
}

class _RowPainter extends CustomPainter {
  _RowPainter(this.bottles, this.lift, this.glow, this.bw, this.gap);

  final List<List<int>> bottles;
  final Set<int> lift;
  final Set<int> glow;
  final double bw;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final total = bottles.length * bw + (bottles.length - 1) * gap;
    final left = (size.width - total) / 2;
    final baseY = size.height - bw * kBottleAspect - 8;
    for (var i = 0; i < bottles.length; i++) {
      final x = left + i * (bw + gap);
      canvas.save();
      canvas.translate(x, baseY);
      paintBottleShadow(canvas, bw);
      canvas.restore();
    }
    for (var i = 0; i < bottles.length; i++) {
      final x = left + i * (bw + gap);
      canvas.save();
      canvas.translate(x, baseY - (lift.contains(i) ? 30 : 0));
      final done = bottles[i].length == kBottleCapacity && bottles[i].every((c) => c == bottles[i].first);
      paintBottle(
        canvas,
        bw,
        layersOf(bottles[i]),
        done: done,
        glow: glow.contains(i) ? 1 : 0,
        glowColor: const Color(0xFF7CF0A0),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RowPainter old) => true;
}
