part of 'getcolor_screen.dart';

/// layout 조각 (화면 코드를 역할별로 나눈 파일)
extension _GsLayout on _GetColorScreenState {
  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: Stack(
                  children: [
                    Positioned.fill(child: GetColorBoard(controller: c)),
                    Positioned(left: 0, right: 0, top: 6, child: Center(child: _banner())),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: c,
                        builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pauseCover() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => c.setPaused(false),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('일시정지', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text('눌러서 계속하기', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            // 제목과 난이도 칩이 남는 폭을 모두 쓴다 (빈 칸과 나눠 갖지 않아 폰에서도 제목이 잘리지 않는다)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '겟 컬러',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.level.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.local_drink_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text(
              '${c.moveCount}',
              key: const ValueKey('gc-moves'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            ValueListenableBuilder<int>(
              valueListenable: c.elapsed,
              builder: (_, sec, _) => Text(
                formatTime(sec),
                style: TextStyle(
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(
                c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                size: 30,
              ),
              onPressed: c.completed ? null : () => c.setPaused(!c.paused),
            ),
            PopupMenuButton<String>(
              tooltip: '메뉴',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'new') _newPuzzle();
                if (v == 'giveup') _giveUp();
                if (v == 'rules') getColorTutorial().open(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(
                  value: 'giveup',
                  enabled: !c.completed && !c.gaveUp && !c.untouched,
                  child: const Text('포기하기'),
                ),
                const PopupMenuItem(value: 'rules', child: Text('게임 방법')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 힌트 안내, 또는 더 부을 곳이 없을 때의 안내.
  Widget _banner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final stuck = c.noMoves;
        final text = c.hintMessage ??
            (stuck
                ? (c.canAddBottle
                    ? '더 부을 곳이 없어요. 되돌리거나 \'병 더하기\'를 눌러 보세요.'
                    : '더 부을 곳이 없어요. 되돌리기로 다른 길을 찾아보세요.')
                : null);
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD84D)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: c.hintThinking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFB88700)),
                      )
                    : const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
              ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              if (c.hintMessage != null)
                GestureDetector(
                  onTap: c.dismissHint,
                  child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 18)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          child: Row(
            children: [
              GameBarButton(icon: Icons.undo_rounded, label: '되돌리기', onTap: c.canUndo ? c.undo : null),
              GameBarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              GameBarButton(
                icon: Icons.add_circle_outline_rounded,
                label: c.extraUsed ? '병 더하기 (사용함)' : '병 더하기',
                onTap: c.canAct && c.canAddBottle ? c.addBottle : null,
              ),
              GameBarButton(icon: Icons.refresh_rounded, label: '처음부터', onTap: c.untouched ? null : _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}
