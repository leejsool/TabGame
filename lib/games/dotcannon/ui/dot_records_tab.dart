import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/record_widgets.dart';
import '../core/dot_levels.dart';
import '../data/dot_custom_store.dart';
import '../data/dot_storage.dart';
import 'dot_menu_screen.dart' show dotAccent;
import 'dot_painter.dart';

/// 도트 캐논 기록 보드: 그림마다 최단 시간과 가장 적게 쓴 대포 수.
class DotRecordsTab extends StatefulWidget {
  const DotRecordsTab({super.key});

  @override
  State<DotRecordsTab> createState() => _DotRecordsTabState();
}

class _DotRecordsTabState extends State<DotRecordsTab> {
  List<DotLevel> _custom = [];
  Map<String, DotStageStats> _stats = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await DotCustomStore.loadAll();
    final stats = await DotStorage.statsFor([...dotLevels, ...custom]);
    if (!mounted) return;
    setState(() {
      _custom = custom;
      _stats = stats;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final all = [...dotLevels, ..._custom];
    final cleared = all.where((l) => _stats[l.id]?.cleared ?? false).length;
    final totalWins = all.fold<int>(0, (s, l) => s + (_stats[l.id]?.wins ?? 0));
    return RecordsList(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 150,
              child: StatCard(title: '깬 그림', value: '$cleared/${all.length}', sub: '클리어 $totalWins번', color: dotAccent),
            ),
          ],
        ),
        const SectionTitle('그림별 기록'),
        if (cleared == 0)
          const EmptyRecords(icon: Icons.grid_view_rounded, message: '아직 깬 그림이 없어요.\n그림을 다 지우면 시간과 대포 수가 기록돼요!')
        else
          for (final l in all)
            if (_stats[l.id]?.cleared ?? false) _row(context, l, _stats[l.id]!),
      ],
    );
  }

  Widget _row(BuildContext context, DotLevel l, DotStageStats s) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(painter: DotArtPainter(l.pixels, l.width, l.height, l.colors)),
        ),
        title: Text('${l.name} · ${formatTime(s.bestSeconds!)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '대포 최소 ${s.bestDeploys}대 · 클리어 ${s.wins}번${l.custom ? ' · 내가 만든 그림' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );
  }
}
