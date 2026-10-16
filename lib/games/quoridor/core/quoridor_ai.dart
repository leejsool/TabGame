import 'dart:math';

import 'quoridor_rules.dart';

/// CPU 난이도.
enum QLevel {
  easy('쉬움', '앞으로 곧장 가고, 가끔만 벽을 세워요'),
  normal('보통', '내 길과 상대 길을 재서 말을 움직일지 벽을 세울지 골라요'),
  hard('어려움', '상대의 대답까지 한 번 더 내다봐요 (두 명이 할 때)');

  const QLevel(this.label, this.description);
  final String label;
  final String description;
}

/// CPU가 둘 수를 고른다.
class QAi {
  QAi._();

  /// 지금 차례([QState.turn])인 사람이 둘 수를 돌려준다.
  static int choose(QState s, QLevel level, Random rng) {
    assert(!s.isOver);
    switch (level) {
      case QLevel.easy:
        return _easy(s, rng);
      case QLevel.normal:
        return _best(s, rng);
      case QLevel.hard:
        return s.players == 2 ? _lookahead(s, rng) : _best(s, rng);
    }
  }

  /// 모든 사람이 벽을 다 썼을 때의 자동 이동: 지금 차례인 사람이 도착 줄까지 가장 짧은 길로 한 걸음 간다
  /// (같으면 칸 번호가 작은 쪽). 누가 두든 같은 결과가 나오니, Wi‑Fi로 하는 두 기기가 각자 계산해도 판이 같다.
  static int autoStep(QState s) {
    final me = s.turn;
    final moves = [...s.legalPawnMoves()]..sort();
    var best = moves.first;
    var bestD = 1 << 20;
    for (final m in moves) {
      final d = s.distanceFrom(me, m);
      if (d >= 0 && d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  /// 판의 값 (말하는 사람 [me] 쪽에서 볼 때 클수록 좋다).
  /// 내가 도착 줄까지 갈 걸음 수는 적을수록, 상대들의 걸음 수는 많을수록, 남은 벽은 많을수록 좋다.
  static double eval(QState s, int me) {
    final w = s.winner;
    if (w != null) return w == me ? 1000 : -1000;
    final mine = s.distance(me);
    var sum = 0, best = 1 << 20, n = 0, walls = 0;
    for (var p = 0; p < s.players; p++) {
      if (p == me) continue;
      final d = s.distance(p);
      sum += d;
      if (d < best) best = d;
      walls += s.wallsLeft[p];
      n++;
    }
    final avg = sum / n;
    // 앞선 상대를 더 크게 본다 (4명일 때 가장 빠른 사람이 가장 위협적이다)
    final oppValue = 0.5 * avg + 0.5 * best;
    return oppValue - mine + 0.12 * (s.wallsLeft[me] - walls / n);
  }

  /// 후보 수: 말 이동 + 앞선 상대들의 가장 짧은 길을 막는 벽 (놓을 수 있는 것만).
  static List<int> candidates(QState s) {
    final out = <int>{...s.legalPawnMoves()};
    if (s.wallsLeft[s.turn] > 0) {
      for (var p = 0; p < s.players; p++) {
        if (p == s.turn) continue;
        final path = s.shortestPath(p);
        if (path == null) continue;
        var from = s.pawn[p];
        for (final cell in path) {
          for (final w in QState.wallsBlocking(from, cell)) {
            if (!out.contains(w) && s.canPlaceWall(wallOrient(w), wallRow(w), wallCol(w))) out.add(w);
          }
          from = cell;
        }
      }
    }
    return out.toList();
  }

  static QState _after(QState s, int move) {
    final c = s.clone();
    c.applyTrusted(move);
    return c;
  }

  /// 후보 수를 한 수 앞의 값으로 견주어 가장 좋은 수를 고른다.
  static int _best(QState s, Random rng) {
    final me = s.turn;
    var bestMove = -1;
    var bestV = -1e9;
    for (final m in candidates(s)) {
      final v = eval(_after(s, m), me) + rng.nextDouble() * 0.05;
      if (v > bestV) {
        bestV = v;
        bestMove = m;
      }
    }
    return bestMove;
  }

  /// 두 사람이 할 때: 내 수 → 상대의 가장 나쁜 대답까지 보고 고른다. 후보는 한 수 앞의 값이 좋은 몇 개만 본다.
  static int _lookahead(QState s, Random rng) {
    final me = s.turn;
    final scored = <(double, int)>[];
    for (final m in candidates(s)) {
      scored.add((eval(_after(s, m), me), m));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    var bestMove = scored.first.$2;
    var bestV = -1e9;
    for (final (first, m) in scored.take(7)) {
      final next = _after(s, m);
      double v;
      if (next.isOver) {
        v = first;
      } else {
        // 상대가 내게 가장 나쁘게 두는 대답
        final replies = <(double, int)>[];
        for (final r in candidates(next)) {
          replies.add((eval(_after(next, r), me), r));
        }
        replies.sort((a, b) => a.$1.compareTo(b.$1));
        v = replies.isEmpty ? first : replies.first.$1;
      }
      v += rng.nextDouble() * 0.05;
      if (v > bestV) {
        bestV = v;
        bestMove = m;
      }
    }
    return bestMove;
  }

  /// 쉬움: 대부분 내 길을 따라 한 칸 가고, 상대가 앞서면 가끔 벽을 세운다.
  static int _easy(QState s, Random rng) {
    final me = s.turn;
    final moves = s.legalPawnMoves();
    // 가끔은 아무 칸으로나 (실수)
    if (rng.nextInt(100) < 12) return moves[rng.nextInt(moves.length)];
    final myD = s.distance(me);
    var behind = false;
    for (var p = 0; p < s.players; p++) {
      if (p != me && s.distance(p) < myD) behind = true;
    }
    if (behind && s.wallsLeft[me] > 0 && rng.nextInt(100) < 30) {
      final walls = [for (final m in candidates(s)) if (isWallMove(m)) m];
      if (walls.isNotEmpty) {
        var bestMove = walls.first;
        var bestV = -1e9;
        for (final m in walls) {
          final v = eval(_after(s, m), me) + rng.nextDouble();
          if (v > bestV) {
            bestV = v;
            bestMove = m;
          }
        }
        return bestMove;
      }
    }
    var bestMove = moves.first;
    double bestD = 1e9;
    for (final m in moves) {
      final d = s.distanceFrom(me, m) + rng.nextDouble();
      if (d < bestD) {
        bestD = d;
        bestMove = m;
      }
    }
    return bestMove;
  }
}
