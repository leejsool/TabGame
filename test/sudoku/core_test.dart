import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/core/grid.dart';
import 'package:tabgame/games/sudoku/core/solver.dart';
import 'package:tabgame/games/sudoku/core/techniques.dart';

/// 퍼즐을 단계별로 풀면서, 모든 단계가 정답과 모순되지 않는지(논리가 옳은지) 확인한다.
/// 사용된 기술별 횟수를 돌려준다.
Map<Technique, int> verifySteps(List<int> puzzle, List<int> solution, int maxLevel, {bool allowStuck = false}) {
  final g = CandidateGrid.fromValues(puzzle);
  final used = <Technique, int>{};
  while (!g.isSolved) {
    expect(g.hasContradiction, isFalse);
    final s = StepFinder.next(g, maxLevel: maxLevel);
    if (allowStuck && s == null) return used; // 극한: 배운 기술로는 막히는 판 (그때까지의 풀이가 옳은지만 본다)
    expect(s, isNotNull, reason: '논리로 풀리다 막힘: ${puzzle.join()}');
    used[s!.technique] = (used[s.technique] ?? 0) + 1;
    expect(s.eliminations.isNotEmpty || s.isPlacement, isTrue);
    if (s.isPlacement) {
      expect(solution[s.placeCell], s.placeDigit,
          reason: '${s.technique} 가 틀린 숫자를 입력: ${puzzle.join()}');
    }
    s.eliminations.forEach((cell, mask) {
      expect(mask & bit(solution[cell]), 0,
          reason: '${s.technique} 가 정답 후보를 지움: 칸 $cell, 퍼즐 ${puzzle.join()}');
      expect(mask & g.cand[cell], mask, reason: '없는 후보를 지우려 함');
    });
    g.apply(s);
  }
  expect(g.values, solution);
  return used;
}

void main() {
  test('격자 상수', () {
    expect(unitCells.length, 27);
    expect(peers.every((p) => p.length == 20), isTrue);
    expect(boxOf[80], 8);
    expect(unitCells[18], [0, 1, 2, 9, 10, 11, 18, 19, 20]);
    expect(unitCells[26], [60, 61, 62, 69, 70, 71, 78, 79, 80]);
  });

  test('백트래킹: 알려진 퍼즐의 유일해', () {
    const p =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    const s =
        '534678912672195348198342567859761423426853791713924856961537284287419635345286179';
    final grid = [for (final c in p.split('')) int.parse(c)];
    expect(BacktrackSolver.countSolutions(grid), 1);
    expect(BacktrackSolver.solve(grid)!.join(), s);
    // 해가 여러 개인 경우
    expect(BacktrackSolver.countSolutions(List.filled(81, 0)), 2);
  });

  test('논리 풀이기가 알려진 퍼즐을 푼다 (싱글만)', () {
    const p =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    final grid = [for (final c in p.split('')) int.parse(c)];
    final grade = HumanSolver.grade(grid, maxLevel: 1);
    expect(grade.solved, isTrue);
    expect(grade.maxLevel, 1);
  });

  for (final d in Difficulty.values) {
    test('${d.label} 퍼즐 생성: 유일해 + 논리가 옳음 + 난이도 일치', () {
      final rng = Random(42);
      final sw = Stopwatch();
      const n = 8;
      var matched = 0;
      final techCounts = <Technique, int>{};
      var clueSum = 0;
      for (var i = 0; i < n; i++) {
        sw.start();
        final p = PuzzleGenerator.generate(d, rng: rng);
        sw.stop();
        clueSum += p.clueCount;
        expect(BacktrackSolver.countSolutions(p.givens), 1);
        expect(BacktrackSolver.solve(p.givens), p.solution);
        // 주어진 숫자는 정답과 같아야 한다
        for (var c = 0; c < 81; c++) {
          if (p.givens[c] != 0) expect(p.givens[c], p.solution[c]);
        }
        verifySteps(p.givens, p.solution, 4, allowStuck: d == Difficulty.extreme).forEach((t, c) {
          techCounts[t] = (techCounts[t] ?? 0) + c;
        });
        final grade = HumanSolver.grade(p.givens, maxLevel: 4);
        final ok = switch (d) {
          Difficulty.easy => grade.maxLevel == 1 &&
              (grade.counts[Technique.hiddenSingle] ?? 0) >= 4,
          Difficulty.medium => grade.maxLevel == 2,
          Difficulty.hard => grade.maxLevel >= 3,
          Difficulty.extreme => !grade.solved,
          Difficulty.expert => grade.maxLevel == 4 && grade.counts.entries.where((e) => e.key.level == 4).fold<int>(0, (a, e) => a + e.value) >= 3,
        };
        if (ok) matched++;
      }
      // ignore: avoid_print
      print('${d.label}: ${sw.elapsedMilliseconds ~/ n}ms/판, 평균 힌트 수 ${clueSum / n}, '
          '난이도 일치 $matched/$n, 기술 사용: ${techCounts.map((k, v) => MapEntry(k.label, v))}');
      expect(matched, greaterThanOrEqualTo(n - 1));
    });
  }

  test('모든 기술 검증: 어려운 판 다수에서 논리가 옳다', () {
    final rng = Random(7);
    final all = <Technique, int>{};
    for (var i = 0; i < 25; i++) {
      final p = PuzzleGenerator.generate(Difficulty.hard, rng: rng);
      verifySteps(p.givens, p.solution, 4).forEach((t, c) {
        all[t] = (all[t] ?? 0) + c;
      });
    }
    // ignore: avoid_print
    print('어려움 25판 기술 사용: ${all.map((k, v) => MapEntry(k.label, v))}');
  });
}
