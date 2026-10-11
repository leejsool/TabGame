import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/generator.dart';
import '../core/grid.dart';
import '../core/techniques.dart';
import 'hint.dart';

class _Snapshot {
  _Snapshot(SudokuGame g)
      : values = List.of(g.values),
        notes = List.of(g.notes),
        elims = List.of(g.hintElims);

  final List<int> values;
  final List<int> notes;
  final List<int> elims;
}

/// 스도쿠 한 판의 상태와 규칙. 화면은 이 객체를 보고 그려진다.
class SudokuGame extends ChangeNotifier {
  SudokuGame({
    required this.puzzle,
    List<int>? values,
    List<int>? notes,
    List<int>? hintElims,
    this.mistakes = 0,
    this.hintsUsed = 0,
    this.ignoreLimit = false,
    int elapsedSeconds = 0,
    this.autoStep = const Duration(milliseconds: 260),
  })  : values = values ?? List.of(puzzle.givens),
        notes = notes ?? List.filled(81, 0),
        hintElims = hintElims ?? List.filled(81, 0),
        elapsed = ValueNotifier<int>(elapsedSeconds);

  factory SudokuGame.fromJson(Map<String, dynamic> j) {
    final d = Difficulty.values.byName(j['d'] as String);
    final puzzle = SudokuPuzzle.fromStrings(
      j['givens'] as String,
      j['solution'] as String,
      d,
    );
    return SudokuGame(
      puzzle: puzzle,
      values: [for (final ch in (j['values'] as String).split('')) int.parse(ch)],
      notes: List<int>.from(j['notes'] as List),
      hintElims: List<int>.from(j['elims'] as List),
      mistakes: j['mistakes'] as int,
      hintsUsed: j['hints'] as int,
      ignoreLimit: j['ignoreLimit'] as bool,
      elapsedSeconds: j['elapsed'] as int,
    );
  }

  static const int maxMistakes = 3;

  /// 남은 빈 칸이 이 개수 이하이고 전부 "바로 보이는 칸"(싱글)이면 자동 완성한다.
  static const int autoCompleteMaxEmpty = 15;

  final SudokuPuzzle puzzle;

  /// 자동 완성 기능 사용 여부 (설정에서 끌 수 있다).
  bool autoCompleteEnabled = true;

  /// 자동 완성이 진행 중인가. 이동 중에는 입력을 받지 않는다.
  bool autoCompleting = false;

  /// 자동 완성에서 한 칸씩 채우는 간격.
  final Duration autoStep;
  Timer? _autoTimer;
  final List<(int, int)> _autoQueue = [];

  /// 현재 칸의 숫자 (0 = 빈 칸). 처음 주어진 숫자도 포함.
  final List<int> values;

  /// 칸별 메모(후보) 마스크.
  final List<int> notes;

  /// 힌트로 "지워도 된다"고 확인한 후보들. 이후 힌트 계산에 반영된다.
  final List<int> hintElims;

  /// 경과 시간(초). 매초 바뀌므로 별도 알림자로 분리.
  final ValueNotifier<int> elapsed;

  int selected = -1;
  bool notesMode = false;

  /// 빠른 입력(번개) 모드: 숫자를 먼저 고르고 칸을 누른다.
  bool quickMode = false;
  int quickDigit = 0;

  int mistakes;
  int hintsUsed;
  bool ignoreLimit;
  bool paused = false;
  bool completed = false;

  /// 대화상자 등으로 시계를 잠시 멈춤.
  bool timerHold = false;

  /// 마지막으로 숫자를 넣은 칸 / 입력 횟수 (애니메이션용).
  int lastPlaced = -1;
  int placeSerial = 0;

  ActiveHint? hint;

  /// 틀린 숫자를 넣어 실수가 3번째가 되었을 때.
  VoidCallback? onMistakeLimit;

  /// 퍼즐을 완성했을 때.
  VoidCallback? onCompleted;

  /// 숫자를 넣었을 때(true=정답, false=오답) 진동 등을 위한 알림.
  void Function(bool correct)? onPlaced;

  final List<_Snapshot> _undo = [];
  bool _strokeOpen = false;
  bool _strokeSnapped = false;
  final Set<int> _visited = {};
  bool _pendingLimit = false;
  bool _pendingComplete = false;

