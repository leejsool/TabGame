import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';
import 'goblet_piece.dart';
import '../tutorial/goblet_tutorial.dart';
import 'goblet_screen.dart';

/// CPU 대전 시작 전 설정: 난이도 + 내 팀.
class GobbletSetupScreen extends StatefulWidget {
  const GobbletSetupScreen({super.key});

  @override
  State<GobbletSetupScreen> createState() => _GobbletSetupScreenState();
}

class _GobbletSetupScreenState extends State<GobbletSetupScreen> {
  CpuLevel _level = CpuLevel.normal;
  Team _team = Team.red;

  void _start() {
    final team = _team, level = _level;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GobbletScreen(mode: PlayMode.vsCpu, humanTeam: team, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'goblet_gobblers',
      title: 'CPU와 대결',
      onStart: _start,
      tutorial: gobletTutorial,
      children: [
        const VsSectionTitle('내 팀'),
        VsChoiceRow(cards: [
          for (final t in Team.values) _TeamCard(team: t, selected: _team == t, onTap: () => setState(() => _team = t)),
        ]),
        const VsHint('빨강팀이 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
        const VsSectionTitle('CPU 난이도', topGap: 24),
        VsLevelPicker<CpuLevel>(
          levels: CpuLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => l.description,
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.selected, required this.onTap});

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = TeamPalette.of(team);
    return VsChoiceCard(
      color: pal.main,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: GobblerPainter(team: team, size: 3, mood: selected ? PieceMood.happy : PieceMood.normal),
            ),
          ),
          const SizedBox(height: 8),
          Text(team.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pal.dark)),
          Text(team == Team.red ? '먼저 시작' : '나중에 시작', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
