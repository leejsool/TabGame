import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../records/record_widgets.dart';
import '../core/mines_rules.dart';
import '../data/mines_storage.dart';
import 'mines_menu_screen.dart' show levelColors;

/// 지뢰찾기 기록 보드: 난이도별 요약 + 최근 클리어 목록.
class MinesRecordsTab extends StatefulWidget {
  const MinesRecordsTab({super.key});

  @override
  State<MinesRecordsTab> createState() => _MinesRecordsTabState();
}

class _MinesRecordsTabState extends State<MinesRecordsTab> {
  List<MinesRecord> _all = [];
  final Map<MinesLevel, MinesStats> _stats = {};
  MinesLevel? _filter;
  bool _fastFirst = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await MinesStorage.loadHistory();
    for (final l in MinesLevel.values) {
      _stats[l] = await MinesStorage.stats(l);
    }
    if (!mounted) return;
    setState(() {
      _all = all;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;
    final list = [
      for (final r in _all)
        if (_filter == null || r.level == _filter) r,
    ];
    if (_fastFirst) list.sort((a, b) => a.seconds.compareTo(b.seconds));
    final best = list.isEmpty ? null : list.map((r) => r.seconds).reduce((a, b) => a < b ? a : b);

    return RecordsList(
      children: [
        Row(
          children: [
            for (final l in MinesLevel.values) ...[
              Expanded(
                child: StatCard(
                  title: l.label,
                  value: _stats[l]!.bestSeconds == null ? '-' : formatTime(_stats[l]!.bestSeconds!),
                  sub: _stats[l]!.starts == 0
                      ? '아직 시작한 판이 없어요'
                      : '클리어 ${_stats[l]!.wins} · 승률 ${(_stats[l]!.winRate * 100).round()}%',
                  color: levelColors[l]!,
                ),
              ),
              if (l != MinesLevel.expert) const SizedBox(width: 8),
            ],
          ],
        ),
        const SectionTitle('클리어한 판'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(label: const Text('전체'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
            for (final l in MinesLevel.values)
              ChoiceChip(label: Text(l.label), selected: _filter == l, onSelected: (_) => setState(() => _filter = l)),
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
          const EmptyRecords(
            icon: Icons.flag_rounded,
            message: '아직 클리어한 판이 없어요.\n지뢰를 피해 한 판 끝내면 시간이 기록돼요!',
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
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: levelColors[r.level]!.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_rounded, color: levelColors[r.level]),
                ),
                title: Row(
                  children: [
                    Text(
                      '${r.level.label} · ${formatTime(r.seconds)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (r.seconds == best) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF2A900)),
                    ],
                  ],
                ),
                subtitle: Text(formatDate(r.at), style: const TextStyle(fontSize: 12.5)),
              ),
            ),
      ],
    );
  }
}