  // ── 조회 ──

  bool isGiven(int i) => puzzle.givens[i] != 0;

  /// 바꿀 수 없는 칸: 처음 주어진 숫자, 그리고 이미 맞게 채운 칸.
  /// (맞힌 칸에 틀린 숫자를 덮어써서 실수로 세지는 일이 없도록)
  bool isLocked(int i) => isGiven(i) || (values[i] != 0 && values[i] == puzzle.solution[i]);

  bool isWrong(int i) =>
      !isGiven(i) && values[i] != 0 && values[i] != puzzle.solution[i];

  /// 보드에서 같은 숫자로 강조할 숫자.
  int get highlightDigit {
    if (quickMode && quickDigit != 0) return quickDigit;
    if (selected >= 0 && values[selected] != 0) return values[selected];
    return 0;
  }

  /// 아직 놓아야 할 개수 (올바르게 놓인 것만 센다).
  int remaining(int digit) {
    var placed = 0;
    for (var i = 0; i < 81; i++) {
      if (values[i] == digit && puzzle.solution[i] == digit) placed++;
    }
    return 9 - placed;
  }

  /// 완성도 0~1.
  double get progress {
    var done = 0, total = 0;
    for (var i = 0; i < 81; i++) {
      if (isGiven(i)) continue;
      total++;
      if (values[i] == puzzle.solution[i]) done++;
    }
    return total == 0 ? 1 : done / total;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get limitReached => mistakes >= maxMistakes;

  // ── 선택/입력 ──

  void select(int cell) {
    selected = cell;
    _changed(keepHint: true);
  }

  /// 보드를 누르기 시작 (손가락/마우스 down).
  void strokeDown(int cell) {
    _strokeOpen = true;
    _strokeSnapped = false;
    _visited
      ..clear()
      ..add(cell);
    _cellAction(cell, isDown: true);
  }

  /// 누른 채 다른 칸으로 이동.
  void strokeMove(int cell) {
    if (!_strokeOpen || !_visited.add(cell)) return;
    _cellAction(cell, isDown: false);
  }

  void strokeEnd() {
    _strokeOpen = false;
    _visited.clear();
  }

  void _cellAction(int cell, {required bool isDown}) {
    if (paused || completed || autoCompleting) return;
    selected = cell;
    if (quickMode && quickDigit != 0 && !isLocked(cell)) {
      final d = quickDigit;
      // 쓸어서 칠할 때는 이미 같은 숫자/메모가 있는 칸을 건드리지 않는다.
      if (!isDown) {
        if (notesMode) {
          if (values[cell] != 0 || notes[cell] & bit(d) != 0) return;
        } else if (values[cell] == d) {
          return;
        }
      }
      _applyDigit(cell, d);
    } else {
      _changed(keepHint: true);
    }
  }

  /// 숫자 패드의 숫자를 눌렀을 때.
  void padDigit(int d) {
    if (paused || completed || autoCompleting) return;
    if (quickMode) {
      quickDigit = quickDigit == d ? 0 : d;
      _changed(keepHint: true);
      return;
    }
    if (selected < 0) return;
    _applyDigit(selected, d);
  }

  void _applyDigit(int cell, int d) {
    if (isLocked(cell) || completed) return;
    if (notesMode) {
      if (values[cell] != 0) return;
      _pushUndo();
      notes[cell] ^= bit(d);
      _changed();
      return;
    }
    if (values[cell] == d) {
      _pushUndo();
      values[cell] = 0;
      _changed();
      return;
    }
    _pushUndo();
    values[cell] = d;
    notes[cell] = 0;
    lastPlaced = cell;
    placeSerial++;
    final correct = d == puzzle.solution[cell];
    if (correct) {
      // 같은 줄/열/박스의 메모에서 이 숫자를 지운다.
      final m = ~bit(d);
      for (final p in peers[cell]) {
        notes[p] &= m;
      }
    } else {
      mistakes++;
      if (mistakes == maxMistakes && !ignoreLimit) {
        timerHold = true;
        _pendingLimit = true;
      }
    }
    onPlaced?.call(correct);
    if (_isSolved()) {
      completed = true;
      paused = false;
      _pendingComplete = true;
    }
    _changed();
    if (correct && !completed) _maybeAutoComplete();
  }

  // ── 자동 완성 ──

  /// 지금 상태에서 자동 완성을 할 수 있는가:
  /// 틀린 숫자가 없고, 빈 칸이 [autoCompleteMaxEmpty]개 이하이며, 나머지가 싱글만으로 끝까지 풀린다.
  bool get canAutoComplete {
    if (completed || autoCompleting) return false;
    var empties = 0;
    for (var i = 0; i < 81; i++) {
      if (values[i] == 0) {
        empties++;
      } else if (isWrong(i)) {
        return false;
      }
    }
    if (empties == 0 || empties > autoCompleteMaxEmpty) return false;
    return HumanSolver.grade(values, maxLevel: 1).solved;
  }

  void _maybeAutoComplete() {
    if (!autoCompleteEnabled || paused || !canAutoComplete) return;
    // 채울 순서를 미리 계산해 둔다 (네이키드/히든 싱글만 사용)
    final g = CandidateGrid.fromValues(values);
    _autoQueue.clear();
    while (!g.isSolved) {
      final step = StepFinder.next(g, maxLevel: 1);
      if (step == null || !step.isPlacement) {
        _autoQueue.clear();
        return;
      }
      _autoQueue.add((step.placeCell, step.placeDigit));
      g.apply(step);
    }
    autoCompleting = true;
    timerHold = true; // 자동으로 채우는 동안에는 시간이 흐르지 않는다
    selected = -1;
    hint = null;
    quickDigit = 0;
    notifyListeners();
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(autoStep, (_) => _autoStepOnce());
  }

  void _autoStepOnce() {
    if (_autoQueue.isEmpty) {
      _finishAuto();
      return;
    }
    final (cell, d) = _autoQueue.removeAt(0);
    values[cell] = d;
    notes[cell] = 0;
    final m = ~bit(d);
    for (final p in peers[cell]) {
      notes[p] &= m;
    }
    selected = cell;
    lastPlaced = cell;
    placeSerial++;
    onPlaced?.call(true);
    if (_autoQueue.isEmpty) {
      _finishAuto();
    } else {
      notifyListeners();
    }
  }

  /// 자동 완성이 진행 중일 때 화면을 떠나는 경우: 남은 칸을 바로 채워서 끝낸다(기록이 남도록).
  void finishAutoNow() {
    if (!autoCompleting) return;
    while (_autoQueue.isNotEmpty) {
      final (cell, d) = _autoQueue.removeAt(0);
      values[cell] = d;
      notes[cell] = 0;
    }
    _finishAuto();
  }

  void _finishAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    autoCompleting = false;
    timerHold = false;
    if (_isSolved()) {
      completed = true;
      _pendingComplete = true;
    }
    selected = -1;
    _changed();
  }

