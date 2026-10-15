import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../core/give_up.dart';
import '../../../records/favorites.dart';
import '../../../records/record_widgets.dart';
import '../data/solitaire_storage.dart';
import '../solitaire_entry.dart';

/// 솔리테어 기록 보드: 뽑기 장수별 요약 + 완성한 판 목록 (같은 번호 판 다시 하기).
class SolitaireRecordsTab extends StatefulWidget {
  const SolitaireRecordsTab({super.key});

  @override
  State<SolitaireRecordsTab> createState() => _SolitaireRecordsTabState();
}

class _SolitaireRecordsTabState extends State<SolitaireRecordsTab> {
  List<SolitaireRecord> _all = [];
  final _favs = FavoriteSet(SolitaireStorage.favorites);
  final Map<int, SolitaireStats> _stats = {};
  int? _filter; // null = 전체, 1, 3
  bool _fastFirst = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await SolitaireStorage.loadHistory();
    await _favs.load();
    final s1 = await SolitaireStorage.stats(1);
    final s3 = await SolitaireStorage.stats(3);
    if (!mounted) return;
    setState(() {
      _all = all;
      _stats[1] = s1;
      _stats[3] = s3;
      _loaded = true;
    });
  }

  Future<void> _toggleFav(SolitaireRecord r) async {
    await _favs.toggle(r);
    if (mounted) setState(() {});
  }

  /// 완성한 판 한 줄: 번호·시간, 날짜·수, 즐겨찾기 별, 다시 하기.
  Widget _tile(SolitaireRecord r, ColorScheme scheme, int? bestSeconds) {
    const green = Color(0xFF2E7D5B);
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
              decoration: BoxDecoration(color: green.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.style_rounded, color: green),
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
                    '${formatDate(r.at)} · ${r.moves}수 · ${r.draw}장 뽑기',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            FavoriteStar(on: _favs.has(r), onTap: () => _toggleFav(r)),
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
    );
  }

  Future<void> _replay(SolitaireRecord r) async {
    await startSolitaireDeal(context, r.deal, r.draw, askIfSaved: true);
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
        if (_filter == null || r.draw == _filter) r,
    ];
    if (_fastFirst) list.sort((a, b) => a.seconds.compareTo(b.seconds));
    final bestSeconds = list.isEmpty ? null : list.map((r) => r.seconds).reduce((a, b) => a < b ? a : b);
    final favs = _favs.shown(cleared, (r) => r.seconds);

    Widget statRow(int draw, Color color) {
      final s = _stats[draw] ?? const SolitaireStats();
      return Row(
        children: [
          Expanded(
            child: StatCard(
              title: '$draw장 뽑기',
              value: '${s.wins}판',
              sub: s.starts == 0 ? '아직 시작한 판이 없어요' : '도전 ${s.starts}번 · 승률 ${(s.winRate * 100).round()}%',
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              title: '최단 시간',
              value: s.bestSeconds == null ? '-' : formatTime(s.bestSeconds!),
              sub: s.bestMoves == null ? '가장 빨리 끝낸 기록' : '최소 이동 ${s.bestMoves}수',
              color: color,
            ),
          ),
        ],
      );
    }

    return RecordsList(
      children: [
        statRow(1, const Color(0xFF3FA796)),
        const SizedBox(height: 10),
        statRow(3, const Color(0xFF8E5BC4)),
        if (favs.isNotEmpty) ...[
          const SectionTitle('즐겨찾기한 판'),
          for (final r in favs) _tile(r, scheme, bestSeconds),
        ],
        if (gaveUps.isNotEmpty) ...[
          const SectionTitle('포기한 판'),
          for (final r in gaveUps)
            GiveUpTile(
              icon: Icons.style_rounded,
              iconColor: const Color(0xFF2E7D5B),
              title: '#${r.deal}',
              subtitle: '${r.moves}수 · ${r.draw}장 뽑기',
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
            ChoiceChip(label: const Text('전체'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
            ChoiceChip(label: const Text('1장 뽑기'), selected: _filter == 1, onSelected: (_) => setState(() => _filter = 1)),
            ChoiceChip(label: const Text('3장 뽑기'), selected: _filter == 3, onSelected: (_) => setState(() => _filter = 3)),
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
            icon: Icons.style_rounded,
            message: cleared.isEmpty
                ? '아직 완성한 판이 없어요.\n한 판 끝내면 번호와 함께 기록되고, 같은 번호로 다시 해볼 수 있어요!'
                : '이 방식으로 완성한 판이 아직 없어요.',
          )
        else
          for (final r in list) _tile(r, scheme, bestSeconds),
      ],
    );
  }
}
