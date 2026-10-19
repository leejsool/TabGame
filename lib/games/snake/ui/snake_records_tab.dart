import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../records/record_widgets.dart';
import '../data/snake_history.dart';
import 'snake_menu_screen.dart' show kSnakeColor;

/// 지렁이의 모험 기록 보드: 최고 점수·최고 순위·가장 많이 잡은 수, 그리고 최근 뱀들.
class SnakeRecordsTab extends StatefulWidget {
  const SnakeRecordsTab({super.key});

  @override
  State<SnakeRecordsTab> createState() => _SnakeRecordsTabState();
}

class _SnakeRecordsTabState extends State<SnakeRecordsTab> {
  List<SnakeRecord>? _list;

  @override
  void initState() {
    super.initState();
    SnakeHistory.load().then((l) {
      if (mounted) setState(() => _list = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return const RecordsList(children: [EmptyRecords(icon: Icons.gesture_rounded, message: '아직 기록이 없어요.\n지렁이가 한 번 끝나면 점수와 순위가 남아요!')]);
    }
    final best = list.map((r) => r.score).reduce(max);
    final rank = list.map((r) => r.bestRank).reduce(min);
    final kills = list.map((r) => r.kills).reduce(max);
    final firsts = list.where((r) => r.bestRank == 1).length;
    Widget card(String t, String v, String sub) => SizedBox(width: 150, child: StatCard(title: t, value: v, sub: sub, color: kSnakeColor));
    return RecordsList(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            card('최고 점수', '$best', '모두 ${list.length}마리'),
            card('최고 순위', '$rank등', '1등 $firsts번'),
            card('가장 많이 잡음', '$kills마리', '한 마리가 살아 있는 동안'),
          ],
        ),
        const SectionTitle('최근 기록'),
        for (final r in list.take(30)) _row(context, r),
      ],
    );
  }

  Widget _row(BuildContext context, SnakeRecord r) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kSnakeColor.withValues(alpha: 0.18),
          child: Text('${r.bestRank}등', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
        ),
        title: Text('점수 ${r.score}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '잡은 지렁이 ${r.kills} · ${formatTime(r.seconds)} 버팀${r.people > 1 ? ' · 사람 ${r.people}명' : ''} · ${formatDate(r.at.millisecondsSinceEpoch)}',
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );
  }
}
