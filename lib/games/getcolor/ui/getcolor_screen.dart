import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../core/settings_scope.dart';
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
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onWon = null;
    GetColorStorage.save(c);
    // 저장은 비동기로 컨트롤러 상태를 읽으므로, 저장 쪽에서 먼저 JSON 으로 굳힌 뒤 정리한다.
    Future<void>.microtask(c.dispose);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      GetColorStorage.save(c);
    }
  }

  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () => GetColorStorage.save(c));
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'select':
        HapticFeedback.selectionClick();
      case 'pour':
        HapticFeedback.lightImpact();
      case 'bottle':
        HapticFeedback.mediumImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  // ── 끝났을 때 ──

  Future<void> _onWon() async {
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

  @override
  Widget build(BuildContext context) {
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
            Flexible(
              child: Text(
                '겟 컬러',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.level.label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
            ),
            const Spacer(),
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
                if (v == 'rules') getColorTutorial().open(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(value: 'rules', child: Text('게임 방법')),
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
              _BarButton(icon: Icons.undo_rounded, label: '되돌리기', onTap: c.canUndo ? c.undo : null),
              _BarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              _BarButton(
                icon: Icons.add_circle_outline_rounded,
                label: c.extraUsed ? '병 더하기 (사용함)' : '병 더하기',
                onTap: c.canAct && c.canAddBottle ? c.addBottle : null,
              ),
              _BarButton(icon: Icons.refresh_rounded, label: '처음부터', onTap: c.untouched ? null : _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 0.78);
    final color = onTap == null ? base.withValues(alpha: 0.3) : base;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
