part of 'dot_screen.dart';

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.controller});

  final DotController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final g = c.game;
            final ex = g.exposedColors();
            return LayoutBuilder(
              builder: (context, box) {
                final cols = g.queue.length;
                final colW = (box.maxWidth - 16) / cols;
                // 태블릿에서는 칸이 넓으니 대포도 크게 (폰은 그대로)
                final maxTile = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide ? 88.0 : 64.0;
                final tile = colW.clamp(34.0, maxTile) - 6;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '맨 앞 대포를 눌러 벨트에 올려요 · 대기 ${g.waiting}대',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cols; i++) _column(context, i, g.queue[i], ex, tile, colW),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 한 줄: 맨 앞(위) 대포가 가장 위에 보이게, 뒤쪽 대포부터 먼저 그린다.
  Widget _column(BuildContext context, int col, List<Cannon> cannons, Set<int> ex, double size, double width) {
    if (cannons.isEmpty) return SizedBox(width: width);
    final step = size * 0.82;
    final height = (cannons.length - 1) * step + size + 4;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var k = cannons.length - 1; k >= 0; k--)
            Positioned(
              top: k * step,
              left: 0,
              right: 0,
              child: Center(child: _tile(col, k, cannons[k], ex, size)),
            ),
        ],
      ),
    );
  }

  Widget _tile(int col, int k, Cannon cannon, Set<int> ex, double size) {
    final front = k == 0;
    final tile = CannonTile(
      color: controller.level.colors[cannon.color],
      ammo: cannon.ammo,
      size: size,
      glow: front && ex.contains(cannon.color),
      dim: !front,
    );
    if (!front) return tile;
    return InkWell(
      key: ValueKey('dot-front-$col'),
      customBorder: const CircleBorder(),
      onTap: () => controller.deploy(col),
      child: tile,
    );
  }
}
