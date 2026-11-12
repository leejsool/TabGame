// 대성One Rule의 길잡이: 힌트와 CPU가 쓰는 "가장 좋은 행동"과 족보별 전망. 화면 없이 쓰는 순수 Dart.
//
// 남길 주사위(keep)는 길이 7: 0~5번은 보통 주사위의 눈별 개수, 6번은 대성One 주사위를 남기면 1.
import 'dart:typed_data';

import 'yacht_advisor.dart';
import 'yacht_daesung.dart';
import 'yacht_daesung_dice.dart';
import 'yacht_daesung_values.dart';
import 'yacht_dice.dart';
import 'yacht_rules.dart';

class YachtDaesungAdvisor implements YachtBrain {
  YachtDaesungAdvisor(this.values);

  final YachtDaesungValues values;
  final YachtDaesungTables _t = YachtDaesungTables.instance;
  late final YachtTurn _turn = YachtTurn(_t);
  late final Float64List _terminal = Float64List(_t.keeps);

  @override
  bool get explains => false;

  @override
  bool isPattern(YachtCategory c) =>
      c == YachtCategory.fullHouse || c == YachtCategory.largeStraight || c == YachtCategory.yacht;

  List<int> _keepList(int k) => [..._t.norms[_t.normOf(k)], _t.greenOf(k) > 0 ? 1 : 0];

  @override
  YachtAdvice advise({required YachtCard card, required List<int> dice, required int rerollsLeft}) {
    final mask = daesungMask(card);
    final upper = card.upperSum > kDaesungBonusAt ? kDaesungBonusAt : card.upperSum;
    for (final r in _t.rolls) {
      var best = double.negativeInfinity;
      for (var i = 0; i < kDaesungCategories.length; i++) {
        if ((mask >> i) & 1 == 1) continue;
        final g = daesungGain(values.at, mask, upper, r, i);
        if (g > best) best = g;
      }
      _terminal[r] = best;
    }
    _turn.solve(_terminal);

    final roll = _t.indexOfDice(dice);
    final scoreNow = <int>[];
    final valueNow = <double?>[];
    var bestCategory = kDaesungCategories.firstWhere(card.isOpen, orElse: () => YachtCategory.ones);
    var stopValue = double.negativeInfinity;
    for (final c in YachtCategory.values) {
      scoreNow.add(_t.score[roll * kYachtSlots + c.index]);
      final i = kDaesungCategories.indexOf(c);
      if (i < 0 || !card.isOpen(c)) {
        valueNow.add(null);
        continue;
      }
      final g = daesungGain(values.at, mask, upper, roll, i);
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
      keep = _keepList(k);
      rollValue = _turn.kv[rerollsLeft - 1][k];
    }
    return YachtAdvice(scoreNow: scoreNow, valueNow: valueNow, bestCategory: bestCategory, stopValue: stopValue, keep: keep, rollValue: rollValue);
  }

  /// [roll]에서 남길 수 있는 경우 중 값이 가장 큰 것. 값이 같으면 많이 남기는 쪽.
  int _bestKeep(Float64List keepValue, int roll, {required bool allowAll}) {
    var best = -1;
    var bestValue = double.negativeInfinity;
    for (var i = _t.subStart[roll]; i < _t.subStart[roll + 1]; i++) {
      final k = _t.subKeep[i];
      if (!allowAll && k == roll) continue;
      final v = keepValue[k];
      if (v > bestValue + 1e-9 || (v > bestValue - 1e-9 && best >= 0 && _t.sizeOf(k) > _t.sizeOf(best))) {
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
      final terminal = Float64List(_t.keeps);
      for (final r in _t.rolls) {
        final s = _t.score[r * kYachtSlots + c.index];
        terminal[r] = kind == 0 ? (s > 0 ? 1.0 : 0.0) : s.toDouble();
      }
      return YachtTurn(_t)..solve(terminal);
    });
  }

  @override
  YachtOutlook outlook(YachtCategory c, List<int> dice, int rerollsLeft) {
    final roll = _t.indexOfDice(dice);
    final byScore = _aim(c, 1);
    final byChance = isPattern(c) ? _aim(c, 0) : null;
    final guide = byChance ?? byScore;
    final keep = rerollsLeft == 0 ? roll : _bestKeep(guide.kv[rerollsLeft - 1], roll, allowAll: true);
    return YachtOutlook(chance: byChance?.w[rerollsLeft][roll], expected: byScore.w[rerollsLeft][roll], keep: _keepList(keep));
  }

  /// 차례를 시작할 때 [c] 모양이 3번 안에 완성될 확률.
  double chanceFromStart(YachtCategory c) => _aim(c, 0).start;

  @override
  double expectedFromStart(YachtCategory c) => _aim(c, 1).start;

  @override
  List<bool> holdsFor(List<int> dice, List<int> keep, {List<bool>? prefer}) {
    final holds = List<bool>.filled(dice.length, false);
    holds[kDaesungDie] = keep.length > 6 && keep[6] > 0;
    final left = List<int>.of(keep.take(6));
    // 지금 잡고 있는 보통 주사위를 먼저 쓴다
    for (final pass in [true, false]) {
      for (var i = 0; i < dice.length; i++) {
        if (i == kDaesungDie || holds[i]) continue;
        if (pass && !(prefer?[i] ?? false)) continue;
        final f = dice[i] - 1;
        if (left[f] > 0) {
          left[f]--;
          holds[i] = true;
        }
      }
    }
    return holds;
  }
}
