import 'package:flutter/material.dart';

import '../../../tutorial/tutorial_progress.dart';
import '../core/generator.dart';
import '../core/grid.dart';
import '../core/solver.dart';
import '../core/techniques.dart';
import '../game/hint.dart';
import '../game/sudoku_game.dart';
import 'basic_lesson.dart' show explainWrong;
import 'lesson_shell.dart';
import 'technique_examples.dart';
import 'technique_info.dart';

enum _Phase { intro, practice, done }

/// 심화 기술 하나를 연습하는 화면: 개념 보기 → 직접 해 보기 → 마무리.
class SudokuTechniqueLessonScreen extends StatefulWidget {
  const SudokuTechniqueLessonScreen({super.key, required this.index});

  /// [kTechniqueInfos]에서 몇 번째 기술인가.
  final int index;

  @override
  State<SudokuTechniqueLessonScreen> createState() => _SudokuTechniqueLessonScreenState();
}

class _SudokuTechniqueLessonScreenState extends State<SudokuTechniqueLessonScreen> {
  /// 싱글 연습에서 채워야 하는 칸 수.
  static const int _fillGoal = 3;

  late final TechniqueInfo info = kTechniqueInfos[widget.index];
  late SudokuGame game;
  late CandidateGrid grid0;
  SolveStep? step;

  int _example = 0;
  _Phase _phase = _Phase.intro;
  int _hintLevel = 0;
  String? _message;
  LessonTone _tone = LessonTone.neutral;
  bool _selfChange = false;

