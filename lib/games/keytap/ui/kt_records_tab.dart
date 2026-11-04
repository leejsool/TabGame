import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/record_widgets.dart';
import '../core/kt_songs.dart';
import '../data/kt_history.dart';
import 'kt_board.dart';
import 'kt_hud.dart';

/// 건반 톡톡 기록 보드: 곡마다 별·최고 점수, 무한 최고 점수, Wi‑Fi 경주 1등 횟수, 최근 판.
class KtRecordsTab extends StatefulWidget {
  const KtRecordsTab({super.key});

  @override
  State<KtRecordsTab> createState() => _KtRecordsTabState();
}

class _KtRecordsTabState extends State<KtRecordsTab> {
  List<KtRecord>? _list;
  Map<String, KtBest> _bests = const {};

  @override
  void initState() {
    super.initState();
    () async {
      final l = await KtHistory.load();
      final b = await KtHistory.bests();
      if (mounted) {
        setState(() {
          _list = l;
          _bests = b;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return const RecordsList(children: [EmptyRecords(icon: Icons.piano_rounded, message: '아직 기록이 없어요.\n곡을 한 번 쳐 보면 별과 점수가 남아요!')]);
    }
    final races = list.where((r) => r.kind == 'race').toList();
    final wins = races.where((r) => r.rank == 1).length;
    final stars = KtSong.all.fold<int>(0, (a, s) => a + (_bests[s.id]?.stars ?? 0));
    Widget card(String t, String v, String sub) => SizedBox(width: 150, child: StatCard(title: t, value: v, sub: sub, color: kKeytapColor));
    return RecordsList(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            card('모은 별', '$stars개', '모두 ${KtSong.all.length * 3}개 중'),
            card('무한 최고', '${_bests['endless']?.score ?? 0}점', '틀릴 때까지'),
            if (races.isNotEmpty) card('경주 1등', '$wins번', '경주 ${races.length}번'),
          ],
        ),
        const SectionTitle('곡별 최고 기록'),
        for (final s in KtSong.all)
          ListTile(
            dense: true,
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text((_bests[s.id]?.score ?? 0) > 0 ? '최고 ${_bests[s.id]!.score}점' : '아직 안 쳐 봤어요'),
            trailing: KtStars(stars: _bests[s.id]?.stars ?? 0, size: 20),
          ),
        const SectionTitle('최근 기록'),
        for (final r in list.take(30))
          ListTile(
            dense: true,
            leading: Icon(r.kind == 'race' ? Icons.wifi_rounded : (r.kind == 'endless' ? Icons.all_inclusive_rounded : Icons.music_note_rounded), color: kKeytapColor),
            title: Text('${r.kind == 'endless' ? '무한 모드' : (KtSong.byId(r.song)?.title ?? r.song)} · ${r.score}점', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (r.kind == 'race') '경주 ${r.players}명 중 ${r.rank}등',
              if (r.kind == 'song') '별 ${r.stars}개',
              formatDate(r.at.millisecondsSinceEpoch),
            ].join(' · ')),
          ),
      ],
    );
  }
}
