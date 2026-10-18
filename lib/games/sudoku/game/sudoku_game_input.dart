part of 'sudoku_game.dart';

/// input 조각 (화면 코드를 역할별로 나눈 파일)
extension SgInput on SudokuGame {
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
      // 빠른 입력에서 숫자를 고르면, 먼저 눌러 둔 칸의 선택과 행·열·박스 강조는 풀린다
      selected = -1;
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
      if (mistakes == SudokuGame.maxMistakes && !ignoreLimit) {
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
    if (empties == 0 || empties > SudokuGame.autoCompleteMaxEmpty) return false;
    return HumanSolver.grade(values, maxLevel: 1).solved;
  }
}
