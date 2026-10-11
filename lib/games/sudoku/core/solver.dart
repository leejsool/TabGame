import 'dart:math';

import 'grid.dart';

/// 백트래킹 풀이기. 해의 개수를 세거나(유일해 검증), 무작위 완성판을 만드는 데 쓴다.
/// (사람이 푸는 방식의 풀이는 techniques.dart 참고)
class BacktrackSolver {
  BacktrackSolver._(List<int> grid, this._limit, this._rng) : _g = List.of(grid);

  final List<int> _g;
  final int _limit;
  final Random? _rng;
  final List<int> _rows = List.filled(9, 0);
  final List<int> _cols = List.filled(9, 0);
  final List<int> _boxes = List.filled(9, 0);
  int _count = 0;
  List<int>? _first;

  /// 해의 개수 (최대 [limit]개까지만 센다). 격자가 모순이면 0.
  static int countSolutions(List<int> grid, {int limit = 2}) {
    final s = BacktrackSolver._(grid, limit, null);
    if (!s._init()) return 0;
    s._search();
    return s._count;
  }

  /// 첫 번째 해. 없으면 null.
  static List<int>? solve(List<int> grid) {
    final s = BacktrackSolver._(grid, 1, null);
    if (!s._init()) return null;
    s._search();
    return s._first;
  }

  /// 무작위 완성판.
  static List<int> randomSolution(Random rng) {
    final s = BacktrackSolver._(List.filled(81, 0), 1, rng);
    s._init();
    s._search();
    return s._first!;
  }

  bool _init() {
    for (var i = 0; i < 81; i++) {
      final d = _g[i];
      if (d == 0) continue;
      final b = bit(d);
      if ((_rows[rowOf[i]] | _cols[colOf[i]] | _boxes[boxOf[i]]) & b != 0) {
        return false;
      }
      _rows[rowOf[i]] |= b;
      _cols[colOf[i]] |= b;
      _boxes[boxOf[i]] |= b;
    }
    return true;
  }

  void _search() {
    if (_count >= _limit) return;
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (_g[i] != 0) continue;
      final m = kAllDigits & ~(_rows[rowOf[i]] | _cols[colOf[i]] | _boxes[boxOf[i]]);
      final c = popCount(m);
      if (c == 0) return;
      if (c < bestCount) {
        best = i;
        bestMask = m;
        bestCount = c;
        if (c == 1) break;
      }
    }
    if (best == -1) {
      _count++;
      _first ??= List.of(_g);
      return;
    }
    final digits = digitsOf(bestMask);
    if (_rng != null) digits.shuffle(_rng);
    final r = rowOf[best], c = colOf[best], b = boxOf[best];
    for (final d in digits) {
      final m = bit(d);
      _g[best] = d;
      _rows[r] |= m;
      _cols[c] |= m;
      _boxes[b] |= m;
      _search();
      _g[best] = 0;
      _rows[r] &= ~m;
      _cols[c] &= ~m;
      _boxes[b] &= ~m;
      if (_count >= _limit) return;
    }
  }
}
