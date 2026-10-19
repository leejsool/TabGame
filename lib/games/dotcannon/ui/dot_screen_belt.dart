part of 'dot_screen.dart';

/// 벨트 위 대포 현황: 어느 색 대포가 몇 발 남았는지 한눈에 보여 준다.
/// (판 위의 대포는 그림이 크면 작아서 숫자를 읽기 어렵다.) 벨트 자리 수만큼 칸이 있고, 빈 칸은 연하게 보인다.
class _BeltStrip extends StatelessWidget {
  const _BeltStrip({required this.controller});

  final DotController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
    final tile = tablet ? 56.0 : 44.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: DecoratedBox(
        key: const ValueKey('dot-belt-strip'),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListenableBuilder(
            listenable: Listenable.merge([c, c.highlight]),
            builder: (context, _) {
              final g = c.game;
              final hi = c.highlight.value;
              return Row(
                children: [
                  Icon(
                    Icons.linear_scale_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '벨트 위',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    // 폭이 좁으면 대포를 그만큼 줄여 한 줄에 다 들어가게 한다
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = min(tile, box.maxWidth / g.capacity);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < g.capacity; i++)
                              SizedBox(
                                width: size,
                                height: tile,
                                child: i < g.belt.length
                                    ? Center(
                                        child: Opacity(
                                          opacity: hi == null || g.belt[i].color == hi ? 1 : 0.35,
                                          child: CannonTile(
                                            color:
                                                c.level.colors[g.belt[i].color],
                                            ammo: g.belt[i].ammo,
                                            size: size,
                                            ring: hi != null && g.belt[i].color == hi,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Container(
                                          width: size * 0.6,
                                          height: size * 0.6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: scheme.outlineVariant,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
