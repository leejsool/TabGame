part of 'solitaire_screen.dart';

/// layout 조각 (화면 코드를 역할별로 나눈 파일)
extension _SsLayout on _SolitaireScreenState {
  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SolitaireTable(
                        controller: c,
                        onCelebrationTap: () {
                          if (!_skipCelebration.isCompleted) _skipCelebration.complete();
                        },
                      ),
                    ),
                    // 힌트 안내는 판 위에 띄워서, 나타나도 카드가 밀리지 않게 한다
                    Positioned(left: 0, right: 0, bottom: 12, child: Center(child: _hintBanner())),
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
            // 제목과 칩이 남는 폭을 모두 쓴다 (빈 칸과 나눠 갖지 않아 폰에서도 제목이 잘리지 않는다)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      // 판 번호는 조금 작고 옅게 (폰에서도 한 줄에 다 들어가게)
                      TextSpan(text: '솔리테어 ', children: [
                        TextSpan(text: '#${c.deal}', style: TextStyle(fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.6))),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${c.draw}장',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${c.moveCount}수',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary),
            ),
            const SizedBox(width: 8),
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
                if (v == 'restart') _confirmRestart();
                if (v == 'new') _startNewGame(askIfSaved: true);
                if (v == 'giveup') _giveUp();
                if (v == 'rules') showSolitaireRules(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'restart', child: Text('처음부터 다시하기')),
                const PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(
                  value: 'giveup',
                  enabled: !c.completed && !c.gaveUp && !c.untouched,
                  child: const Text('포기하기'),
                ),
                const PopupMenuItem(value: 'rules', child: Text('규칙 보기')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
