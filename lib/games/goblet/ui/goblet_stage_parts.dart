part of 'goblet_stage.dart';

// 쟁반·말 위젯 (파일을 역할별로 나눈 것)

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.rect,
    required this.team,
    required this.cell,
    required this.active,
    required this.pulse,
    required this.flipped,
    required this.caption,
  });

  final Rect rect;
  final Team team;
  final double cell;
  final bool active;
  final Animation<double> pulse;
  final bool flipped;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final pal = TeamPalette.of(team);
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fromRect(
      rect: rect,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final glow = active ? 0.5 + 0.5 * sin(pulse.value * 2 * pi) : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cell * 0.24),
              color: Color.alphaBlend(
                pal.main.withValues(alpha: active ? 0.20 : 0.10),
                scheme.surface,
              ),
              border: Border.all(
                color: pal.main.withValues(alpha: active ? 0.6 + 0.4 * glow : 0.25),
                width: active ? cell * 0.045 : cell * 0.025,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: pal.main.withValues(alpha: 0.25 + 0.2 * glow),
                        blurRadius: cell * (0.15 + 0.1 * glow),
                      ),
                    ]
                  : null,
            ),
            child: Align(
              // 가로로 긴 대기 칸은 라벨을 왼쪽 위 빈 곳에 둔다 (큰 말의 귀를 가리지 않게)
              alignment: rect.width > rect.height ? Alignment.topLeft : Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: cell * 0.06, left: rect.width > rect.height ? cell * 0.12 : 0),
                child: Transform.rotate(
                  angle: flipped ? pi : 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: rect.width - cell * 0.2),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: cell * 0.14, vertical: cell * 0.03),
                      decoration: BoxDecoration(
                        color: pal.main,
                        borderRadius: BorderRadius.circular(cell),
                      ),
                      // 라벨이 길어도 한 줄로 줄어든다
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          caption,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: max(11.0, cell * 0.16),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.cell,
    required this.isTarget,
    required this.covers,
    required this.hovered,
    required this.winning,
    required this.pulse,
    required this.onTap,
  });

  final double cell;
  final bool isTarget;

  /// 이미 말이 있는 칸(덮게 되는 칸).
  final bool covers;
  final bool hovered;
  final bool winning;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = covers ? const Color(0xFFFFA726) : const Color(0xFF34C38F);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final p = 0.5 + 0.5 * sin(pulse.value * 2 * pi);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cell * 0.16),
                  color: winning
                      ? Color.lerp(const Color(0xFFFFF1B8), const Color(0xFFFFD84D), p)
                      : isTarget
                          ? Color.alphaBlend(
                              ringColor.withValues(alpha: hovered ? 0.45 : 0.18),
                              const Color(0xFFFFF7E8),
                            )
                          : const Color(0xFFFFF7E8),
                  border: isTarget
                      ? Border.all(
                          color: ringColor.withValues(alpha: hovered ? 1 : 0.55 + 0.35 * p),
                          width: cell * (hovered ? 0.06 : 0.04),
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withValues(alpha: 0.12),
                      offset: Offset(0, cell * 0.025),
                    ),
                  ],
                ),
              ),
              // 덮인 말은 일부러 표시하지 않는다: 아래에 뭐가 깔렸는지는 플레이어가 기억해야 한다
            ],
          );
        },
      ),
    );
  }
}
