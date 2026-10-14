import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../core/give_up.dart';
import '../../../records/record_widgets.dart';
import '../core/generator.dart';
import '../data/sudoku_history.dart';
import '../data/sudoku_storage.dart';
import '../sudoku_entry.dart';

const _levelColors = {
  Difficulty.easy: Color(0xFF3FA796),
  Difficulty.medium: Color(0xFF3F7CAC),
  Difficulty.hard: Color(0xFF8E5BC4),
};

/// 스도쿠 기록 보드: 난이도별 요약 + 완성한 판 목록 (같은 판 다시 풀기).
class SudokuRecordsTab extends StatefulWidget {
  const SudokuRecordsTab({super.key});

  @override
  State<SudokuRecordsTab> createState() => _SudokuRecordsTabState();
}

class _SudokuRecordsTabState extends State<SudokuRecordsTab> {
  List<SudokuRecord> _all = [];
  final Map<Difficulty, SudokuStats> _stats = {};
  Difficulty? _filter;
  bool _fastFirst = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await SudokuHistory.load();
    final stats = <Difficulty, SudokuStats>{
      for (final d in Difficulty.values) d: await SudokuStorage.stats(d),
    };
    if (!mounted) return;
    setState(() {
      _all = all;
      _stats
        ..clear()
        ..addAll(stats);
      _loaded = true;
    });
  }

  /// 난이도별 최단 기록 (이 목록 안에서).
  int? _bestIn(Difficulty d) {
    final s = [for (final r in _all) if (!r.gaveUp && r.difficulty == d) r.seconds];
    return s.isEmpty ? null : s.reduce((a, b) => a < b ? a : b);
  }

  String _avgText(Difficulty d) {
    final s = [for (final r in _all) if (!r.gaveUp && r.difficulty == d) r.seconds];
    if (s.isEmpty) return '';
    final avg = s.reduce((a, b) => a + b) ~/ s.length;
    return ' · 평균 ${formatTime(avg)}';
  }

  Future<void> _replay(SudokuRecord r) async {
    await replaySudokuRecord(context, r);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final gaveUps = [for (final r in _all) if (r.gaveUp) r];
    final list = [
      for (final r in _all)
        if (!r.gaveUp && (_filter == null || r.difficulty == _filter)) r,
    ];
    if (_fastFirst) list.sort((a, b) => a.seconds.compareTo(b.seconds));

    return RecordsList(
      children: [
        Row(
          children: [
            for (final d in Difficulty.values) ...[
              Expanded(
                child: StatCard(
                  title: d.label,
                  value: _stats[d]?.bestSeconds == null ? '-' : formatTime(_stats[d]!.bestSeconds!),
                  sub: '최고 기록 · 완성 ${_stats[d]?.wins ?? 0}번${_avgText(d)}',
                  color: _levelColors[d]!,
                ),
              ),
              if (d != Difficulty.hard) const SizedBox(width: 10),
            ],
          ],
        ),
        if (gaveUps.isNotEmpty) ...[
          const SectionTitle('포기한 판'),
          for (final r in gaveUps)
            GiveUpTile(
              icon: Icons.grid_on_rounded,
              iconColor: _levelColors[r.difficulty]!,
              title: r.difficulty.label,
              subtitle: '실수 ${r.mistakes} · 힌트 ${r.hints}',
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
            ChoiceChip(
              label: const Text('전체'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final d in Difficulty.values)
              ChoiceChip(
                label: Text(d.label),
                selected: _filter == d,
                onSelected: (_) => setState(() => _filter = d),
              ),
            const SizedBox(width: 8),
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
            icon: Icons.grid_on_rounded,
            message: _all.every((r) => r.gaveUp) && _stats.values.any((s) => s.wins > 0)
                ? '판 목록 기능이 생기기 전에 완성한 판은 목록에 없어요.\n이제부터 완성하는 판은 여기에 쌓이고, 같은 판을 다시 풀어볼 수 있어요!'
                : _all.every((r) => r.gaveUp)
                    ? '아직 완성한 판이 없어요.\n한 판 끝내면 여기에 기록되고, 같은 판을 다시 풀어볼 수 있어요!'
                    : '이 난이도로 완성한 판이 아직 없어요.',
          )
        else
          for (final r in list)
            _RecordTile(
              record: r,
              isBest: r.seconds == _bestIn(r.difficulty),
              onReplay: () => _replay(r),
            ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.isBest, required this.onReplay});

  final SudokuRecord record;
  final bool isBest;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final color = _levelColors[record.difficulty]!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
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
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.grid_on_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${record.difficulty.label} · ${formatTime(record.seconds)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF2A900)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDate(record.at)} · 실수 ${record.mistakes} · 힌트 ${record.hints}',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            // 좁은 화면(폰)에서는 아이콘만 보여준다
            if (MediaQuery.sizeOf(context).width < 460)
              IconButton.filledTonal(
                tooltip: '다시 풀기',
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('다시 풀기'),
              ),
          ],
        ),
      ),
    );
  }
}
