import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../tutorial/uttt_tutorial.dart';
import 'uttt_lesson_screen.dart';
import 'uttt_board.dart';
import 'uttt_screen.dart';

/// CPU 대전 시작 전 설정: 난이도 + 내 표시(X/O).
class UtttSetupScreen extends StatefulWidget {
  const UtttSetupScreen({super.key});

  @override
  State<UtttSetupScreen> createState() => _UtttSetupScreenState();
}

class _UtttSetupScreenState extends State<UtttSetupScreen> {
  UttLevel _level = UttLevel.normal;
  int _side = kX;

  void _start() {
    final side = _side, level = _level;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => UtttScreen(mode: PlayMode.vsCpu, humanSide: side, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'ultimate_tictactoe',
      title: 'CPU와 대결',
      onStart: _start,
      tutorial: utttTutorial,
      onLesson: () => openUtttLesson(context),
      children: [
        const VsSectionTitle('내 표시'),
        VsChoiceRow(cards: [
          _SideCard(side: kX, selected: _side == kX, onTap: () => setState(() => _side = kX)),
          _SideCard(side: kO, selected: _side == kO, onTap: () => setState(() => _side = kO)),
        ]),
        const VsHint('X가 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
        const VsSectionTitle('CPU 난이도', topGap: 24),
        VsLevelPicker<UttLevel>(
          levels: UttLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => l.description,
        ),
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.side, required this.selected, required this.onTap});

  final int side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sideColor(side);
    return VsChoiceCard(
      color: color,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _SidePainter(side))),
          const SizedBox(height: 8),
          Text(side == kX ? 'X' : 'O', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(side == kX ? '먼저 시작' : '나중에 시작', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SidePainter extends CustomPainter {
  const _SidePainter(this.side);
  final int side;

  @override
  void paint(Canvas canvas, Size size) =>
      drawMark(canvas, side, Offset.zero & size, 1, strokeWidth: size.width * 0.14);

  @override
  bool shouldRepaint(_SidePainter old) => old.side != side;
}
