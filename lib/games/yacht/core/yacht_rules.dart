// 야추 규칙: 족보 12개와 점수 계산. 화면 없이 쓰는 순수 Dart.
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

/// 족보(점수 칸) 12개. 순서가 곧 점수판의 줄 순서다.
enum YachtCategory {
  ones('1', '1만 모두 더해요'),
  twos('2', '2만 모두 더해요'),
  threes('3', '3만 모두 더해요'),
  fours('4', '4만 모두 더해요'),
  fives('5', '5만 모두 더해요'),
  sixes('6', '6만 모두 더해요'),
  choice('초이스', '눈 5개의 합'),
  fourKind('포카드', '같은 눈 4개 → 눈 5개의 합'),
  fullHouse('풀하우스', '같은 눈 3개 + 2개 → 눈 5개의 합'),
  smallStraight('스몰 스트레이트', '이어진 눈 4개 → 15점'),
  largeStraight('라지 스트레이트', '이어진 눈 5개 → 30점'),
  yacht('야추', '같은 눈 5개 → 50점');

  const YachtCategory(this.label, this.rule);

  /// 점수판에 쓰는 이름.
  final String label;

  /// 한 줄 설명.
  final String rule;

  /// 문장 속에서 부르는 이름 (숫자 칸은 "숫자 1"처럼).
  String get title => isUpper ? '숫자 $label' : label;

  /// 1~6 칸(보너스에 들어가는 칸)인가.
  bool get isUpper => index < 6;

  /// 모양을 맞춰야 점수가 나는 칸인가 (포카드~야추). 이 칸들만 "완성 확률"이 있다.
  bool get isPattern => index >= YachtCategory.fourKind.index;
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
    case YachtCategory.fourKind:
      return maxSame >= 4 ? sum : 0;
    case YachtCategory.fullHouse:
      return hasThree && hasTwo ? sum : 0;
    case YachtCategory.smallStraight:
      return bestRun >= 4 ? 15 : 0;
    case YachtCategory.largeStraight:
      return bestRun >= 5 ? 30 : 0;
    case YachtCategory.yacht:
      return maxSame == 5 ? 50 : 0;
    default:
      return 0;
  }
}

/// 한 사람의 점수판.
class YachtCard {
  YachtCard() : scores = List<int?>.filled(YachtCategory.values.length, null);

  YachtCard.fromJson(List<dynamic> json)
      : scores = [for (final v in json) v as int?];

  /// 칸별 점수. 아직 안 적은 칸은 null.
  final List<int?> scores;

  bool isOpen(YachtCategory c) => scores[c.index] == null;

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
    var sum = bonus;
    for (final s in scores) {
      sum += s ?? 0;
    }
    return sum;
  }

  /// 적은 칸을 비트로 나타낸 값 (c.index 번째 비트).
  int get filledMask {
    var mask = 0;
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] != null) mask |= 1 << i;
    }
    return mask;
  }

  /// 12칸을 모두 적었는가.
  bool get full => !scores.contains(null);

  List<int?> toJson() => List<int?>.of(scores);
}
