// 야추 길잡이: 지금 상황에서 족보별 확률과 가장 좋은 행동을 계산한다.
// 힌트 버튼, CPU, 교과학습이 함께 쓴다. 화면 없이 쓰는 순수 Dart.
//
// "가장 좋은 행동" = 게임이 끝났을 때 내 점수의 평균이 가장 커지는 선택.
import 'dart:typed_data';

import 'yacht_dice.dart';
import 'yacht_fraction.dart';
import 'yacht_rules.dart';
import 'yacht_values.dart';

/// 지금 상황의 추천.
class YachtAdvice {
  YachtAdvice({
    required this.scoreNow,
    required this.valueNow,
    required this.bestCategory,
    required this.stopValue,
    required this.keep,
    required this.rollValue,
  });

  /// 칸마다, 지금 적으면 받는 점수.
  final List<int> scoreNow;

  /// 칸마다, 지금 적었을 때 "이번 점수 + 앞으로 더 얻을 점수의 평균". 이미 적은 칸은 null.
  final List<double?> valueNow;

  /// 지금 적는다면 가장 좋은 칸.
  final YachtCategory bestCategory;

  /// [bestCategory]에 적었을 때의 값.
  final double stopValue;

  /// 다시 굴리는 게 더 좋을 때 남길 주사위(눈별 개수). 지금 적는 게 좋거나 못 굴리면 null.
  final List<int>? keep;

  /// 가장 좋게 했을 때의 값 (다시 굴리는 게 좋으면 [stopValue]보다 크다).
  final double rollValue;

  /// 다시 굴리는 게 더 좋은가.
  bool get shouldRoll => keep != null;
}

/// 한 족보만 노렸을 때의 전망 (점수판 상태와 상관없다).
class YachtOutlook {
  YachtOutlook({required this.chance, required this.expected, required this.keep});

  /// 남은 굴림 안에 모양이 완성될 확률 (포카드~야추만. 나머지는 null).
  final double? chance;

  /// 이 칸의 점수만 노렸을 때 받을 점수의 평균.
  final double expected;

  /// 이 족보를 노릴 때 남길 주사위(눈별 개수).
  final List<int> keep;
}

/// 첫 굴림의 결과를 비슷한 것끼리 묶은 한 줄 ([YachtChanceBreakdown.groups]).
class YachtBreakdownGroup {
  const YachtBreakdownGroup({required this.done, required this.prob, required this.next});

  /// 이 결과면 바로 모양이 완성되었는가.
  final bool done;

  /// 첫 굴림이 이 묶음에 들어갈 확률.
  final YachtFrac prob;

  /// 이 묶음이 된 뒤 (남은 굴림으로) 끝내 완성될 확률. 바로 완성이면 1.
  final YachtFrac next;

  /// 이 묶음이 결국 완성에 보태는 확률 (= [prob] x [next]).
  YachtFrac get gain => prob * next;
}

/// 모양 족보 하나를 노릴 때 "완성 확률"이 어떻게 나왔는지의 풀이: 가장 좋은 주사위를 고정하고 굴린 첫 결과를
/// 묶음으로 나누고, 묶음마다 (다음 굴림까지 포함해) 완성될 확률을 곱해 더한 것.
class YachtChanceBreakdown {
  const YachtChanceBreakdown({required this.keep, required this.rolled, required this.rerollsLeft, required this.groups, required this.total});

  /// 고정할 주사위 (눈별 개수).
  final List<int> keep;

  /// 다시 굴리는 주사위 수.
  final int rolled;

  /// 지금 남은 굴림 횟수.
  final int rerollsLeft;

  /// 첫 굴림 결과의 묶음들: 바로 완성인 것 → 다음 굴림에서 완성될 가망이 큰 것 순서.
  final List<YachtBreakdownGroup> groups;

  /// 완성 확률 (정확한 분수).
  final YachtFrac total;

  /// 고정한 주사위의 눈들 (작은 것부터).
  List<int> get keptValues => [
        for (var f = 0; f < 6; f++)
          for (var k = 0; k < keep[f]; k++) f + 1,
      ];

  /// 첫 굴림 뒤에 한 번 더 굴려서 완성되는 갈래들 (바로 완성이 아니면서 가망이 있는 묶음).
  List<YachtBreakdownGroup> get later => [for (final g in groups) if (!g.done && g.next.num > 0) g];
}

class YachtAdvisor {
  YachtAdvisor(this.values);

  final YachtValues values;
  final YachtDiceTables _t = YachtDiceTables.instance;
  final YachtTurn _turn = YachtTurn();
  final Float64List _terminal = Float64List(YachtDiceTables.keepCount);

