import 'dart:math';

import 'davinci_rules.dart';

/// CPU 난이도.
enum DvLevel {
  easy('쉬움', '아무 타일이나 찍어서 맞혀 봐요. 맞혀도 자주 멈춰요'),
  normal('보통', '가장 확실한 타일부터 맞히고, 절반 넘게 확실할 때 계속해요'),
  hard('어려움', '여러 줄을 함께 따져서 확률을 구하고, 과감하게 계속 맞혀요');

  const DvLevel(this.label, this.description);
  final String label;
  final String description;
}

/// CPU가 다음 수를 고른다.
class DvAi {
  DvAi._();

  /// 지금 차례([DvState.turn])인 사람이 둘 다음 수.
  static List<int> choose(DvState s, DvLevel level, Random rng) {
    assert(!s.isOver);
    switch (s.phase) {
      case DvPhase.draw:
        final colors = s.drawableColors;
        return DvMove.drawMove(colors[rng.nextInt(colors.length)]);
      case DvPhase.placeJoker:
        return DvMove.placeJoker(rng.nextInt(s.rows[s.turn].length + 1));
      case DvPhase.reveal:
        final hidden = [for (var i = 0; i < s.rows[s.turn].length; i++) if (!s.isRevealed(s.rows[s.turn][i])) i];
        return DvMove.reveal(hidden[rng.nextInt(hidden.length)]);
      case DvPhase.decide:
        final best = _bestGuess(s, level, rng);
        if (best == null || !_shouldContinue(s, level, best.p, rng)) return DvMove.stop;
        return DvMove.guess(best.seat, best.index, best.number);
      case DvPhase.guess:
        final best = _bestGuess(s, level, rng);
        // (맞힐 수 있는 타일이 없으면 판이 이미 끝나 있다)
        return DvMove.guess(best!.seat, best.index, best.number);
    }
  }

  static bool _shouldContinue(DvState s, DvLevel level, double p, Random rng) {
    if (p >= 0.999) return true; // 확실하면 언제나 계속
    switch (level) {
      case DvLevel.easy:
        return rng.nextInt(100) < 35;
      case DvLevel.normal:
        return p >= 0.5;
      case DvLevel.hard:
        return p >= 0.42; // 틀려도 잃는 건 방금 뽑은 타일 하나뿐이라, 반반이면 밀어붙인다
    }
  }

  /// 가장 좋은 맞히기 (타일, 숫자, 맞힐 확률).
  /// 쉬움은 아무 타일·후보나 고르고, 보통·어려움은 [rowMarginals]로 가장 확률이 높은 타일과 숫자를 고른다.
  static ({int seat, int index, int number, double p})? _bestGuess(DvState s, DvLevel level, Random rng) {
    final options = <({int seat, int index, Map<int, double> probs})>[];
    for (var seat = 0; seat < s.players; seat++) {
      if (seat == s.turn || s.isOut(seat)) continue;
      final marg = rowMarginals(s, s.turn, seat);
      for (var i = 0; i < s.rows[seat].length; i++) {
        final m = marg[i];
        if (m == null || m.isEmpty) continue;
        options.add((seat: seat, index: i, probs: m));
      }
    }
    if (options.isEmpty) return null;
    if (level == DvLevel.hard) _refineJointly(s, options);
    if (level == DvLevel.easy) {
      // 순서는 따지지 않고, 이미 보이는 타일의 숫자만 빼고 아무 숫자나 찍는다
      final o = options[rng.nextInt(options.length)];
      final color = dvColor(s.rows[o.seat][o.index]);
      final seen = <int>{...s.revealed, ...s.rows[s.turn]};
      final numbers = [for (var n = 0; n < kDvNumbers; n++) if (!seen.contains(dvTile(color, n))) n];
      if (numbers.isEmpty) numbers.add(o.probs.keys.first);
      final number = numbers[rng.nextInt(numbers.length)];
      return (seat: o.seat, index: o.index, number: number, p: o.probs[number] ?? 0);
    }
    // 확률이 가장 높은 (타일, 숫자). 같으면 무작위.
    var bestP = -1.0;
    final bests = <({int seat, int index, int number})>[];
    for (final o in options) {
      for (final e in o.probs.entries) {
        if (e.value > bestP + 1e-9) {
          bestP = e.value;
          bests
            ..clear()
            ..add((seat: o.seat, index: o.index, number: e.key));
        } else if ((e.value - bestP).abs() <= 1e-9) {
          bests.add((seat: o.seat, index: o.index, number: e.key));
        }
      }
    }
    final pick = bests[rng.nextInt(bests.length)];
    return (seat: pick.seat, index: pick.index, number: pick.number, p: bestP);
  }

