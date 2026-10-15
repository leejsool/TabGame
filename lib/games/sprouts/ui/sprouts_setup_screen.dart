import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/sprouts_ai.dart';
import '../tutorial/sprouts_tutorial.dart';
import 'sprouts_lesson_screen.dart';
import 'sprouts_painter.dart';
import 'sprouts_screen.dart';

/// 시작 전 설정: 점의 수 (+ CPU 대결이면 난이도와 먼저/나중).
class SproutsSetupScreen extends StatefulWidget {
  const SproutsSetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<SproutsSetupScreen> createState() => _SproutsSetupScreenState();
}

class _SproutsSetupScreenState extends State<SproutsSetupScreen> {
  int _dots = 3;
  SproutsLevel _level = SproutsLevel.normal;
  int _side = 0; // 0 = 먼저, 1 = 나중

  bool get _vsCpu => widget.mode == PlayMode.vsCpu;

  void _start() {
    final dots = _dots, side = _side, level = _level, mode = widget.mode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SproutsScreen(mode: mode, dotCount: dots, humanSide: side, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'sprouts',
      title: _vsCpu ? '콩나물 · CPU와 대결' : '콩나물 · 둘이서',
      onStart: _start,
      tutorial: sproutsTutorial,
      onLesson: () => openSproutsLesson(context),
      children: [
        const VsSectionTitle('처음 점의 수'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final n in const [2, 3, 4, 5, 6])
              ChoiceChip(
                label: Text('$n개', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                selected: _dots == n,
                onSelected: (_) => setState(() => _dots = n),
              ),
          ],
        ),
        const VsHint('점이 많을수록 판이 길어져요. 처음에는 2~3개로 해 보세요.'),
        if (_vsCpu) ...[
          const VsSectionTitle('나는', topGap: 24),
          VsChoiceRow(cards: [
            _SideCard(side: 0, selected: _side == 0, onTap: () => setState(() => _side = 0)),
            _SideCard(side: 1, selected: _side == 1, onTap: () => setState(() => _side = 1)),
          ]),
          const VsHint('다음 판부터는 번갈아 시작해요.'),
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<SproutsLevel>(
            levels: SproutsLevel.values,
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

class _SideCard extends StatelessWidget {
  const _SideCard({required this.side, required this.selected, required this.onTap});

  final int side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sproutsColor(side);
    return VsChoiceCard(
      color: color,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 56, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Text(side == 0 ? '먼저 시작' : '나중에 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(side == 0 ? '초록 선' : '분홍 선', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
