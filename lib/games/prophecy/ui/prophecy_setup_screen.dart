import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/prophecy_ai.dart';
import '../tutorial/prophecy_tutorial.dart';
import 'prophecy_board.dart';
import 'prophecy_lesson_screen.dart';
import 'prophecy_screen.dart';
import 'table_picker.dart';

/// 시작 전 설정: 표의 크기 (+ CPU 대결이면 먼저/나중과 난이도).
class ProphecySetupScreen extends StatefulWidget {
  const ProphecySetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<ProphecySetupScreen> createState() => _ProphecySetupScreenState();
}

class _ProphecySetupScreenState extends State<ProphecySetupScreen> {
  int _rows = 5, _cols = 5;
  ProphLevel _level = ProphLevel.normal;
  int _side = 0; // 0 = 먼저 쓰기, 1 = 나중에 쓰기

  bool get _vsCpu => widget.mode == PlayMode.vsCpu;

  void _start() {
    final rows = _rows, cols = _cols, side = _side, level = _level, mode = widget.mode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ProphecyScreen(mode: mode, rows: rows, cols: cols, humanSide: side, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'prophecy',
      title: _vsCpu ? '예언 · CPU와 대결' : '예언 · 둘이서',
      onStart: _start,
      tutorial: prophecyTutorial,
      onLesson: () => openProphecyLesson(context),
      children: [
        const VsSectionTitle('표의 크기'),
        Center(child: TablePicker(rows: _rows, cols: _cols, onChanged: (r, c) => setState(() {
          _rows = r;
          _cols = c;
        }))),
        const VsHint('칸이 많을수록 판이 길어져요. 처음에는 4×4나 5×5로 해 보세요.'),
        if (_vsCpu) ...[
          const VsSectionTitle('나는', topGap: 24),
          VsChoiceRow(cards: [
            _PenCard(side: 0, selected: _side == 0, onTap: () => setState(() => _side = 0)),
            _PenCard(side: 1, selected: _side == 1, onTap: () => setState(() => _side = 1)),
          ]),
          const VsHint('다음 판부터는 번갈아 시작해요.'),
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<ProphLevel>(
            levels: ProphLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
        ],
      ],
    );
  }
}

class _PenCard extends StatelessWidget {
  const _PenCard({required this.side, required this.selected, required this.onTap});

  final int side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = penColor(side);
    return VsChoiceCard(
      color: color,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Text('7', style: TextStyle(fontSize: 44, height: 1.0, color: color, fontWeight: side == 0 ? FontWeight.w500 : FontWeight.w900)),
          const SizedBox(height: 6),
          Text(side == 0 ? '먼저 쓰기' : '나중에 쓰기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(side == 0 ? '분홍 펜' : '청록 펜', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
