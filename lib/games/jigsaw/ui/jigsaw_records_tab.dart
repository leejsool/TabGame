import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/format.dart';
import '../../../core/give_up.dart';
import '../../../records/favorites.dart';
import '../../../records/record_widgets.dart';
import '../data/jigsaw_history.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';
import 'jigsaw_images.dart';

const _countColors = {
  12: Color(0xFF3FA796),
  24: Color(0xFF3F7CAC),
  48: Color(0xFF8E5BC4),
  96: Color(0xFFD1495B),
};

/// 직소퍼즐 기록 보드: 조각 수별 요약 + 완성한 퍼즐 목록 (같은 그림으로 다시 하기).
class JigsawRecordsTab extends StatefulWidget {
  const JigsawRecordsTab({super.key});

  @override
  State<JigsawRecordsTab> createState() => _JigsawRecordsTabState();
}

class _JigsawRecordsTabState extends State<JigsawRecordsTab> {
  List<JigsawRecord> _all = [];
  final _favs = FavoriteSet(JigsawHistory.favorites);
  final Map<int, int?> _best = {};
  final Map<int, int> _wins = {};
  int? _filter;
  bool _fastFirst = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await JigsawHistory.load();
    await _favs.load();
    final best = <int, int?>{};
    final wins = <int, int>{};
    for (final (n, _) in kPieceChoices) {
      best[n] = await JigsawStorage.bestSeconds(n);
      wins[n] = await JigsawStorage.wins(n);
    }
    if (!mounted) return;
    setState(() {
      _all = all;
      _best
        ..clear()
        ..addAll(best);
      _wins
        ..clear()
        ..addAll(wins);
      _loaded = true;
    });
  }

  int? _bestIn(int target) {
    final s = [for (final r in _all) if (!r.gaveUp && r.target == target) r.seconds];
    return s.isEmpty ? null : s.reduce((a, b) => a < b ? a : b);
  }

  Future<void> _toggleFav(JigsawRecord r) async {
    await _favs.toggle(r);
    await JigsawStorage.pruneAfterHistoryChange(); // 즐겨찾기에서 뺀 퍼즐의 사진이 더 안 쓰이면 정리
    if (mounted) setState(() {});
  }

  Widget _tile(JigsawRecord r) => _RecordTile(
        record: r,
        isBest: r.seconds == _bestIn(r.target),
        isFav: _favs.has(r),
        onToggleFav: r.canReplay ? () => _toggleFav(r) : null,
        onReplay: r.canReplay ? () => _replay(r) : null,
      );

  Future<void> _replay(JigsawRecord r) async {
    await replayJigsawRecord(context, r);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final gaveUps = [for (final r in _all) if (r.gaveUp) r];
    final cleared = [for (final r in _all) if (!r.gaveUp) r];
    final list = [
      for (final r in cleared)
        if (_filter == null || r.target == _filter) r,
    ];
    if (_fastFirst) list.sort((a, b) => a.seconds.compareTo(b.seconds));
    final favs = _favs.shown(cleared, (r) => r.seconds);

    return RecordsList(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // 카드 높이를 고정해서, 좁은 화면에서도 글자가 넘치지 않게 한다
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 150,
          ),
          children: [
            for (final (n, name) in kPieceChoices)
              StatCard(
                title: '$name · $n조각',
                value: _best[n] == null ? '-' : formatTime(_best[n]!),
                sub: '최고 기록 · 완성 ${_wins[n] ?? 0}번',
                color: _countColors[n]!,
              ),
          ],
        ),
        if (favs.isNotEmpty) ...[
          const SectionTitle('즐겨찾기한 퍼즐'),
          for (final r in favs) _tile(r),
        ],
        if (gaveUps.isNotEmpty) ...[
          const SectionTitle('포기한 퍼즐'),
          for (final r in gaveUps)
            GiveUpTile(
              icon: Icons.extension_rounded,
              iconColor: _countColors[r.target] ?? const Color(0xFFE09F3E),
              title: '${r.pieces}조각',
              subtitle: r.canReplay ? '${r.placed}조각 맞춤' : '${r.placed}조각 맞춤 · 그림이 남아 있지 않아요',
              seconds: r.seconds,
              at: r.at,
              onRetry: r.canReplay ? () => _replay(r) : null,
            ),
        ],
        const SectionTitle('완성한 퍼즐'),
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
            for (final (n, _) in kPieceChoices)
              ChoiceChip(
                label: Text('$n조각'),
                selected: _filter == n,
                onSelected: (_) => setState(() => _filter = n),
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
            icon: Icons.extension_rounded,
            message: cleared.isEmpty && _wins.values.any((n) => n > 0)
                ? '판 목록 기능이 생기기 전에 완성한 퍼즐은 목록에 없어요.\n이제부터 완성하는 퍼즐은 여기에 쌓이고, 같은 그림으로 다시 해볼 수 있어요!'
                : cleared.isEmpty
                    ? '아직 완성한 퍼즐이 없어요.\n한 장 완성하면 여기에 기록되고, 같은 그림으로 다시 해볼 수 있어요!'
                    : '이 조각 수로 완성한 퍼즐이 아직 없어요.',
          )
        else
          for (final r in list) _tile(r),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.isBest,
    required this.isFav,
    required this.onToggleFav,
    required this.onReplay,
  });

  final JigsawRecord record;
  final bool isBest;
  final bool isFav;

  /// 그림을 다시 불러올 수 없는 기록은 null (별이 없다).
  final VoidCallback? onToggleFav;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            _Thumb(source: record.source),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${record.pieces}조각 · ${formatTime(record.seconds)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF2A900)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.canReplay
                        ? formatDate(record.at)
                        : '${formatDate(record.at)} · 그림이 남아 있지 않아요',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            if (onToggleFav != null) FavoriteStar(on: isFav, onTap: onToggleFav!),
            // 좁은 화면(폰)에서는 아이콘만 보여준다
            if (MediaQuery.sizeOf(context).width < 460)
              IconButton.filledTonal(
                tooltip: '다시 하기',
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('다시 하기'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 기록 한 줄의 그림 미리보기.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.source});

  final JigsawSource source;

  static final Map<String, Future<ui.Image>> _sampleThumbs = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, color: scheme.outline),
    );
    Widget child = placeholder;
    if (source.kind == 'sample') {
      final f = _sampleThumbs.putIfAbsent(source.ref, () => SampleArt.render(source.ref, scale: 0.18));
      child = FutureBuilder<ui.Image>(
        future: f,
        builder: (_, snap) =>
            snap.data == null ? placeholder : RawImage(image: snap.data, fit: BoxFit.cover),
      );
    } else if (source.kind == 'file' && !kIsWeb) {
      child = Image.file(
        File(source.ref),
        cacheWidth: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 64, height: 64, child: child),
    );
  }
}
