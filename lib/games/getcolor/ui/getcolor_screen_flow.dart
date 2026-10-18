part of 'getcolor_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _GsFlow on _GetColorScreenState {
  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _save);
    // 더 부을 곳이 없고 병도 더할 수 없으면 막다른 길이다
    if (c.noMoves && !c.canAddBottle && !_stuckShown) _onStuck();
  }

  /// 막다른 길: 어떻게 할지 묻는다 (병 더하기가 남아 있으면 안내 문구만 띄우고 묻지 않는다).
  Future<void> _onStuck() async {
    _stuckShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !c.noMoves || c.canAddBottle || c.paused) {
      _stuckShown = false;
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('더 부을 곳이 없어요'),
        content: const Text('이 상태에서는 더 이상 부을 수 없어요. 되돌려서 다른 길을 찾아볼까요?'),
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: c.untouched
            ? [FilledButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('새 판'))]
            : [
                TextButton(onPressed: () => Navigator.pop(ctx, 'giveup'), child: const Text('포기')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'restart'), child: const Text('처음부터')),
                FilledButton(onPressed: () => Navigator.pop(ctx, 'undo'), child: const Text('되돌리기')),
              ],
      ),
    );
    _stuckShown = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        c.undo();
      case 'restart':
        await GetColorStorage.clearSave(c);
        c.restart();
      case 'giveup':
        await _giveUp();
      case 'new':
        await _newPuzzle();
    }
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _onWon() async {
    WinSound.play(context); showWinCelebration(context, title: '완성!', subtitle: '모든 병을 맞췄어요'); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final moves = c.moveCount;
    await GetColorStorage.clearSave(c);
    final best = await GetColorStorage.recordWin(GetColorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      moves: moves,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('모두 모았어요! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${c.level.label} · ${c.level.description}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('$moves번 부었어요', style: const TextStyle(fontSize: 15)),
            if (best.any)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  best.time && best.moves
                      ? '시간도, 붓기 횟수도 새 최고 기록이에요!'
                      : best.time
                          ? '새 최고 기록이에요!'
                          : '가장 적게 부은 새 기록이에요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      await startGetColor(context, c.level, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _giveUp() async {
    if (c.completed || c.gaveUp || c.untouched) return;
    final ok = await confirmGiveUp(context, detail: '${c.moveCount}번 부었고, ${c.doneCount}개의 병을 모았어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await GetColorStorage.clearSave(c);
    await GetColorStorage.recordGiveUp(GetColorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      moves: c.moveCount,
      gaveUp: true,
      initial: [for (final b in c.initial.bottles) List<int>.of(b)],
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '${c.level.label} · ${formatTime(seconds)} · ${c.moveCount}번 부음',
      againLabel: '새 판',
    );
    if (!mounted) return;
    if (again) {
      await startGetColor(context, c.level, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newPuzzle() async {
    if (!c.completed && !c.untouched) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('새 판으로 바꿀까요?'),
          content: const Text('지금 하던 판은 사라지고, 같은 난이도로 새 판이 시작돼요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 판')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await GetColorStorage.clearSave(c);
    if (!mounted) return;
    await startGetColor(context, c.level, replace: true);
  }

  Future<void> _confirmRestart() async {
    if (c.untouched) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시 할까요?'),
        content: const Text('같은 판을 처음 모습으로 되돌려요. 시간도 처음부터 다시 재요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('처음부터')),
        ],
      ),
    );
    if (ok ?? false) {
      await GetColorStorage.clearSave(c);
      c.restart();
    }
  }

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await GetColorStorage.save(c);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await GetColorStorage.clearSave(c);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !c.completed && !c.gaveUp && !c.untouched;
}
