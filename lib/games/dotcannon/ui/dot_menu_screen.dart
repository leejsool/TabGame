import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/game_save.dart';
import '../../../core/game_widgets.dart';
import '../../../records/records_screen.dart';
import '../../../tutorial/tutorial_button.dart';
import '../core/dot_levels.dart';
import '../data/dot_custom_store.dart';
import '../data/dot_storage.dart';
import '../dotcannon_entry.dart';
import '../game/dot_controller.dart';
import '../tutorial/dot_tutorial.dart';
import 'dot_create_screen.dart';
import 'dot_painter.dart';
import 'dot_stage_carousel.dart';

const Color dotAccent = Color(0xFF2F8FDB);

/// 난이도 이름표 색.
const List<Color> dotDifficultyColors = [Color(0xFF3FA796), Color(0xFF3F7CAC), Color(0xFFE09F3E), Color(0xFFD1495B)];

/// 도트 캐논 첫 화면: 이어하기 + 내 사진으로 만들기 + 그림 고르기 (내가 만든 그림, 그리고 묶음마다 옆으로 미는 줄).
class DotMenuScreen extends StatefulWidget {
  const DotMenuScreen({super.key});

  @override
  State<DotMenuScreen> createState() => _DotMenuScreenState();
}

class _DotMenuScreenState extends State<DotMenuScreen> {
  Map<String, dynamic>? _saved;
  List<DotLevel> _custom = [];
  Map<String, DotStageStats> _stats = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    GameSave.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    GameSave.changes.removeListener(_load);
    super.dispose();
  }

  /// 읽기를 시작한 차례. 잇달아 읽을 때(연속 클리어) 먼저 시작한 낡은 읽기가 늦게 끝나 새 기록을 덮어쓰지 않게 한다.
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final saved = await GameSave.load(dotGameId);
    final custom = await DotCustomStore.loadAll();
    final stats = await DotStorage.statsFor([...dotLevels, ...custom]);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _saved = saved;
      _custom = custom;
      _stats = stats;
      _loaded = true;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _start(DotLevel level) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startDotCannon(context, level, askIfSaved: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _load();
  }

  Future<void> _resume() async {
    if (_busy || _saved == null) return;
    setState(() => _busy = true);
    final ok = await resumeDotCannon(context, _saved!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _toast('저장된 판을 불러오지 못했어요.');
    _load();
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DotCreateScreen(bytes: bytes)));
    } catch (_) {
      if (mounted) _toast('사진을 불러오지 못했어요. 다른 사진으로 다시 해볼까요?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _load();
  }

  Future<void> _delete(DotLevel level) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 그림을 지울까요?'),
        content: Text('"${level.name}" 그림이 목록에서 사라져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true) return;
    await DotCustomStore.remove(level.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final hint = TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55));
    return Scaffold(
      appBar: AppBar(
        title: const Text('도트 캐논', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => dotTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'dot_cannon');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_saved != null) ...[
                        _ResumeCard(saved: _saved!, onTap: _resume),
                        const SizedBox(height: 18),
                      ],
                      const TutorialButton(tutorial: dotTutorial),
                      const SizedBox(height: 14),
                      _CreateCard(onTap: _pickFromGallery, busy: _busy),
                      const SizedBox(height: 10),
                      Text(
                        '아무 그림이나 골라 바로 할 수 있어요. 줄을 옆으로 밀면 그림이 더 있어요.',
                        key: const ValueKey('dot-stage-title'),
                        style: hint,
                      ),
                      // 내가 만든 그림이 맨 위, 그 아래로 묶음마다 한 줄씩
                      if (_custom.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text('내가 만든 그림', style: heading),
                        const SizedBox(height: 2),
                        Text('그림을 길게 누르면 지울 수 있어요.', style: hint),
                        const SizedBox(height: 10),
                        DotStageCarousel(
                          key: const ValueKey('dot-row-custom'),
                          listKey: const ValueKey('dot-custom-list'),
                          levels: _custom,
                          stats: _stats,
                          numbered: false,
                          onPlay: _start,
                          onLongPress: _delete,
                        ),
                      ],
                      for (final t in DotTheme.values)
                        if (dotLevelsByTheme[t]!.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text.rich(
                            key: ValueKey('dot-theme-${t.name}'),
                            TextSpan(children: [
                              TextSpan(text: t.label),
                              TextSpan(text: '  ${dotLevelsByTheme[t]!.length}장', style: hint),
                            ]),
                            style: heading,
                          ),
                          const SizedBox(height: 10),
                          DotStageCarousel(
                            key: ValueKey('dot-row-${t.name}'),
                            listKey: t == DotTheme.anime ? const ValueKey('dot-stage-list') : ValueKey('dot-stage-list-${t.name}'),
                            levels: dotLevelsByTheme[t]!,
                            stats: _stats,
                            onPlay: _start,
                          ),
                        ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// 그림 한 장 카드: 도트 그림, 이름, 기록.
class DotLevelCard extends StatelessWidget {
  const DotLevelCard({
    super.key,
    required this.level,
    required this.stats,
    required this.onTap,
    this.onLongPress,
    this.number,
    this.highlight = false,
  });

  final DotLevel level;
  final DotStageStats? stats;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 기본 그림의 줄 안 차례 번호 (내가 만든 그림은 없다).
  final int? number;

  /// 지금 도전할 그림이라서 눈에 띄게 한다.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleared = stats?.cleared ?? false;
    return Material(
        color: highlight ? dotAccent.withValues(alpha: 0.14) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: highlight ? const BorderSide(color: dotAccent, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: const Color(0xFFF7F1E3), borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: CustomPaint(
                              painter: DotArtPainter(level.pixels, level.width, level.height, level.colors, fog: !cleared && !level.custom),
                            ),
                          ),
                        ),
                      ),
                      if (!level.custom && level.difficulty >= 2) Positioned(left: 4, top: 4, child: DotHardBadge(difficulty: level.difficulty)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        number == null ? level.name : '$number. ${level.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (cleared) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF3FA34D)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${level.width}×${level.height} · 색 ${level.colorCount}가지',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                if (level.custom)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      dotDifficultyNames[level.difficulty.clamp(0, 3)],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: dotDifficultyColors[level.difficulty.clamp(0, 3)],
                      ),
                    ),
                  ),
                Text(
                  // (기록을 저장하는 중간에 읽어 최단 시간이 아직 없을 수 있다: 그때는 시간 없이 보여 준다)
                  !cleared ? '아직 못 깼어요' : (stats?.bestSeconds == null ? '깼어요' : '최단 ${formatTime(stats!.bestSeconds!)}'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// 유난히 어려운 기본 그림 카드 왼쪽 위의 이름표 (HARD / VERY HARD).
class DotHardBadge extends StatelessWidget {
  const DotHardBadge({super.key, required this.difficulty});

  final int difficulty;

  @override
  Widget build(BuildContext context) {
    final d = difficulty.clamp(2, 3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: dotDifficultyColors[d],
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Text(
        d == 3 ? 'VERY HARD' : 'HARD',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dotAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: const ValueKey('dot-create'),
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: dotAccent.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_photo_alternate_rounded, size: 40, color: dotAccent),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 사진으로 만들기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dotAccent)),
                    SizedBox(height: 2),
                    Text('갤러리에서 사진을 고르면 도트 그림으로 바꾸고 난이도를 매겨 줘요', style: TextStyle(fontSize: 13.5)),
                  ],
                ),
              ),
              busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.chevron_right_rounded, color: dotAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.saved, required this.onTap});

  final Map<String, dynamic> saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String line;
    try {
      final c = DotController.fromJson(saved);
      line = '${c.level.name} · 남은 도트 ${c.game.remaining}개 · ${formatTime(c.elapsed.value)}';
      c.dispose();
    } catch (_) {
      line = '저장된 판';
    }
    return ResumeCard(key: const ValueKey('dot-resume'), detail: line, onTap: onTap);
  }
}
