import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/record_widgets.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../data/uttt_history.dart';
import 'uttt_board.dart';

/// 얼티밋 틱택토 기록 보드: CPU 난이도별 전적 + 2인 대결 요약 + 최근 결과.
class UtttRecordsTab extends StatefulWidget {
  const UtttRecordsTab({super.key});

  @override
  State<UtttRecordsTab> createState() => _UtttRecordsTabState();
}

class _UtttRecordsTabState extends State<UtttRecordsTab> {
  List<UtttRecord> _all = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    UtttHistory.load().then((v) {
      if (mounted) {
        setState(() {
          _all = v;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final cpu = _all.where((r) => r.vsCpu).toList();
    final two = _all.where((r) => !r.vsCpu).toList();
    return RecordsList(
      children: [
        const SectionTitle('CPU와 대결'),
        for (final level in UttLevel.values)
          _LevelRow(level: level, records: cpu.where((r) => r.level == level).toList()),
        const SectionTitle('둘이서 (한 기기)'),
        _TwoPlayerCard(records: two),
        const SectionTitle('최근 결과'),
        if (_all.isEmpty)
          const EmptyRecords(
            icon: Icons.tag_rounded,
            message: '아직 끝낸 판이 없어요.\n한 판 끝내면 여기에 전적이 쌓여요!',
          )
        else
          for (final r in _all.take(30)) _ResultTile(record: r),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.records});

  final UttLevel level;
  final List<UtttRecord> records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wins = records.where((r) => r.humanWon == true).length;
    final losses = records.where((r) => r.humanWon == false).length;
    final draws = records.where((r) => r.isDraw).length;
    final total = records.length;
    final rate = total == 0 ? 0.0 : wins / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(level.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                total == 0 ? '아직 기록이 없어요' : '$wins승 $losses패 $draws무',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: rate, minHeight: 8),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0 ? '' : '승률 ${(rate * 100).round()}% · $total판',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerCard extends StatelessWidget {
  const _TwoPlayerCard({required this.records});

  final List<UtttRecord> records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final x = records.where((r) => r.winner == kX).length;
    final o = records.where((r) => r.winner == kO).length;
    final draws = records.where((r) => r.isDraw).length;
    Widget cell(String label, int n, Color c) => Expanded(
          child: Column(
            children: [
              Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c)),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: records.isEmpty
          ? Center(
              child: Text(
                '아직 기록이 없어요',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
            )
          : Row(
              children: [
                cell('X 승', x, kXColor),
                cell('O 승', o, kOColor),
                cell('무승부', draws, scheme.outline),
                cell('총 판 수', records.length, scheme.onSurface),
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.record});

  final UtttRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = record;
    final IconData icon;
    final Color color;
    final String title;
    if (r.isDraw) {
      icon = Icons.handshake_rounded;
      color = scheme.outline;
      title = r.vsCpu ? '무승부 · CPU ${r.level!.label}' : '무승부';
    } else if (r.vsCpu) {
      final won = r.humanWon!;
      icon = won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded;
      color = won ? const Color(0xFFF2A900) : scheme.error;
      title = '${won ? '이겼어요' : '졌어요'} · CPU ${r.level!.label}';
    } else {
      icon = Icons.emoji_events_rounded;
      color = sideColor(r.winner!);
      title = '${sideLabel(r.winner!)} 승리';
    }
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) '${sideLabel(r.human!)}로 플레이' else '2인',
      '${r.moves}수',
    ].join(' · ');
    return Card(
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}
