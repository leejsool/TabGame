import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings.dart';
import '../../../core/settings_scope.dart';
import '../tutorial/freecell_tutorial.dart';
import '../core/freecell_difficulty.dart';
import '../data/freecell_storage.dart';
import '../freecell_entry.dart';
import '../game/freecell_controller.dart';
import 'freecell_menu_screen.dart' show levelColors;
import 'freecell_table.dart';

/// 프리셀 플레이 화면.
class FreecellScreen extends StatefulWidget {
  const FreecellScreen({super.key, this.deal = 1, this.saved, this.controller});

  /// 새로 시작할 판 번호.
  final int deal;

  /// 이어하기: 저장된 판 (있으면 [deal]은 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final FreecellController? controller;

  @override
  State<FreecellScreen> createState() => _FreecellScreenState();
}

class _FreecellScreenState extends State<FreecellScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final FreecellController c = widget.controller ?? _create();
  Timer? _ticker;
  Timer? _saveDebounce;
  bool _noMovesShown = false;
  final Completer<void> _skipCelebration = Completer<void>();
  FcDifficultyTable? _table;

  /// 이 판의 난이도 (표를 읽은 뒤에만 안다).
  FcLevel? get _level => _table?.levelOf(c.deal);

  FreecellController _create() {
    final autoMove =
        context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier?.freecellAutoMove ?? true;
    if (widget.saved != null) {
      return FreecellController.fromJson(widget.saved!, autoMove: autoMove);
    }
    return FreecellController(deal: widget.deal, autoMoveEnabled: autoMove);
  }

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'drop': const Fx(haptic: Haptic.select),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FreecellStorage.setActive(c);
    c.addListener(_onChanged);
    c.onCompleted = _onCompleted;
    c.onNoMoves = _onNoMoves;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
    FcDifficultyTable.load().then((t) {
      if (mounted) setState(() => _table = t);
    }).catchError((_) {}); // 난이도 표를 못 읽어도 게임은 계속된다
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onCompleted = null;
    c.onNoMoves = null;
    c.onFeedback = null;
    _save();
    c.dispose();
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
  }

  void _feedback(String kind) => _fx.play(context, kind);

  // ── 끝났을 때 ──

  Future<void> _onCompleted() async {
    WinSound.play(context); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final moves = c.moveCount;
    await FreecellStorage.clearSave(c);
    final isBest = await FreecellStorage.recordWin(FreecellRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
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
            Text('#${c.deal}${_level == null ? '' : ' · ${_level!.label}'}', style: const TextStyle(fontSize: 15)),
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
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
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
        content: const Text('놓을 수 있는 곳이 없어요. 되돌려서 다른 길을 시도해 볼까요?'),
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
        _startNewGame(askIfSaved: true);
      case 'giveup':
        _giveUp();
    }
  }

  /// 메뉴에서 마지막으로 고른 난이도로 새 판을 시작한다 (이 화면을 새 판으로 바꾼다).
  /// [askIfSaved]면 하던 판이 보관돼 있을 때 사라져도 되는지 먼저 묻는다 (이긴 뒤·포기한 뒤에는 보관된 판이 없다).
  Future<void> _startNewGame({bool askIfSaved = false}) async {
    final level = await FreecellStorage.loadLevel();
    final deal = await pickDeal(level);
    if (!mounted) return;
    await startFreecellDeal(context, deal, replace: true, askIfSaved: askIfSaved);
  }

  Future<void> _giveUp() async {
    if (c.completed || c.gaveUp || c.untouched) return;
    final ok = await confirmGiveUp(context, detail: '#${c.deal} 판 · ${c.moveCount}수를 두었어요.');
    if (!ok || !mounted || !c.giveUp()) return;
    final seconds = c.elapsed.value;
    await FreecellStorage.clearSave(c);
    await FreecellStorage.recordGiveUp(FreecellRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      deal: c.deal,
      seconds: seconds,
      moves: c.moveCount,
      gaveUp: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: '#${c.deal}${_level == null ? '' : ' · ${_level!.label}'} · ${formatTime(seconds)} · ${c.moveCount}수',
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

  /// "저장 안 하고 나가기"를 골랐다: 이 판은 더 보관하지 않는다.
  bool _discarded = false;

  /// 이어하기용으로 지금 판을 보관한다 (저장 안 하고 나가는 중이면 하지 않는다).
  Future<void> _save() async {
    if (!_discarded) await FreecellStorage.save(c);
  }

  Future<void> _discard() async {
    _discarded = true;
    _saveDebounce?.cancel();
    await FreecellStorage.clearSave(c);
  }

  /// 나갈 때 저장할지 물어야 하는 판인가 (아직 아무것도 안 했거나 이미 끝난 판이면 그냥 나간다).
  bool _inProgress() => !c.completed && !c.gaveUp && !c.untouched;

  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(active: _inProgress, onSave: _save, onDiscard: _discard, child: _scaffold(context));
  }

  Widget _scaffold(BuildContext context) {
    // 폰을 가로로 돌렸을 때는 세로가 모자라니, 도구를 위·아래가 아닌 좌·우로 뺀다
    final size = MediaQuery.sizeOf(context);
    final sideBars = size.shortestSide < 600 && size.width > size.height;
    final table = Padding(
      padding: sideBars ? const EdgeInsets.fromLTRB(2, 4, 2, 4) : const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Stack(
        children: [
          Positioned.fill(
            child: FreecellTable(
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
    );
    return Scaffold(
      body: SafeArea(
        child: sideBars
            ? Row(
                children: [
                  _leftRail(),
                  Expanded(child: table),
                  _rightRail(),
                ],
              )
            : Column(
                children: [
                  _topBar(),
                  Expanded(child: table),
                  _bottomBar(),
                ],
              ),
      ),
    );
  }

  /// 가로 폰 화면의 왼쪽 줄: 뒤로 가기, 판 번호·난이도, 수·시간, 일시정지, 메뉴.
  Widget _leftRail() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Text(
              '#${c.deal}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (_level != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColors[_level!]!.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _level!.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: levelColors[_level!]!),
                ),
              ),
            Text(
              '${c.moveCount}수',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.primary),
            ),
            ValueListenableBuilder<int>(
              valueListenable: c.elapsed,
              builder: (_, sec, _) => Text(
                formatTime(sec),
                style: TextStyle(
                  fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(
                c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                size: 28,
              ),
              onPressed: c.completed ? null : () => c.setPaused(!c.paused),
            ),
            _menuButton(),
          ],
        ),
      ),
    );
  }

  /// 가로 폰 화면의 오른쪽 줄: 되돌리기·힌트·자동 올리기·처음부터.
  Widget _rightRail() {
    return SizedBox(
      width: 72,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(children: _barButtons(SettingsScope.of(context))),
      ),
    );
  }

  Widget _menuButton() {
    return PopupMenuButton<String>(
      tooltip: '메뉴',
      icon: const Icon(Icons.more_vert_rounded),
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
      onSelected: (v) {
        if (v == 'restart') _confirmRestart();
        if (v == 'new') _startNewGame();
        if (v == 'giveup') _giveUp();
        if (v == 'rules') showFreecellRules(context);
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
                    child: Text.rich(
                      // 판 번호는 조금 작고 옅게 (폰에서도 한 줄에 다 들어가게)
                      TextSpan(text: '프리셀 ', children: [
                        TextSpan(text: '#${c.deal}', style: TextStyle(fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.6))),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_level != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: levelColors[_level!]!.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _level!.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: levelColors[_level!]!,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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
              visualDensity: VisualDensity.compact,
            ),
            _menuButton(),
          ],
        ),
      ),
    );
  }

  Widget _hintBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = c.thinkingHint
            ? '풀이를 찾는 중…'
            : c.hintMessage ?? (c.hint != null ? '노란 카드를 표시된 곳으로 옮겨 보세요' : null);
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
              if (c.thinkingHint)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
                ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              if (!c.thinkingHint)
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
          child: Row(children: _barButtons(settings)),
        );
      },
    );
  }

  /// 되돌리기·힌트·자동 올리기·처음부터 버튼 (아래 줄에서는 가로로, 가로 폰 화면에서는 세로로 놓인다).
  List<Widget> _barButtons(Settings settings) {
    return [
      GameBarButton(
        icon: Icons.undo_rounded,
        label: '되돌리기',
        onTap: c.canUndo ? c.undo : null,
      ),
      GameBarButton(
        icon: Icons.lightbulb_rounded,
        label: '힌트',
        onTap: c.canAct && !c.thinkingHint ? c.requestHint : null,
      ),
      GameBarButton(
        icon: Icons.auto_awesome_rounded,
        label: c.autoMoveEnabled ? '자동 올리기 켬' : '자동 올리기 끔',
        highlight: c.autoMoveEnabled,
        onTap: () {
          c.autoMoveEnabled = !c.autoMoveEnabled;
          settings.freecellAutoMove = c.autoMoveEnabled;
          c.start(); // 켰을 때 바로 올릴 카드가 있으면 올린다
        },
      ),
      GameBarButton(
        icon: Icons.refresh_rounded,
        label: '처음부터',
        onTap: _confirmRestart,
      ),
    ];
  }
}

/// 규칙 설명.
Future<void> showFreecellRules(BuildContext context) {
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
      title: const Text('프리셀 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 카드 52장을 무늬별로 A부터 K까지 위쪽 오른쪽 네 칸(완성 칸)에 모두 쌓아요.'),
            line('아래 8개 열에서는 맨 위 카드를 옮겨요. 다른 색이고 숫자가 하나 큰 카드 위에 올릴 수 있어요. (예: 빨강 7 위에 검정 6)'),
            line('위쪽 왼쪽 네 칸(프리셀)은 카드 한 장씩 잠깐 맡아두는 곳이에요.'),
            line('빈 프리셀과 빈 열이 많을수록 여러 장을 한꺼번에 옮길 수 있어요.'),
            line('빈 열에는 아무 카드나(줄째로) 올릴 수 있어요.'),
            line('카드를 끌어서 놓거나, 카드를 탭하면 알아서 갈 수 있는 곳으로 가요.'),
            line('번호가 같으면 항상 같은 판이에요 (1~32000번). 11982번만 풀 수 없는 판이라 제외돼요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            freecellTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
