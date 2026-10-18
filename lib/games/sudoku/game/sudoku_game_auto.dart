part of 'sudoku_game.dart';

/// auto 조각 (화면 코드를 역할별로 나눈 파일)
extension SgAuto on SudokuGame {
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
    _notify();
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
      _notify();
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
}
