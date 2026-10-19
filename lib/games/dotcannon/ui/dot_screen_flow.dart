part of 'dot_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _DsFlow on _DotScreenState {
  void _onChanged() {
    if (c.completed || c.stalled) {
      _saver.finish();
    } else if (c.game.deploys != _savedAtDeploys) {
      if (c.untouched) _saver.rearm(); // 처음부터 다시 시작했다
      _savedAtDeploys = c.game.deploys;
      _saver.save();
    }
  }

  void _showBanner(String text) {
    _banner.value = text;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1600), () => _banner.value = null);
  }

  void _feedback(String kind) {
    if (kind == 'full') _showBanner('벨트가 가득 찼거나, 입구가 막혀 있어요');
    _fx.play(context, kind);
  }

  Future<void> _onWon() async {
    WinSound.play(context); showWinCelebration(context, title: '완성!', subtitle: '도트를 모두 채웠어요'); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final deploys = c.game.deploys;
    // 기록을 먼저 남긴다: 보관된 판이 지워지면 메뉴가 곧바로 기록을 읽으러 오는데, 그때 아직 기록이 없으면 "못 깼어요"로 보인다
    final best = await DotStorage.recordWin(c.level.id, seconds: seconds, deploys: deploys);
    await _saver.finish();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final index = dotLevels.indexWhere((l) => l.id == c.level.id);
    final hasNext = !c.level.custom && index >= 0 && index + 1 < dotLevels.length;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 완성! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: DotArtPainter(c.level.pixels, c.level.width, c.level.height, c.level.colors),
              ),
            ),
            const SizedBox(height: 6),
            Text(c.level.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('대포 $deploys대를 썼어요', style: const TextStyle(fontSize: 15)),
            if (best.any)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  best.time && best.deploys
                      ? '시간도, 대포 수도 새 최고 기록이에요!'
                      : best.time
                          ? '새 최고 기록이에요!'
                          : '가장 적은 대포로 깬 새 기록이에요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('다시 하기')),
          if (hasNext) FilledButton(onPressed: () => Navigator.pop(ctx, 'next'), child: const Text('다음 그림')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'next':
        await startDotCannon(context, dotLevels[index + 1], replace: true);
      case 'again':
        await startDotCannon(context, c.level, replace: true);
      default:
        Navigator.of(context).pop();
    }
  }

  Future<void> _onStalled() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block_rounded, size: 32),
        title: const Text('막혔어요', textAlign: TextAlign.center),
        content: const Text(
          '벨트 위의 대포도, 대기 중인 대포도\n지금 보이는 도트를 맞힐 수 없어요.\n'
          '맞히지 못하는 대포를 먼저 올리면 벨트 자리만 차지해요.\n처음부터 다시 해 볼까요?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('처음부터')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'again') {
      await _saver.save(); // (아직 아무것도 안 올린 판이라 보관된 것이 지워진다)
      _restartNow();
    } else {
      await _saver.finish();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _restartNow() {
    c.restart();
    _saver.rearm();
    _saver.save();
    _savedAtDeploys = 0;
  }

  Future<void> _confirmRestart() async {
    if (c.untouched) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시 할까요?'),
        content: const Text('같은 그림을 처음 모습으로 되돌려요. 시간도 처음부터 다시 재요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('처음부터')),
        ],
      ),
    );
    if (ok ?? false) _restartNow();
  }
}
