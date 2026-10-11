import 'dart:math';
import 'dart:typed_data';

import 'uttt_rules.dart';

enum UttLevel {
  easy('쉬움', '가끔 실수해요'),
  normal('보통', '몇 수 앞을 내다봐요'),
  hard('어려움', '깊이 읽고 함정을 노려요');

  const UttLevel(this.label, this.description);

  final String label;
  final String description;
}

/// CPU: 알파-베타 탐색. 난이도는 탐색 깊이/노드 수와 "일부러 덜 좋은 수를 고를 확률"로 조절한다.
class UttAi {
  UttAi._();

  static const int _win = 100000;

  /// 큰 판에서 작은 판의 가치 (한가운데 > 모서리 > 가장자리).
  static const List<int> _bigW = [3, 2, 3, 2, 4, 2, 3, 2, 3];

  // 작은 판 안의 점수 표 (X 시점): (X칸 마스크, O칸 마스크) → 점수. 처음 쓸 때 계산한다.
  static final Int16List _smallTable = Int16List(512 * 512);
  static final Uint8List _smallDone = Uint8List(512 * 512);

  static int _smallEval(int x, int o) {
    final idx = x * 512 + o;
    if (_smallDone[idx] == 1) return _smallTable[idx];
    var s = 0;
    for (final line in kLineMasks) {
      final lx = _count(x & line), lo = _count(o & line);
      if (lo == 0) {
        if (lx == 2) {
          s += 6;
        } else if (lx == 1) {
          s += 1;
        }
      }
      if (lx == 0) {
        if (lo == 2) {
          s -= 6;
        } else if (lo == 1) {
          s -= 1;
        }
      }
    }
    if ((x >> 4) & 1 == 1) s += 2;
    if ((o >> 4) & 1 == 1) s -= 2;
    _smallTable[idx] = s;
    _smallDone[idx] = 1;
    return s;
  }

  static int _count(int m) {
    var c = 0;
    while (m != 0) {
      m &= m - 1;
      c++;
    }
    return c;
  }

  /// 형세 점수 (X 시점, 클수록 X에게 유리).
  static int _evalX(UttState s) {
    var score = 0;
    for (var b = 0; b < 9; b++) {
      final owner = s.boardOwner(b);
      if (owner == 1) {
        score += _bigW[b] * 14;
      } else if (owner == 2) {
        score -= _bigW[b] * 14;
      } else if (owner == 0) {
        score += _smallEval(s.cellsX[b], s.cellsO[b]) * _bigW[b] ~/ 2;
      }
    }
    // 큰 판의 줄 가능성
    for (final line in kLineMasks) {
      final lx = _count(s.bigX & line), lo = _count(s.bigO & line);
      final blocked = _count(s.bigDraw & line);
      if (blocked > 0) continue;
      if (lo == 0 && lx > 0) score += lx == 2 ? 60 : 8;
      if (lx == 0 && lo > 0) score -= lo == 2 ? 60 : 8;
    }
    // 아무 판이나 고를 수 있는 쪽이 조금 유리하다
    if (s.next < 0) score += s.turn == kX ? 6 : -6;
    return score;
  }

  /// 수 정렬용 가벼운 점수 (높을수록 먼저 본다).
  static int _orderScore(UttState s, int move) {
    final b = move ~/ 9, c = move % 9;
    final mine = s.turn == kX ? s.cellsX[b] : s.cellsO[b];
    final theirs = s.turn == kX ? s.cellsO[b] : s.cellsX[b];
    var sc = 0;
    if (hasLine(mine | (1 << c))) sc += 40; // 작은 판을 차지한다
    if (hasLine(theirs | (1 << c))) sc += 15; // 상대가 차지하려던 칸을 막는다
    if (c == 4) sc += 3;
    if (!s.boardOpen(c)) sc -= 6; // 상대에게 아무 판이나 고를 자유를 준다
    return sc;
  }

  static List<int> _ordered(UttState s) {
    final moves = s.legalMoves();
    final scored = [for (final m in moves) (m, _orderScore(s, m))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1];
  }

