import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../records/record_widgets.dart';
import '../core/sprouts_ai.dart';
import '../data/sprouts_history.dart';
import 'sprouts_painter.dart';
import 'sprouts_screen.dart';

/// 콩나물 기록 보드: CPU 난이도별 전적 + 둘이서 요약 + 최근 결과.
class SproutsRecordsTab extends StatefulWidget {
  const SproutsRecordsTab({super.key});

  @override
  State<SproutsRecordsTab> createState() => _SproutsRecordsTabState();
}

class _SproutsRecordsTabState extends State<SproutsRecordsTab> {
  List<SproutsRecord> _all = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SproutsHistory.load().then((v) {
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
        for (final level in SproutsLevel.values) _LevelRow(level: level, records: cpu.where((r) => r.level == level).toList()),
        const SectionTitle('둘이서 (한 기기)'),
        _TwoPlayerCard(records: two),
        const SectionTitle('최근 결과'),
        if (_all.isEmpty)
          const EmptyRecords(
            icon: Icons.scatter_plot_rounded,
            message: '아직 끝낸 판이 없어요.\n한 판 끝내면 여기에 전적이 쌓여요!',
          )
        else
          for (final r in _all.take(30))
            _ResultTile(
              record: r,
              onRetry: r.resigned && r.vsCpu
                  ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SproutsScreen(mode: PlayMode.vsCpu, dotCount: r.dots, humanSide: r.human!, level: r.level!),
                      ))
                  : null,
            ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.records});

  final SproutsLevel level;
  final List<SproutsRecord> records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wins = records.where((r) => r.humanWon == true).length;
    final losses = records.where((r) => r.humanWon == false).length;
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
                total == 0 ? '아직 기록이 없어요' : '$wins승 $losses패',
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

  final List<SproutsRecord> records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p1 = records.where((r) => r.winner == 0).length;
    final p2 = records.where((r) => r.winner == 1).length;
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
          ? Center(child: Text('아직 기록이 없어요', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))))
          : Row(
              children: [
                cell('플레이어 1 승', p1, sproutsColor(0)),
                cell('플레이어 2 승', p2, sproutsColor(1)),
                cell('총 판 수', records.length, scheme.onSurface),
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.record, this.onRetry});

  final SproutsRecord record;

  /// 기권한 CPU 대결을 같은 설정(점 수·난이도·맡은 쪽)으로 다시 해 본다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = record;
    final IconData icon;
    final Color color;
    final String title;
    if (r.vsCpu) {
      final won = r.humanWon!;
      icon = won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded;
      color = won ? const Color(0xFFF2A900) : scheme.error;
      title = '${won ? '이겼어요' : r.resigned ? '기권했어요' : '졌어요'} · CPU ${r.level!.label}';
    } else {
      icon = Icons.emoji_events_rounded;
      color = sproutsColor(r.winner);
      title = r.resigned ? '플레이어 ${2 - r.winner} 기권 · 플레이어 ${r.winner + 1} 승리' : '플레이어 ${r.winner + 1} 승리';
    }
    final detail = [
      formatDate(r.at),
      '점 ${r.dots}개',
      if (r.vsCpu) (r.human == 0 ? '먼저' : '나중') else '2인',
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
        title: Row(
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (r.resigned) ...[const SizedBox(width: 6), const GiveUpChip()],
          ],
        ),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12.5)),
        trailing: r.resigned && r.vsCpu && onRetry != null
            ? IconButton.filledTonal(tooltip: '다시 도전', onPressed: onRetry, icon: const Icon(Icons.replay_rounded))
            : null,
      ),
    );
  }
}
