part of 'game_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _SgsFlow on _SudokuGameScreenState {
  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await SudokuStorage.save(game);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await SudokuStorage.clearSave(game);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !game.completed && !game.gaveUp && game.canUndo;

  void _onPlaced(bool correct) {
    final settings = SettingsScope.of(context);
    if (!settings.haptics) return;
    if (correct) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _onMistakeLimit() async {
    // 화면 갱신이 끝난 뒤에 대화상자를 띄운다.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final choice = await showDialog<_MistakeChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MistakeDialog(),
    );
    if (!mounted) return;
    switch (choice) {
      case _MistakeChoice.restart:
        game.restart();
      case _MistakeChoice.keepGoing || null:
        game.continueAnyway();
      case _MistakeChoice.newGame:
        // 하던 판이 사라지니 먼저 묻는다 (취소하면 하던 판을 계속한다)
        if (!await startSudokuGame(context, game.puzzle.difficulty, replace: true, askIfSaved: true)) game.continueAnyway();
    }
  }

  Future<void> _onCompleted() async {
    WinSound.play(context); showWinCelebration(context, title: '완성!', subtitle: '퍼즐을 모두 풀었어요'); // 이겼을 때 "짜잔"
    final seconds = game.elapsed.value;
    final diff = game.puzzle.difficulty;
    await SudokuStorage.clearSave(game);
    final isBest = await SudokuStorage.recordWin(diff, seconds);
    await SudokuHistory.add(SudokuRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      difficulty: diff,
      seconds: seconds,
      mistakes: game.mistakes,
      hints: game.hintsUsed,
      givens: game.puzzle.givensString,
      solution: game.puzzle.solutionString,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompleteDialog(game: game, isBest: isBest),
    );
    if (!mounted) return;
    if (again ?? false) {
      startSudokuGame(context, diff, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _giveUp() async {
    if (game.completed || game.gaveUp || !game.canUndo) return;
    game.timerHold = true;
    final ok = await confirmGiveUp(context, detail: '지금까지 ${formatTime(game.elapsed.value)} 풀었어요.');
    game.timerHold = false;
    if (!ok || !mounted || game.completed) return;
    game.gaveUp = true;
    _saveDebounce?.cancel();
    final seconds = game.elapsed.value;
    final diff = game.puzzle.difficulty;
    await SudokuStorage.clearSave(game);
    await SudokuHistory.add(SudokuRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      difficulty: diff,
      seconds: seconds,
      mistakes: game.mistakes,
      hints: game.hintsUsed,
      givens: game.puzzle.givensString,
      solution: game.puzzle.solutionString,
      gaveUp: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(context, summary: '${diff.label} · ${formatTime(seconds)}');
    if (!mounted) return;
    if (again) {
      startSudokuGame(context, diff, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시할까요?'),
        content: const Text('지금까지 입력한 내용이 모두 지워지고 시간도 0부터 시작해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('다시 시작')),
        ],
      ),
    );
    if (ok ?? false) game.restart();
  }
}
