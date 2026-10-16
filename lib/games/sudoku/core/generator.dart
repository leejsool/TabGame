import 'dart:math';

import 'solver.dart';
import 'techniques.dart';

enum Difficulty {
  easy('쉬움', '기본 기술(싱글)만으로 풀려요', 1),
  medium('보통', '페어·교차 같은 기술이 필요해요', 2),
  hard('어려움', '트리플·X-윙 같은 고급 기술이 필요해요', 4),
  expert('매우 어려움', 'X-윙·XY-윙·스워드피시 같은 전문가 기술이 여러 번 필요해요', 4),
  extreme('극한', '배운 기술로는 막혀요 · 가정해서 풀어야 해요', 4);

  const Difficulty(this.label, this.description, this.maxLevel);

  final String label;
  final String description;

  /// 이 난이도의 퍼즐을 만들 때 허용하는 가장 어려운 기술 레벨.
  final int maxLevel;
}

/// 문제(주어진 숫자)와 정답.
class SudokuPuzzle {
  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.difficulty,
  });

  factory SudokuPuzzle.fromStrings(String givens, String solution, Difficulty d) =>
      SudokuPuzzle(
        givens: [for (final ch in givens.split('')) int.parse(ch)],
        solution: [for (final ch in solution.split('')) int.parse(ch)],
        difficulty: d,
      );

  /// 0은 빈 칸.
  final List<int> givens;
  final List<int> solution;
  final Difficulty difficulty;

  SudokuPuzzle copyWith(Difficulty d) => SudokuPuzzle(givens: givens, solution: solution, difficulty: d);

  String get givensString => givens.join();
  String get solutionString => solution.join();
  int get clueCount => givens.where((v) => v != 0).length;
}

class PuzzleGenerator {
  PuzzleGenerator._();

  /// 난이도에 맞는 새 퍼즐을 만든다. 모든 퍼즐은 논리 기술만으로 풀리고, 해가 하나뿐이다.
  static SudokuPuzzle generate(Difficulty difficulty, {Random? rng, int maxAttempts = 40}) {
    rng ??= Random();
    if (difficulty == Difficulty.extreme) return _generateExtreme(rng);
    if (difficulty == Difficulty.hard || difficulty == Difficulty.expert) return _generateHard(difficulty, rng);
    SudokuPuzzle? best;
    var bestScore = -1;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solution = BacktrackSolver.randomSolution(rng);
      final puzzle = _carve(solution, difficulty, rng);
      final grade = HumanSolver.grade(puzzle, maxLevel: difficulty.maxLevel);
      if (!grade.solved) continue;

      // 쉬움: 히든 싱글도 몇 번은 써야 하는 판 (네이키드 싱글만 반복하면 너무 밋밋하다)
      final hidden = grade.counts[Technique.hiddenSingle] ?? 0;
      final fits = switch (difficulty) {
        Difficulty.easy => grade.maxLevel == 1 && hidden >= 4,
        Difficulty.medium => grade.maxLevel == 2,
        Difficulty.hard || Difficulty.expert || Difficulty.extreme => grade.maxLevel >= 3,
      };
      final candidate = SudokuPuzzle(
        givens: puzzle,
        solution: solution,
        difficulty: difficulty,
      );
      if (fits) return candidate;

      // 딱 맞는 게 안 나오면 가장 가까운 것을 쓴다.
      final score = switch (difficulty) {
        Difficulty.easy => (10 - grade.maxLevel) * 100 + hidden,
        _ => grade.maxLevel,
      };
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best ?? _fallback(difficulty, rng);
  }

  // ── 어려움 · 매우 어려움 ──
  //
  // 그냥 칸을 지우기만 하면 어려운 기술이 필요한 판은 아주 드물다 (대부분 싱글만으로 풀린다). 그래서 "어렵게 만들어 가는" 방식을 쓴다:
  // 해가 하나인 판에서 주어진 숫자 하나를 빼고 다른 칸의 정답을 하나 알려 주는 식으로 바꿔 보며, 풀이에 어려운 기술이 더 많이 쓰이게
  // 되는 쪽으로만 받아들인다. 목표에 닿으면 멈춘다.

