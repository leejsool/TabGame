part of 'game_screen.dart';

/// layout 조각 (화면 코드를 역할별로 나눈 파일)
extension _SgsLayout on _SudokuGameScreenState {
  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight * 1.1;
            return Column(
              children: [
                _topBar(),
                Expanded(
                  child: landscape ? _landscape() : _portrait(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '스도쿠',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: '메뉴',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'restart') _confirmRestart();
              if (v == 'giveup') _giveUp();
              if (v == 'new') {
                startSudokuGame(context, game.puzzle.difficulty, replace: true, askIfSaved: true);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'restart', child: Text('처음부터 다시하기')),
              const PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
              PopupMenuItem(
                value: 'giveup',
                enabled: game.canUndo && !game.completed && !game.gaveUp,
                child: const Text('포기하기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: Text(
                '실수: ${game.mistakes}/${SudokuGame.maxMistakes}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: game.mistakes > 0
                      ? Theme.of(context).colorScheme.error
                      : scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              game.puzzle.difficulty.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.elapsed,
                    builder: (_, s, _) => Text(
                      formatTime(s),
                      style: TextStyle(
                        fontSize: 16,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: game.paused ? '계속하기' : '일시정지',
                    icon: Icon(
                      game.paused
                          ? Icons.play_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 30,
                    ),
                    onPressed: game.completed ? null : () => game.setPaused(!game.paused),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board() {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(child: SudokuBoard(game: game)),
              // 자동 완성 중임을 알리는 안내. 투명할 때도 자리는 있어서, 터치는 통과시켜야
              // 아래 보드(맨 아래 줄 가운데 칸)가 눌린다.
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: game,
                    builder: (context, _) => AnimatedOpacity(
                      opacity: game.autoCompleting ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✨ 남은 칸을 자동으로 채워요',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: game,
                  builder: (context, _) => game.paused
                      ? Material(
                          color: scheme.surface,
                          child: InkWell(
                            onTap: () => game.setPaused(false),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded,
                                      size: 72, color: scheme.primary),
                                  const SizedBox(height: 8),
                                  const Text('일시정지', style: TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text('눌러서 계속하기',
                                      style: TextStyle(
                                          color: scheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 숫자/액션 영역. 힌트가 열려 있으면 힌트 카드가 그 자리를 차지한다.
  Widget _controls({required int padColumns}) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final hint = game.hint;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuickInputToggle(game: game),
            const SizedBox(height: 4),
            if (hint != null)
              HintPanel(game: game, hint: hint)
            else ...[
              ActionBar(game: game),
              const SizedBox(height: 14),
              NumberPad(game: game, columns: padColumns),
            ],
          ],
        );
      },
    );
  }

  Widget _portrait() {
    return LayoutBuilder(
      builder: (context, box) {
        // 태블릿은 아래에 남던 자리만큼 판을 더 키운다 (폰은 그대로)
        final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
        final boardMax = min(box.maxWidth - 24, box.maxHeight * (tablet ? 0.64 : 0.56));
        return Column(
          children: [
            _statusRow(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(width: boardMax, child: _board()),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  max(12.0, (box.maxWidth - boardMax) / 2),
                  4,
                  max(12.0, (box.maxWidth - boardMax) / 2),
                  16,
                ),
                child: _controls(padColumns: 9),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _landscape() {
    return LayoutBuilder(
      builder: (context, box) {
        final boardSize = min(box.maxHeight - 24, box.maxWidth * 0.58);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: SizedBox(width: boardSize, height: boardSize, child: _board()),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
                child: Column(
                  children: [
                    _statusRow(),
                    const SizedBox(height: 8),
                    _controls(padColumns: 3),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