  List<TechniqueExample> get _examples => kTechniqueExamples[info.technique]!;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  void dispose() {
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  // ── 예제 준비 ──

  /// [n]번째 예제를 불러온다. [direct]이면 개념 설명·정답 표시 없이 바로 직접 해 보기로 시작한다 (답을 모른 채로 풀어 보도록).
  void _load(int n, {bool direct = false}) {
    final old = _loaded ? game : null;
    old?.removeListener(_onGame);
    _example = n % _examples.length;
    final ex = _examples[_example];
    final values = ex.valueList;
    final elims = ex.elimList;
    final solution = BacktrackSolver.solve(values)!;
    grid0 = CandidateGrid.fromValues(values, eliminated: elims);
    step = StepFinder.next(grid0, maxLevel: 9);
    game = SudokuGame(
      puzzle: SudokuPuzzle(givens: values, solution: solution, difficulty: Difficulty.hard),
      hintElims: elims,
      notes: info.fill ? null : List<int>.of(grid0.cand),
      ignoreLimit: true,
    )..autoCompleteEnabled = false;
    game.addListener(_onGame);
    _loaded = true;
    _phase = _Phase.intro;
    _hintLevel = 0;
    _message = null;
    _tone = LessonTone.neutral;
    final s = step;
    if (s != null && !direct) game.hint = ActiveHint.fromStep(s, grid0, visualOnly: true);
    if (direct) {
      game.notesMode = !info.fill && !info.placeOne;
      game.selected = -1;
      _phase = _Phase.practice;
      _message = _progressText();
    }
    // 이전 판은 화면이 새 판으로 바뀐 뒤에 정리한다.
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    if (mounted) setState(() {});
  }

  bool _loaded = false;

  // ── 상태 확인 ──

  /// 싱글 연습: 맞게 넣은 칸 수.
  int get _placed {
    var n = 0;
    for (var i = 0; i < 81; i++) {
      if (game.puzzle.givens[i] == 0 && game.values[i] == game.puzzle.solution[i]) n++;
    }
    return n;
  }

  /// 후보 지우기 연습: 아직 지우지 못한 후보 개수. (정답 한 칸을 넣는 연습은 아직 안 넣었으면 1)
  int get _remaining {
    final s = step;
    if (s == null) return 0;
    if (info.placeOne) return s.isPlacement && game.values[s.placeCell] != s.placeDigit ? 1 : 0;
    var n = 0;
    s.eliminations.forEach((cell, mask) {
      if (game.values[cell] == 0) n += popCount(game.notes[cell] & mask);
    });
    return n;
  }

  bool get _goalReached => info.fill ? _placed >= _fillGoal : _remaining == 0;

  /// 연습 중 카드 아래에 보이는 진행 안내.
  String _progressText() {
    if (info.fill) return '맞게 넣은 칸: $_placed / $_fillGoal';
    if (info.placeOne) return '정답 한 칸을 찾아 넣어 보세요.';
    return '지워야 할 후보가 $_remaining개 남았어요.';
  }

  void _onGame() {
    if (!mounted || _selfChange || _phase != _Phase.practice) return;

    // 틀린 숫자는 이유를 알려주고 지운다.
    for (var i = 0; i < 81; i++) {
      if (!game.isWrong(i)) continue;
      _message = explainWrong(game, i);
      _tone = LessonTone.problem;
      _selfChange = true;
      game.values[i] = 0;
      game.mistakes = 0;
      game.setVisual(game.hint);
      _selfChange = false;
      setState(() {});
      return;
    }

    // 정답인 숫자를 후보에서 지우면 되돌려 놓는다.
    for (var i = 0; i < 81; i++) {
      if (game.values[i] != 0 || game.notes[i] == 0) continue;
      final b = bit(game.puzzle.solution[i]);
      if (game.notes[i] & b != 0) continue;
      _message = '숫자 ${game.puzzle.solution[i]}: 이 칸의 정답이 될 수 있는 후보라서 지우면 안 돼요. '
          '다시 살려 둘게요.';
      _tone = LessonTone.problem;
      _selfChange = true;
      game.notes[i] |= b;
      game.setVisual(game.hint);
      _selfChange = false;
      setState(() {});
      return;
    }

    if (game.hint == null && _hintLevel > 0) {
      _selfChange = true;
      game.hint = _hintVisual(_hintLevel);
      _selfChange = false;
    }

    if (_goalReached) {
      _finish();
      return;
    }
    _message = _progressText();
    _tone = LessonTone.neutral;
    setState(() {});
  }

  void _finish() {
    TutorialProgress.markLessonDone(info.id);
    _selfChange = true;
    game.hint = null;
    game.selected = -1;
    game.notesMode = false;
    game.setVisual(null);
    _selfChange = false;
    setState(() {
      _phase = _Phase.done;
      _message = null;
      _tone = LessonTone.success;
    });
  }

  // ── 단계 전환 ──

  void _startPractice() {
    _selfChange = true;
    game.notesMode = !info.fill && !info.placeOne;
    game.selected = -1;
    game.setVisual(null);
    _selfChange = false;
    setState(() {
      _phase = _Phase.practice;
      _hintLevel = 0;
      _message = _progressText();
      _tone = LessonTone.neutral;
    });
  }

  // ── 힌트 사다리 ──

  /// 지금 풀어야 할 단계. 후보 지우기는 처음에 정해 둔 단계, 싱글은 매번 새로 찾는다.
  (SolveStep, CandidateGrid)? _currentStep() {
    if (!info.fill) {
      final s = step;
      return s == null ? null : (s, grid0);
    }
    final g = CandidateGrid.fromValues(game.values, eliminated: game.hintElims);
    final s = StepFinder.next(g, maxLevel: 1);
    return s == null ? null : (s, g);
  }

  ActiveHint? _hintVisual(int level) {
    final cur = _currentStep();
    if (cur == null) return null;
    final (s, g) = cur;
    final full = ActiveHint.fromStep(s, g, visualOnly: true);
    if (level >= 2) return full;
    // 1단계: 패턴이 놓인 곳만 알려주고, 지울 후보·정답은 아직 가린다.
    final region = full.regionCells.isNotEmpty ? full.regionCells : const <int>{};
    return ActiveHint(
      title: '',
      message: '',
      applyLabel: '',
      visualOnly: true,
      causeCells: full.causeCells,
      regionCells: region,
      targetCells: region.isEmpty && full.causeCells.isEmpty ? full.targetCells : const {},
      cands: {for (final c in full.causeCells) c: full.cands[c] ?? 0},
      patternDigits: full.patternDigits,
    );
  }

  void _moreHint() {
    final cur = _currentStep();
    if (cur == null) return;
    final (s, g) = cur;
    if (_hintLevel >= 2) {
      // 정답대로 해 준다.
      final apply = ActiveHint.fromStep(s, g);
      _selfChange = true;
      game.hint = apply;
      game.applyHint();
      _selfChange = false;
      _hintLevel = 0;
      if (_goalReached) {
        _finish();
      } else {
        setState(() => _message = '정답대로 해 줬어요. 계속해 보세요!');
      }
      return;
    }
    _hintLevel++;
    _selfChange = true;
    game.setVisual(_hintVisual(_hintLevel));
    _selfChange = false;
    setState(() {
      _tone = LessonTone.neutral;
      _message = _hintLevel == 1
          ? (info.fill
              ? '표시된 곳을 살펴보세요. ${info.how}'
              : '노란 칸에 주목해 보세요. 이 칸들이 만드는 패턴이 열쇠예요.')
          : describeStep(s, g);
    });
  }

  // ── 화면 ──

  void _goNext() {
    final next = widget.index + 1;
    if (next >= kTechniqueInfos.length) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => SudokuTechniqueLessonScreen(index: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = step;
    final intro = _phase == _Phase.intro;
    final practice = _phase == _Phase.practice;
    final hasNext = widget.index + 1 < kTechniqueInfos.length;

    late final String title;
    late final String text;
    late final List<Widget> actions;
    switch (_phase) {
      case _Phase.intro:
        title = info.label;
        text = '${info.what}\n\n▶ 이 판에서는\n'
            '${cur == null ? info.summary : describeStep(cur, grid0)}';
        actions = [
          FilledButton.icon(
            onPressed: _startPractice,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('직접 해 보기'),
          ),
        ];
      case _Phase.practice:
        title = '직접 해 보기';
        text = info.fill
            ? '${info.label}로 풀 수 있는 칸을 찾아 숫자를 $_fillGoal개 넣어 보세요. '
                '(메모 버튼을 켜고 "빠른 메모"를 누르면 후보가 보여요)\n\n▶ 찾는 법: ${info.how}'
            : '이 판에 숨어 있는 기술: ${info.label}\n패턴을 찾아 지울 수 있는 후보를 지워 보세요. '
                '메모 모드가 켜져 있으니, 칸을 누른 뒤 지울 숫자를 누르면 그 후보가 지워져요.'
                '\n\n▶ 찾는 법: ${info.how}';
        actions = [
          TextButton(
            onPressed: _moreHint,
            child: Text(switch (_hintLevel) {
              0 => '힌트',
              1 => '더 알려줘요',
              _ => '정답대로 해 줘요',
            }),
          ),
        ];
      case _Phase.done:
        title = '잘했어요! 🎉';
        text = info.fill
            ? '${info.label} 연습을 마쳤어요. 이제 어려운 판에서도 후보가 하나만 남은 칸, '
                '한 줄에서 자리가 하나뿐인 숫자를 놓치지 마세요.'
            : '${info.label} 성공! 패턴을 찾아 후보를 지웠어요.\n\n'
                '${cur == null ? '' : describeStep(cur, grid0)}';
        actions = [
          if (_examples.length > 1)
            OutlinedButton(onPressed: () => _load(_example + 1, direct: true), child: const Text('다른 예제로 한 번 더')),
          FilledButton(
            onPressed: _goNext,
            child: Text(hasNext ? '다음 기술' : '목록으로'),
          ),
        ];
    }

    return LessonShell(
      game: game,
      title: '심화 기술 연습 · ${info.label}',
      closeLabel: '목록',
      onClose: () => Navigator.of(context).pop(),
      showControls: practice,
      spotlight: practice && !info.fill && !info.placeOne && !game.notesMode ? const {'notes'} : const {},
      actions: actions,
      revealSignal: _message,
      panel: LessonCard(
        badge: 'Lv.${info.level}',
        title: title,
        text: text,
        feedback: intro ? null : _message,
        tone: _tone,
      ),
    );
  }
}
