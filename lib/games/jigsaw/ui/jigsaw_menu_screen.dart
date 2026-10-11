import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';
import 'jigsaw_images.dart';
import 'jigsaw_setup_screen.dart';

/// 직소퍼즐 첫 화면: 이어하기 + 갤러리에서 사진 고르기 + 샘플 그림.
class JigsawMenuScreen extends StatefulWidget {
  const JigsawMenuScreen({super.key});

  @override
  State<JigsawMenuScreen> createState() => _JigsawMenuScreenState();
}

class _JigsawMenuScreenState extends State<JigsawMenuScreen> {
  JigsawSave? _save;
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
    final save = await JigsawStorage.load();
    if (!mounted) return;
    setState(() {
      _save = save;
      _loaded = true;
    });
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

  Future<void> _openSetup(PickedImage pick) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => JigsawSetupScreen(pick: pick)),
    );
    if (mounted) _load();
  }

  Future<void> _resume() async {
    final save = _save;
    if (save == null || _busy) return;
    setState(() => _busy = true);
    final ok = await resumeJigsawGame(context, save);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _toast('저장된 그림을 불러오지 못했어요.');
    _load();
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
                    if (_save != null) ...[
                      _ResumeCard(save: _save!, onTap: _resume),
                      const SizedBox(height: 22),
                    ],
                    _GalleryCard(onTap: _pickFromGallery, busy: _busy),
                    const SizedBox(height: 26),
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
