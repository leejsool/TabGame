import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/record_widgets.dart';
import '../data/pinball_history.dart';
import 'pinball_hud.dart' show fmtNum, kPinballColor;

/// 핀볼 기록 보드: 최고 라운드·최고 점수·최고 콤보, 그리고 최근 도전들.
class PinballRecordsTab extends StatefulWidget {
  const PinballRecordsTab({super.key});

  @override
  State<PinballRecordsTab> createState() => _PinballRecordsTabState();
}

class _PinballRecordsTabState extends State<PinballRecordsTab> {
  List<PinballRecord>? _list;

  @override
  void initState() {
    super.initState();
    PinballHistory.load().then((l) {
      if (mounted) setState(() => _list = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return const RecordsList(children: [EmptyRecords(icon: Icons.blur_circular_rounded, message: '아직 기록이 없어요.\n한 번 도전하면 도착한 라운드와 점수가 남아요!')]);
    }
    final bestRound = list.map((r) => r.round).reduce(max);
    final bestScore = list.map((r) => r.score).reduce(max);
    final bestCombo = list.map((r) => r.bestCombo).reduce(max);
    Widget card(String t, String v, String sub) => SizedBox(width: 150, child: StatCard(title: t, value: v, sub: sub, color: kPinballColor));
    return RecordsList(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            card('가장 먼 라운드', '$bestRound라운드', '모두 ${list.length}번 도전'),
            card('최고 점수', fmtNum(bestScore), '한 번의 도전에서'),
            card('최고 콤보', '$bestCombo', '연속으로 맞힌 수'),
          ],
        ),
        const SectionTitle('최근 도전'),
        for (final r in list.take(30)) _row(context, r),
      ],
    );
  }

  Widget _row(BuildContext context, PinballRecord r) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPinballColor.withValues(alpha: 0.18),
          child: Text('${r.round}R', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
        title: Text('${r.round}라운드 · ${fmtNum(r.score)}점', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '최고 콤보 ${r.bestCombo} · 업그레이드 ${r.upgrades}개 · ${formatDate(r.at.millisecondsSinceEpoch)}'
          '${r.names.isEmpty ? '' : '\n${r.names.join(', ')}'}',
          style: const TextStyle(fontSize: 12.5),
        ),
        isThreeLine: r.names.isNotEmpty,
      ),
    );
  }
}