  /// 줄마다 따로 구한 확률은 같은 타일이 여러 줄에서 동시에 나올 수 있다고 보아 들떠 있다. 타일 하나(색·숫자)는 한 곳에만 있으니,
  /// 한 타일의 확률 합이 1을 넘으면 비율대로 줄이고 칸별로 다시 합이 1이 되게 맞추기를 몇 번 되풀이한다.
  static void _refineJointly(DvState s, List<({int seat, int index, Map<int, double> probs})> options) {
    for (var round = 0; round < 4; round++) {
      final sums = <int, double>{}; // 색*100 + 숫자(조커 12) → 확률 합
      for (final o in options) {
        final c = dvColor(s.rows[o.seat][o.index]);
        o.probs.forEach((n, p) => sums[c * 100 + n] = (sums[c * 100 + n] ?? 0) + p);
      }
      for (final o in options) {
        final c = dvColor(s.rows[o.seat][o.index]);
        var total = 0.0;
        for (final n in o.probs.keys.toList()) {
          final sum = sums[c * 100 + n]!;
          final v = o.probs[n]! / (sum > 1 ? sum : 1);
          o.probs[n] = v;
          total += v;
        }
        if (total > 0) o.probs.updateAll((_, v) => v / total);
      }
    }
  }

  /// [viewer]가 가진 정보로 [seat]의 줄에서 숨은 타일 하나하나가 각 숫자(조커는 [kJokerGuess])일 확률.
  /// 줄은 작은 숫자부터 놓여 있다는 규칙을 지키는 모든 경우를 세어서 구한다 (내 타일·공개된 타일은 후보에서 뺀다).
  /// 공개된 칸은 null.
  static List<Map<int, double>?> rowMarginals(DvState s, int viewer, int seat) {
    final row = s.rows[seat];
    final n = row.length;
    final known = <int>{...s.revealed, ...s.rows[viewer]};

    // 상태: (마지막으로 놓인 타일의 순서값 + 1) * 4 + (검정 조커 썼나, 흰색 조커 썼나)
    // 순서값 = 숫자 * 2 + 색 (같은 숫자면 검정이 앞)
    const nStates = 25 * 4;
    int st(int last, int flags) => (last + 1) * 4 + flags;

    // 칸마다 가능한 전이: (다음 상태, 숫자값, 현재 상태에서)
    List<({int to, int value})> trans(int state, int pos) {
      final last = state ~/ 4 - 1, flags = state % 4;
      final t = row[pos];
      if (s.isRevealed(t)) {
        if (dvIsJoker(t)) return [(to: state, value: -1)];
        final o = dvNumber(t) * 2 + dvColor(t);
        return o > last ? [(to: st(o, flags), value: -1)] : const [];
      }
      final c = dvColor(t);
      final out = <({int to, int value})>[];
      for (var num = 0; num < kDvNumbers; num++) {
        if (known.contains(dvTile(c, num))) continue;
        final o = num * 2 + c;
        if (o > last) out.add((to: st(o, flags), value: num));
      }
      if (!known.contains(24 + c) && (flags & (1 << c)) == 0) out.add((to: st(last, flags | (1 << c)), value: kJokerGuess));
      return out;
    }

    // 앞에서부터 / 뒤에서부터 세기
    final fwd = List.generate(n + 1, (_) => List<double>.filled(nStates, 0));
    fwd[0][st(-1, 0)] = 1;
    for (var i = 0; i < n; i++) {
      for (var state = 0; state < nStates; state++) {
        final w = fwd[i][state];
        if (w == 0) continue;
        for (final tr in trans(state, i)) {
          fwd[i + 1][tr.to] += w;
        }
      }
    }
    final bwd = List.generate(n + 1, (_) => List<double>.filled(nStates, 1));
    for (var i = n - 1; i >= 0; i--) {
      for (var state = 0; state < nStates; state++) {
        var sum = 0.0;
        for (final tr in trans(state, i)) {
          sum += bwd[i + 1][tr.to];
        }
        bwd[i][state] = sum;
      }
    }
    final total = bwd[0][st(-1, 0)];
    final res = List<Map<int, double>?>.filled(n, null);
    if (total <= 0) return res;
    for (var i = 0; i < n; i++) {
      if (s.isRevealed(row[i])) continue;
      final m = <int, double>{};
      for (var state = 0; state < nStates; state++) {
        final w = fwd[i][state];
        if (w == 0) continue;
        for (final tr in trans(state, i)) {
          m[tr.value] = (m[tr.value] ?? 0) + w * bwd[i + 1][tr.to];
        }
      }
      m.removeWhere((_, v) => v <= 0); // (순서에 맞지 않아 불가능한 숫자는 뺀다)
      m.updateAll((_, v) => v / total);
      res[i] = m;
    }
    return res;
  }
}
