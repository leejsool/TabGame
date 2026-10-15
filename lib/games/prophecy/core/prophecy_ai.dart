import 'dart:math';

import 'prophecy_rules.dart';

enum ProphLevel {
  easy('쉬움', '아무 칸에나 아무 숫자나 써요'),
  normal('보통', '여러 번 끝까지 해 보고 골라요'),
  hard('어려움', '아주 많이 끝까지 해 보고 골라요');

  const ProphLevel(this.label, this.description);

  final String label;
  final String description;
}

/// CPU: 몬테카를로. 후보 수마다 "그 수를 둔 뒤 끝까지 아무렇게나 두는" 시합을 여러 번 해 보고,
/// 내 점수에서 상대 점수를 뺀 값의 평균이 가장 높은 수를 고른다. 난이도는 후보와 시합 횟수로 조절한다.
class ProphAi {
  ProphAi._();

  /// 난이도별 (후보 수 상한, 후보마다 시합 횟수). 쉬움은 0이라 그냥 아무 수나 둔다.
  static (int, int) _budget(ProphLevel level) => switch (level) {
        ProphLevel.easy => (0, 0),
        ProphLevel.normal => (24, 14),
        ProphLevel.hard => (70, 70),
      };

  /// 현재 차례인 사람이 둘 수 하나 (encodeMove).
  static int choose(ProphState s, ProphLevel level, Random rng) {
    final moves = s.legalMoves();
    assert(moves.isNotEmpty);
    final (cap, games) = _budget(level);
    if (cap == 0 || moves.length == 1) return moves[rng.nextInt(moves.length)];

    // 후보: 너무 많으면 무작위로 일부만 (칸마다 골고루 나오도록 섞어서 앞에서부터)
    moves.shuffle(rng);
    final cands = moves.length > cap ? moves.sublist(0, cap) : moves;
    final me = s.turn;

    // 남은 칸이 적을수록 시합이 짧으니, 시합 수를 늘려도 부담이 적다
    final n = s.blanks <= 12 ? games * 2 : games;
    var best = cands.first;
    var bestVal = -1e18;
    for (final m in cands) {
      var sum = 0;
      for (var g = 0; g < n; g++) {
        final t = s.copy()..play(moveCell(m), moveValue(m));
        playRandomly(t, rng);
        final sc = t.scores();
        sum += sc[me] - sc[1 - me];
      }
      final v = sum / n + rng.nextDouble() * 1e-6;
      if (v > bestVal) {
        bestVal = v;
        best = m;
      }
    }
    return best;
  }
}
