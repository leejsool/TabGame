import '../core/nickname.dart';
import 'package:flutter/material.dart';

import '../core/card_look.dart';
import '../core/settings.dart';
import '../core/update/update_service.dart';
import '../core/update/update_ui.dart';
import '../games/freecell/ui/playing_card.dart';
import '../games/solitaire/ui/card_back.dart';
import '../tutorial/tutorial_progress.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(top: false, child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          // 맨 아래 항목이 태블릿의 아래 시스템 바(내비게이션 바)에 가리지 않게 그만큼 띄운다
          padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: const Text('내 별명'),
              subtitle: Text('${settings.nickname} · 같은 Wi‑Fi로 함께 할 때 상대에게 보여요'),
              trailing: const Icon(Icons.edit_rounded),
              onTap: () => editNickname(context, settings: settings),
            ),
            const Divider(height: 24),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('효과음'),
              value: settings.sound,
              onChanged: (v) => settings.sound = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('진동'),
              value: settings.haptics,
              onChanged: (v) => settings.haptics = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('스도쿠 자동 완성'),
              subtitle: const Text('남은 칸이 15개 이하이고 바로 보이는 칸뿐이면 자동으로 채워서 끝내요'),
              value: settings.autoComplete,
              onChanged: (v) => settings.autoComplete = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.style_rounded),
              title: const Text('프리셀 자동 올리기'),
              subtitle: const Text('손해 없는 카드는 완성 칸으로 알아서 올려요'),
              value: settings.freecellAutoMove,
              onChanged: (v) => settings.freecellAutoMove = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('솔리테어 자동 올리기'),
              subtitle: const Text('손해 없는 카드는 완성 칸으로 알아서 올려요'),
              value: settings.solitaireAutoMove,
              onChanged: (v) => settings.solitaireAutoMove = v,
            ),
            const Divider(height: 24),
            SwitchListTile(
              secondary: const Icon(Icons.school_rounded),
              title: const Text('게임 방법 안내'),
              subtitle: const Text('게임을 처음 열 때 방법을 알려 줘요 (언제든 건너뛸 수 있어요)'),
              value: settings.showTutorials,
              onChanged: (v) => settings.showTutorials = v,
            ),
            ListTile(
              leading: const Icon(Icons.replay_rounded),
              title: const Text('게임 방법 안내 다시 받기'),
              subtitle: const Text('모든 게임의 처음 안내를 다시 보여줘요'),
              onTap: () async {
                await TutorialProgress.resetSeen();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('다음에 게임을 열 때 방법 안내가 다시 나와요')),
                  );
              },
            ),
            const Divider(height: 24),
            _CardStylePicker(settings: settings),
            _CardLayoutPicker(settings: settings),
            _CardBackStylePicker(settings: settings),
            _SuitColorPicker(settings: settings),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('화면 모드'),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('자동')),
                  ButtonSegment(value: ThemeMode.light, label: Text('밝게')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('어둡게')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.themeMode = s.first,
              ),
            ),
            if (updatesSupported) ...[
              const Divider(height: 24),
              SwitchListTile(
                secondary: const Icon(Icons.system_update_rounded),
                title: const Text('시작할 때 업데이트 확인'),
                subtitle: const Text('새 버전이 나오면 알려 주고, 눌러서 바로 내려받아 설치해요'),
                value: settings.autoUpdateCheck,
                onChanged: (v) => settings.autoUpdateCheck = v,
              ),
              _UpdateTile(settings: settings),
            ],
          ],
        ),
      )),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.style_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            const Text('카드 뒷면', style: TextStyle(fontSize: 16)),
          ]),
          const SizedBox(height: 10),
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
      ),
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
class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.refresh_rounded),
      title: const Text('지금 업데이트 확인'),
      subtitle: FutureBuilder<AppVersion?>(
        future: UpdateService().currentVersion().then<AppVersion?>((v) => v).catchError((_) => null),
        builder: (_, snap) => Text(snap.data == null ? '현재 버전을 알 수 없어요' : '현재 버전 v${snap.data}'),
      ),
      onTap: () => checkForUpdate(context, settings, manual: true),
    );
  }
}
