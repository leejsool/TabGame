/// 콩나물 CPU. 격자 길찾기([findMoves])로 "둘 수 있는 수"를 만들고, 난이도에 따라 고른다.
///
/// - 쉬움: 둘 수 있는 수 중 아무거나.
/// - 보통: 한 수 앞을 본다. 내가 둔 뒤 상대가 움직일 곳이 하나도 없으면(= 내가 이기면) 그 수를 두고,
///   아니면 상대가 둘 수 있는 수가 가장 적어지는 수를 고른다 (가끔 일부러 아무거나).
/// - 어려움: 두 수 앞을 본다. 상대가 어떻게 받아도 내가 곧바로 막히지 않는 수를 고른다. 시간이 모자라면 보통처럼 고른다.
///
/// 판이 끝나는 쪽이 이기는 게임이라, 남은 "목숨"이 적을수록 앞날을 읽는 게 잘 통한다.
library;

import 'dart:math';

import 'sprouts_board.dart';
import 'sprouts_planner.dart';

enum SproutsLevel {
  easy('쉬움', '아무 곳에나 이어요'),
  normal('보통', '한 수 앞을 내다봐요'),
  hard('어려움', '두 수 앞까지 읽고 함정을 노려요');

  const SproutsLevel(this.label, this.description);

  final String label;
  final String description;
}

/// [b]에서 [level]의 CPU가 둘 수를 고른다. 둘 수가 없으면 null.
SproutsMove? chooseMove(SproutsBoard b, SproutsLevel level, Random rng, {Duration budget = const Duration(milliseconds: 1800)}) {
  final clock = Stopwatch()..start();
  final moves = findMoves(b, clock: clock, deadline: budget);
  if (moves.isEmpty) return null;
  if (level == SproutsLevel.easy || moves.length == 1) return moves[rng.nextInt(moves.length)];

  // 후보가 너무 많으면 일부만 본다 (무작위로 섞어서 앞에서부터)
  final cands = List<SproutsMove>.of(moves)..shuffle(rng);
  final limit = level == SproutsLevel.hard ? 10 : 14;
  final shown = cands.take(limit).toList();

  // 내가 둔 뒤 상대가 둘 수 있는 수들
  final after = <SproutsMove, List<SproutsMove>>{};
  for (final m in shown) {
    if (clock.elapsed > budget) break;
    final nb = b.copy()..apply(m.s, m.e, m.result, 0);
    final replies = findMoves(nb, clock: clock, deadline: budget, allowRelax: false);
    if (replies.isEmpty) return m; // 상대가 막혔다: 내가 이긴다
    after[m] = replies;
  }
  if (after.isEmpty) return shown.first;

  final scored = after.keys.toList();
  if (level == SproutsLevel.hard) {
    // 상대의 받는 수마다, 내가 곧바로 막히는지 본다
    final lossRate = <SproutsMove, double>{};
    for (final m in scored) {
      if (clock.elapsed > budget) break;
      final replies = after[m]!;
      final nb = b.copy()..apply(m.s, m.e, m.result, 0);
      var bad = 0, seen = 0;
      for (final r in replies.take(8)) {
        if (clock.elapsed > budget) break;
        final nb2 = nb.copy()..apply(r.s, r.e, r.result, 1);
        seen++;
        if (!hasMove(nb2, allowRelax: false)) bad++; // 상대가 이 수로 나를 막아 버린다
      }
      if (seen > 0) lossRate[m] = bad / seen;
    }
    if (lossRate.isNotEmpty) {
      var best = double.infinity;
      for (final v in lossRate.values) {
        best = min(best, v);
      }
      final safest = [
        for (final e in lossRate.entries)
          if (e.value <= best + 1e-9) e.key,
      ];
      safest.sort((a, c) => after[a]!.length.compareTo(after[c]!.length));
      return safest.first;
    }
  }

  // 보통(과 어려움의 대비책): 상대가 움직일 곳이 가장 적은 수. 가끔은 아무거나.
  if (level == SproutsLevel.normal && rng.nextDouble() < 0.2) return scored[rng.nextInt(scored.length)];
  scored.sort((a, c) => after[a]!.length.compareTo(after[c]!.length));
  final bestCount = after[scored.first]!.length;
  final slack = level == SproutsLevel.normal ? 1 : 0;
  final ties = [
    for (final m in scored)
      if (after[m]!.length <= bestCount + slack) m,
  ];
  return ties[rng.nextInt(ties.length)];
}

/// isolate에서 쓰는 형태: [판 데이터, 난이도 번호, 시드] → 고른 수를 숫자 목록으로 ([encodeMove]). 없으면 빈 목록.
List<double> sproutsCpuTask(List<Object> args) {
  final board = SproutsBoard.fromData(List<double>.from(args[0] as List));
  final level = SproutsLevel.values[args[1] as int];
  final m = chooseMove(board, level, Random(args[2] as int));
  if (m == null) return const [];
  return encodeMove(m);
}
