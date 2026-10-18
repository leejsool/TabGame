import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../data/getcolor_storage.dart';
import '../game/getcolor_controller.dart';
import '../getcolor_entry.dart';
import '../tutorial/getcolor_tutorial.dart';
import 'getcolor_board.dart';

/// 겟 컬러 플레이 화면.
class GetColorScreen extends StatefulWidget {
  const GetColorScreen({super.key, required this.controller});

  /// 이 화면이 맡아서 정리한다.
  final GetColorController controller;

  @override
  State<GetColorScreen> createState() => _GetColorScreenState();
}

class _GetColorScreenState extends State<GetColorScreen> with WidgetsBindingObserver {
  GetColorController get c => widget.controller;
  Timer? _ticker;
  Timer? _saveDebounce;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'select': const Fx(haptic: Haptic.select),
    'pour': const Fx(haptic: Haptic.light),
    'bottle': const Fx(haptic: Haptic.medium),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GetColorStorage.setActive(c);
    c.addListener(_onChanged);
    c.onFeedback = _feedback;
    c.onWon = _onWon;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onWon = null;
    _save();
    // 저장은 비동기로 컨트롤러 상태를 읽으므로, 저장 쪽에서 먼저 JSON 으로 굳힌 뒤 정리한다.
    Future<void>.microtask(c.dispose);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      _save();
    }
  }

  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _save);
    // 더 부을 곳이 없고 병도 더할 수 없으면 막다른 길이다
    if (c.noMoves && !c.canAddBottle && !_stuckShown) _onStuck();
  }

  bool _stuckShown = false;

  /// 막다른 길: 어떻게 할지 묻는다 (병 더하기가 남아 있으면 안내 문구만 띄우고 묻지 않는다).
  Future<void> _onStuck() async {
    _stuckShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !c.noMoves || c.canAddBottle || c.paused) {
      _stuckShown = false;
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('더 부을 곳이 없어요'),
        content: const Text('이 상태에서는 더 이상 부을 수 없어요. 되돌려서 다른 길을 찾아볼까요?'),
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: c.untouched
            ? [FilledButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('새 판'))]
            : [
                TextButton(onPressed: () => Navigator.pop(ctx, 'giveup'), child: const Text('포기')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'restart'), child: const Text('처음부터')),
                FilledButton(onPressed: () => Navigator.pop(ctx, 'undo'), child: const Text('되돌리기')),
              ],
      ),
    );
    _stuckShown = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        c.undo();
      case 'restart':
        await GetColorStorage.clearSave(c);
        c.restart();
      case 'giveup':
        await _giveUp();
      case 'new':
        await _newPuzzle();
    }
  }

  void _feedback(String kind) => _fx.play(context, kind);

  // ── 끝났을 때 ──

  Future<void> _onWon() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final moves = c.moveCount;
    await GetColorStorage.clearSave(c);
    final best = await GetColorStorage.recordWin(GetColorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      moves: moves,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('모두 모았어요! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${c.level.label} · ${c.level.description}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('$moves번 부었어요', style: const TextStyle(fontSize: 15)),
            if (best.any)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  best.time && best.moves
                      ? '시간도, 붓기 횟수도 새 최고 기록이에요!'
                      : best.time
                          ? '새 최고 기록이에요!'
                          : '가장 적게 부은 새 기록이에요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      await startGetColor(context, c.level, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 포기 ──

  Future<void> _giveUp() async {
    if (c.completed || c.gaveUp || c.untouched) return;
    final ok = await confirmGiveUp(context, detail: '${c.moveCount}번 부었고, ${c.doneCount}개의 병을 모았어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await GetColorStorage.clearSave(c);
    await GetColorStorage.recordGiveUp(GetColorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
      moves: c.moveCount,
      gaveUp: true,
      initial: [for (final b in c.initial.bottles) List<int>.of(b)],
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '${c.level.label} · ${formatTime(seconds)} · ${c.moveCount}번 부음',
      againLabel: '새 판',
    );
    if (!mounted) return;
    if (again) {
      await startGetColor(context, c.level, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newPuzzle() async {
    if (!c.completed && !c.untouched) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('새 판으로 바꿀까요?'),
          content: const Text('지금 하던 판은 사라지고, 같은 난이도로 새 판이 시작돼요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 판')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await GetColorStorage.clearSave(c);
    if (!mounted) return;
    await startGetColor(context, c.level, replace: true);
  }

  Future<void> _confirmRestart() async {
    if (c.untouched) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시 할까요?'),
        content: const Text('같은 판을 처음 모습으로 되돌려요. 시간도 처음부터 다시 재요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('처음부터')),
        ],
      ),
    );
    if (ok ?? false) {
      await GetColorStorage.clearSave(c);
      c.restart();
    }
  }

  // ── 화면 ──

  /// "저장 안 하고 나가기"를 골랐다: 이 판은 더 보관하지 않는다.
  bool _discarded = false;

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await GetColorStorage.save(c);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await GetColorStorage.clearSave(c);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !c.completed && !c.gaveUp && !c.untouched;

  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(active: _inProgress, onSave: _save, onDiscard: _discard, child: _scaffold(context));
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: Stack(
                  children: [
                    Positioned.fill(child: GetColorBoard(controller: c)),
                    Positioned(left: 0, right: 0, top: 6, child: Center(child: _banner())),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: c,
                        builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => c.setPaused(false),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('일시정지', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text('눌러서 계속하기', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            // 제목과 난이도 칩이 남는 폭을 모두 쓴다 (빈 칸과 나눠 갖지 않아 폰에서도 제목이 잘리지 않는다)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '겟 컬러',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.level.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.local_drink_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text(
              '${c.moveCount}',
              key: const ValueKey('gc-moves'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
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
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'new') _newPuzzle();
                if (v == 'giveup') _giveUp();
                if (v == 'rules') getColorTutorial().open(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(
                  value: 'giveup',
                  enabled: !c.completed && !c.gaveUp && !c.untouched,
                  child: const Text('포기하기'),
                ),
                const PopupMenuItem(value: 'rules', child: Text('게임 방법')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 힌트 안내, 또는 더 부을 곳이 없을 때의 안내.
  Widget _banner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final stuck = c.noMoves;
        final text = c.hintMessage ??
            (stuck
                ? (c.canAddBottle
                    ? '더 부을 곳이 없어요. 되돌리거나 \'병 더하기\'를 눌러 보세요.'
                    : '더 부을 곳이 없어요. 되돌리기로 다른 길을 찾아보세요.')
                : null);
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD84D)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: c.hintThinking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFB88700)),
                      )
                    : const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
              ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              if (c.hintMessage != null)
                GestureDetector(
                  onTap: c.dismissHint,
                  child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 18)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          child: Row(
            children: [
              GameBarButton(icon: Icons.undo_rounded, label: '되돌리기', onTap: c.canUndo ? c.undo : null),
              GameBarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              GameBarButton(
                icon: Icons.add_circle_outline_rounded,
                label: c.extraUsed ? '병 더하기 (사용함)' : '병 더하기',
                onTap: c.canAct && c.canAddBottle ? c.addBottle : null,
              ),
              GameBarButton(icon: Icons.refresh_rounded, label: '처음부터', onTap: c.untouched ? null : _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}