  /// 풀이에 쓰인 기술의 어려움 점수 (높을수록 어렵다). 전문가 기술(레벨 4)이 가장 크게 센다.
  static int _score(Grade g) {
    var s = 0;
    g.counts.forEach((t, c) {
      s += c * switch (t.level) { 4 => 12, 3 => 4, 2 => 1, _ => 0 };
    });
    return s;
  }

  static bool _reached(Difficulty d, Grade g) {
    final expert = _expertSteps(g);
    return switch (d) {
      Difficulty.expert => g.maxLevel == 4 && expert >= 3,
      _ => g.maxLevel >= 3 && expert <= 2,
    };
  }

  /// 전문가 기술(레벨 4: X-윙·XY-윙·XYZ-윙·스워드피시)을 쓴 횟수.
  static int _expertSteps(Grade grade) {
    var n = 0;
    grade.counts.forEach((t, c) {
      if (t.level == 4) n += c;
    });
    return n;
  }

  static SudokuPuzzle _generateHard(Difficulty d, Random rng) {
    List<int>? bestPuzzle, bestSolution;
    var bestScore = -1;
    for (var attempt = 0; attempt < 8; attempt++) {
      final solution = BacktrackSolver.randomSolution(rng);
      var puzzle = _carve(solution, Difficulty.hard, rng);
      var grade = HumanSolver.grade(puzzle, maxLevel: 4);
      if (!grade.solved) continue;
      var score = _score(grade);
      var stale = 0;
      for (var it = 0; it < 1500 && !_reached(d, grade); it++) {
        // 어려운 기술이 하나도 안 나오는 시작판은 오래 붙들지 않고 새로 시작한다
        if (score == 0 && ++stale > 400) break;
        final q = List<int>.of(puzzle);
        final filled = [for (var k = 0; k < 81; k++) if (q[k] != 0) k];
        final blanks = [for (var k = 0; k < 81; k++) if (q[k] == 0) k];
        if (blanks.isEmpty || filled.isEmpty) break;
        q[filled[rng.nextInt(filled.length)]] = 0;
        final b = blanks[rng.nextInt(blanks.length)];
        q[b] = solution[b];
        final g2 = HumanSolver.grade(q, maxLevel: 4);
        if (!g2.solved) continue;
        final s2 = _score(g2);
        // 같은 점수로 옮겨 다니는 것도 받아들인다 (막힌 데서 빠져나오려고)
        if (s2 >= score) {
          puzzle = q;
          grade = g2;
          score = s2;
        }
      }
      if (_reached(d, grade)) return SudokuPuzzle(givens: puzzle, solution: solution, difficulty: d);
      if (score > bestScore) {
        bestScore = score;
        bestPuzzle = puzzle;
        bestSolution = solution;
      }
    }
    if (bestPuzzle != null) return SudokuPuzzle(givens: bestPuzzle, solution: bestSolution!, difficulty: d);
    return _fallback(d, rng);
  }

  // ── 극한 ──
  //
  // 배우는 기술을 다 써도 도중에 막히는 판. 해는 하나뿐이지만 (칸을 지울 때마다 해가 하나인지 확인한다), 논리 풀이는 어딘가에서
  // 멈춘다. 그때부터는 어떤 칸에 숫자를 가정해 보고 모순이 나는지 따져야 한다.
  // 그냥 지우기만 하면 거의 처음부터 막혀 버리는 판이 되기 쉬워서 (재미없다), 논리로 풀리는 판에서 한 칸씩 더 지워 보며
  // "막히긴 막히되 꽤 풀린 뒤에 막히는" 판을 고른다.

