import 'dart:math';

import 'dandelion_rules.dart';

enum DandLevel {
  easy('쉬움', '가끔 엉뚱한 곳을 골라요'),
  normal('보통', '몇 수 앞을 내다봐요'),
  hard('어려움', '끝까지 깊이 읽어요');

  const DandLevel(this.label, this.description);

  final String label;
  final String description;
}

/// CPU: 탐색(알파-베타)과 형세 점수. 난이도는 탐색량과 "일부러 아무 수나 둘 확률"로 조절한다.
///
/// 점수는 민들레 쪽에서 본 값이다 (클수록 민들레에게 유리, 바람은 이 값을 줄이려 한다).
class DandAi {
  DandAi._();

  static const int _win = 100000;

  /// 한가운데에 가까운 칸부터 살핀다 (가운데 꽃이 더 많은 칸에 씨앗을 보낸다).
  static final List<int> _centerFirst = () {
    final cells = List<int>.generate(kSize * kSize, (i) => i);
    int d(int i) {
      final r = i ~/ kSize - (kSize - 1) / 2, c = i % kSize - (kSize - 1) / 2;
      return ((r * r + c * c) * 4).round();
    }

    cells.sort((a, b) => d(a).compareTo(d(b)));
    return cells;
  }();

  /// 형세 점수. 빈칸이 적을수록, 그리고 빈칸마다 앞으로 씨앗이 닿을 길이 많을수록 높다.
  static int _eval(DandState s) {
    final w = s.winner;
    if (w != null) return w == Role.dandelion ? _win : -_win;
    final empties = [for (var i = 0; i < s.cells.length; i++) if (s.cells[i] == kEmpty) i];
    if (empties.isEmpty) return _win;
    // 빈칸마다 씨앗이 닿을 수 있는 서로 다른 방향 수: 둘 이상이면 바람이 한 방향을 빼도 채워진다(보장)
    final reach = DandState.reachMasks(s.cells, s.usedWinds);
    var score = 0;
    for (final c in empties) {
      final n = _bits(reach[c]);
      score -= n >= 2 ? 12 : (n == 1 ? 34 : 80);
    }
    // 앞으로 심을 수 있는 꽃이 많을수록 유리
    return score + s.windsLeft * 4;
  }

  static int _bits(int m) {
    var n = 0;
    while (m != 0) {
      m &= m - 1;
      n++;
    }
    return n;
  }

  static int _nodes = 0;
  static int _budget = 0;
  static bool _aborted = false;

  static List<int> _ordered(DandState s) {
    if (s.turn == Role.dandelion) {
      return [for (final c in _centerFirst) if (s.cells[c] != kFlower) c];
    }
    // 바람은 씨앗이 적게 생기는 방향부터
    final moves = s.legalMoves();
    final fills = <int, int>{
      for (final m in moves) m: s.copy().blow(WindDir.values[m]).length,
    };
    moves.sort((a, b) => fills[a]!.compareTo(fills[b]!));
    return moves;
  }

  static int _search(DandState s, int depth, int alpha, int beta) {
    if (_aborted) return 0;
    if (++_nodes > _budget) {
      _aborted = true;
      return 0;
    }
    if (s.isOver) {
      final w = s.winner!;
      // 같은 결과라면 빨리 끝나는 쪽을 조금 더 좋게 본다
      return w == Role.dandelion ? _win - s.plies : -_win + s.plies;
    }
    if (depth == 0) return _eval(s);
    final maximizing = s.turn == Role.dandelion;
    var best = maximizing ? -1 << 30 : 1 << 30;
    for (final m in _ordered(s)) {
      final child = s.copy()..apply(m);
      final v = _search(child, depth - 1, alpha, beta);
      if (_aborted) return 0;
      if (maximizing) {
        if (v > best) best = v;
        if (best > alpha) alpha = best;
      } else {
        if (v < best) best = v;
        if (best < beta) beta = best;
      }
      if (alpha >= beta) break;
    }
    return best;
  }

  /// 지금 차례의 수를 고른다.
  static int choose(DandState s, DandLevel level, Random rng) {
    final moves = s.legalMoves();
    if (moves.length == 1) return moves.first;
    final mistake = switch (level) {
      DandLevel.easy => 0.3,
      DandLevel.normal => 0.06,
      DandLevel.hard => 0.0,
    };
    if (mistake > 0 && rng.nextDouble() < mistake) return moves[rng.nextInt(moves.length)];
    final budget = switch (level) {
      DandLevel.easy => 1,
      DandLevel.normal => 25000,
      DandLevel.hard => 150000,
    };
    final maximizing = s.turn == Role.dandelion;
    final order = _ordered(s);
    var bestMoves = <int>[order.first];
    // 깊이를 한 수씩 늘려 가며, 예산이 바닥나면 마지막으로 끝까지 본 깊이의 결과를 쓴다
    final maxDepth = s.turn == Role.dandelion ? 2 * s.windsLeft : 2 * s.windsLeft - 1;
    for (var depth = 1; depth <= maxDepth; depth++) {
      _nodes = 0;
      _aborted = false;
      _budget = level == DandLevel.easy ? 1 << 30 : budget;
      var bestV = maximizing ? -1 << 30 : 1 << 30;
      var cur = <int>[];
      var alpha = -1 << 30, beta = 1 << 30;
      for (final m in order) {
        final child = s.copy()..apply(m);
        final v = _search(child, depth - 1, alpha, beta);
        if (_aborted) break;
        if (maximizing ? v > bestV : v < bestV) {
          bestV = v;
          cur = [m];
          // 같은 점수의 수도 골라 낼 수 있게 창을 한 칸 열어 둔다
          if (maximizing) {
            alpha = v - 1;
          } else {
            beta = v + 1;
          }
        } else if (v == bestV) {
          cur.add(m);
        }
      }
      if (_aborted) break;
      bestMoves = cur;
      if (level == DandLevel.easy) break; // 쉬움: 한 수 앞만
      if (bestV.abs() >= _win - 100) break; // 승패가 이미 갈렸다
    }
    return bestMoves[rng.nextInt(bestMoves.length)];
  }
}
