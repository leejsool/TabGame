import 'dart:math';

import 'goblet_rules.dart';

enum CpuLevel {
  easy('쉬움', '가끔 실수해요'),
  normal('보통', '두세 수 앞을 내다봐요'),
  hard('어려움', '다섯 수 앞까지 읽어요');

  const CpuLevel(this.label, this.description);

  final String label;
  final String description;
}

/// CPU: 깊이가 제한된 알파-베타 탐색. 난이도는 탐색 깊이와 "일부러 덜 좋은 수를 고를 확률"로 조절한다.
class GobbletAi {
  GobbletAi._();

  static const int _win = 10000;

  /// 현재 차례([board].turn)의 수를 고른다. 보드는 변경하지 않는다.
  static GobbletMove choose(GobbletBoard board, CpuLevel level, Random rng) {
    final b = board.copy();
    final moves = b.legalMoves();
    final mover = b.turn;

    // 쉬움: 가끔은 완전히 아무 수나 둔다
    if (level == CpuLevel.easy && rng.nextDouble() < 0.2) {
      return moves[rng.nextInt(moves.length)];
    }

    final depth = switch (level) {
      CpuLevel.easy => 1,
      CpuLevel.normal => 3,
      CpuLevel.hard => 5,
    };
    final margin = switch (level) {
      CpuLevel.easy => 40,
      CpuLevel.normal => 8,
      CpuLevel.hard => 0,
    };

    final scores = <int>[];
    var best = -1 << 30;
    for (final m in moves) {
      b.apply(m);
      final w = b.winnerAfter(mover);
      final int score;
      if (w == mover) {
        score = _win;
      } else if (w != 0) {
        score = -_win;
      } else if (depth <= 1) {
        score = _eval(b, mover);
      } else {
        score = -_search(b, depth - 1, -_win * 2, _win * 2, 1);
      }
      b.undo(m);
      scores.add(score);
      if (score > best) best = score;
    }

    final candidates = <GobbletMove>[
      for (var i = 0; i < moves.length; i++)
        if (scores[i] >= best - margin && (best < _win || scores[i] >= _win)) moves[i],
    ];
    return candidates[rng.nextInt(candidates.length)];
  }

  static int _search(GobbletBoard b, int depth, int alpha, int beta, int ply) {
    final mover = b.turn;
    var best = -_win * 3;
    for (final m in b.legalMoves()) {
      b.apply(m);
      final w = b.winnerAfter(mover);
      final int score;
      if (w == mover) {
        score = _win - ply;
      } else if (w != 0) {
        score = -(_win - ply);
      } else if (depth <= 1) {
        score = _eval(b, mover);
      } else {
        score = -_search(b, depth - 1, -beta, -alpha, ply + 1);
      }
      b.undo(m);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// [me] 입장에서의 형세 점수. (방금 [me]가 둔 직후, 상대 차례)
  static int _eval(GobbletBoard b, int me) {
    final opp = 3 - me;
    var s = 0;
    for (final l in GobbletBoard.lines) {
      var mine = 0, theirs = 0;
      for (final c in l) {
        final o = b.topOwner(c);
        if (o == me) {
          mine++;
        } else if (o == opp) {
          theirs++;
        }
      }
      if (mine > 0 && theirs > 0) continue;
      if (mine == 2) s += 25;
      if (mine == 1) s += 3;
      if (theirs == 2) s -= 35; // 상대 차례라 더 위험하다
      if (theirs == 1) s -= 3;
    }
    for (var c = 0; c < 9; c++) {
      final o = b.topOwner(c);
      if (o == 0) continue;
      final sz = b.topSize(c);
      final w = c == 4 ? sz + 3 : sz;
      s += o == me ? w : -w;
    }
    return s;
  }
}
