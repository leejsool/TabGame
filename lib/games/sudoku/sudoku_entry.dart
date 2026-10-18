import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/generator.dart';
import 'data/sudoku_history.dart';
import 'data/sudoku_storage.dart';
import 'game/sudoku_game.dart';
import 'ui/game_screen.dart';
import 'ui/menu_screen.dart';
export 'ui/sudoku_icon.dart';

/// 허브(game_registry)에서 스도쿠를 열 때 쓰는 진입점.
Widget buildSudoku(BuildContext context, PlayMode mode) => const SudokuMenuScreen();

/// 다른 isolate에서 퍼즐을 만든다. (UI가 멈추지 않도록)
List<String> _generateInBackground(int difficultyIndex) {
  final d = Difficulty.values[difficultyIndex];
  final p = PuzzleGenerator.generate(d);
  return [p.givensString, p.solutionString];
}

/// 새 판을 만들어 게임 화면을 연다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다. 새 판을 시작했으면 true.
Future<bool> startSudokuGame(
  BuildContext context,
  Difficulty difficulty, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await SudokuStorage.loadSaved();
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '스도쿠');
      if (!ok) return false;
    }
  }
  if (!context.mounted) return false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(child: _GeneratingCard(slow: difficulty == Difficulty.expert || difficulty == Difficulty.extreme)),
    ),
  );
  // 로딩 화면이 먼저 그려질 시간을 준다.
  await Future<void>.delayed(const Duration(milliseconds: 80));
  final parts = await compute(_generateInBackground, difficulty.index);
  final game = SudokuGame(
    puzzle: SudokuPuzzle.fromStrings(parts[0], parts[1], difficulty),
  );
  navigator.pop(); // 로딩 대화상자 닫기
  final route = MaterialPageRoute<void>(builder: (_) => SudokuGameScreen(game: game));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
  return true;
}

/// 기록에서 고른 판(같은 문제)을 처음부터 다시 푼다. 이어하던 판이 있으면 먼저 물어본다.
Future<void> replaySudokuRecord(BuildContext context, SudokuRecord record) async {
  final saved = await SudokuStorage.loadSaved();
  if (!context.mounted) return;
  if (saved != null) {
    final ok = await confirmOverwrite(context, gameName: '스도쿠');
    if (!ok || !context.mounted) return;
  }
  final game = SudokuGame(puzzle: record.puzzle);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SudokuGameScreen(game: game)),
  );
}

/// 저장된 판을 이어서 한다.
Future<void> resumeSudokuGame(BuildContext context, SudokuGame game) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SudokuGameScreen(game: game)),
  );
}

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard({this.slow = false});

  /// 만드는 데 몇 초 더 걸리는 난이도인가 (안내 글을 덧붙인다).
  final bool slow;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            const Text('새 판을 만드는 중…', style: TextStyle(fontSize: 16)),
            if (slow) ...[
              const SizedBox(height: 6),
              Text('어려운 판은 몇 초 걸려요', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ],
        ),
      ),
    );
  }
}

/// 마지막에 하던 판이 있는지 확인한다 (메뉴에서 사용).
Future<SudokuGame?> loadSavedSudoku() => SudokuStorage.loadSaved();
