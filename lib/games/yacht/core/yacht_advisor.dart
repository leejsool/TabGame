// 야추 길잡이: 지금 상황에서 족보별 확률과 가장 좋은 행동을 계산한다.
// 힌트 버튼, CPU, 교과학습이 함께 쓴다. 화면 없이 쓰는 순수 Dart.
//
// "가장 좋은 행동" = 게임이 끝났을 때 내 점수의 평균이 가장 커지는 선택.
import 'dart:typed_data';

import 'yacht_dice.dart';
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
      for (var c = 0; c < 12; c++) {
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
      scoreNow.add(_t.score[roll * 12 + c.index]);
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
        final s = _t.score[r * 12 + c.index];
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
