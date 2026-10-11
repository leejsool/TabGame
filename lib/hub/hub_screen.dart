import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import '../records/records_screen.dart';
import 'game_card.dart';
import 'launch.dart';
import 'settings_screen.dart';

enum _Filter { all, solo, multi }

/// 폭이 고정된 필터 버튼 글자 (글자 폭 계산에 기대지 않아 어떤 기기에서도 안 깨진다).
class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        child: Text(text, textAlign: TextAlign.center, softWrap: false),
      );
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
  Widget build(BuildContext context) {
    final solo = allGames.where((g) => g.hasSolo).toList();
    final multi = allGames.where((g) => g.hasMulti).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_filter != _Filter.multi) ..._section(context, '혼자 놀기', solo),
            if (_filter != _Filter.solo) ..._section(context, '함께 놀기', multi),
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
          SegmentedButton<_Filter>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            segments: const [
              ButtonSegment(value: _Filter.all, label: _FilterLabel('전체')),
              ButtonSegment(value: _Filter.solo, label: _FilterLabel('혼자')),
              ButtonSegment(value: _Filter.multi, label: _FilterLabel('함께')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<GameInfo> games) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
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
