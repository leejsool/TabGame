import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';
import '../tutorial/jigsaw_tutorial.dart';
import 'jigsaw_images.dart';
import 'jigsaw_setup_screen.dart';

/// 직소퍼즐 첫 화면: 이어하기 + 갤러리에서 사진 고르기 + 샘플 그림.
class JigsawMenuScreen extends StatefulWidget {
  const JigsawMenuScreen({super.key});

  @override
  State<JigsawMenuScreen> createState() => _JigsawMenuScreenState();
}

class _JigsawMenuScreenState extends State<JigsawMenuScreen> {
  List<JigsawEntry> _entries = const [];
  bool _loaded = false;
  bool _busy = false;
  late final Future<List<ui.Image>> _thumbs = Future.wait(
    [for (final s in SampleArt.all) SampleArt.render(s.id, scale: 0.35)],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await JigsawStorage.library();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loaded = true;
    });
  }

  /// 이어하던 판이 있는 가장 최근 퍼즐.
  JigsawEntry? get _latestInProgress {
    for (final e in _entries) {
      if (e.inProgress) return e;
    }
    return null;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final image = await decodeImageBytes(bytes);
      if (!mounted) return;
      await _openSetup(PickedImage(image: image, bytes: bytes, source: JigsawSource.none));
    } catch (_) {
      if (mounted) _toast('사진을 불러오지 못했어요. 다른 사진으로 다시 해볼까요?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSample(SampleInfo info) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await SampleArt.render(info.id);
      if (!mounted) return;
      await _openSetup(PickedImage(image: image, source: JigsawSource('sample', info.id)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSetup(PickedImage pick, {int initialTarget = 24}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => JigsawSetupScreen(pick: pick, initialTarget: initialTarget)),
    );
    if (mounted) _load();
  }

  Future<void> _resume(JigsawSave save) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await resumeJigsawGame(context, save);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _toast('저장된 그림을 불러오지 못했어요.');
    _load();
  }

  /// 보관함의 퍼즐을 누르면: 이어하던 판이 있으면 이어서, 없으면 조각 수를 골라 새로 시작한다.
  Future<void> _openEntry(JigsawEntry e) async {
    final save = e.save;
    if (save != null) return _resume(save);
    await _newFromEntry(e);
  }

  Future<void> _newFromEntry(JigsawEntry e) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await JigsawStorage.loadImage(e.source);
      if (!mounted) return;
      if (image == null) {
        _toast('그림 파일을 찾을 수 없어요. 이 퍼즐은 지워 주세요.');
        return;
      }
      await _openSetup(PickedImage(image: image, source: e.source), initialTarget: e.pieceTarget);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEntry(JigsawEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 퍼즐을 지울까요?'),
        content: Text(e.inProgress ? '맞추던 판도 함께 사라져요. 사진은 갤러리에 그대로 있어요.' : '사진은 갤러리에 그대로 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true) return;
    await JigsawStorage.remove(e.source);
    if (mounted) _load();
  }

  ui.Image? _sampleThumb(List<ui.Image>? thumbs, String id) {
    final i = SampleArt.all.indexWhere((s) => s.id == id);
    return thumbs == null || i < 0 ? null : thumbs[i];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('직소퍼즐', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => jigsawTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'jigsaw');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_latestInProgress != null) ...[
                      _ResumeCard(
                        save: _latestInProgress!.save!,
                        onTap: () => _resume(_latestInProgress!.save!),
                      ),
                      const SizedBox(height: 22),
                    ],
                    _GalleryCard(onTap: _pickFromGallery, busy: _busy),
                    const SizedBox(height: 26),
                    if (_entries.isNotEmpty) ...[
                      Text(
                        '내 퍼즐',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '만든 퍼즐은 지우기 전까지 남아요. 누르면 이어서 하거나 다시 시작해요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<ui.Image>>(
                        future: _thumbs,
                        builder: (context, snap) {
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final e in _entries)
                                _EntryTile(
                                  entry: e,
                                  sampleImage: e.source.kind == 'sample'
                                      ? _sampleThumb(snap.data, e.source.ref)
                                      : null,
                                  onTap: () => _openEntry(e),
                                  onRestart: e.inProgress ? () => _newFromEntry(e) : null,
                                  onDelete: () => _deleteEntry(e),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                    ],
                    Text(
                      '샘플 그림으로 해보기',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<ui.Image>>(
                      future: _thumbs,
                      builder: (context, snap) {
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (var i = 0; i < SampleArt.all.length; i++)
                              _SampleTile(
                                info: SampleArt.all[i],
                                image: snap.data?[i],
                                onTap: () => _pickSample(SampleArt.all[i]),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '사진은 기기 안에서만 쓰이고, 어디에도 올라가지 않아요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

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
      width: 180,
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
    final scheme = Theme.of(context).colorScheme;
    final placed = (save.state['placed'] as List).where((v) => v == 1).length;
    final total = (save.state['placed'] as List).length;
    final elapsed = save.state['elapsed'] as int;
    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 44, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이어하기',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('$total조각 · $placed/$total 맞춤 · ${formatTime(elapsed)}'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
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
      width: 180,
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
