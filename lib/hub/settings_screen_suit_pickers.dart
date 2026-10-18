part of 'settings_screen.dart';

// 무늬 색·카드 뒷면 고르기 (파일을 역할별로 나눈 것)

/// 무늬 색 고르기: 기본(두 색) / 4색 / 4색(계열 유지)를 위아래로 나란히 보여 주고, 누르면 바로 바뀐다.
/// 설정 화면에서 바로 차이가 보이게, 각 줄에 무늬 네 개를 실제 색으로 그린다.
class _SuitColorPicker extends StatelessWidget {
  const _SuitColorPicker({required this.settings});

  final Settings settings;

  // 보여 주는 순서: ♠ ♥ ♣ ♦ (무늬 번호는 ♣=0 ♦=1 ♥=2 ♠=3)
  static const _order = [3, 2, 0, 1];

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
              Icon(Icons.palette_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 16),
              const Text('무늬 색깔', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          for (final p in SuitPalette.values) ...[
            _SuitColorTile(palette: p, selected: settings.suitPalette == p, onTap: () => settings.suitPalette = p),
            const SizedBox(height: 8),
          ],
          Text(
            switch (settings.suitPalette) {
              SuitPalette.twoColor => '전통 카드처럼 스페이드·클로버는 검정, 하트·다이아는 빨강이에요.',
              SuitPalette.fourColor => '작은 카드에서도 스페이드와 클로버, 하트와 다이아를 색으로 바로 알아봐요.',
              SuitPalette.family => '검정 계열(스페이드·클로버)과 빨강 계열(하트·다이아)은 지키면서 무늬도 색으로 구분해요. 번갈아 쌓는 규칙을 볼 때 편해요.',
            },
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SuitColorTile extends StatelessWidget {
  const _SuitColorTile({required this.palette, required this.selected, required this.onTap});

  final SuitPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 22, color: selected ? scheme.primary : scheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(palette.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(palette.detail, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 흰 카드 위에 무늬 네 개를 실제 색으로
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x22000000)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final suit in _SuitColorPicker._order)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: SizedBox(width: 24, height: 24, child: CustomPaint(painter: _SuitGlyphPainter(suit, paletteSuitColor(palette, suit)))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuitGlyphPainter extends CustomPainter {
  const _SuitGlyphPainter(this.suit, this.color);

  final int suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => drawSuit(canvas, suit, Offset.zero & size, Paint()..color = color);

  @override
  bool shouldRepaint(_SuitGlyphPainter old) => old.suit != suit || old.color != color;
}

class _CardBackStylePicker extends StatelessWidget {
  const _CardBackStylePicker({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 뒷면 모양이 많아 자리를 많이 차지하니, 접고 펼 수 있게 한다 (접어 두면 지금 고른 모양만 보인다)
    return ExpansionTile(
      key: const ValueKey('card-back-section'),
      leading: SizedBox(width: 28, height: 40, child: CustomPaint(painter: CardBackPainter(style: settings.cardBackStyle))),
      title: const Text('카드 뒷면', style: TextStyle(fontSize: 16)),
      subtitle: Text(settings.cardBackStyle.label),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      iconColor: scheme.onSurfaceVariant,
      children: [
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth < 420 ? 2 : 3;
          final gap = 10.0;
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final style in CardBackStyle.values)
                SizedBox(
                  width: width,
                  child: _CardBackTile(
                    style: style,
                    selected: settings.cardBackStyle == style,
                    onTap: () => settings.cardBackStyle = style,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _CardBackTile extends StatelessWidget {
  const _CardBackTile({required this.style, required this.selected, required this.onTap});

  final CardBackStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('card-back-style-${style.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2.5),
          ),
          child: Column(children: [
            SizedBox(width: 64, height: 90, child: CustomPaint(painter: CardBackPainter(style: style))),
            const SizedBox(height: 8),
            Text(style.label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.primary : null)),
            Text(style.description, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .65))),
          ]),
        ),
      ),
    );
  }
}

/// 카드 표시 방식 고르기 (자동 / 폰용 / 전체): 방식마다 실제로 그려지는 모습을 미리 보여준다.
