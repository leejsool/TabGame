import 'dart:async';

import 'package:flutter/material.dart';

import '../game/sudoku_game.dart';
import '../../../tutorial/tutorial_progress.dart';
import 'basic_lesson.dart';
import 'lesson_shell.dart';
import 'practice_menu_screen.dart';

/// 스도쿠 기본 규칙 튜토리얼: 진짜 판 위에서 한 단계씩 직접 해 보며 배운다.
/// 언제든 "건너뛰기"로 나갈 수 있다.
class SudokuBasicLessonScreen extends StatefulWidget {
  const SudokuBasicLessonScreen({super.key, this.firstTime = false});

  /// 스도쿠를 처음 열 때 자동으로 뜬 것인가 (마지막 장 버튼 문구만 달라진다).
  final bool firstTime;

  @override
  State<SudokuBasicLessonScreen> createState() => _SudokuBasicLessonScreenState();
}

class _SudokuBasicLessonScreenState extends State<SudokuBasicLessonScreen> {
  late final SudokuGame game = SudokuGame(puzzle: basicPuzzle(), ignoreLimit: true)
    ..autoCompleteEnabled = false;
  late final LessonContext ctx = LessonContext(game);
  final List<LessonStep> steps = basicSteps();

  int _index = 0;
  bool _done = false;

  /// 잘못 눌렀을 때 알려주는 말 / 도움말.
  String? _problem;
  String? _helpText;

  Timer? _clearTimer;
  bool _selfChange = false;

  LessonStep get _step => steps[_index];

  @override
  void initState() {
    super.initState();
    game.addListener(_onGame);
    _enter(0);
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  void _enter(int i) {
    _clearTimer?.cancel();
    _index = i;
    _problem = null;
    _helpText = null;
    final step = steps[i];
    _selfChange = true;
    step.enter?.call(ctx);
    game.hint = step.visuals?.call(ctx);
    // 위의 enter에서 알림이 갔더라도, 방금 바꾼 표시를 한 번 더 알린다.
    game.setVisual(game.hint);
    _selfChange = false;
    _done = step.goal == null;
    if (!_done && step.goal!(ctx)) _done = true;
    setState(() {});
  }

  void _onGame() {
    if (!mounted || _selfChange) return;
    final step = _step;

    // 틀린 숫자: 이유를 알려주고 잠깐 뒤에 지운다.
    if (!step.allowWrong) {
      final wrong = [
        for (var i = 0; i < 81; i++)
          if (game.isWrong(i)) i,
      ];
      if (wrong.isNotEmpty) {
        _problem = explainWrong(game, wrong.first);
        _clearTimer?.cancel();
        _clearTimer = Timer(const Duration(milliseconds: 1400), () => _clearWrong(wrong));
      } else if (_clearTimer == null || !_clearTimer!.isActive) {
        _problem = step.problem?.call(ctx);
      }
    } else {
      _problem = step.problem?.call(ctx);
    }

    // 숫자를 넣으면 힌트 표시가 사라지니, 목표 전이라면 다시 칠해 둔다.
    if (game.hint == null && step.visuals != null && !_done) {
      game.hint = step.visuals!(ctx);
    }

    if (!_done && step.goal != null && step.goal!(ctx)) {
      _done = true;
      _problem = null;
      _helpText = null;
    }
    setState(() {});
  }

  void _clearWrong(List<int> cells) {
    if (!mounted) return;
    _selfChange = true;
    for (final c in cells) {
      if (game.isWrong(c)) game.values[c] = 0;
    }
    game.mistakes = 0;
    game.setVisual(game.hint);
    _selfChange = false;
    // 지워진 뒤에도 말풍선은 남겨 둔다 (읽을 시간을 주려고). 다음 입력 때 갱신된다.
    setState(() {});
  }

  void _next() {
    if (_index >= steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      _enter(_index + 1);
    }
  }

  void _close() {
    // 마지막 장까지 읽고 닫았다면 마친 것으로 친다. (중간에 건너뛰면 기록하지 않는다)
    if (_step.finale) TutorialProgress.markLessonDone('sudoku_basic');
    Navigator.of(context).pop();
  }

  Future<void> _openPractice() async {
    await TutorialProgress.markLessonDone('sudoku_basic');
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SudokuPracticeMenuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final last = step.finale;
    final feedback = _problem ?? (_done && step.goal != null ? step.success?.call(ctx) : null) ?? _helpText;
    final tone = _problem != null
        ? LessonTone.problem
        : (_done && step.goal != null)
            ? LessonTone.success
            : LessonTone.neutral;

    final actions = <Widget>[];
    if (last) {
      actions.add(
        OutlinedButton(onPressed: _openPractice, child: const Text('심화 기술 연습하기')),
      );
      actions.add(
        FilledButton(
          onPressed: () {
            TutorialProgress.markLessonDone('sudoku_basic');
            Navigator.of(context).pop();
          },
          child: Text(widget.firstTime ? '스도쿠 시작하기' : '닫기'),
        ),
      );
    } else {
      if (!_done && step.help != null) {
        actions.add(
          TextButton(
            onPressed: () => setState(() => _helpText = step.help!(ctx)),
            child: const Text('도와줘요'),
          ),
        );
      }
      actions.add(
        FilledButton(
          // 직접 해 보는 단계는 목표를 이뤄야 넘어갈 수 있다. (막히면 건너뛰기로 나갈 수 있다)
          onPressed: _done ? _next : null,
          child: Text(_done ? '다음' : '직접 해 보세요'),
        ),
      );
    }

    return LessonShell(
      game: game,
      title: '스도쿠 기본 규칙',
      progress: (_index + 1) / steps.length,
      progressLabel: '${_index + 1} / ${steps.length}',
      onClose: _close,
      closeLabel: last ? '닫기' : '건너뛰기',
      showControls: step.showControls,
      spotlight: step.spotlight,
      padSpotlight: step.padSpotlight && !_done,
      actions: actions,
      revealSignal: feedback,
      panel: LessonCard(
        title: step.title,
        text: step.text(ctx),
        feedback: feedback,
        tone: tone,
      ),
    );
  }
}
