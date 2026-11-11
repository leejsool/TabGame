// 야추 규칙: 족보 12개(쓰리카드를 켜면 13개)와 점수 계산. 화면 없이 쓰는 순수 Dart.
// 점수는 진짜 야추 점수표대로: 풀하우스 25 · 스몰 30 · 라지 40 · 야추 50, 야추를 또 굴리면 +100.
//
// 주사위 5개의 눈은 "눈별 개수"(길이 6, counts[0] = 1의 개수)로 다룬다.

/// 주사위 개수.
const int kYachtDice = 5;

/// 한 차례에 굴릴 수 있는 횟수 (처음 1번 + 다시 굴리기 2번).
const int kYachtRolls = 3;

/// 1~6 칸의 합이 이 점수 이상이면 보너스를 받는다.
const int kYachtBonusAt = 63;

/// 보너스 점수.
const int kYachtBonus = 35;

/// 풀하우스 · 스몰 스트레이트 · 라지 스트레이트 · 야추의 고정 점수.
const int kYachtFullHouse = 25;
const int kYachtSmallStraight = 30;
const int kYachtLargeStraight = 40;
const int kYachtYacht = 50;

/// 야추 칸에 50점을 적은 뒤 야추를 또 굴려 적을 때마다 받는 보너스.
const int kYachtYahtzeeBonus = 100;

/// 점수 칸의 종류 수 (쓰리카드 칸까지 센 것).
const int kYachtSlots = 13;

/// 족보(점수 칸). 번호([index])는 저장된 판 · 확률 표와 맞물리니 순서를 바꾸지 않는다
/// (그래서 나중에 생긴 쓰리카드가 맨 끝 12번이다). 점수판에 보이는 줄 순서는 [sheetOrder]다.
enum YachtCategory {
  ones('에이스', '1만 모두 더해요'),
  twos('듀스', '2만 모두 더해요'),
  threes('트레이', '3만 모두 더해요'),
  fours('포', '4만 모두 더해요'),
  fives('파이브', '5만 모두 더해요'),
  sixes('식스', '6만 모두 더해요'),
  choice('찬스', '눈 5개의 합'),
  fourKind('포카드', '같은 눈 4개 이상 → 눈 5개의 합'),
  fullHouse('풀하우스', '같은 눈 3개 + 2개 → 25점'),
  smallStraight('스몰 스트레이트', '이어진 눈 4개 → 30점'),
  largeStraight('라지 스트레이트', '이어진 눈 5개 → 40점'),
  yacht('야추', '같은 눈 5개 → 50점'),

  /// 시작 전에 켜야만 쓰는 칸 ([YachtGame.threeKind]).
  threeKind('쓰리카드', '같은 눈 3개 이상 → 눈 5개의 합');

  const YachtCategory(this.label, this.rule);

  /// 점수판에 쓰는 이름.
  final String label;

  /// 한 줄 설명.
  final String rule;

  /// 문장 속에서 부르는 이름.
  String get title => label;

  /// 점수판에서 이 칸 이름을 눌렀을 때 보여 주는 자세한 설명.
  String get help => switch (this) {
        ones => '1이 나온 주사위 눈의 총합 (최대 5점)',
        twos => '2가 나온 주사위 눈의 총합 (최대 10점)',
        threes => '3이 나온 주사위 눈의 총합 (최대 15점)',
        fours => '4가 나온 주사위 눈의 총합 (최대 20점)',
        fives => '5가 나온 주사위 눈의 총합 (최대 25점)',
        sixes => '6이 나온 주사위 눈의 총합 (최대 30점)',
        choice => '주사위 눈 5개의 총합 (최대 30점). 모양이 필요 없어서 애매한 주사위를 버리기 좋아요.',
        threeKind => '같은 눈이 3개 이상일 때 주사위 눈 5개의 총합 (최대 30점)',
        fourKind => '같은 눈이 4개 이상일 때 주사위 눈 5개의 총합 (최대 30점)',
        fullHouse => '같은 눈 3개와 같은 눈 2개로 묶을 수 있을 때 고정 25점',
        smallStraight => '이어지는 눈이 4개 이상일 때 고정 30점 (예: 1-2-3-4, 3-4-5-6)',
        largeStraight => '이어지는 눈이 5개일 때 고정 40점 (1-2-3-4-5 또는 2-3-4-5-6)',
        yacht => '같은 눈이 5개일 때 고정 50점. 이 칸에 50점을 적은 뒤 야추를 또 굴리면 보너스 100점!',
      };

  /// 1~6 칸(보너스에 들어가는 칸)인가.
  bool get isUpper => index < 6;

  /// 모양을 맞춰야 점수가 나는 칸인가 (포카드~야추, 쓰리카드). 이 칸들만 "완성 확률"이 있다.
  bool get isPattern => index >= YachtCategory.fourKind.index;

