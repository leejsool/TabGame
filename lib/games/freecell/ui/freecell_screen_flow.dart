part of 'freecell_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _FsFlow on _FreecellScreenState {
  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _save);
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _onCompleted() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final moves = c.moveCount;
    await FreecellStorage.clearSave(c);
    final isBest = await FreecellStorage.recordWin(FreecellRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
      seconds: seconds,
      moves: moves,
    ));
    // 연출을 보여주다가, 화면을 누르면 바로 (아니면 14초 뒤에) 결과를 보여준다
    await Future.any([Future<void>.delayed(const Duration(seconds: 14)), _skipCelebration.future]);
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('완성! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#${c.deal}${_level == null ? '' : ' · ${_level!.label}'}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              '${formatTime(seconds)} · $moves수',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '새 최고 기록이에요!',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 게임')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      _startNewGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onNoMoves() async {
    if (_noMovesShown) return;
    _noMovesShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || c.completed || !c.noMoves) {
      _noMovesShown = false;
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('더 움직일 수 없어요'),
        content: const Text('놓을 수 있는 곳이 없어요. 되돌려서 다른 길을 시도해 볼까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'giveup'), child: const Text('포기')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'restart'), child: const Text('처음부터')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('새 게임')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'undo'), child: const Text('되돌리기')),
        ],
      ),
    );
    _noMovesShown = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        c.undo();
      case 'restart':
        c.restart();
      case 'new':
        _startNewGame(askIfSaved: true);
      case 'giveup':
        _giveUp();
    }
  }

  /// 메뉴에서 마지막으로 고른 난이도로 새 판을 시작한다 (이 화면을 새 판으로 바꾼다).
  /// [askIfSaved]면 하던 판이 보관돼 있을 때 사라져도 되는지 먼저 묻는다 (이긴 뒤·포기한 뒤에는 보관된 판이 없다).
  Future<void> _startNewGame({bool askIfSaved = false}) async {
    final level = await FreecellStorage.loadLevel();
    final deal = await pickDeal(level);
    if (!mounted) return;
    await startFreecellDeal(context, deal, replace: true, askIfSaved: askIfSaved);
  }

  Future<void> _giveUp() async {
    if (c.completed || c.gaveUp || c.untouched) return;
    final ok = await confirmGiveUp(context, detail: '#${c.deal} 판 · ${c.moveCount}수를 두었어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await FreecellStorage.clearSave(c);
    await FreecellStorage.recordGiveUp(FreecellRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
      seconds: seconds,
      moves: c.moveCount,
      gaveUp: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '#${c.deal}${_level == null ? '' : ' · ${_level!.label}'} · ${formatTime(seconds)} · ${c.moveCount}수',
      againLabel: '새 게임',
    );
    if (!mounted) return;
    if (again) {
      _startNewGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시할까요?'),
        content: Text('#${c.deal} 판을 처음 모습으로 되돌리고 시간도 0부터 시작해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('다시 시작')),
        ],
      ),
    );
    if (ok ?? false) c.restart();
  }

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await FreecellStorage.save(c);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await FreecellStorage.clearSave(c);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !c.completed && !c.gaveUp && !c.untouched;
}