  static int _nodes = 0;
  static int _nodeLimit = 1 << 30;
  static bool _aborted = false;

  /// 지금 둘 차례의 시점에서 본 점수 (negamax).
  static int _search(UttState s, int depth, int alpha, int beta, int ply) {
    if (s.outcome != Outcome.ongoing) {
      if (s.outcome == Outcome.draw) return 0;
      final xWon = s.outcome == Outcome.xWins;
      final forMover = (xWon && s.turn == kX) || (!xWon && s.turn == kO);
      return forMover ? _win - ply : -(_win - ply);
    }
    if (depth <= 0) {
      final x = _evalX(s);
      return s.turn == kX ? x : -x;
    }
    if (++_nodes > _nodeLimit) {
      _aborted = true;
      return 0;
    }
    var best = -_win * 2;
    for (final m in _ordered(s)) {
      s.apply(m);
      final score = -_search(s, depth - 1, -beta, -alpha, ply + 1);
      s.undo(m);
      if (_aborted) return 0;
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// 지금 둘 차례([s].turn)의 수를 고른다. [s]는 변경하지 않는다.
  static int choose(UttState state, UttLevel level, Random rng) {
    final s = state.copy();
    final moves = s.legalMoves();

    // 쉬움: 가끔은 완전히 아무 수나
    if (level == UttLevel.easy && rng.nextDouble() < 0.25) {
      return moves[rng.nextInt(moves.length)];
    }

    // 한 수로 이길 수 있으면 (쉬움 제외) 둔다
    if (level != UttLevel.easy) {
      for (final m in moves) {
        s.apply(m);
        final won = s.outcome == (s.turn == kO ? Outcome.xWins : Outcome.oWins);
        s.undo(m);
        if (won) return m;
      }
    }

    final (depth, limit, margin) = switch (level) {
      UttLevel.easy => (1, 1 << 30, 25),
      UttLevel.normal => (4, 1 << 30, 6),
      UttLevel.hard => (9, 350000, 0),
    };

    var scores = <int>[];
    var ordered = _ordered(s);
    _nodeLimit = limit;

    if (level == UttLevel.hard) {
      // 점점 깊게 읽는다. 노드 한도에 걸린 깊이는 버리고 마지막으로 끝낸 깊이의 결과를 쓴다.
      var bestOrder = ordered;
      var bestScores = <int>[for (final _ in ordered) 0];
      for (var d = 1; d <= depth; d++) {
        _nodes = 0;
        _aborted = false;
        final cur = <int>[];
        var alpha = -_win * 2;
        for (final m in bestOrder) {
          s.apply(m);
          // 첫 수 이후에는 alpha 로 가지치기하되, 같은 점수의 수들을 구별하려고 한 칸 낮춰서 본다
          final score = -_search(s, d - 1, -_win * 2, -(alpha - 1), 1);
          s.undo(m);
          if (_aborted) break;
          cur.add(score);
          if (score > alpha) alpha = score;
        }
        if (_aborted) break;
        // 이번 깊이의 점수 순으로 다시 정렬
        final pairs = [for (var i = 0; i < bestOrder.length; i++) (bestOrder[i], cur[i])]
          ..sort((a, b) => b.$2.compareTo(a.$2));
        bestOrder = [for (final p in pairs) p.$1];
        bestScores = [for (final p in pairs) p.$2];
        if (bestScores.first >= _win - 50) break; // 이기는 길을 찾았다
      }
      ordered = bestOrder;
      scores = bestScores;
    } else {
      for (final m in ordered) {
        s.apply(m);
        _nodes = 0;
        _aborted = false;
        scores.add(-_search(s, depth - 1, -_win * 2, _win * 2, 1));
        s.undo(m);
      }
    }

    var best = scores.reduce(max);
    final candidates = <int>[
      for (var i = 0; i < ordered.length; i++)
        if (scores[i] >= best - margin) ordered[i],
    ];
    return candidates[rng.nextInt(candidates.length)];
  }
}