  bool _isSolved() {
    for (var i = 0; i < 81; i++) {
      if (values[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  void erase() {
    final s = selected;
    if (s < 0 || isLocked(s) || completed || paused || autoCompleting) return;
    if (values[s] == 0 && notes[s] == 0) return;
    _pushUndo();
    values[s] = 0;
    notes[s] = 0;
    _changed();
  }

  void toggleNotes() {
    notesMode = !notesMode;
    _changed(keepHint: true);
  }

  void toggleQuick() {
    quickMode = !quickMode;
    if (!quickMode) quickDigit = 0;
    _changed(keepHint: true);
  }

  /// 빠른 메모: 모든 빈 칸에 가능한 후보를 한꺼번에 채운다.
  void autoNotes() {
    if (completed || paused || autoCompleting) return;
    _pushUndo();
    final g = CandidateGrid.fromValues(values, eliminated: hintElims);
    for (var i = 0; i < 81; i++) {
      notes[i] = values[i] == 0 ? g.cand[i] : 0;
    }
    _changed();
  }

  // ── 취소/다시 시작 ──

  void undo() {
    if (_undo.isEmpty || completed || autoCompleting) return;
    final s = _undo.removeLast();
    values.setAll(0, s.values);
    notes.setAll(0, s.notes);
    hintElims.setAll(0, s.elims);
    _changed();
  }

  void _pushUndo() {
    if (_strokeOpen && _strokeSnapped) return;
    _undo.add(_Snapshot(this));
    if (_undo.length > 200) _undo.removeAt(0);
    if (_strokeOpen) _strokeSnapped = true;
  }

  /// 같은 문제를 처음부터 다시.
  void restart() {
    _autoTimer?.cancel();
    _autoTimer = null;
    autoCompleting = false;
    _autoQueue.clear();
    values.setAll(0, puzzle.givens);
    notes.fillRange(0, 81, 0);
    hintElims.fillRange(0, 81, 0);
    mistakes = 0;
    hintsUsed = 0;
    ignoreLimit = false;
    completed = false;
    paused = false;
    timerHold = false;
    selected = -1;
    quickDigit = 0;
    hint = null;
    lastPlaced = -1;
    _undo.clear();
    elapsed.value = 0;
    _changed();
  }

  // ── 시계 ──

  void tick() {
    if (paused || completed || timerHold) return;
    elapsed.value++;
  }

  void setPaused(bool v) {
    if (completed || paused == v) return;
    paused = v;
    notifyListeners();
  }

  /// "그래도 계속하기": 실수 제한 없이 이어서 한다.
  void continueAnyway() {
    ignoreLimit = true;
    timerHold = false;
    notifyListeners();
  }

  // ── 힌트 ──

  void requestHint() {
    if (completed || paused || autoCompleting) return;
    final wrong = [
      for (var i = 0; i < 81; i++)
        if (isWrong(i)) i,
    ];
    if (wrong.isNotEmpty) {
      hint = ActiveHint.wrong(wrong);
      notifyListeners();
      return;
    }
    final g = CandidateGrid.fromValues(values, eliminated: hintElims);
    final step = StepFinder.next(g, maxLevel: 4);
    if (step != null) {
      hint = ActiveHint.fromStep(step, g);
    } else {
      // 논리 기술로 풀리는 단계가 없을 때: 후보가 가장 적은 빈 칸의 정답을 알려준다.
      var best = -1;
      var bestCount = 10;
      for (var i = 0; i < 81; i++) {
        if (values[i] != 0) continue;
        final c = popCount(g.cand[i]);
        if (c < bestCount) {
          bestCount = c;
          best = i;
        }
      }
      if (best < 0) return;
      hint = ActiveHint.reveal(best, puzzle.solution[best]);
    }
    hintsUsed++;
    final h = hint!;
    if (h.placeCell >= 0) selected = h.placeCell;
    notifyListeners();
  }

  void dismissHint() {
    if (hint == null) return;
    hint = null;
    notifyListeners();
  }

  /// 힌트가 안내한 대로 실행한다 (숫자 입력 / 후보 지우기 / 틀린 칸 지우기).
  void applyHint() {
    final h = hint;
    if (h == null || completed) return;
    _pushUndo();
    if (h.isWrongCells) {
      for (final c in h.wrongCells) {
        values[c] = 0;
        notes[c] = 0;
      }
    } else if (h.isPlacement) {
      final cell = h.placeCell, d = h.placeDigit;
      values[cell] = d;
      notes[cell] = 0;
      final m = ~bit(d);
      for (final p in peers[cell]) {
        notes[p] &= m;
      }
      selected = cell;
      lastPlaced = cell;
      placeSerial++;
      onPlaced?.call(true);
      if (_isSolved()) {
        completed = true;
        _pendingComplete = true;
      }
    } else {
      h.removeMask.forEach((cell, mask) {
        hintElims[cell] |= mask;
        notes[cell] &= ~mask;
      });
    }
    _changed();
    if (h.isPlacement && !completed) _maybeAutoComplete();
  }

  // ── 저장 ──

  Map<String, dynamic> toJson() => {
        'd': puzzle.difficulty.name,
        'givens': puzzle.givensString,
        'solution': puzzle.solutionString,
        'values': values.join(),
        'notes': notes,
        'elims': hintElims,
        'mistakes': mistakes,
        'hints': hintsUsed,
        'ignoreLimit': ignoreLimit,
        'elapsed': elapsed.value,
      };

  void _changed({bool keepHint = false}) {
    if (!keepHint) hint = null;
    notifyListeners();
    if (_pendingLimit) {
      _pendingLimit = false;
      onMistakeLimit?.call();
    }
    if (_pendingComplete) {
      _pendingComplete = false;
      onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    elapsed.dispose();
    super.dispose();
  }
}
