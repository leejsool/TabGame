import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../core/give_up.dart';
import '../../../records/record_widgets.dart';
import '../core/freecell_difficulty.dart';
import '../data/freecell_storage.dart';
import '../freecell_entry.dart';
import 'freecell_menu_screen.dart' show levelColors;

/// 프리셀 기록 보드: 요약 + 완성한 판 목록 (같은 번호 판 다시 하기).
class FreecellRecordsTab extends StatefulWidget {
  const FreecellRecordsTab({super.key});

  @override
  State<FreecellRecordsTab> createState() => _FreecellRecordsTabState();
}

class _FreecellRecordsTabState extends State<FreecellRecordsTab> {
  List<FreecellRecord> _all = [];
  FreecellStats _stats = const FreecellStats();
  FcDifficultyTable? _table;
  FcLevel? _filter;
  bool _fastFirst = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await FreecellStorage.loadHistory();
    final stats = await FreecellStorage.stats();
    FcDifficultyTable? table;
    try {
      table = await FcDifficultyTable.load();
    } catch (_) {
      table = null;
    }
    if (!mounted) return;
    setState(() {
      _all = all;
      _stats = stats;
      _table = table;
      _loaded = true;
    });
  }

  FcLevel? _levelOf(FreecellRecord r) => _table?.levelOf(r.deal);

  /// 난이도별 (완성한 판 수, 최단 시간) — 목록에 남아 있는 기록 기준.
  (int, int?) _levelSummary(FcLevel l) {
    final secs = [for (final r in _all) if (!r.gaveUp && _levelOf(r) == l) r.seconds];
    return (secs.length, secs.isEmpty ? null : secs.reduce((a, b) => a < b ? a : b));
  }

  Future<void> _replay(FreecellRecord r) async {
    await startFreecellDeal(context, r.deal, askIfSaved: true);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;
    final gaveUps = [for (final r in _all) if (r.gaveUp) r];
    final cleared = [for (final r in _all) if (!r.gaveUp) r];
    final list = [
      for (final r in cleared)
        if (_filter == null || _levelOf(r) == _filter) r,
    ];
    if (_fastFirst) list.sort((a, b) => a.seconds.compareTo(b.seconds));
    final bestSeconds = cleared.isEmpty ? null : cleared.map((r) => r.seconds).reduce((a, b) => a < b ? a : b);
    final s = _stats;

    return RecordsList(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 150,
          ),
          children: [
            StatCard(
              title: '완성한 판',
              value: '${s.wins}판',
              sub: s.starts == 0 ? '아직 시작한 판이 없어요' : '도전 ${s.starts}번 · 승률 ${(s.winRate * 100).round()}%',
              color: const Color(0xFF3F7CAC),
            ),
            StatCard(
              title: '최단 시간',
              value: s.bestSeconds == null ? '-' : formatTime(s.bestSeconds!),
              sub: '가장 빨리 끝낸 기록',
              color: const Color(0xFF3FA796),
            ),
            StatCard(
              title: '최소 이동',
              value: s.bestMoves == null ? '-' : '${s.bestMoves}수',
              sub: '가장 적게 움직여 끝낸 기록',
              color: const Color(0xFF8E5BC4),
            ),
          ],
        ),
        if (_table != null) ...[
          const SectionTitle('난이도별 기록'),
          Row(
            children: [
              for (final l in FcLevel.values) ...[
                Expanded(
                  child: StatCard(
                    title: l.label,
                    value: _levelSummary(l).$2 == null ? '-' : formatTime(_levelSummary(l).$2!),
                    sub: '${_levelSummary(l).$1}판 완성',
                    color: levelColors[l]!,
                  ),
                ),
                if (l != FcLevel.expert) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
        if (gaveUps.isNotEmpty) ...[
          const SectionTitle('포기한 판'),
          for (final r in gaveUps)
            GiveUpTile(
              icon: Icons.style_rounded,
              iconColor: const Color(0xFF2A7F58),
              title: '#${r.deal}',
              subtitle: '${r.moves}수${_levelOf(r) == null ? '' : ' · ${_levelOf(r)!.label}'}',
              seconds: r.seconds,
              at: r.at,
              onRetry: () => _replay(r),
            ),
        ],
        const SectionTitle('완성한 판'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_table != null) ...[
              ChoiceChip(
                label: const Text('전체'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final l in FcLevel.values)
                ChoiceChip(
                  label: Text(l.label),
                  selected: _filter == l,
                  onSelected: (_) => setState(() => _filter = l),
                ),
              const SizedBox(width: 8),
            ],
            FilterChip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('빠른 순'),
              selected: _fastFirst,
              onSelected: (v) => setState(() => _fastFirst = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          EmptyRecords(
            icon: Icons.style_rounded,
            message: cleared.isEmpty && s.wins > 0
                ? '판 목록 기능이 생기기 전에 완성한 판은 목록에 없어요.\n이제부터 완성하는 판은 번호와 함께 쌓여요!'
                : cleared.isEmpty
                    ? '아직 완성한 판이 없어요.\n한 판 끝내면 번호와 함께 기록되고, 같은 번호로 다시 해볼 수 있어요!'
                    : '이 난이도로 완성한 판이 아직 없어요.',
          )
        else
          for (final r in list)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A7F58).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.style_rounded, color: Color(0xFF2A7F58)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '#${r.deal} · ${formatTime(r.seconds)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (r.seconds == bestSeconds) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF2A900)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDate(r.at)} · ${r.moves}수${_levelOf(r) == null ? '' : ' · ${_levelOf(r)!.label}'}',
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                          ),
                        ],
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width < 460)
                      IconButton.filledTonal(
                        tooltip: '다시 하기',
                        onPressed: () => _replay(r),
                        icon: const Icon(Icons.replay_rounded),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: () => _replay(r),
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('다시 하기'),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
