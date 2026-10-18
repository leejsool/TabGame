part of 'dot_screen.dart';

/// layout 조각 (화면 코드를 역할별로 나눈 파일)
extension _DsLayout on _DotScreenState {
  Widget _board() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: DotBoardPainter(c, c.level.colors))),
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: _banner,
                builder: (context, text, _) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: text == null ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20)),
                    child: Text(text ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
            ),
          ),
        ],
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
            Flexible(
              child: Text(
                c.level.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            // 벨트 자리: 올려 둔 대포 / 최대
            Container(
              key: const ValueKey('dot-belt-gauge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.linear_scale_rounded, size: 17, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${c.game.belt.length}/${c.game.capacity}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('도트 ${c.game.remaining}', style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7))),
            const Spacer(),
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
            TextButton(
              key: const ValueKey('dot-speed'),
              onPressed: c.cycleSpeed,
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('${c.speed}배속', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded, size: 30),
              onPressed: c.completed ? null : () => c.setPaused(!c.paused),
            ),
            PopupMenuButton<String>(
              tooltip: '메뉴',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'restart') _confirmRestart();
                if (v == 'rules') dotTutorial().open(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'restart', enabled: !c.untouched && !c.completed, child: const Text('처음부터 다시')),
                const PopupMenuItem(value: 'rules', child: Text('게임 방법')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
