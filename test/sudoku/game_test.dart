import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/core/grid.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';

/// [auto]가 false면 자동 완성을 끈 판 (다른 테스트가 자동 완성에 방해받지 않게).
SudokuGame newGame(Difficulty d, [int seed = 1, bool auto = false]) => SudokuGame(
      puzzle: PuzzleGenerator.generate(d, rng: Random(seed)),
      autoStep: const Duration(milliseconds: 1),
    )..autoCompleteEnabled = auto;

/// 빈 칸이 [target]개가 될 때까지 정답을 채운다 (자동 완성이 켜져 있으면 중간에 시작될 수 있음).
void fillUntil(SudokuGame g, int target) {
  for (var i = 0; i < 81; i++) {
    if (g.values.where((v) => v == 0).length <= target) return;
    if (g.values[i] != 0) continue;
    g.select(i);
    g.padDigit(g.puzzle.solution[i]);
  }
}

/// 빈 칸 하나와 그 정답을 찾는다.
(int, int) firstEmpty(SudokuGame g) {
  for (var i = 0; i < 81; i++) {
    if (g.values[i] == 0) return (i, g.puzzle.solution[i]);
  }
  throw StateError('빈 칸 없음');
}

int wrongDigitFor(SudokuGame g, int cell) {
  final s = g.puzzle.solution[cell];
  return s == 9 ? 1 : s + 1;
}

