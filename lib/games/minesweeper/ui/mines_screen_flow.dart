part of 'mines_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _MsFlow on _MinesScreenState {
  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _save);
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _onWon() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    await MinesStorage.clearSave(c);
    final isBest = await MinesStorage.recordWin(MinesRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      mines: c.retryOf, // 포기했던 판을 클리어한 거면 그 판의 포기 기록이 지워진다
    ));
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('클리어! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${c.level.label} · ${c.level.description}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '새 최고 기록이에요!',
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
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onLost() async {
    await MinesStorage.clearSave(c);
    await Future.any([Future<void>.delayed(const Duration(milliseconds: 2600)), _skip.future]);
    if (!mounted || c.status != MinesStatus.lost) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('펑! 💥', textAlign: TextAlign.center),
        content: const Text('지뢰를 밟았어요. 다시 도전해 볼까요?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'look'), child: const Text('판 보기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('다시 하기')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'again':
        c.restart();
      case 'menu':
        Navigator.of(context).pop();
    }
  }

  Future<void> _giveUp() async {
    if (c.status != MinesStatus.playing || c.gaveUp) return;
    final total = c.board.size - c.level.mines;
    final ok = await confirmGiveUp(context, detail: '안전한 칸 ${c.board.revealedCount}/$total칸을 열었어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await MinesStorage.clearSave(c);
    await MinesStorage.recordGiveUp(MinesRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      gaveUp: true,
      mines: c.recordMines,
      opened: c.board.revealedCount,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '${c.level.label} · ${formatTime(seconds)} · 안전한 칸 ${c.board.revealedCount}/$total칸',
      againLabel: '새 판',
    );
    if (!mounted) return;
    if (again) {
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    if (c.status != MinesStatus.playing) {
      c.restart();
      return;
    }
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
    if (ok ?? false) {
      await MinesStorage.clearSave(c);
      c.restart();
    }
  }

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await MinesStorage.save(c);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await MinesStorage.clearSave(c);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => c.saveable;
}
