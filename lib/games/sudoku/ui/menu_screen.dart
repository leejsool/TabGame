import 'package:flutter/material.dart';

import '../core/generator.dart';
import '../data/sudoku_storage.dart';
import '../game/sudoku_game.dart';
import '../sudoku_entry.dart';
import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../../../tutorial/tutorial_progress.dart';
import '../tutorial/practice_menu_screen.dart';
import '../tutorial/technique_info.dart';
import '../tutorial/sudoku_tutorial.dart';

/// 스도쿠 첫 화면: 이어하기 + 난이도 선택.
class SudokuMenuScreen extends StatefulWidget {
  const SudokuMenuScreen({super.key});

  @override
  State<SudokuMenuScreen> createState() => _SudokuMenuScreenState();
}

class _SudokuMenuScreenState extends State<SudokuMenuScreen> {
  SudokuGame? _saved;
  final Map<Difficulty, SudokuStats> _stats = {};
  Set<String> _lessonsDone = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await loadSavedSudoku();
    final lessons = await TutorialProgress.doneLessons();
    final stats = <Difficulty, SudokuStats>{};
    for (final d in Difficulty.values) {
      stats[d] = await SudokuStorage.stats(d);
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _lessonsDone = lessons;
      _stats
        ..clear()
        ..addAll(stats);
      _loaded = true;
    });
  }

  Future<void> _start(Difficulty d) async {
    await startSudokuGame(context, d);
    if (mounted) _load();
  }

  Future<void> _resume() async {
    final saved = _saved;
    if (saved == null) return;
    await resumeSudokuGame(context, saved);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('스도쿠', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => sudokuTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'sudoku');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_saved != null) ...[
                      _ResumeCard(game: _saved!, onTap: _resume),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      '새 게임',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    for (final d in Difficulty.values) ...[
                      _DifficultyCard(
                        difficulty: d,
                        stats: _stats[d] ?? const SudokuStats(),
                        onTap: () => _start(d),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '배우기',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _LearnCard(
                      icon: Icons.school_rounded,
                      title: '기본 규칙 배우기',
                      subtitle: '진짜 판 위에서 한 단계씩 직접 해 보며 배워요',
                      done: _lessonsDone.contains('sudoku_basic'),
                      onTap: () async {
                        await sudokuTutorial().open(context);
                        if (mounted) _load();
                      },
                    ),
                    const SizedBox(height: 12),
                    _LearnCard(
                      icon: Icons.psychology_alt_rounded,
                      title: '심화 기술 연습',
                      subtitle: '싱글·포인팅·페어·X-윙 …  어려운 판을 푸는 기술을 하나씩'
                          ' (${kTechniqueInfos.where((i) => _lessonsDone.contains(i.id)).length}'
                          ' / ${kTechniqueInfos.length} 완료)',
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => const SudokuPracticeMenuScreen()),
                        );
                        if (mounted) _load();
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '힌트는 정답이 아니라, 지금 논리로 찾을 수 있는 다음 단계를 알려줘요.',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.done = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 이미 해 본 항목이면 체크 표시.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 30, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (done) ...[
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B)),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.game, required this.onTap});

  final SudokuGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    const Text('이어하기',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${game.puzzle.difficulty.label} · ${formatTime(game.elapsed.value)} · '
                      '${(game.progress * 100).round()}% 완료',
                    ),
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

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.stats,
    required this.onTap,
  });

  final Difficulty difficulty;
  final SudokuStats stats;
  final VoidCallback onTap;

  static const _colors = {
    Difficulty.easy: Color(0xFF3FA796),
    Difficulty.medium: Color(0xFF3F7CAC),
    Difficulty.hard: Color(0xFF8E5BC4),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[difficulty]!;
    final record = stats.bestSeconds == null
        ? '아직 기록이 없어요'
        : '최고 ${formatTime(stats.bestSeconds!)} · ${stats.wins}번 완성';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grid_on_rounded, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(difficulty.label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(difficulty.description, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      record,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
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
