import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import '../core/update/update_ui.dart';
import '../records/records_screen.dart';
import 'game_card.dart';
import 'launch.dart';
import 'settings_screen.dart';

enum _Filter { all, solo, multi }

extension on _Filter {
  IconData get icon => switch (this) {
        _Filter.all => Icons.apps_rounded,
        _Filter.solo => Icons.person_rounded,
        _Filter.multi => Icons.groups_rounded,
      };

  String get label => switch (this) {
        _Filter.all => '전체',
        _Filter.solo => '혼자',
        _Filter.multi => '함께',
      };
}

/// 칸 구분선 없이 알약 모양으로 고르는 필터. 고른 항목만 아이콘+글자, 나머지는 아이콘만 보인다.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final _Filter selected;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in _Filter.values)
            _FilterPill(
              filter: f,
              selected: f == selected,
              onTap: () => onChanged(f),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.filter, required this.selected, required this.onTap});

  final _Filter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Tooltip(
      message: filter.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon, size: 24, color: fg),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(filter.label,
                            softWrap: false,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 첫 화면: 게임 목록.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.settings});

  final Settings settings;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    // 앱을 켜면 GitHub에 새 버전이 있는지 슬쩍 확인한다 (있을 때만 알려준다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) autoCheckForUpdate(context, widget.settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    final solo = allGames.where((g) => g.hasSolo).toList();
    final multi = allGames.where((g) => g.hasMulti).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_filter != _Filter.multi) ..._section(context, '혼자 놀기', Icons.person_rounded, solo),
            if (_filter != _Filter.solo) ..._section(context, '함께 놀기', Icons.groups_rounded, multi),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TabGame',
                        style: text.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text('혼자서도, 함께도 즐거운 게임 놀이터',
                        style: text.bodyLarge),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: '내 기록',
                iconSize: 28,
                icon: const Icon(Icons.emoji_events_rounded),
                onPressed: () => openRecords(context),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '설정',
                iconSize: 28,
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(settings: widget.settings),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _FilterBar(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, IconData icon, List<GameInfo> games) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            mainAxisExtent: 220,
          ),
          itemCount: games.length,
          itemBuilder: (context, i) => GameCard(
            game: games[i],
            onTap: () => launchGame(context, games[i]),
          ),
        ),
      ),
    ];
  }
}
