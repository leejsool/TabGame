part of 'jigsaw_menu_screen.dart';

// 카드·칸 위젯 (파일을 역할별로 나눈 것)

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.photo_library_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '갤러리에서 사진 고르기',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '내 사진으로 나만의 퍼즐을 만들어요',
                      style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.info, required this.image, required this.onTap});

  final SampleInfo info;
  final ui.Image? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _tileWidth(context),
      child: Material(
        color: scheme.surface,
        elevation: 1.5,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: image == null
                      ? ColoredBox(color: scheme.surfaceContainerHighest)
                      : RawImage(image: image, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(info.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.save, required this.onTap});

  final JigsawSave save;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placed = (save.state['placed'] as List).where((v) => v == 1).length;
    final total = (save.state['placed'] as List).length;
    final elapsed = save.state['elapsed'] as int;
    return ResumeCard(detail: '$total조각 · $placed/$total 맞춤 · ${formatTime(elapsed)}', onTap: onTap);
  }
}

/// 내 퍼즐 보관함의 한 칸: 그림 + 진행 상황 + (처음부터 다시 / 지우기) 메뉴.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.sampleImage,
    required this.onTap,
    required this.onRestart,
    required this.onDelete,
  });

  final JigsawEntry entry;
  final ui.Image? sampleImage;
  final VoidCallback onTap;
  final VoidCallback? onRestart;
  final VoidCallback onDelete;

  String get _title {
    if (entry.source.kind == 'sample') {
      final i = SampleArt.all.indexWhere((s) => s.id == entry.source.ref);
      return i < 0 ? '샘플 그림' : SampleArt.all[i].name;
    }
    final d = DateTime.fromMillisecondsSinceEpoch(entry.updatedAt);
    return '내 사진 · ${d.month}월 ${d.day}일';
  }

  String get _subtitle {
    if (entry.inProgress) {
      final (placed, total) = entry.progress;
      return '진행 중 · $placed/$total';
    }
    return entry.wins > 0 ? '완성 ${entry.wins}번 · 다시 도전' : '아직 안 풀었어요';
  }

  Widget _picture(ColorScheme scheme) {
    final blank = ColoredBox(color: scheme.surfaceContainerHighest);
    if (entry.source.kind == 'sample') {
      return sampleImage == null ? blank : RawImage(image: sampleImage, fit: BoxFit.cover);
    }
    return Image.file(
      File(entry.source.ref),
      fit: BoxFit.cover,
      cacheWidth: 420,
      errorBuilder: (_, _, _) => Center(child: Icon(Icons.broken_image_rounded, color: scheme.outline)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (placed, total) = entry.progress;
    return SizedBox(
      width: _tileWidth(context),
      child: Material(
        color: scheme.surface,
        elevation: 1.5,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: SizedBox(height: 130, width: double.infinity, child: _picture(scheme)),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: PopupMenuButton<String>(
                      tooltip: '메뉴',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                      onSelected: (v) => v == 'restart' ? onRestart?.call() : onDelete(),
                      itemBuilder: (_) => [
                        if (onRestart != null) const PopupMenuItem(value: 'restart', child: Text('처음부터 다시')),
                        const PopupMenuItem(value: 'delete', child: Text('지우기')),
                      ],
                    ),
                  ),
                  if (entry.inProgress && total > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: placed / total,
                        minHeight: 5,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_subtitle, style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사진 칸 하나의 폭: 폰처럼 좁으면 두 장씩, 넓으면 180 안팎으로 여러 장씩 놓아 오른쪽이 비지 않게 한다 (칸 사이 14).
double _tileWidth(BuildContext context) {
  final avail = (MediaQuery.sizeOf(context).width.clamp(0.0, menuMaxWidth(context))) - 40;
  final cols = avail >= 2 * 180 + 14 ? ((avail + 14) / (180 + 14)).floor() : 2;
  return ((avail - 14 * (cols - 1)) / cols).floorToDouble();
}
