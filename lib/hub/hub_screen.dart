import 'package:flutter/material.dart';

import '../core/game_filter.dart';
import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import '../core/update/update_ui.dart';
import '../records/records_screen.dart';
import 'game_card.dart';
import 'launch.dart';
import 'settings_screen.dart';

/// 첫 화면: 게임 목록.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.settings});

  final Settings settings;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  GameFilter _filter = GameFilter.all;

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
            if (_filter == GameFilter.all || _filter == GameFilter.solo)
              ..._section(context, '혼자 놀기', Icons.person_rounded, solo),
            if (_filter == GameFilter.all || _filter == GameFilter.multi)
              ..._section(context, '함께 놀기', Icons.groups_rounded, multi),
            // Wi‑Fi·교과학습처럼 등록 정보로 정해지는 분류는 해당 게임만 한 묶음으로 모아 보여 준다
            if (_filter != GameFilter.all && _filter != GameFilter.solo && _filter != GameFilter.multi)
              ..._section(context, _filterTitle(_filter), _filter.icon, [for (final g in allGames) if (_filter.matches(g)) g]),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _filterTitle(GameFilter f) => switch (f) {
        GameFilter.wifi => '같은 Wi‑Fi로 함께',
        GameFilter.lesson => '교과학습이 있는 게임',
        _ => f.label,
      };

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
                    Text(
                      'TabGame',
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('혼자서도, 함께도 즐거운 게임 놀이터', style: text.bodyLarge),
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
          GameFilterBar(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    IconData icon,
    List<GameInfo> games,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      // 폰처럼 좁은 화면에서는 카드 폭을 절반으로 줄여 한 줄에 두 장씩 놓는다 (스크롤을 줄이려고)
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
        sliver: SliverGrid.builder(
          gridDelegate: compact
              ? const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 212,
                )
              : const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  mainAxisExtent: 220,
                ),
          itemCount: games.length,
          itemBuilder: (context, i) => GameCard(
            game: games[i],
            compact: compact,
            onTap: () => launchGame(context, games[i]),
          ),
        ),
      ),
    ];
  }
}
