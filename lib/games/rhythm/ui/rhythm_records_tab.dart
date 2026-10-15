import 'package:flutter/material.dart';

import '../../../records/record_widgets.dart';
import '../core/rhythm_chart.dart';
import '../data/rhythm_storage.dart';

const _gold = Color(0xFFF2A900);

/// 리듬 검사단 기록 보드: 코스(스테이지)마다 최고 기록 한 장씩.
///
/// 판마다 남기는 목록은 없고, 코스별로 가장 잘한 기록(별·점수·정확도)과 수료 횟수만 보여 준다.
class RhythmRecordsTab extends StatefulWidget {
  const RhythmRecordsTab({super.key});

  @override
  State<RhythmRecordsTab> createState() => _RhythmRecordsTabState();
}

class _RhythmRecordsTabState extends State<RhythmRecordsTab> {
  final List<RhythmResult?> _best = List.filled(RhythmCourse.all.length, null);
  final List<int> _clears = List.filled(RhythmCourse.all.length, 0);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final best = <RhythmResult?>[];
    final clears = <int>[];
    for (var i = 0; i < RhythmCourse.all.length; i++) {
      best.add(await RhythmStorage.loadBest(i));
      clears.add(await RhythmStorage.clears(i));
    }
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < best.length; i++) {
        _best[i] = best[i];
        _clears[i] = clears[i];
      }
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final totalStars = _best.fold<int>(0, (a, b) => a + (b?.stars ?? 0));
    final maxStars = RhythmCourse.all.length * 3;
    return RecordsList(
      children: [
        const SectionTitle('코스별 최고 기록'),
        Text(
          '별 $totalStars / $maxStars개',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < RhythmCourse.all.length; i++)
          _CourseCard(index: i, course: RhythmCourse.all[i], best: _best[i], clears: _clears[i]),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.index, required this.course, required this.best, required this.clears});

  final int index;
  final RhythmCourse course;
  final RhythmResult? best;
  final int clears;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = best;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Text('${index + 1}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: scheme.primary)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  if (r == null)
                    Text('아직 수료하지 않았어요', style: muted)
                  else ...[
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(Icons.star_rounded, size: 22, color: i < r.stars ? _gold : scheme.outlineVariant),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('최고 ${r.score}점 · 정확도 ${(r.accuracy * 100).round()}% · $clears회 수료', style: muted),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
