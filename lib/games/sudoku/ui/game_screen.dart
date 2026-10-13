import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../core/settings_scope.dart';
import '../data/sudoku_history.dart';
import '../data/sudoku_storage.dart';
import '../game/sudoku_game.dart';
import '../sudoku_entry.dart';
import 'board_widget.dart';
import 'controls.dart';

enum _MistakeChoice { restart, keepGoing, newGame }

/// 스도쿠 플레이 화면.
class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({super.key, required this.game});

  final SudokuGame game;

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen>
    with WidgetsBindingObserver {
  late final SudokuGame game = widget.game;
  Timer? _ticker;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SudokuStorage.setActive(game);
    game.addListener(_onChanged);
    game.onMistakeLimit = _onMistakeLimit;
    game.onCompleted = _onCompleted;
    game.onPlaced = _onPlaced;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => game.tick());
    _save();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    game.autoCompleteEnabled = SettingsScope.of(context).autoComplete;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    game.finishAutoNow(); // 자동 완성 도중에 나가도 완성으로 기록되게
    game.removeListener(_onChanged);
    game.onMistakeLimit = null;
    game.onCompleted = null;
    game.onPlaced = null;
    SudokuStorage.save(game);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      game.setPaused(true);
      SudokuStorage.save(game);
    }
  }

  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  void _save() => SudokuStorage.save(game);

  void _onPlaced(bool correct) {
    final settings = SettingsScope.of(context);
    if (!settings.haptics) return;
    if (correct) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  // ── 실수 3번 ──

  Future<void> _onMistakeLimit() async {
    // 화면 갱신이 끝난 뒤에 대화상자를 띄운다.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final choice = await showDialog<_MistakeChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MistakeDialog(),
    );
    if (!mounted) return;
    switch (choice) {
      case _MistakeChoice.restart:
        game.restart();
      case _MistakeChoice.keepGoing || null:
        game.continueAnyway();
      case _MistakeChoice.newGame:
        startSudokuGame(context, game.puzzle.difficulty, replace: true);
    }
  }

  // ── 완성 ──

  Future<void> _onCompleted() async {
    final seconds = game.elapsed.value;
    final diff = game.puzzle.difficulty;
    await SudokuStorage.clearSave(game);
    final isBest = await SudokuStorage.recordWin(diff, seconds);
    await SudokuHistory.add(SudokuRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      difficulty: diff,
      seconds: seconds,
      mistakes: game.mistakes,
      hints: game.hintsUsed,
      givens: game.puzzle.givensString,
      solution: game.puzzle.solutionString,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompleteDialog(game: game, isBest: isBest),
    );
    if (!mounted) return;
    if (again ?? false) {
      startSudokuGame(context, diff, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시할까요?'),
        content: const Text('지금까지 입력한 내용이 모두 지워지고 시간도 0부터 시작해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('다시 시작')),
        ],
      ),
    );
    if (ok ?? false) game.restart();
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight * 1.1;
            return Column(
              children: [
                _topBar(),
                Expanded(
                  child: landscape ? _landscape() : _portrait(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '스도쿠',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: '메뉴',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'restart') _confirmRestart();
              if (v == 'new') {
                startSudokuGame(context, game.puzzle.difficulty, replace: true);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'restart', child: Text('처음부터 다시하기')),
              PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: Text(
                '실수: ${game.mistakes}/${SudokuGame.maxMistakes}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: game.mistakes > 0
                      ? Theme.of(context).colorScheme.error
                      : scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              game.puzzle.difficulty.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.elapsed,
                    builder: (_, s, _) => Text(
                      formatTime(s),
                      style: TextStyle(
                        fontSize: 16,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: game.paused ? '계속하기' : '일시정지',
                    icon: Icon(
                      game.paused
                          ? Icons.play_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 30,
                    ),
                    onPressed: game.completed ? null : () => game.setPaused(!game.paused),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board() {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(child: SudokuBoard(game: game)),
              // 자동 완성 중임을 알리는 안내. 투명할 때도 자리는 있어서, 터치는 통과시켜야
              // 아래 보드(맨 아래 줄 가운데 칸)가 눌린다.
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: game,
                    builder: (context, _) => AnimatedOpacity(
                      opacity: game.autoCompleting ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✨ 남은 칸을 자동으로 채워요',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: game,
                  builder: (context, _) => game.paused
                      ? Material(
                          color: scheme.surface,
                          child: InkWell(
                            onTap: () => game.setPaused(false),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded,
                                      size: 72, color: scheme.primary),
                                  const SizedBox(height: 8),
                                  const Text('일시정지', style: TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text('눌러서 계속하기',
                                      style: TextStyle(
                                          color: scheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 숫자/액션 영역. 힌트가 열려 있으면 힌트 카드가 그 자리를 차지한다.
  Widget _controls({required int padColumns}) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final hint = game.hint;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuickInputToggle(game: game),
            const SizedBox(height: 4),
            if (hint != null)
              HintPanel(game: game, hint: hint)
            else ...[
              ActionBar(game: game),
              const SizedBox(height: 14),
              NumberPad(game: game, columns: padColumns),
            ],
          ],
        );
      },
    );
  }

  Widget _portrait() {
    return LayoutBuilder(
      builder: (context, box) {
        final boardMax = min(box.maxWidth - 24, box.maxHeight * 0.56);
        return Column(
          children: [
            _statusRow(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(width: boardMax, child: _board()),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  max(12.0, (box.maxWidth - boardMax) / 2),
                  4,
                  max(12.0, (box.maxWidth - boardMax) / 2),
                  16,
                ),
                child: _controls(padColumns: 9),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _landscape() {
    return LayoutBuilder(
      builder: (context, box) {
        final boardSize = min(box.maxHeight - 24, box.maxWidth * 0.58);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: SizedBox(width: boardSize, height: boardSize, child: _board()),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
                child: Column(
                  children: [
                    _statusRow(),
                    const SizedBox(height: 8),
                    _controls(padColumns: 3),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MistakeDialog extends StatelessWidget {
  const _MistakeDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_rounded, color: scheme.error),
          const SizedBox(width: 8),
          const Text('실수 3번!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('틀린 숫자를 3번 넣었어요. 어떻게 할까요?'),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, _MistakeChoice.restart),
            child: const Text('처음부터 다시하기'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, _MistakeChoice.keepGoing),
            child: const Text('그래도 계속하기'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, _MistakeChoice.newGame),
            child: const Text('다른 판으로 시작'),
          ),
        ],
      ),
    );
  }
}

class _CompleteDialog extends StatelessWidget {
  const _CompleteDialog({required this.game, required this.isBest});

  final SudokuGame game;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('완성! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${game.puzzle.difficulty.label} · ${formatTime(game.elapsed.value)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('실수 ${game.mistakes}번 · 힌트 ${game.hintsUsed}번'),
          if (isBest) ...[
            const SizedBox(height: 8),
            Text('새 최고 기록이에요!',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('메뉴로'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('같은 난이도로 새 판'),
        ),
      ],
    );
  }
}