  /// 점수판의 줄 순서 (진짜 야추 점수표대로: 숫자 칸 → 쓰리카드 · 포카드 · 풀하우스 · 스트레이트 · 야추 → 찬스).
  static const List<YachtCategory> sheetOrder = [
    ones, twos, threes, fours, fives, sixes,
    threeKind, fourKind, fullHouse, smallStraight, largeStraight, yacht, choice,
  ];
}

/// 주사위 눈 목록(1~6)을 눈별 개수로 바꾼다.
List<int> yachtCounts(List<int> dice) {
  final counts = List<int>.filled(6, 0);
  for (final d in dice) {
    counts[d - 1]++;
  }
  return counts;
}

/// 눈별 개수 [counts]를 [c] 칸에 적으면 받는 점수.
int yachtScore(YachtCategory c, List<int> counts) {
  if (c.isUpper) return counts[c.index] * (c.index + 1);
  var sum = 0;
  var maxSame = 0;
  var hasThree = false;
  var hasTwo = false;
  var run = 0;
  var bestRun = 0;
  for (var i = 0; i < 6; i++) {
    final n = counts[i];
    sum += n * (i + 1);
    if (n > maxSame) maxSame = n;
    if (n == 3) hasThree = true;
    if (n == 2) hasTwo = true;
    run = n > 0 ? run + 1 : 0;
    if (run > bestRun) bestRun = run;
  }
  switch (c) {
    case YachtCategory.choice:
      return sum;
    case YachtCategory.threeKind:
      return maxSame >= 3 ? sum : 0;
    case YachtCategory.fourKind:
      return maxSame >= 4 ? sum : 0;
    case YachtCategory.fullHouse:
      return hasThree && hasTwo ? kYachtFullHouse : 0;
    case YachtCategory.smallStraight:
      return bestRun >= 4 ? kYachtSmallStraight : 0;
    case YachtCategory.largeStraight:
      return bestRun >= 5 ? kYachtLargeStraight : 0;
    case YachtCategory.yacht:
      return maxSame == 5 ? kYachtYacht : 0;
    default:
      return 0;
  }
}

/// 한 사람의 점수판.
class YachtCard {
  /// [threeKind]: 쓰리카드 칸을 쓰는 판인가. 안 쓰면 그 칸은 처음부터 닫혀 있다.
  YachtCard({this.threeKind = false}) : scores = List<int?>.filled(kYachtSlots, null);

  /// 보관한 점수에서. 쓰리카드가 없던 옛 보관본(12칸)도 읽는다.
  YachtCard.fromJson(List<dynamic> json, {this.threeKind = false})
      : scores = [for (final v in json) v as int?, for (var i = json.length; i < kYachtSlots; i++) null];

  final bool threeKind;

  /// 야추 보너스를 받은 횟수 (야추 칸에 50점을 적은 뒤 야추를 또 굴려 적을 때마다 +100).
  int yahtzeeBonuses = 0;

  /// 야추 보너스 점수 합.
  int get yahtzeeBonusTotal => yahtzeeBonuses * kYachtYahtzeeBonus;

  /// 칸별 점수 (칸 번호 순서). 아직 안 적은 칸 · 안 쓰는 칸은 null.
  final List<int?> scores;

  /// 이 판에서 쓰는 칸 수 (12 또는 13).
  int get slotCount => threeKind ? kYachtSlots : kYachtSlots - 1;

  /// 점수판에 보이는 칸들 (줄 순서대로).
  List<YachtCategory> get categories => [
        for (final c in YachtCategory.sheetOrder)
          if (threeKind || c != YachtCategory.threeKind) c,
      ];

  bool isOpen(YachtCategory c) => scores[c.index] == null && (threeKind || c != YachtCategory.threeKind);

  /// 1~6 칸에 적은 점수의 합.
  int get upperSum {
    var sum = 0;
    for (var i = 0; i < 6; i++) {
      sum += scores[i] ?? 0;
    }
    return sum;
  }

  /// 받은 보너스 (없으면 0).
  int get bonus => upperSum >= kYachtBonusAt ? kYachtBonus : 0;

  /// 지금까지의 총점 (보너스 포함).
  int get total {
    var sum = bonus + yahtzeeBonusTotal;
    for (final s in scores) {
      sum += s ?? 0;
    }
    return sum;
  }

  /// 적은 칸을 비트로 나타낸 값 (c.index 번째 비트). 안 쓰는 칸은 "이미 찬 칸"으로 센다 (확률 표가 그렇게 짜여 있다).
  int get filledMask {
    var mask = threeKind ? 0 : 1 << YachtCategory.threeKind.index;
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] != null) mask |= 1 << i;
    }
    return mask;
  }

  /// 쓰는 칸을 모두 적었는가.
  bool get full => filledMask == (1 << kYachtSlots) - 1;

  /// 적은 칸 수.
  int get filledCount => scores.where((s) => s != null).length;

  List<int?> toJson() => List<int?>.of(scores);
}
