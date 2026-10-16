import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sudoku/core/grid.dart';
import 'package:tabgame/games/sudoku/core/solver.dart';
import 'package:tabgame/games/sudoku/core/techniques.dart';

/// 정답이 하나뿐이도록 칸을 지울 수 있는 만큼 지운 퍼즐 (논리 난이도는 따지지 않는다: 어려운 기술이 필요한 판이 잘 나온다).
List<int> _minimal(List<int> solution, Random rng) {
  final p = List<int>.of(solution);
  final order = List<int>.generate(81, (i) => i)..shuffle(rng);
  for (final i in order) {
    final a = p[i];
    p[i] = 0;
    if (BacktrackSolver.countSolutions(p) != 1) p[i] = a;
  }
  return p;
}

void main() {
  test('마스터 기술들(Lv.5~7)은 정답을 건드리지 않고, 한 번씩은 쓰인다', () {
    final rng = Random(5);
    final used = <Technique, int>{};
    for (var n = 0; n < 700; n++) {
      final solution = BacktrackSolver.randomSolution(rng);
      final puzzle = _minimal(solution, rng);
      final g = CandidateGrid.fromValues(puzzle);
      for (var guard = 0; guard < 300 && !g.isSolved; guard++) {
        expect(g.hasContradiction, isFalse, reason: '모순: ${puzzle.join()}');
        final s = StepFinder.next(g, maxLevel: 7);
        if (s == null) break;
        used[s.technique] = (used[s.technique] ?? 0) + 1;
        if (s.isPlacement) {
          expect(solution[s.placeCell], s.placeDigit, reason: '${s.technique}가 틀린 숫자를 입력: ${puzzle.join()}');
        }
        s.eliminations.forEach((cell, mask) {
          expect(mask & bit(solution[cell]), 0, reason: '${s.technique}가 정답 후보를 지움: 칸 $cell, 퍼즐 ${puzzle.join()}');
          expect(g.cand[cell] & mask, isNot(0), reason: '없는 후보를 지우려 함');
        });
        expect(s.isPlacement || s.eliminations.isNotEmpty, isTrue);
        g.apply(s);
      }
    }
    for (final t in Technique.values.where((t) => t.level >= 5 && t.level <= 7)) {
      expect(used[t] ?? 0, greaterThan(0), reason: '${t.label}이(가) 한 번도 안 쓰였어요');
    }
  });
}