  /// 점수판 [card], 주사위 [dice](눈 5개), 다시 굴릴 기회 [rerollsLeft](0~2)에서의 추천.
  YachtAdvice advise({
    required YachtCard card,
    required List<int> dice,
    required int rerollsLeft,
  }) {
    final mask = card.filledMask;
    final upper = card.upperSum > kYachtBonusAt ? kYachtBonusAt : card.upperSum;
    for (final r in _t.rolls) {
      var best = double.negativeInfinity;
      for (var c = 0; c < kYachtSlots; c++) {
        if ((mask >> c) & 1 == 1) continue;
        final g = yachtGain(values, mask, upper, r, c);
        if (g > best) best = g;
      }
      _terminal[r] = best;
    }
    _turn.solve(_terminal);

    final roll = _t.indexOfDice(dice);
    final scoreNow = <int>[];
    final valueNow = <double?>[];
    var bestCategory = YachtCategory.ones;
    var stopValue = double.negativeInfinity;
    for (final c in YachtCategory.values) {
      scoreNow.add(_t.score[roll * kYachtSlots + c.index]);
      if (!card.isOpen(c)) {
        valueNow.add(null);
        continue;
      }
      final g = yachtGain(values, mask, upper, roll, c.index);
      valueNow.add(g);
      if (g > stopValue) {
        stopValue = g;
        bestCategory = c;
      }
    }

    List<int>? keep;
    var rollValue = stopValue;
    if (rerollsLeft > 0 && _turn.w[rerollsLeft][roll] > stopValue + 1e-9) {
      final k = _bestKeep(_turn.kv[rerollsLeft - 1], roll, allowAll: false);
      keep = List<int>.of(_t.counts[k]);
      rollValue = _turn.kv[rerollsLeft - 1][k];
    }
    return YachtAdvice(
      scoreNow: scoreNow,
      valueNow: valueNow,
      bestCategory: bestCategory,
      stopValue: stopValue,
      keep: keep,
      rollValue: rollValue,
    );
  }

  /// [roll]에서 남길 수 있는 경우 중 값이 가장 큰 것. 값이 같으면 많이 남기는 쪽.
  int _bestKeep(Float64List keepValue, int roll, {required bool allowAll}) {
    var best = -1;
    var bestValue = double.negativeInfinity;
    for (var i = _t.subStart[roll]; i < _t.subStart[roll + 1]; i++) {
      final k = _t.subKeep[i];
      if (!allowAll && k == roll) continue;
      final v = keepValue[k];
      if (v > bestValue + 1e-9 ||
          (v > bestValue - 1e-9 && best >= 0 && _t.size[k] > _t.size[best])) {
        best = k;
        bestValue = v;
      }
    }
    return best;
  }

  static final Map<int, YachtTurn> _aims = {};

  /// 한 족보만 노리는 계산 (0: 완성 확률, 1: 점수). 한 번 계산해 두고 다시 쓴다.
  YachtTurn _aim(YachtCategory c, int kind) {
    return _aims.putIfAbsent(c.index * 2 + kind, () {
      final terminal = Float64List(YachtDiceTables.keepCount);
      for (final r in _t.rolls) {
        final s = _t.score[r * kYachtSlots + c.index];
        terminal[r] = kind == 0 ? (s > 0 ? 1.0 : 0.0) : s.toDouble();
      }
      return YachtTurn()..solve(terminal);
    });
  }

  /// [c] 족보만 노렸을 때의 전망.
  YachtOutlook outlook(YachtCategory c, List<int> dice, int rerollsLeft) {
    final roll = _t.indexOfDice(dice);
    final byScore = _aim(c, 1);
    final byChance = c.isPattern ? _aim(c, 0) : null;
    final guide = byChance ?? byScore;
    final keep = rerollsLeft == 0
        ? roll
        : _bestKeep(guide.kv[rerollsLeft - 1], roll, allowAll: true);
    return YachtOutlook(
      chance: byChance?.w[rerollsLeft][roll],
      expected: byScore.w[rerollsLeft][roll],
      keep: List<int>.of(_t.counts[keep]),
    );
  }

