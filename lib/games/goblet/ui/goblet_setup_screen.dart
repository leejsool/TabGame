import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../records/records_screen.dart';
import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';
import 'goblet_piece.dart';
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GobbletScreen(mode: PlayMode.vsCpu, humanTeam: team, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPU와 대결', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'goblet_gobblers'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('내 팀', style: _heading(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final t in Team.values) ...[
                    Expanded(child: _TeamCard(
                      team: t,
                      selected: _team == t,
                      onTap: () => setState(() => _team = t),
                    )),
                    if (t == Team.red) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '빨강팀이 먼저 시작해요. 다음 판부터는 번갈아 시작해요.',
                style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              Text('CPU 난이도', style: _heading(context)),
              const SizedBox(height: 12),
              for (final l in CpuLevel.values) ...[
                _LevelTile(
                  level: l,
                  selected: _level == l,
                  onTap: () => setState(() => _level = l),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('시작하기'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => showGobbletRules(context),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('규칙 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _heading(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.selected, required this.onTap});

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = TeamPalette.of(team);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: pal.main.withValues(alpha: selected ? 0.20 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? pal.main : pal.main.withValues(alpha: 0.25),
          width: selected ? 3 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: GobblerPainter(
                    team: team,
                    size: 3,
                    mood: selected ? PieceMood.happy : PieceMood.normal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                team.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: pal.dark,
                ),
              ),
              Text(team == Team.red ? '먼저 시작' : '나중에 시작',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.selected, required this.onTap});

  final CpuLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      elevation: selected ? 0 : 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.label,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(level.description, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
