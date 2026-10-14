import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../records/records_screen.dart';
import '../../../tutorial/tutorial_button.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../tutorial/dandelion_tutorial.dart';
import 'dandelion_art.dart';
import 'dandelion_lesson_screen.dart';
import 'dandelion_screen.dart';

/// CPU 대전 시작 전 설정: 내가 맡을 쪽(민들레/바람) + 난이도.
class DandelionSetupScreen extends StatefulWidget {
  const DandelionSetupScreen({super.key});

  @override
  State<DandelionSetupScreen> createState() => _DandelionSetupScreenState();
}

class _DandelionSetupScreenState extends State<DandelionSetupScreen> {
  DandLevel _level = DandLevel.normal;
  Role _role = Role.dandelion;

  void _start() {
    final role = _role, level = _level;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DandelionScreen(mode: PlayMode.vsCpu, humanRole: role, level: level),
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
            onPressed: () => openRecords(context, game: 'dandelion'),
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
                Text('내가 맡을 쪽', style: heading),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final r in Role.values) ...[
                      if (r != Role.dandelion) const SizedBox(width: 12),
                      Expanded(child: _RoleCard(role: r, selected: _role == r, onTap: () => setState(() => _role = r))),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '민들레가 먼저 꽃을 심고, 바람이 이어서 불어요.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 24),
                Text('CPU 난이도', style: heading),
                const SizedBox(height: 12),
                for (final l in DandLevel.values) ...[
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
                const TutorialButton(tutorial: dandelionTutorial),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openDandelionLesson(context),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final Role role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
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
              SizedBox(width: 64, height: 64, child: CustomPaint(painter: _RolePainter(role))),
              const SizedBox(height: 8),
              Text(role.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(role == Role.dandelion ? '꽃을 심어 초원을 덮어요' : '바람으로 빈칸을 남겨요',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePainter extends CustomPainter {
  const _RolePainter(this.role);
  final Role role;

  @override
  void paint(Canvas canvas, Size size) => paintRoleIcon(canvas, size, role);

  @override
  bool shouldRepaint(_RolePainter old) => old.role != role;
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.selected, required this.onTap});

  final DandLevel level;
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
