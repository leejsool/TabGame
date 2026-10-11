import 'dart:math';

import 'solver.dart';
import 'techniques.dart';

enum Difficulty {
  easy('쉬움', '기본 기술(싱글)만으로 풀려요', 1),
  medium('보통', '페어·교차 같은 기술이 필요해요', 2),
  hard('어려움', '트리플·X-윙 같은 고급 기술이 필요해요', 4);

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

  String get givensString => givens.join();
  String get solutionString => solution.join();
  int get clueCount => givens.where((v) => v != 0).length;
}

class PuzzleGenerator {
  PuzzleGenerator._();

  /// 난이도에 맞는 새 퍼즐을 만든다. 모든 퍼즐은 논리 기술만으로 풀리고, 해가 하나뿐이다.
  static SudokuPuzzle generate(Difficulty difficulty, {Random? rng, int maxAttempts = 40}) {
    rng ??= Random();
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
        Difficulty.hard => grade.maxLevel >= 3,
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
