// 야추 한 판의 진행: 사람 수만큼의 점수판, 차례, 주사위. 화면 없이 쓰는 순수 Dart.
import 'dart:math';

import 'yacht_rules.dart';

class YachtGame {
  /// [first]: 먼저 시작하는 사람. [threeKind]: 쓰리카드 칸을 넣고 하는 판.
  YachtGame({required this.playerCount, int first = 0, bool threeKind = false, this.daesung = false})
      : assert(playerCount >= 1 && playerCount <= 4),
        threeKind = threeKind && !daesung,
        cards = [for (var i = 0; i < playerCount; i++) YachtCard(threeKind: threeKind, daesung: daesung)],
        turn = first % playerCount;

  YachtGame.fromJson(Map<String, dynamic> json)
      : playerCount = (json['cards'] as List).length,
        threeKind = json['three'] == true && json['ds'] != true,
        daesung = json['ds'] == true,
        cards = [
          for (final c in json['cards'] as List) YachtCard.fromJson(c as List, threeKind: json['three'] == true, daesung: json['ds'] == true),
        ] {
    final yb = json['yb'];
    if (yb is List) {
      for (var i = 0; i < cards.length && i < yb.length; i++) {
        cards[i].yahtzeeBonuses = yb[i] as int;
      }
    }
    turn = json['turn'] as int;
    rollsUsed = json['rolls'] as int;
    dice.setAll(0, (json['dice'] as List).cast<int>());
    held.setAll(0, (json['held'] as List).cast<bool>());
  }

  final int playerCount;

  /// 쓰리카드 칸을 넣고 하는 판인가 (시작 전에 정한다).
  final bool threeKind;

  /// 대성One Rule 판인가 (0번 주사위가 만능 대성One. yacht_daesung.dart).
  final bool daesung;

  /// 이 판에서 쓰는 칸들 (점수판 줄 순서).
  List<YachtCategory> get categories => cards.first.categories;

  /// 사람별 점수판.
  final List<YachtCard> cards;

  /// 지금 차례인 사람 (0부터).
  int turn = 0;

  /// 이번 차례에 굴린 횟수 (0~3).
  int rollsUsed = 0;

  /// 주사위 눈 5개. 아직 안 굴렸으면 0.
  final List<int> dice = List<int>.filled(kYachtDice, 0);

  /// 잡아 둔(다시 안 굴리는) 주사위.
  final List<bool> held = List<bool>.filled(kYachtDice, false);

  YachtCard get card => cards[turn];

  /// 다시 굴릴 수 있는 남은 횟수.
  int get rollsLeft => kYachtRolls - rollsUsed;

  /// 모든 사람이 쓰는 칸을 다 적었는가.
  bool get over => cards.every((c) => c.full);

  /// 라운드 수 (= 쓰는 칸 수: 12 또는 13).
  int get rounds => card.slotCount;

  /// 몇 번째 라운드인가 (1~[rounds]).
  int get round => min(card.filledCount + 1, rounds);

  bool get canRoll => !over && rollsLeft > 0 && !(rollsUsed > 0 && held.every((h) => h));

  /// 한 번이라도 굴려야 주사위를 잡거나 점수를 적을 수 있다.
  bool get canHold => !over && rollsUsed > 0 && rollsLeft > 0;

  bool canScore(YachtCategory c) => !over && rollsUsed > 0 && card.isOpen(c);

  /// 잡지 않은 주사위를 굴린다. 새 주사위 눈을 돌려준다 (다른 기기에 보낼 때 쓴다).
  List<int> roll(Random rng) {
    final next = nextRoll(rng);
    applyRoll(next);
    return next;
  }

  /// 지금 굴리면 나올 눈을 미리 정한다 (구르는 모습을 보여 준 뒤 [applyRoll]로 적용한다).
  List<int> nextRoll(Random rng) => [
        for (var i = 0; i < kYachtDice; i++)
          rollsUsed > 0 && held[i] ? dice[i] : rng.nextInt(6) + 1,
      ];

  /// 굴린 결과 [values]를 그대로 받아 적용한다 (다른 기기가 굴린 결과).
  void applyRoll(List<int> values) {
    if (!canRoll) throw StateError('지금은 굴릴 수 없다');
    dice.setAll(0, values);
    rollsUsed++;
  }

  void toggleHold(int i) {
    if (!canHold) return;
    held[i] = !held[i];
  }

  void setHolds(List<bool> holds) {
    if (!canHold) return;
    held.setAll(0, holds);
  }

  /// [c] 칸에 지금 주사위의 점수를 적고 다음 사람에게 넘긴다. 적은 점수를 돌려준다.
  int score(YachtCategory c) {
    if (!canScore(c)) throw StateError('이 칸에는 적을 수 없다');
    final counts = yachtCounts(dice);
    final s = card.scoreOf(c, dice);
    // 야추 칸에 50점을 적어 둔 사람이 야추를 또 굴려 어느 칸에든 적으면 보너스 100점 (대성One Rule에는 없다)
    if (!daesung && counts.contains(kYachtDice) && card.scores[YachtCategory.yacht.index] == kYachtYacht) card.yahtzeeBonuses++;
    card.scores[c.index] = s;
    dice.fillRange(0, kYachtDice, 0);
    held.fillRange(0, kYachtDice, false);
    rollsUsed = 0;
    if (!over) turn = (turn + 1) % playerCount;
    return s;
  }

  /// 총점이 가장 높은 사람(들). 동점이면 여러 명.
  List<int> get winners {
    final best = cards.map((c) => c.total).reduce(max);
    return [
      for (var i = 0; i < playerCount; i++)
        if (cards[i].total == best) i,
    ];
  }

  Map<String, dynamic> toJson() => {
        'cards': [for (final c in cards) c.toJson()],
        if (threeKind) 'three': true,
        if (daesung) 'ds': true,
        if (cards.any((c) => c.yahtzeeBonuses > 0)) 'yb': [for (final c in cards) c.yahtzeeBonuses],
        'turn': turn,
        'rolls': rollsUsed,
        'dice': List<int>.of(dice),
        'held': List<bool>.of(held),
      };
}