  /// 극한 판이 "막혀야" 하는 기술 레벨: 체인·ALS까지(Lv.6) 다 써도 막힌다. (가정법(Lv.7)은 막혔을 때 쓰는 최후의 수단이라 뺀다.)
  static const int kExtremeLevel = 6;

  /// 논리로 풀 수 있는 데까지 푼 뒤에 남는 빈 칸 수 (0이면 끝까지 풀린다).
  static int _stallLeft(List<int> puzzle) {
    final g = CandidateGrid.fromValues(puzzle);
    for (var guard = 0; guard < 500 && !g.isSolved && !g.hasContradiction; guard++) {
      final step = StepFinder.next(g, maxLevel: kExtremeLevel);
      if (step == null) break;
      g.apply(step);
    }
    return g.values.where((v) => v == 0).length;
  }

  static SudokuPuzzle _generateExtreme(Random rng) {
    List<int>? bestPuzzle, bestSolution;
    var bestLeft = 1 << 30;
    for (var attempt = 0; attempt < 40; attempt++) {
      final solution = BacktrackSolver.randomSolution(rng);
      var puzzle = _carve(solution, Difficulty.hard, rng);
      if (_stallLeft(puzzle) != 0) continue;
      List<int>? stuck; // 이번 판에서 가장 늦게 막히는 후보
      var stuckLeft = 1 << 30;
      var changed = true;
      while (changed) {
        changed = false;
        final filled = [for (var k = 0; k < 81; k++) if (puzzle[k] != 0) k]..shuffle(rng);
        for (final k in filled) {
          final q = List<int>.of(puzzle)..[k] = 0;
          if (BacktrackSolver.countSolutions(q) != 1) continue;
          final left = _stallLeft(q);
          if (left == 0) {
            puzzle = q; // 아직 논리로 풀린다: 더 지울 수 있다
            changed = true;
            break;
          }
          if (left < stuckLeft) {
            stuckLeft = left;
            stuck = q;
          }
        }
      }
      if (stuck != null && stuckLeft < bestLeft) {
        bestLeft = stuckLeft;
        bestPuzzle = stuck;
        bestSolution = solution;
        if (bestLeft <= 36) break;
      }
    }
    if (bestPuzzle != null) return SudokuPuzzle(givens: bestPuzzle, solution: bestSolution!, difficulty: Difficulty.extreme);
    // (거의 없는 일) 막히는 판을 못 찾았으면 가장 어려운 판을 쓴다
    return _generateHard(Difficulty.expert, rng).copyWith(Difficulty.extreme);
  }

  /// 완성판에서 칸을 (180도 대칭으로) 지워 가며, 논리로 풀리는 한 계속 지운다.
  static List<int> _carve(List<int> solution, Difficulty d, Random rng) {
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(41, (i) => i)..shuffle(rng);
    final minClues = d == Difficulty.easy ? 30 + rng.nextInt(6) : 0;
    var clues = 81;
    for (final i in order) {
      final j = 80 - i;
      final removed = i == j ? 1 : 2;
      if (clues - removed < minClues) continue;
      final a = puzzle[i], b = puzzle[j];
      puzzle[i] = 0;
      puzzle[j] = 0;
      if (HumanSolver.grade(puzzle, maxLevel: d.maxLevel).solved) {
        clues -= removed;
      } else {
        puzzle[i] = a;
        puzzle[j] = b;
      }
    }
    return puzzle;
  }

  /// 어떤 시도도 논리로 풀리지 않았을 때(사실상 없음): 쉬운 방식으로 만든 판을 돌려준다.
  /// (지우기 전에 항상 풀리는지 확인하므로 해가 하나뿐임이 보장된다.)
  static SudokuPuzzle _fallback(Difficulty d, Random rng) {
    final solution = BacktrackSolver.randomSolution(rng);
    return SudokuPuzzle(
      givens: _carve(solution, Difficulty.easy, rng),
      solution: solution,
      difficulty: d,
    );
  }
}
