import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../core/game_widgets.dart';
import '../../../tutorial/lesson_kit.dart';
import '../core/stones_rules.dart';
import 'stones_board.dart';
import 'stones_lesson_screen.dart';
import 'stones_screen.dart';

/// 첫 메뉴: 처음 판에서 자유 대결, 또는 문제 (1)·(2)·(3) 고르기.
class StonesMenuScreen extends StatelessWidget {
  const StonesMenuScreen({super.key, required this.mode});

  final PlayMode mode;

  bool get _cpu => mode == PlayMode.vsCpu;

  void _open(BuildContext context, StonesPuzzle p, {Side? cpuSide}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StonesScreen(mode: mode, puzzle: p, cpuSide: cpuSide ?? (_cpu ? p.turn.other : null)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final free = _MenuCard(
      puzzle: kStartBoard,
      subtitle: _cpu ? '갑(흰 돌)이 먼저 둬요. 내가 할 쪽을 고르세요.' : '갑(흰 돌)부터 둘이서 번갈아 둬요.',
      actions: _cpu
          ? [
              FilledButton(onPressed: () => _open(context, kStartBoard, cpuSide: Side.black), child: const Text('내가 갑(흰 돌)')),
              FilledButton.tonal(onPressed: () => _open(context, kStartBoard, cpuSide: Side.white), child: const Text('내가 을(검은 돌)')),
            ]
          : [FilledButton(onPressed: () => _open(context, kStartBoard), child: const Text('시작'))],
    );
    final puzzles = [
      for (final p in kPuzzles)
        _MenuCard(
          puzzle: p,
          subtitle: p.question + (_cpu ? '\n(상대 ${p.turn.other.name}은 컴퓨터가 둬요)' : ''),
          onTap: () => _open(context, p),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('바둑돌 옮기기', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(tooltip: '교과학습', icon: const Icon(Icons.menu_book_rounded), onPressed: () => openStonesLesson(context)),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showStonesRules(context)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: menuMaxWidth(context)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                free,
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('문제 풀기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                CardGrid(children: puzzles),
                const SizedBox(height: 18),
                LessonOpenButton(onPressed: () => openStonesLesson(context), label: '교과학습: 님 게임 · 31 게임 · 이진법 필승법'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.puzzle, required this.subtitle, this.onTap, this.actions = const []});

  final StonesPuzzle puzzle;
  final String subtitle;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kStonesColor.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(puzzle.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 8),
            SizedBox(height: 92, child: StonesBoard(state: puzzle.start(), onTapCell: null)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
            ],
          ]),
        ),
      ),
    );
  }
}