  /// [c] 모양(포카드~야추 · 쓰리카드)을 노릴 때 완성 확률의 풀이. 굴릴 기회가 없으면 null.
  ///
  /// 가장 좋은 고정(이 족보를 가장 잘 노리는 주사위)으로 굴린 첫 결과들을 "바로 완성 / 다음 굴림에서 완성될 확률이 같은 것끼리"
  /// 묶고, 분수는 모두 정수로 세어 정확하게 계산한다.
  YachtChanceBreakdown? breakdown(YachtCategory c, List<int> dice, int rerollsLeft) {
    if (!c.isPattern || rerollsLeft <= 0) return null;
    const unit = 7776; // 6의 5제곱: 주사위 5개를 굴리는 경우의 수. 모든 확률을 이 분모로 센다
    final roll = _t.indexOfDice(dice);
    final guide = _aim(c, 0);
    final keep = _bestKeep(guide.kv[rerollsLeft - 1], roll, allowAll: true);
    final n = kYachtDice - _t.size[keep]; // 다시 굴리는 주사위 수
    var scale = 1; // 6^(5-n)
    for (var i = n; i < kYachtDice; i++) {
      scale *= 6;
    }
    var pow6n = 1;
    for (var i = 0; i < n; i++) {
      pow6n *= 6;
    }
    // (완성 여부, 다음 굴림에서 완성될 확률 x 7776) 별로 첫 굴림의 확률(x 7776)을 모은다
    final sums = <(bool, int), int>{};
    for (var i = _t.outStart[keep]; i < _t.outStart[keep + 1]; i++) {
      final o = _t.outTo[i];
      final p = (_t.outP[i] * pow6n).round() * scale; // 이 결과가 나올 확률 x 7776
      final done = _t.score[o * kYachtSlots + c.index] > 0;
      final q = done ? unit : (guide.w[rerollsLeft - 1][o] * unit).round(); // 이 결과 뒤 완성 확률 x 7776
      sums.update((done, q), (v) => v + p, ifAbsent: () => p);
    }
    final groups = [
      for (final e in sums.entries)
        YachtBreakdownGroup(done: e.key.$1, prob: YachtFrac(e.value, unit), next: YachtFrac(e.key.$2, unit)),
    ]..sort((a, b) {
        if (a.done != b.done) return a.done ? -1 : 1;
        return b.next.value.compareTo(a.next.value);
      });
    final total = groups.fold(YachtFrac.zero, (sum, g) => sum + g.gain);
    return YachtChanceBreakdown(keep: List<int>.of(_t.counts[keep]), rolled: n, rerollsLeft: rerollsLeft, groups: groups, total: total);
  }

  /// 풀이 [bd]의 첫 굴림 결과 중 묶음 [g]에 들어가는 것들을 모두 센다: 다시 굴린 주사위 [YachtChanceBreakdown.rolled]개의 눈을
  /// 순서대로 적은 목록이다 (주사위마다 6가지이니 전체는 6의 n제곱 가지를 하나씩 살펴 고른다). 개수는 확률의 분자가 된다.
  List<List<int>> outcomesOf(YachtCategory c, YachtChanceBreakdown bd, YachtBreakdownGroup g) {
    const unit = 7776;
    final guide = _aim(c, 0);
    final n = bd.rolled;
    final wantQ = g.next.num * (unit ~/ g.next.den);
    var total = 1;
    for (var i = 0; i < n; i++) {
      total *= 6;
    }
    final found = <List<int>>[];
    final counts = List<int>.of(bd.keep);
    for (var t = 0; t < total; t++) {
      final tuple = List<int>.filled(n, 0);
      var rest = t;
      for (var i = n - 1; i >= 0; i--) {
        tuple[i] = rest % 6 + 1;
        rest ~/= 6;
      }
      for (final v in tuple) {
        counts[v - 1]++;
      }
      final o = _t.indexOf(counts);
      for (final v in tuple) {
        counts[v - 1]--;
      }
      final done = _t.score[o * kYachtSlots + c.index] > 0;
      final q = done ? unit : (guide.w[bd.rerollsLeft - 1][o] * unit).round();
      if (done == g.done && q == wantQ) found.add(tuple);
    }
    return found;
  }

  /// 차례를 시작할 때(굴리기 전) [c] 모양이 3번 안에 완성될 확률. 모양 족보만.
  double chanceFromStart(YachtCategory c) => _aim(c, 0).start;

  /// 차례를 시작할 때 [c] 칸만 노리면 받을 점수의 평균.
  double expectedFromStart(YachtCategory c) => _aim(c, 1).start;
}

/// 눈별 개수 [keep]만큼 남기려면 [dice]의 어느 주사위를 잡아야 하는지.
/// [prefer](지금 잡고 있는 주사위)를 먼저 쓴다.
List<bool> yachtHoldsFor(List<int> dice, List<int> keep, {List<bool>? prefer}) {
  final left = List<int>.of(keep);
  final holds = List<bool>.filled(dice.length, false);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < dice.length; i++) {
      if (holds[i] || left[dice[i] - 1] == 0) continue;
      if (pass == 0 && !(prefer != null && prefer[i])) continue;
      holds[i] = true;
      left[dice[i] - 1]--;
    }
  }
  return holds;
}