void main() {
  test('정답을 넣으면 숫자가 들어가고, 같은 줄 메모에서 지워진다', () {
    final g = newGame(Difficulty.easy);
    g.autoNotes();
    final (cell, d) = firstEmpty(g);
    g.select(cell);
    g.padDigit(d);
    expect(g.values[cell], d);
    expect(g.mistakes, 0);
    for (final p in peers[cell]) {
      expect(g.notes[p] & bit(d), 0);
    }
  });

  test('틀린 숫자는 실수로 센다. 3번째에 한도 알림', () {
    final g = newGame(Difficulty.easy);
    var limitCalls = 0;
    g.onMistakeLimit = () => limitCalls++;
    final empties = [for (var i = 0; i < 81; i++) if (g.values[i] == 0) i];
    for (var k = 0; k < 3; k++) {
      final c = empties[k];
      g.select(c);
      g.padDigit(wrongDigitFor(g, c));
      expect(g.isWrong(c), isTrue);
    }
    expect(g.mistakes, 3);
    expect(limitCalls, 1);
    expect(g.timerHold, isTrue);
    g.continueAnyway();
    expect(g.timerHold, isFalse);
    // 계속하기 이후에는 알림이 더 없다
    final c = empties[3];
    g.select(c);
    g.padDigit(wrongDigitFor(g, c));
    expect(g.mistakes, 4);
    expect(limitCalls, 1);
  });

  test('처음부터 다시하기는 실수와 입력을 초기화한다', () {
    final g = newGame(Difficulty.easy);
    final (c, _) = firstEmpty(g);
    g.select(c);
    g.padDigit(wrongDigitFor(g, c));
    g.restart();
    expect(g.mistakes, 0);
    expect(g.values, g.puzzle.givens);
  });

  test('주어진 칸은 바꿀 수 없다', () {
    final g = newGame(Difficulty.easy);
    final given = g.values.indexWhere((v) => v != 0);
    g.select(given);
    g.padDigit(wrongDigitFor(g, given));
    expect(g.values[given], g.puzzle.givens[given]);
    expect(g.mistakes, 0);
  });

  test('메모 모드: 메모를 넣고 빼고, 숫자는 안 들어간다', () {
    final g = newGame(Difficulty.easy);
    final (c, _) = firstEmpty(g);
    g.toggleNotes();
    g.select(c);
    g.padDigit(3);
    g.padDigit(5);
    expect(g.notes[c], bit(3) | bit(5));
    g.padDigit(3);
    expect(g.notes[c], bit(5));
    expect(g.values[c], 0);
  });

  test('이미 맞춘 칸은 잠겨서, 틀린 숫자를 덮어써도 바뀌지 않고 실수로 세지 않는다', () {
    final g = newGame(Difficulty.easy);
    final (c, d) = firstEmpty(g);
    g.select(c);
    g.padDigit(d);
    expect(g.isLocked(c), isTrue);
    g.padDigit(wrongDigitFor(g, c)); // 틀린 숫자
    expect(g.values[c], d);
    expect(g.mistakes, 0);
    g.padDigit(d); // 같은 숫자를 다시 눌러도 지워지지 않는다
    expect(g.values[c], d);
    g.erase(); // 지우기도 안 된다
    expect(g.values[c], d);
    // 메모 모드에서도 안 바뀐다
    g.toggleNotes();
    g.padDigit(3);
    expect(g.notes[c], 0);
  });

  test('틀린 숫자가 들어간 칸은 잠기지 않아서, 같은 숫자를 다시 누르거나 지울 수 있다', () {
    final g = newGame(Difficulty.easy);
    final (c, _) = firstEmpty(g);
    final wrong = wrongDigitFor(g, c);
    g.select(c);
    g.padDigit(wrong);
    expect(g.isLocked(c), isFalse);
    g.padDigit(wrong);
    expect(g.values[c], 0);
    g.padDigit(wrong);
    g.erase();
    expect(g.values[c], 0);
  });

  test('이미 맞춘 칸은 취소(undo)로는 되돌릴 수 있다', () {
    final g = newGame(Difficulty.easy);
    final (c, d) = firstEmpty(g);
    g.select(c);
    g.padDigit(d);
    g.undo();
    expect(g.values[c], 0);
    expect(g.isLocked(c), isFalse);
  });

  test('빠른 입력(번개): 숫자를 먼저 고르고 칸을 누르면 입력된다', () {
    final g = newGame(Difficulty.easy);
    g.toggleQuick();
    final (c, d) = firstEmpty(g);
    g.padDigit(d); // 숫자 선택
    expect(g.quickDigit, d);
    expect(g.values[c], 0);
    g.strokeDown(c);
    g.strokeEnd();
    expect(g.values[c], d);
    // 맞춘 칸은 잠겨서 같은 숫자를 다시 탭해도 그대로다
    g.strokeDown(c);
    g.strokeEnd();
    expect(g.values[c], d);
    g.undo(); // 취소로만 되돌릴 수 있다
    expect(g.values[c], 0);
    // 같은 숫자를 다시 누르면 선택 해제
    g.padDigit(d);
    expect(g.quickDigit, 0);
    // 번개를 끄면 선택이 사라진다
    g.padDigit(d);
    g.toggleQuick();
    expect(g.quickDigit, 0);
  });

  test('빠른 입력: 쓸어서 여러 칸에 한 번에 입력하고, 취소는 한 번에 되돌린다', () {
    final g = newGame(Difficulty.easy);
    g.toggleQuick();
    // 같은 숫자가 들어갈 빈 칸들을 찾는다
    final byDigit = <int, List<int>>{};
    for (var i = 0; i < 81; i++) {
      if (g.values[i] == 0) (byDigit[g.puzzle.solution[i]] ??= []).add(i);
    }
    final d = byDigit.entries.firstWhere((e) => e.value.length >= 3).key;
    final cells = byDigit[d]!.take(3).toList();
    g.padDigit(d);
    g.strokeDown(cells[0]);
    g.strokeMove(cells[1]);
    g.strokeMove(cells[1]); // 같은 칸 중복 이동은 무시
    g.strokeMove(cells[2]);
    g.strokeEnd();
    for (final c in cells) {
      expect(g.values[c], d);
    }
    g.undo();
    for (final c in cells) {
      expect(g.values[c], 0);
    }
  });

  test('빠른 입력에서 주어진 칸은 선택만 된다', () {
    final g = newGame(Difficulty.easy);
    g.toggleQuick();
    g.padDigit(5);
    final given = g.values.indexWhere((v) => v != 0);
    g.strokeDown(given);
    g.strokeEnd();
    expect(g.selected, given);
    expect(g.values[given], g.puzzle.givens[given]);
  });

  test('취소(undo)', () {
    final g = newGame(Difficulty.easy);
    final (c, d) = firstEmpty(g);
    g.select(c);
    g.padDigit(d);
    expect(g.canUndo, isTrue);
    g.undo();
    expect(g.values[c], 0);
  });

  test('남은 개수와 완성도', () {
    final g = newGame(Difficulty.easy);
    final (c, d) = firstEmpty(g);
    final before = g.remaining(d);
    g.select(c);
    g.padDigit(d);
    expect(g.remaining(d), before - 1);
    expect(g.progress, greaterThan(0));
  });

  test('저장 후 복원하면 같은 상태', () {
    final g = newGame(Difficulty.medium);
    final (c, d) = firstEmpty(g);
    g.select(c);
    g.padDigit(d);
    g.autoNotes();
    final r = SudokuGame.fromJson(g.toJson());
    expect(r.values, g.values);
    expect(r.notes, g.notes);
    expect(r.puzzle.solution, g.puzzle.solution);
    expect(r.mistakes, g.mistakes);
  });

  test('틀린 숫자가 있으면 힌트는 그 칸을 알려준다', () {
    final g = newGame(Difficulty.easy);
    final (c, _) = firstEmpty(g);
    g.select(c);
    g.padDigit(wrongDigitFor(g, c));
    g.requestHint();
    expect(g.hint!.isWrongCells, isTrue);
    expect(g.hint!.wrongCells, [c]);
    g.applyHint();
    expect(g.values[c], 0);
  });

  group('자동 완성', () {
    test('남은 칸이 15개 이하이고 바로 보이는 칸뿐이면 자동으로 끝낸다', () async {
      final g = newGame(Difficulty.medium, 2, true);
      var done = 0;
      g.onCompleted = () => done++;
      var placed = 0;
      g.onPlaced = (_) => placed++;

      fillUntil(g, 16);
      // 아직 16칸이 남아서 자동 완성이 시작되지 않는다
      expect(g.values.where((v) => v == 0).length, 16);
      expect(g.autoCompleting, isFalse);

      // 하나를 더 맞히면 15칸 → 자동 완성 시작
      final i = g.values.indexOf(0);
      g.select(i);
      g.padDigit(g.puzzle.solution[i]);
      expect(g.autoCompleting, isTrue);
      final placedBefore = placed;
      final timeBefore = g.elapsed.value;

      // 진행 중에는 입력이 막힌다
      final j = g.values.indexOf(0);
      g.select(j);
      g.padDigit(g.puzzle.solution[j] == 9 ? 1 : g.puzzle.solution[j] + 1);
      expect(g.mistakes, 0);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(g.autoCompleting, isFalse);
      expect(g.completed, isTrue);
      expect(g.values, g.puzzle.solution);
      expect(g.mistakes, 0);
      expect(done, 1);
      expect(placed - placedBefore, 15); // 남은 15칸이 하나씩 채워졌다
      g.tick();
      expect(g.elapsed.value, timeBefore); // 시간이 멈춰 있다
    });

    test('틀린 숫자가 있으면 시작하지 않는다', () {
      final g = newGame(Difficulty.medium, 2, true);
      fillUntil(g, 16);
      final i = g.values.indexOf(0);
      g.select(i);
      g.padDigit(wrongDigitFor(g, i)); // 틀린 숫자
      expect(g.autoCompleting, isFalse);
      expect(g.canAutoComplete, isFalse);
    });

    test('설정에서 끄면 시작하지 않는다', () {
      final g = newGame(Difficulty.medium, 2, false);
      fillUntil(g, 15);
      expect(g.values.where((v) => v == 0).length, 15);
      expect(g.autoCompleting, isFalse);
      expect(g.canAutoComplete, isTrue); // 조건은 맞지만 꺼져 있어서 안 한다
    });

    test('칸이 15개보다 많이 남으면 조건이 안 된다', () {
      final g = newGame(Difficulty.hard, 2, true);
      expect(g.canAutoComplete, isFalse);
    });

    test('자동 완성 도중에 나가면 즉시 끝내서 완성으로 기록된다', () {
      final g = newGame(Difficulty.medium, 2, true);
      var done = 0;
      g.onCompleted = () => done++;
      fillUntil(g, 15);
      expect(g.autoCompleting, isTrue);
      g.finishAutoNow();
      expect(g.completed, isTrue);
      expect(g.values, g.puzzle.solution);
      expect(done, 1);
    });

    test('힌트로 숫자를 넣어서 조건이 되어도 자동 완성이 시작된다', () {
      final g = newGame(Difficulty.medium, 2, true);
      fillUntil(g, 16);
      g.requestHint();
      // 힌트 단계가 숫자 입력이 될 때까지 후보 지우기를 적용한다
      var guard = 0;
      while (g.hint != null && !g.hint!.isPlacement && guard++ < 50) {
        g.applyHint();
        g.requestHint();
      }
      if (g.hint != null && g.hint!.isPlacement) g.applyHint();
      expect(g.autoCompleting || g.completed, isTrue);
    });
  });

  for (final d in Difficulty.values) {
    test('${d.label}: 힌트만 따라가도 퍼즐이 끝까지 풀린다 (실수 0)', () {
      for (var seed = 1; seed <= 4; seed++) {
        final g = newGame(d, seed);
        var done = false;
        g.onCompleted = () => done = true;
        var steps = 0;
        while (!g.completed && steps < 500) {
          g.requestHint();
          expect(g.hint, isNotNull, reason: '힌트가 나와야 함');
          g.applyHint();
          steps++;
        }
        expect(done, isTrue, reason: 'seed $seed: 완성되지 않음');
        expect(g.mistakes, 0);
        expect(g.values, g.puzzle.solution);
      }
    });
  }
}
