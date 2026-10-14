import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../records/records_screen.dart';
import '../../../tutorial/tutorial_button.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final hint = TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6));
    return Scaffold(
      appBar: AppBar(
        title: Text(_vsCpu ? '콩나물 · CPU와 대결' : '콩나물 · 둘이서', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'sprouts'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text('처음 점의 수', style: heading),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                Text(
                  '점이 많을수록 판이 길어져요. 처음에는 2~3개로 해 보세요.',
                  style: hint,
                ),
                if (_vsCpu) ...[
                  const SizedBox(height: 24),
                  Text('나는', style: heading),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _SideCard(side: 0, selected: _side == 0, onTap: () => setState(() => _side = 0))),
                      const SizedBox(width: 12),
                      Expanded(child: _SideCard(side: 1, selected: _side == 1, onTap: () => setState(() => _side = 1))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('다음 판부터는 번갈아 시작해요.', style: hint),
                  const SizedBox(height: 24),
                  Text('CPU 난이도', style: heading),
                  const SizedBox(height: 12),
                  for (final l in SproutsLevel.values) ...[
                    _LevelTile(level: l, selected: _level == l, onTap: () => setState(() => _level = l)),
                    const SizedBox(height: 10),
                  ],
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
                const TutorialButton(tutorial: sproutsTutorial),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openSproutsLesson(context),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('교과학습'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
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
    final color = sproutsColor(side);
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
              Container(width: 56, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 10),
              Text(side == 0 ? '먼저 시작' : '나중에 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              Text(side == 0 ? '초록 선' : '분홍 선', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.selected, required this.onTap});

  final SproutsLevel level;
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
