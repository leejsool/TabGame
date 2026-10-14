import '../../../tutorial/tutorial_button.dart';
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../core/mines_rules.dart';
import '../data/mines_storage.dart';
import '../minesweeper_entry.dart';
import '../tutorial/mines_tutorial.dart';

const levelColors = {
  MinesLevel.beginner: Color(0xFF3FA796),
  MinesLevel.intermediate: Color(0xFF3F7CAC),
  MinesLevel.expert: Color(0xFFD1495B),
};

/// 지뢰찾기 첫 화면: 이어하기 + 난이도 고르기(고르면 바로 시작).
class MinesMenuScreen extends StatefulWidget {
  const MinesMenuScreen({super.key});

  @override
  State<MinesMenuScreen> createState() => _MinesMenuScreenState();
}

class _MinesMenuScreenState extends State<MinesMenuScreen> {
  Map<String, dynamic>? _saved;
  final Map<MinesLevel, MinesStats> _stats = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await MinesStorage.loadSaved();
    for (final l in MinesLevel.values) {
      _stats[l] = await MinesStorage.stats(l);
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loaded = true;
    });
  }

  Future<void> _start(MinesLevel level) async {
    await startMines(context, level, askIfSaved: true);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    return Scaffold(
      appBar: AppBar(
        title: const Text('지뢰찾기', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => minesTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'minesweeper');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: SafeArea(top: false, child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_saved != null) ...[
                      _ResumeCard(
                        saved: _saved!,
                        onTap: () async {
                          await resumeMines(context, _saved!);
                          if (mounted) _load();
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    const TutorialButton(tutorial: minesTutorial),
                    const SizedBox(height: 18),
                    Text('난이도를 골라 시작해요', style: heading),
                    const SizedBox(height: 12),
                    for (final l in MinesLevel.values) ...[
                      _LevelCard(level: l, stats: _stats[l] ?? const MinesStats(), onTap: () => _start(l)),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            )),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.stats, required this.onTap});

  final MinesLevel level;
  final MinesStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColors[level]!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.flag_rounded, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.label, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color)),
                    Text(level.description, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      stats.wins == 0
                          ? '아직 클리어한 적이 없어요'
                          : '클리어 ${stats.wins}번 · 최단 ${formatTime(stats.bestSeconds!)}',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.saved, required this.onTap});

  final Map<String, dynamic> saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = MinesLevel.values[saved['level'] as int];
    final marks = saved['marks'] as String;
    final opened = marks.split('').where((m) => m == '1').length;
    final total = level.rows * level.cols - level.mines;
    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 44, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이어하기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${level.label} · ${(opened * 100 / total).round()}% 진행 · ${formatTime(saved['elapsed'] as int)}'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
