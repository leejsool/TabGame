import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../core/give_up.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../tutorial/solitaire_tutorial.dart';
import '../data/solitaire_storage.dart';
import '../game/solitaire_controller.dart';
import '../solitaire_entry.dart';
import 'solitaire_table.dart';

/// 솔리테어 플레이 화면.
class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key, this.deal = 1, this.draw = 1, this.saved, this.controller});

  /// 새로 시작할 판 번호와 뽑기 장수.
  final int deal;
  final int draw;

  /// 이어하기: 저장된 판 (있으면 [deal]/[draw]는 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final SolitaireController? controller;

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final SolitaireController c = widget.controller ?? _create();
  Timer? _ticker;
  Timer? _saveDebounce;
  bool _noMovesShown = false;
  final Completer<void> _skipCelebration = Completer<void>();

  SolitaireController _create() {
    final autoMove =
        context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier?.solitaireAutoMove ?? true;
    if (widget.saved != null) {
      return SolitaireController.fromJson(widget.saved!, autoMove: autoMove);
    }
    return SolitaireController(deal: widget.deal, draw: widget.draw, autoMoveEnabled: autoMove);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SolitaireStorage.setActive(c);
    c.addListener(_onChanged);
    c.onCompleted = _onCompleted;
    c.onNoMoves = _onNoMoves;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onCompleted = null;
    c.onNoMoves = null;
    c.onFeedback = null;
    SolitaireStorage.save(c);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      SolitaireStorage.save(c);
    }
  }

  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () => SolitaireStorage.save(c));
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'drop':
        HapticFeedback.selectionClick();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  // ── 끝났을 때 ──

  Future<void> _onCompleted() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final moves = c.moveCount;
    await SolitaireStorage.clearSave(c);
    final isBest = await SolitaireStorage.recordWin(SolitaireRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
      draw: c.draw,
      seconds: seconds,
      moves: moves,
    ));
    // 연출을 보여주다가, 화면을 누르면 바로 (아니면 14초 뒤에) 결과를 보여준다
    await Future.any([Future<void>.delayed(const Duration(seconds: 14)), _skipCelebration.future]);
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('완성! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#${c.deal} · ${c.draw}장 뽑기', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              '${formatTime(seconds)} · $moves수',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '새 최고 기록이에요!',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 게임')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      _startNewGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onNoMoves() async {
    if (_noMovesShown) return;
    _noMovesShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || c.completed || !c.noMoves) {
      _noMovesShown = false;
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('더 움직일 수 없어요'),
        content: const Text('더미를 끝까지 넘겨 봐도 놓을 수 있는 곳이 없어요. 되돌려서 다른 길을 시도해 볼까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'giveup'), child: const Text('포기')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'restart'), child: const Text('처음부터')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('새 게임')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'undo'), child: const Text('되돌리기')),
        ],
      ),
    );
    _noMovesShown = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        c.undo();
      case 'restart':
        c.restart();
      case 'new':
        _startNewGame();
      case 'giveup':
        _giveUp();
    }
  }

  /// 같은 뽑기 장수로 무작위 새 판을 시작한다 (이 화면을 새 판으로 바꾼다).
  Future<void> _startNewGame() async {
    await startSolitaireDeal(context, randomSolitaireDeal(), c.draw, replace: true);
  }

  Future<void> _giveUp() async {
    if (c.completed || c.gaveUp || c.untouched) return;
    final ok = await confirmGiveUp(context, detail: '#${c.deal} 판 · ${c.moveCount}수를 두었어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await SolitaireStorage.clearSave(c);
    await SolitaireStorage.recordGiveUp(SolitaireRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
      draw: c.draw,
      seconds: seconds,
      moves: c.moveCount,
      gaveUp: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '#${c.deal} · ${c.draw}장 뽑기 · ${formatTime(seconds)} · ${c.moveCount}수',
      againLabel: '새 게임',
    );
    if (!mounted) return;
    if (again) {
      _startNewGame();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시할까요?'),
        content: Text('#${c.deal} 판을 처음 모습으로 되돌리고 시간도 0부터 시작해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('다시 시작')),
        ],
      ),
    );
    if (ok ?? false) c.restart();
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
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SolitaireTable(
                        controller: c,
                        onCelebrationTap: () {
                          if (!_skipCelebration.isCompleted) _skipCelebration.complete();
                        },
                      ),
                    ),
                    // 힌트 안내는 판 위에 띄워서, 나타나도 카드가 밀리지 않게 한다
                    Positioned(left: 0, right: 0, bottom: 12, child: Center(child: _hintBanner())),
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
                '솔리테어 #${c.deal}',
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
                '${c.draw}장',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
            ),
            const Spacer(),
            Text(
              '${c.moveCount}수',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.primary),
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
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'restart') _confirmRestart();
                if (v == 'new') _startNewGame();
                if (v == 'giveup') _giveUp();
                if (v == 'rules') showSolitaireRules(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'restart', child: Text('처음부터 다시하기')),
                const PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(
                  value: 'giveup',
                  enabled: !c.completed && !c.gaveUp && !c.untouched,
                  child: const Text('포기하기'),
                ),
                const PopupMenuItem(value: 'rules', child: Text('규칙 보기')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = c.hintMessage ?? (c.hint != null ? '노란 카드를 표시된 곳으로 옮겨 보세요' : null);
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              GestureDetector(
                onTap: c.dismissHint,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded, size: 18),
                ),
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
        final settings = SettingsScope.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              _BarButton(icon: Icons.undo_rounded, label: '되돌리기', onTap: c.canUndo ? c.undo : null),
              _BarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              _BarButton(
                icon: Icons.auto_awesome_rounded,
                label: c.autoMoveEnabled ? '자동 올리기 켬' : '자동 올리기 끔',
                highlight: c.autoMoveEnabled,
                onTap: () {
                  c.autoMoveEnabled = !c.autoMoveEnabled;
                  settings.solitaireAutoMove = c.autoMoveEnabled;
                  c.start();
                },
              ),
              _BarButton(icon: Icons.refresh_rounded, label: '처음부터', onTap: _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.onTap, this.highlight = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = highlight ? scheme.primary : scheme.onSurface.withValues(alpha: 0.78);
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

/// 규칙 설명.
Future<void> showSolitaireRules(BuildContext context) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('솔리테어 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 카드 52장을 무늬별로 A부터 K까지 위쪽 오른쪽 네 칸(완성 칸)에 모두 쌓아요.'),
            line('아래 7개 열에서는 다른 색이고 숫자가 하나 작은 카드를 이어 붙여요. (예: 검정 7 위에 빨강 6)'),
            line('앞면인 카드는 줄째로 한꺼번에 옮길 수 있어요. 맨 위 뒷면 카드는 위의 카드를 옮기면 저절로 뒤집혀요.'),
            line('빈 열에는 K(또는 K로 시작하는 줄)만 놓을 수 있어요.'),
            line('왼쪽 위 더미를 누르면 카드를 뽑아요. (1장 또는 3장씩) 더미가 비면 한 번 더 눌러서 다시 넘길 수 있어요.'),
            line('뽑은 카드는 맨 위 한 장만 쓸 수 있어요.'),
            line('카드를 끌어서 놓거나, 카드를 탭하면 알아서 갈 수 있는 곳으로 가요.'),
            line('번호가 같으면 항상 같은 판이에요. 모든 판이 풀리는 건 아니에요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            solitaireTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
