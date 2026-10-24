import 'package:flutter/material.dart';

import '../../../versus/vs_screen_parts.dart';
import '../core/stones_rules.dart';
import '../tutorial/stones_tutorial.dart';

// 바둑돌 옮기기 화면의 작은 조각들: 안내 상자, 작은 바둑돌, 규칙 창.

class StonesInfoCard extends StatelessWidget {
  const StonesInfoCard({super.key, required this.color, required this.icon, required this.title, required this.text});

  final Color color;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

/// 선수 칩·결과 창에 쓰는 작은 바둑돌.
class StoneDot extends StatelessWidget {
  const StoneDot({super.key, required this.side, required this.size});

  final Side side;
  final double size;

  @override
  Widget build(BuildContext context) {
    final white = side == Side.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: white ? const [Colors.white, Color(0xFFD6D6D6)] : const [Color(0xFF5A5A5A), Color(0xFF111111)],
        ),
        border: Border.all(color: white ? const Color(0xFF555555) : Colors.black, width: 1.2),
      ),
    );
  }
}

Future<void> showStonesRules(BuildContext context) => showVsRules(
      context,
      title: '바둑돌 옮기기 규칙',
      lines: const [
        '갑은 흰 돌, 을은 검은 돌을 움직이며 갑부터 번갈아 둬요.',
        '자기 돌 한 개를 같은 행의 다른 빈칸으로 옮겨요. 앞으로도, 뒤로도 갈 수 있어요.',
        '다른 돌을 건너뛸 수는 없어요.',
        '더는 움직일 수 없는 사람이 져요.',
        '세 행의 빈칸이 모두 0이 되면 승부가 정해진 거예요. 남은 수는 자동으로 둬서 끝내요.',
        '옮길 칸을 바로 누르면 그 행의 내 돌이 옮겨 가요. 내 돌을 먼저 누르면 갈 수 있는 칸이 점으로 보여요.',
        '내 돌을 손가락으로 끌어서 원하는 칸에 놓아도 돼요.',
      ],
      openTutorial: () => stonesTutorial().open(context),
    );
