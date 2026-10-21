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
          listenable: Listenable.merge([c, c.highlight]),
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
                              '맨 앞 대포를 눌러 벨트에 올려요 · 꾹 누르면 같은 색 표시 · 대기 ${g.waiting}대',
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
    final hi = controller.highlight.value;
    final same = hi != null && cannon.color == hi;
    Widget tile = CannonTile(
      color: controller.level.colors[cannon.color],
      ammo: cannon.ammo,
      size: size,
      glow: front && ex.contains(cannon.color),
      dim: !front,
      ring: same,
    );
    if (hi != null && !same) tile = Opacity(opacity: 0.35, child: tile);
    if (front) {
      tile = InkWell(
        key: ValueKey('dot-front-$col'),
        customBorder: const CircleBorder(),
        onTap: () => controller.deploy(col),
        child: tile,
      );
    }
    return _holdToHighlight(controller, cannon.color, ValueKey('dot-hold-$col-$k'), tile);
  }
}

/// 대포(대기열·벨트 위)를 꾹 누르고 있는 동안, 판·벨트·대기열에서 같은 색을 돋보이게 한다 (손을 떼면 원래대로).
/// (색을 확인하려고 누를 때가 많으니, 기본(0.5초)보다 빨리 반응해서 살짝 눌렀다 떼는 일을 줄인다. 한 번 반응한 뒤에 떼면 올라가지 않는다)
/// [color]가 null이면(빈 칸) 눌러도 아무 일 없다.
Widget _holdToHighlight(DotController controller, int? color, Key key, Widget child) {
  return RawGestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    gestures: {
      LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 300)),
        (r) => r
          ..onLongPressStart = ((_) {
            if (color != null) controller.highlight.value = color;
          })
          ..onLongPressEnd = ((_) => controller.highlight.value = null)
          ..onLongPressCancel = (() => controller.highlight.value = null),
      ),
    },
    child: child,
  );
}
