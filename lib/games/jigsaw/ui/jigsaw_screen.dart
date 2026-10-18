import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../data/jigsaw_history.dart';
import '../data/jigsaw_storage.dart';
import '../jigsaw_entry.dart';
import 'jigsaw_table.dart';

/// 직소퍼즐 플레이 화면.
class JigsawScreen extends StatefulWidget {
  const JigsawScreen({super.key, required this.session});

  final JigsawSession session;

  @override
  State<JigsawScreen> createState() => _JigsawScreenState();
}

class _JigsawScreenState extends State<JigsawScreen> with WidgetsBindingObserver {
  JigsawSession get s => widget.session;
  Timer? _ticker;
  Timer? _saveDebounce;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    JigsawStorage.setActive(s.controller);
    s.controller.addListener(_onChanged);
    s.controller.onCompleted = _onCompleted;
    s.controller.onSnap = _onSnap;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => s.controller.tick());
    _save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    s.controller.removeListener(_onChanged);
    s.controller.onCompleted = null;
    s.controller.onSnap = null;
    _save();
    // 저장은 비동기로 컨트롤러 상태를 읽으므로, 그 값을 먼저 JSON 으로 굳힌 뒤 정리한다.
    Future<void>.microtask(s.dispose);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      s.controller.setPaused(true);
      _save();
    }
  }

  void _onChanged() {
    // 끌고 있는 동안에는 저장하지 않고, 손을 뗀 뒤에 저장한다.
    if (s.controller.dragging != null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _save);
  }

  /// "저장 안 하고 나가기"를 골랐다: 이 판은 더 보관하지 않는다.
  bool _discarded = false;

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await JigsawStorage.save(s.controller, s.source, s.pieceTarget);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await JigsawStorage.abandon(s.controller, s.source);
    await JigsawStorage.pruneAfterHistoryChange();
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !s.controller.completed && !s.controller.gaveUp;

  void _onSnap() {
    if (SettingsScope.of(context).haptics) HapticFeedback.mediumImpact();
  }

  Future<void> _onCompleted() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = s.controller.elapsed.value;
    await JigsawStorage.clear(s.controller, s.source);
    final isBest = await JigsawStorage.recordWin(s.pieceTarget, seconds);
    await JigsawHistory.add(JigsawRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      target: s.pieceTarget,
      pieces: s.controller.geometry.count,
      seconds: seconds,
      source: s.source,
    ));
    await JigsawStorage.pruneAfterHistoryChange();
    if (!mounted) return;
    if (SettingsScope.of(context).haptics) HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('완성! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RawImage(image: s.image, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${s.controller.geometry.count}조각 · ${formatTime(seconds)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '새 최고 기록이에요!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('다른 퍼즐 하기'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _giveUp() async {
    final c = s.controller;
    if (c.completed || c.gaveUp) return;
    final ok = await confirmGiveUp(context, detail: '${c.placedCount}/${c.geometry.count}조각을 맞췄어요.');
    if (!ok || !mounted || c.completed) return;
    c.gaveUp = true;
    _saveDebounce?.cancel();
    final seconds = c.elapsed.value;
    await JigsawStorage.abandon(c, s.source);
    await JigsawHistory.add(JigsawRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      target: s.pieceTarget,
      pieces: c.geometry.count,
      seconds: seconds,
      source: s.source,
      gaveUp: true,
      placed: c.placedCount,
    ));
    await JigsawStorage.pruneAfterHistoryChange();
    if (!mounted) return;
    await showGaveUpDialog(
      context,
      summary: '${c.geometry.count}조각 · ${formatTime(seconds)} · ${c.placedCount}조각 맞춤',
      offerAgain: false,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _showPreview() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RawImage(image: s.image, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(active: _inProgress, onSave: _save, onDiscard: _discard, child: _scaffold(context));
  }

  Widget _scaffold(BuildContext context) {
    final c = s.controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: JigsawTable(controller: c, pieces: s.pieces, image: s.image),
                  ),
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: c,
                      builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _pauseCover() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => s.controller.setPaused(false),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('일시정지', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text('눌러서 계속하기',
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final c = s.controller;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            // 좁은 화면에서는 제목이 줄어들다 사라진다
            Expanded(
              child: Text(
                '직소퍼즐',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${c.placedCount} / ${c.geometry.count}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: c.elapsed,
              builder: (_, sec, _) => Text(
                formatTime(sec),
                style: TextStyle(
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(
                c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                size: 30,
              ),
              onPressed: c.completed ? null : () => c.setPaused(!c.paused),
            ),
            PopupMenuButton<String>(
              tooltip: '메뉴',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                minimumSize: const Size(34, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'giveup') _giveUp();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'giveup',
                  enabled: !c.completed && !c.gaveUp && c.placedCount > 0,
                  child: const Text('포기하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final c = s.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: Row(
          children: [
            GameBarButton(icon: Icons.image_outlined, label: '완성 그림', onTap: _showPreview),
            GameBarButton(
              icon: c.ghost ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              label: '밑그림',
              highlight: c.ghost,
              onTap: c.toggleGhost,
            ),
            GameBarButton(
              icon: Icons.lightbulb_rounded,
              label: '힌트',
              onTap: () => c.giveHint(_rng),
            ),
            GameBarButton(
              icon: Icons.shuffle_rounded,
              label: '흩어 놓기',
              onTap: () => c.scatter(_rng),
            ),
          ],
        ),
      ),
    );
  }
}
