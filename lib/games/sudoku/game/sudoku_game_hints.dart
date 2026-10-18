part of 'sudoku_game.dart';

/// hints 조각 (화면 코드를 역할별로 나눈 파일)
extension SgHints on SudokuGame {
  void requestHint() {
    if (completed || paused || autoCompleting) return;
    final wrong = [
      for (var i = 0; i < 81; i++)
        if (isWrong(i)) i,
    ];
    if (wrong.isNotEmpty) {
      hint = ActiveHint.wrong(wrong);
      _notify();
      return;
    }
    // 힌트로 지운 후보뿐 아니라, 내가 메모에서 이미 지운 후보도 "지운 것"으로 친다.
    // (그러지 않으면 이미 지운 후보를 또 지우라고 알려준다)
    final elims = List<int>.of(hintElims);
    var g = CandidateGrid.fromValues(values, eliminated: elims);
    var step = StepFinder.next(g, maxLevel: 7);
    for (var guard = 0; guard < 200 && step != null && !step.isPlacement; guard++) {
      final left = <int, int>{};
      step.eliminations.forEach((cell, mask) {
        // 메모가 비어 있는 칸은 아직 후보를 안 적은 칸이니, 지울 후보가 그대로 남아 있다고 본다.
        final remain = notes[cell] == 0 ? mask : mask & notes[cell];
        if (remain != 0) left[cell] = remain;
      });
      if (left.isNotEmpty) {
        step = SolveStep(
          technique: step.technique,
          cells: step.cells,
          digits: step.digits,
          unit: step.unit,
          units: step.units,
          coverUnits: step.coverUnits,
          eliminations: left,
          note: step.note,
        );
        break;
      }
      // 이 단계는 내가 이미 해 둔 것: 반영하고 다음 단계를 찾는다.
      step.eliminations.forEach((cell, mask) => elims[cell] |= mask);
      g = CandidateGrid.fromValues(values, eliminated: elims);
      step = StepFinder.next(g, maxLevel: 7);
    }
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
    _notify();
  }

  /// 튜토리얼에서 판 위에 칠할 표시를 바꾼다. (설명 카드가 없는 [ActiveHint.visualOnly]용)
  void setVisual(ActiveHint? visual) {
    hint = visual;
    _notify();
  }

  void dismissHint() {
    if (hint == null) return;
    hint = null;
    _notify();
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
}
