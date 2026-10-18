import '../../../tutorial/tutorial_button.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/game_widgets.dart';
import '../../../records/records_screen.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';
import '../tutorial/jigsaw_tutorial.dart';
import 'jigsaw_images.dart';
import 'jigsaw_setup_screen.dart';

part 'jigsaw_menu_screen_tiles.dart';

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
      body: SafeArea(top: false, child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: menuMaxWidth(context)),
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
                    const TutorialButton(tutorial: jigsawTutorial),
                    const SizedBox(height: 18),
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
            )),
    );
  }
}
