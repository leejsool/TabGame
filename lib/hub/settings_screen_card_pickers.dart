part of 'settings_screen.dart';

// 카드 배치·모양 고르기 (파일을 역할별로 나눈 것)

/// 카드 표시 방식 고르기 (자동 / 폰용 / 전체): 방식마다 실제로 그려지는 모습을 미리 보여준다.
class _CardLayoutPicker extends StatelessWidget {
  const _CardLayoutPicker({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 16),
              const Text('카드 표시 (프리셀·솔리테어)', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 420;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final layout in CardLayout.values)
                    SizedBox(
                      width: narrow ? box.maxWidth : (box.maxWidth - 20) / 3,
                      child: _LayoutTile(
                        layout: layout,
                        selected: settings.cardLayout == layout,
                        style: settings.cardStyle,
                        palette: settings.suitPalette,
                        onTap: () => settings.cardLayout = layout,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({required this.layout, required this.selected, required this.style, required this.palette, required this.onTap});

  final CardLayout layout;
  final bool selected;
  final CardStyle style;
  final SuitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 자동은 지금 기기에서 실제로 그려질 모습을 보여 준다
    final compact = switch (layout) {
      CardLayout.phone => true,
      CardLayout.full => false,
      CardLayout.auto => MediaQuery.sizeOf(context).shortestSide < 600,
    };
    Widget mini(int card) => SizedBox(
          width: 46,
          height: 64,
          child: CustomPaint(painter: PlayingCardPainter(card, style: style, palette: palette, compact: compact)),
        );
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('card-layout-${layout.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mini(9 * 4 + 1), // 10♦
                  const SizedBox(width: 6),
                  mini(12 * 4 + 2), // K♥
                  const SizedBox(width: 6),
                  mini(0 * 4 + 3), // A♠
                ],
              ),
              const SizedBox(height: 8),
              Text(layout.label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.primary : null)),
              Text(
                layout.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 모양 고르기: 모양마다 에이스·왕 그림을 미리 보여준다.
class _CardStylePicker extends StatelessWidget {
  const _CardStylePicker({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.style_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 16),
              const Text('카드 모양', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 420;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final style in CardStyle.values)
                    SizedBox(
                      width: narrow ? box.maxWidth : (box.maxWidth - 20) / 3,
                      child: _StyleTile(
                        style: style,
                        selected: settings.cardStyle == style,
                        palette: settings.suitPalette,
                        onTap: () => settings.cardStyle = style,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.style, required this.selected, required this.palette, required this.onTap});

  final CardStyle style;
  final bool selected;
  final SuitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget mini(int card) => SizedBox(
          width: 46,
          height: 64,
          child: CustomPaint(painter: PlayingCardPainter(card, style: style, palette: palette)),
        );
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('card-style-${style.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mini(0 * 4 + 3), // A♠
                  const SizedBox(width: 6),
                  mini(11 * 4 + 2), // Q♥
                  const SizedBox(width: 6),
                  mini(12 * 4 + 1), // K♦
                ],
              ),
              const SizedBox(height: 8),
              Text(
                style.label,
                style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.primary : null),
              ),
              Text(
                style.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지금 버전을 보여 주고, 눌러서 바로 업데이트를 확인한다.
