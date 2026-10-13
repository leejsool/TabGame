import '../../../tutorial/tutorial_button.dart';
import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../records/records_screen.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../tutorial/uttt_tutorial.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPU와 대결', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'ultimate_tictactoe'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('내 표시', style: heading),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SideCard(side: kX, selected: _side == kX, onTap: () => setState(() => _side = kX))),
                  const SizedBox(width: 12),
                  Expanded(child: _SideCard(side: kO, selected: _side == kO, onTap: () => setState(() => _side = kO))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'X가 먼저 시작해요. 다음 판부터는 번갈아 시작해요.',
                style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              Text('CPU 난이도', style: heading),
              const SizedBox(height: 12),
              for (final l in UttLevel.values) ...[
                _LevelTile(level: l, selected: _level == l, onTap: () => setState(() => _level = l)),
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
              const SizedBox(height: 10),
              const TutorialButton(tutorial: utttTutorial),
            ],
          ),
        ),
      ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.20 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: selected ? 3 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              SizedBox(width: 64, height: 64, child: CustomPaint(painter: _SidePainter(side))),
              const SizedBox(height: 8),
              Text(side == kX ? 'X' : 'O',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(side == kX ? '먼저 시작' : '나중에 시작', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
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

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.selected, required this.onTap});

  final UttLevel level;
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
                    Text(level.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
