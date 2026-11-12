import '../../../core/game_speed.dart';
import '../core/yacht_game.dart';
import '../core/yacht_rules.dart';

/// 정산 한 줄의 종류.
enum YachtTallyKind { category, upperBonus, yahtzeeBonus }

/// 정산의 한 걸음: 점수판의 한 줄 (사람마다 받은 점수). 점수판의 줄 순서와 똑같다.
class YachtTallyStep {
  const YachtTallyStep(this.kind, this.values, {this.category});

  final YachtTallyKind kind;

  /// [kind]가 [YachtTallyKind.category]일 때 그 칸.
  final YachtCategory? category;

  /// 자리별로 합계에 더해지는 점수.
  final List<int> values;

  /// 더해지는 점수가 하나라도 있는가 (없으면 빨리 지나간다).
  bool get any => values.any((v) => v != 0);
}

/// 정산 화면의 한 순간.
class YachtTallyFrame {
  const YachtTallyFrame({required this.step, required this.fly, required this.shown});

  /// 지금 합계로 내려가고 있는 줄 번호 (맨 위가 0). 끝났으면 줄 수와 같다.
  final int step;

  /// 그 줄의 숫자가 합계까지 내려가는 정도 (0 = 제자리, 1 = 합계에 닿음). 내려가지 않는 순간은 null.
  final double? fly;

  /// 지금 합계 칸에 보이는 점수 (자리별).
  final List<int> shown;
}

/// 게임이 끝났을 때의 정산: 점수판 맨 윗줄부터 차례로, 그 줄의 점수가 합계로 내려와 더해진다.
/// 시간 계산만 하는 순수 Dart다 (화면은 [frameAt]으로 그 순간의 모습을 받아 그린다).
class YachtTally {
  /// [game]은 끝난 판. 시간은 "빠른 진행" 설정을 따른다.
  YachtTally(YachtGame game, {Duration Function(Duration)? scale}) : players = game.playerCount {
    final s = scale ?? GameSpeed.scale;
    final list = <YachtTallyStep>[];
    for (final cat in game.categories) {
      list.add(YachtTallyStep(YachtTallyKind.category, [for (final c in game.cards) c.scores[cat.index] ?? 0], category: cat));
      if (cat == YachtCategory.sixes) {
        list.add(YachtTallyStep(YachtTallyKind.upperBonus, [for (final c in game.cards) c.bonus])); // 숫자 칸 바로 아래
      }
    }
    if (!game.daesung) list.add(YachtTallyStep(YachtTallyKind.yahtzeeBonus, [for (final c in game.cards) c.yahtzeeBonusTotal])); // (대성One Rule엔 그 줄이 없다)
    steps = list;
    lead = s(leadTime);
    _stepTime = [for (final st in list) s(st.any ? valueStep : emptyStep)];
    var at = lead;
    _starts = [];
    for (final t in _stepTime) {
      _starts.add(at);
      at += t;
    }
    duration = at;
  }

  /// 점수가 있는 줄 · 점수가 없는 줄이 차지하는 시간.
  static const Duration valueStep = Duration(milliseconds: 1000);
  static const Duration emptyStep = Duration(milliseconds: 520);

  /// 시작하기 전에 합계 줄이 나타나기를 기다리는 시간.
  static const Duration leadTime = Duration(milliseconds: 600);

  /// 정산이 끝난 뒤 승자를 보여 주기 전에 잠깐 멈추는 시간.
  static const Duration holdTime = Duration(milliseconds: 600);

  /// 한 줄의 시간 중 숫자가 내려가는 데 쓰는 비율 (나머지는 합계가 올라가는 시간).
  ///
  /// 한 줄의 흐름: 줄이 먼저 빛나고 (0 ~ [litPart]) → 그 줄의 점수가 합계로 슉 내려오고 ([litPart] ~ [flyPart]) → 합계가 올라간다.
  /// 모든 자리가 같은 줄에서 같은 순간에 같이 움직인다 (0점인 자리도 "0"이 같이 내려온다).
  static const double litPart = 0.30;
  static const double flyPart = 0.72;

  final int players;
  late final List<YachtTallyStep> steps;
  late final Duration lead;
  late final List<Duration> _stepTime;
  late final List<Duration> _starts;

  /// 정산이 끝나기까지 걸리는 전체 시간.
  late final Duration duration;

  /// 자리별 최종 합계 (정산이 끝났을 때 합계 칸에 보이는 점수).
  List<int> get totals => [
        for (var seat = 0; seat < players; seat++) steps.fold(0, (sum, st) => sum + st.values[seat]),
      ];

  /// 시작한 지 [elapsed]가 지난 순간의 모습.
  YachtTallyFrame frameAt(Duration elapsed) {
    if (elapsed >= duration) return YachtTallyFrame(step: steps.length, fly: null, shown: totals);
    if (elapsed < lead) return YachtTallyFrame(step: -1, fly: null, shown: List<int>.filled(players, 0));
    var s = 0;
    while (s + 1 < steps.length && _starts[s + 1] <= elapsed) {
      s++;
    }
    final t = (elapsed - _starts[s]).inMicroseconds / _stepTime[s].inMicroseconds; // 이 줄 안에서 0~1
    final shown = List<int>.filled(players, 0);
    for (var seat = 0; seat < players; seat++) {
      var sum = 0;
      for (var k = 0; k < s; k++) {
        sum += steps[k].values[seat];
      }
      // 숫자가 합계에 닿은 뒤 그 줄의 점수만큼 합계가 올라간다
      final up = ((t - flyPart) / (1 - flyPart)).clamp(0.0, 1.0);
      sum += (steps[s].values[seat] * _easeOut(up)).round();
      shown[seat] = sum;
    }
    final fall = t >= litPart && t < flyPart ? (t - litPart) / (flyPart - litPart) : null; // 내려오는 동안만 0~1
    return YachtTallyFrame(step: s, fly: fall, shown: shown);
  }

  static double _easeOut(double x) => 1 - (1 - x) * (1 - x);
}
