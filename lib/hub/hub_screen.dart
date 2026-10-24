import 'package:flutter/material.dart';

import '../core/game_filter.dart';
import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import '../core/update/update_ui.dart';
import '../records/records_screen.dart';
import 'game_card.dart';
import 'launch.dart';
import 'rejoin_cards.dart';
import 'settings_screen.dart';

/// 첫 화면: 게임 목록.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.settings, this.initialFilter = GameFilter.all});

  final Settings settings;

  /// 앱을 켰을 때 골라져 있는 분류 (앱은 멘토링으로 시작한다).
  final GameFilter initialFilter;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late GameFilter _filter = widget.initialFilter;

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
    // 설정에서 숨겨 둔 게임은 메인 화면에 보이지 않는다 (설정이 바뀌면 바로 반영)
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final shown = [for (final g in allGames) if (widget.settings.isGameVisible(g.id)) g];
        final solo = shown.where((g) => g.hasSolo).toList();
        final multi = shown.where((g) => g.hasMulti).toList();
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                const SliverToBoxAdapter(child: RejoinCards()),
                if (shown.isEmpty) SliverToBoxAdapter(child: _allHidden(context)),
                if (_filter == GameFilter.all || _filter == GameFilter.solo)
                  ..._section(context, '혼자 놀기', Icons.person_rounded, solo),
                if (_filter == GameFilter.all || _filter == GameFilter.multi)
                  ..._section(context, '함께 놀기', Icons.groups_rounded, multi),
                // Wi‑Fi·교과학습처럼 등록 정보로 정해지는 분류는 해당 게임만 한 묶음으로 모아 보여 준다
                if (_filter != GameFilter.all && _filter != GameFilter.solo && _filter != GameFilter.multi)
                  ..._section(context, _filterTitle(_filter), _filter.icon, [for (final g in shown) if (_filter.matches(g)) g]),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 게임을 모두 숨겨 둔 경우의 안내.
  Widget _allHidden(BuildContext context) {
    return Padding(
      key: const ValueKey('hub-all-hidden'),
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
      child: Column(
        children: [
          Icon(Icons.visibility_off_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('보이는 게임이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('설정에서 메인 화면에 보일 게임을 켜 주세요.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: widget.settings.showAllGames,
            child: const Text('모든 게임 다시 보이기'),
          ),
        ],
      ),
    );
  }

  String _filterTitle(GameFilter f) => switch (f) {
        GameFilter.wifi => '같은 Wi‑Fi로 함께',
        GameFilter.lesson => '교과학습이 있는 게임',
        GameFilter.mentoring => '멘토링 게임',
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
                    // 폰에서 "놀이 / 터"처럼 끊기지 않게 한 줄로 두고, 모자라면 살짝 줄인다
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('혼자서도, 함께도 즐거운 게임 놀이터', maxLines: 1, style: text.bodyLarge),
                    ),
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
    if (games.isEmpty) return const []; // (모두 숨긴 묶음은 제목도 보이지 않는다)
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
