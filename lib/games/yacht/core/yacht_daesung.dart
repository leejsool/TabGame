// 야추 "대성One Rule": 트릭컬 리바이브의 '트릭 다이스'(세계 게임전집 51 규칙 바탕)를 따른 변형 규칙. 화면 없이 쓰는 순수 Dart.
//
// - 주사위 5개 중 하나(0번 주사위)가 초록색 "대성One" 주사위다. 이 주사위의 1(학교 로고)은 어떤 눈이든 될 수 있다(만능).
// - 칸: 원즈 · 듀스 · 트레이 · 포 · 파이브 · 식스 · 찬스 · 풀하우스 · 라지 스트레이트 · 야추 (포카드 · 스몰 스트레이트 · 쓰리카드 없음).
// - 원즈: 1의 합. 단, 1 네 개 + 대성One이면 고정 70점.
// - 찬스 · 풀하우스: 눈 5개의 합 (풀하우스는 같은 눈 3개 + 다른 같은 눈 2개).
// - 라지 스트레이트 30점, 야추 50점. 야추 보너스(+100)는 없다.
// - 숫자 칸(원즈~식스)의 합이 55 이상이면 보너스 40점.
// 만능 눈은 칸마다 가장 점수가 높아지는 눈으로 저절로 정한다.
import 'yacht_rules.dart';

/// 대성One 주사위의 자리 (게임의 주사위 목록에서 0번).
const int kDaesungDie = 0;

/// 숫자 칸 보너스 기준과 점수.
const int kDaesungBonusAt = 55;
const int kDaesungBonus = 40;

/// 원즈의 특별 점수 (1 네 개 + 대성One).
const int kDaesungOnes = 70;

/// 라지 스트레이트 · 야추 점수.
const int kDaesungLargeStraight = 30;
const int kDaesungYacht = 50;

/// 대성One Rule에서 쓰는 칸 (확률 표의 칸 번호 순서이기도 하다: i번 칸 = i번 비트).
const List<YachtCategory> kDaesungCategories = [
  YachtCategory.ones,
  YachtCategory.twos,
  YachtCategory.threes,
  YachtCategory.fours,
  YachtCategory.fives,
  YachtCategory.sixes,
  YachtCategory.choice,
  YachtCategory.fullHouse,
  YachtCategory.largeStraight,
  YachtCategory.yacht,
];

/// 대성One Rule에서 쓰는 칸인가.
bool daesungUses(YachtCategory c) => kDaesungCategories.contains(c);

/// 눈별 개수 [counts](만능 없이 정해진 눈)로 [c] 칸에 적는 점수 (세계 게임전집 51 방식).
int _plainScore(YachtCategory c, List<int> counts) {
  if (c.isUpper) return counts[c.index] * (c.index + 1);
  var sum = 0, maxSame = 0, run = 0, bestRun = 0;
  var hasThree = false, hasTwo = false;
  for (var i = 0; i < 6; i++) {
    final n = counts[i];
    sum += n * (i + 1);
    if (n > maxSame) maxSame = n;
    if (n == 3) hasThree = true;
    if (n == 2) hasTwo = true;
    run = n > 0 ? run + 1 : 0;
    if (run > bestRun) bestRun = run;
  }
  return switch (c) {
    YachtCategory.choice => sum,
    YachtCategory.fullHouse => hasThree && hasTwo ? sum : 0,
    YachtCategory.largeStraight => bestRun >= 5 ? kDaesungLargeStraight : 0,
    YachtCategory.yacht => maxSame == 5 ? kDaesungYacht : 0,
    _ => 0,
  };
}

/// 대성One 주사위의 눈 [green]과 나머지 주사위 4개의 눈별 개수 [others]로 [c] 칸에 적는 점수.
/// [green]이 1(로고)이면 만능: 1~6 중 가장 높은 점수가 나오는 눈으로 본다.
int daesungScoreParts(YachtCategory c, int green, List<int> others) {
  if (!daesungUses(c)) return 0;
  final counts = List<int>.of(others);
  if (green != 1) {
    counts[green - 1]++;
    return _plainScore(c, counts);
  }
  // 원즈: 1 네 개 + 대성One이면 70점
  if (c == YachtCategory.ones && others[0] == 4) return kDaesungOnes;
  var best = 0;
  for (var v = 0; v < 6; v++) {
    counts[v]++;
    final s = _plainScore(c, counts);
    if (s > best) best = s;
    counts[v]--;
  }
  return best;
}

/// 주사위 눈 5개 [dice](0번이 대성One)로 [c] 칸에 적는 점수.
int daesungScore(YachtCategory c, List<int> dice) {
  final others = List<int>.filled(6, 0);
  for (var i = 0; i < dice.length; i++) {
    if (i != kDaesungDie) others[dice[i] - 1]++;
  }
  return daesungScoreParts(c, dice[kDaesungDie], others);
}

/// 대성One Rule에서 칸의 이름 (1 칸은 "원즈").
String daesungLabel(YachtCategory c) => c == YachtCategory.ones ? '원즈' : c.label;

/// 대성One Rule에서 칸의 한 줄 설명.
String daesungRule(YachtCategory c) => switch (c) {
      YachtCategory.ones => '1만 더해요 · 1 네 개 + 대성One → 70점',
      YachtCategory.fullHouse => '같은 눈 3개 + 2개 → 눈 5개의 합',
      YachtCategory.largeStraight => '이어진 눈 5개 → 30점',
      YachtCategory.yacht => '같은 눈 5개 → 50점',
      _ => c.rule,
    };

/// 대성One Rule에서 칸 이름을 눌렀을 때의 자세한 설명.
String daesungHelp(YachtCategory c) => switch (c) {
      YachtCategory.ones => '1이 나온 주사위 눈의 총합. 단, 1 네 개와 대성One(로고)이 함께 나오면 고정 70점!',
      YachtCategory.choice => '주사위 눈 5개의 총합 (최대 30점). 대성One은 6으로 셉니다.',
      YachtCategory.fullHouse => '같은 눈 3개와 다른 같은 눈 2개로 묶을 수 있을 때 주사위 눈 5개의 총합 (최대 28점)',
      YachtCategory.largeStraight => '이어지는 눈이 5개일 때 고정 30점 (1-2-3-4-5 또는 2-3-4-5-6)',
      YachtCategory.yacht => '같은 눈이 5개일 때 고정 50점',
      _ => c.help,
    } +
    (c.isUpper || c == YachtCategory.choice ? '' : '\n대성One(로고)은 가장 점수가 높아지는 눈으로 쳐요.');

/// 규칙 설명 창에 보여 줄 줄들.
const List<String> kDaesungRuleLines = [
  '주사위 5개 중 초록색 주사위 하나가 "대성One" 주사위예요. 이 주사위의 1 자리에는 학교 로고가 있어요.',
  '로고가 나오면 만능! 1~6 중 어떤 눈이든 될 수 있어요. 칸마다 가장 점수가 높아지는 눈으로 저절로 쳐요.',
  '포카드 · 스몰 스트레이트 칸은 없어요. 1 칸의 이름은 "원즈"예요.',
  '원즈: 1의 합. 그런데 1 네 개 + 대성One이 함께 나오면 고정 70점!',
  '찬스 · 풀하우스는 눈 5개의 합, 라지 스트레이트 30점, 야추 50점이에요.',
  '숫자 칸(원즈~식스)의 합이 55점 이상이면 보너스 40점. (야추 보너스 +100은 없어요.)',
];
