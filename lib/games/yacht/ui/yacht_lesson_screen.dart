import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import 'yacht_lesson_parts.dart';
import 'yacht_lesson_widgets.dart';
import 'yacht_look.dart';

/// 야추 "교과학습": 확률의 뜻 → 여사건 → 두 번 굴릴 기회(곱셈·독립) → 도박사의 오류 → 조건부 확률 → 기댓값.
class YachtLessonScreen extends StatelessWidget {
  const YachtLessonScreen({super.key});

  static final List<LessonUnit> units = [
    LessonUnit(title: '확률이란?', subtitle: '그 일의 경우의 수 ÷ 모든 경우의 수', icon: Icons.casino_rounded, build: _unitBasic),
    LessonUnit(title: '여사건의 확률', subtitle: '"적어도 하나"는 반대로 세요', icon: Icons.flip_rounded, build: _unitComplement),
    LessonUnit(title: '다시 굴릴 기회가 두 번', subtitle: '곱하고 더하기 · 독립', icon: Icons.account_tree_rounded, build: _unitTwice),
    LessonUnit(title: '도박사의 오류', subtitle: '"이번엔 나올 차례야!"는 착각', icon: Icons.psychology_alt_rounded, build: _unitGambler),
    LessonUnit(title: '조건부 확률', subtitle: '아는 사실이 생기면 확률이 바뀌어요', icon: Icons.filter_alt_rounded, build: _unitConditional),
    LessonUnit(title: '기댓값', subtitle: '평균적으로 몇 점? 힌트의 비밀', icon: Icons.balance_rounded, build: _unitExpected),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: kYachtColor,
      heroArt: const Center(child: YachtDie(value: 6, size: 62)),
      heroText: '주사위 게임은 확률 놀이예요!\n"이 주사위를 다시 굴릴까?"를 고민하면서 여사건, 조건부 확률, 기댓값을 배워 봐요.',
      units: units,
    );
  }
}

Future<void> openYachtLesson(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const YachtLessonScreen()));

bool _six(int a, int b) => a == 6 || b == 6;

final _basicEvents = [
  YachtLessonEvent('합이 7', (a, b) => a + b == 7),
  YachtLessonEvent('6이 적어도 하나', _six),
  YachtLessonEvent('같은 눈 (더블)', (a, b) => a == b),
  YachtLessonEvent('둘 다 6', (a, b) => a == 6 && b == 6),
  YachtLessonEvent('합이 10 이상', (a, b) => a + b >= 10),
];

// ───────────────────────── 단원 내용 ─────────────────────────

List<Widget> _unitBasic(BuildContext context) => [
  lessonP('주사위 하나를 굴리면 1부터 6까지 여섯 가지 눈이 똑같이 잘 나와요. 그러니 6이 나올 확률은 6가지 중 1가지, 1/6이에요.'),
  lessonKey(context, '확률 = (그 일이 일어나는 경우의 수) ÷ (모든 경우의 수)\n(단, 모든 경우가 똑같이 잘 일어날 때)', icon: Icons.functions_rounded),
  lessonH(context, '주사위 두 개는 36가지'),
  richP('주사위 ①과 ②를 함께 굴리면 ①이 6가지, 그 각각에 ②가 6가지라서 6 × 6 = 36가지예요. '
      '이때 (1,6)과 (6,1)은 서로 다른 경우예요. 두 주사위의 색이 다르다고 생각하면 쉬워요.'),
  lessonP('아래에서 "알고 싶은 일"을 골라 칸을 세어 보세요.'),
  TwoDiceExplorer(events: _basicEvents),
  lessonBullets(context, [
    '합이 2인 경우는 (1,1) 1가지뿐이지만, 합이 7인 경우는 6가지라서 7이 가장 잘 나와요.',
    '"6이 적어도 하나"는 11칸이에요. 6 + 6 = 12가 아니에요! (6,6)을 두 번 세면 안 되거든요.',
  ]),
  lessonH(context, '주사위 다섯 개는 7776가지'),
  lessonP('야추에서는 주사위 5개를 굴리니 6 × 6 × 6 × 6 × 6 = 7776가지예요.'),
  lessonBullets(context, [
    '첫 굴림에 바로 야추: 같은 눈 5개는 1·1·1·1·1부터 6·6·6·6·6까지 6가지 → 6/7776 = 1/1296',
    '첫 굴림에 바로 라지 스트레이트: 1-2-3-4-5 또는 2-3-4-5-6, 각각 5개를 늘어놓는 순서가 5! = 120가지 → 240/7776 = 5/162 (약 3.1%)',
  ]),
  lessonP('게임에서 "힌트"를 누르면 족보마다 완성될 확률이 분수로 나와요. 분수를 누르면 경우를 하나씩 센 풀이도 볼 수 있어요.'),
];

List<Widget> _unitComplement(BuildContext context) => [
  lessonP('주사위 3개를 다시 굴릴 때 6이 적어도 하나 나올 확률은 얼마일까요?'),
  lessonP('바로 세려면 "6이 1개인 경우, 2개인 경우, 3개인 경우"를 따로따로 세서 더해야 해서 복잡해요.'),
  lessonH(context, '반대로 세기'),
  lessonP('"적어도 하나 나온다"의 반대는 "하나도 안 나온다"예요. 하나도 안 나오려면 주사위마다 1~5 중 하나가 나와야 하니 5 × 5 × 5 = 125가지예요.'),
  lessonBullets(context, [
    '모든 경우: 6 × 6 × 6 = 216가지',
    '하나도 안 나올 확률: 125/216',
    '적어도 하나 나올 확률: 1 - 125/216 = 91/216 (약 42%)',
  ]),
  lessonKey(context, '여사건의 확률: (A가 일어나지 않을 확률) = 1 - (A가 일어날 확률)\n"적어도 하나"가 나오면 "하나도 없음"을 먼저 구해서 1에서 빼요.', icon: Icons.flip_rounded),
  lessonH(context, '해 보기'),
  lessonP('주사위 수를 바꿔 보세요. 주사위가 많아질수록 6이 적어도 하나 나올 확률은 커지지만, 100%가 되지는 않아요.'),
  const AtLeastOneExplorer(),
  lessonH(context, '자주 하는 실수'),
  lessonP('"주사위 하나에 1/6이니까 3개면 3/6 = 1/2"이라고 더하면 안 돼요. 그렇게 더하면 주사위 6개일 때 6/6 = 1, 즉 반드시 나온다는 말이 되는데, 실제로는 약 67%뿐이에요. '
      '더하기는 "6이 두 개 이상 나오는 경우"를 여러 번 세기 때문이에요.'),
  lessonP('게임의 힌트에서 분수를 누르면 "다른 방법: 반대로 세기"로 이 풀이가 나올 때가 있어요.'),
];

List<Widget> _unitTwice(BuildContext context) => [
  lessonP('같은 눈 4개(3·3·3·3)를 고정했고, 다시 굴릴 기회가 2번 남았어요. 남은 주사위 1개로 3을 만들어 야추가 될 확률은?'),
  lessonH(context, '방법 1: 나뭇가지로 나눠 세기'),
  const RerollTree(),
  lessonBullets(context, [
    '1번째에 바로 3이 나오면 야추예요: 1/6 (= 6/36)',
    '1번째에 안 나오고(5/6) 2번째에 나오면(1/6): 두 일이 연달아 일어나니 곱해요 → 5/6 × 1/6 = 5/36',
    '두 길은 겹치지 않으니 더해요: 6/36 + 5/36 = 11/36 (약 31%)',
  ]),
  lessonH(context, '방법 2: 여사건'),
  lessonP('야추가 안 되려면 두 번 모두 3이 아니어야 해요: 5/6 × 5/6 = 25/36. 그러니 야추가 될 확률은 1 - 25/36 = 11/36. 똑같죠?'),
  lessonKey(context, '연달아 일어나는 일의 확률은 곱하고, 겹치지 않는 경우들의 확률은 더해요.', icon: Icons.account_tree_rounded),
  lessonH(context, '주사위는 기억이 없어요 (독립)'),
  lessonP('첫 번째에 3이 안 나왔다고 두 번째에 3이 나올 확률이 커지지는 않아요. 언제 굴려도 1/6이에요. '
      '앞의 결과가 뒤의 확률에 영향을 주지 않는 것을 "독립"이라고 해요. 그래서 5/6 × 1/6처럼 그냥 곱할 수 있었어요.'),
  lessonH(context, '더 알아보기: 같은 눈 3개라면?'),
  lessonP('같은 눈 3개를 고정하고 2개를 두 번까지 다시 굴리면? 다시 굴리는 두 주사위가 "두 번 안에 3이 되는" 일은 서로 독립이고, 각각 11/36이에요.'),
  lessonP('그래서 둘 다 3이 될 확률은 11/36 × 11/36 = 121/1296 (약 9.3%)이에요. 게임의 힌트 창은 이렇게 경우를 나눠 곱하고 더하는 방법으로 확률을 계산해요.'),
];

List<Widget> _unitGambler(BuildContext context) => [
  lessonP('야추를 하다 보면 이런 생각이 들 때가 있어요.'),
  lessonBullets(context, [
    '"6이 다섯 번이나 안 나왔으니까, 이번엔 6이 나올 차례야!"',
    '"방금 야추가 나왔으니까, 한동안은 안 나오겠지."',
  ]),
  lessonP('둘 다 착각이에요. 이런 착각을 "도박사의 오류"라고 해요. 카지노에서 룰렛이 빨강만 계속 나오자 "이제 검정이 나올 차례"라며 큰돈을 걸었다가 잃은 사람들 이야기에서 나온 이름이에요.'),
  lessonH(context, '왜 착각일까?'),
  lessonBullets(context, [
    '주사위는 앞에서 무엇이 나왔는지 기억하지 못해요. 굴릴 때마다 6이 나올 확률은 언제나 1/6이에요 (독립).',
    '"많이 굴리면 6이 1/6쯤 나온다"는 말은 맞아요. 하지만 그건 모자란 만큼 나중에 더 나와서 맞춰지는 게 아니에요. 굴린 횟수가 아주 많아지면 앞의 작은 차이가 묻혀서 비율이 1/6에 가까워지는 거예요.',
    '그러니 "오래 안 나왔다"는 사실은 다음 굴림에 아무 도움이 안 돼요.',
  ]),
  lessonH(context, '실험해 보기'),
  lessonP('주사위를 아주 많이 굴려서, 6이 5번 연속으로 안 나온 바로 다음 굴림만 모아 봐요. 그때 6이 나온 비율이 정말 더 높을까요?'),
  const StreakSimulator(),
  lessonKey(context, '앞의 결과가 다음 결과에 영향을 주지 않는 일(독립)에서는, "이번엔 나올 차례"라는 건 없어요. 확률은 언제나 같아요.', icon: Icons.psychology_alt_rounded),
  lessonH(context, '반대로 착각하는 경우도 있어요'),
  lessonP('"요즘 6이 잘 나오니까 이 주사위는 6이 잘 나오는 주사위야!"도 마찬가지예요. 몇 번 잘 나온 건 우연일 수 있어요. 정말 그런지 알려면 아주 많이 굴려 봐야 해요.'),
  lessonP('그런데 카드 게임은 달라요! 카드는 한 번 뽑으면 다시 안 넣으니, 앞에서 무엇이 나왔는지에 따라 남은 카드가 달라져요. 이런 건 독립이 아니라서 "앞의 결과"를 따져야 해요. 이게 바로 다음 단원의 조건부 확률이에요.'),
];

final _condEvents = [
  YachtLessonEvent('둘 다 6', (a, b) => a == 6 && b == 6),
  YachtLessonEvent('같은 눈 (더블)', (a, b) => a == b),
  YachtLessonEvent('합이 7', (a, b) => a + b == 7),
];

final _conditions = [
  YachtLessonEvent('조건 없음', (a, b) => true),
  YachtLessonEvent('6이 적어도 하나', _six),
  YachtLessonEvent('①이 6', (a, b) => a == 6),
  YachtLessonEvent('합이 10 이상', (a, b) => a + b >= 10),
];

List<Widget> _unitConditional(BuildContext context) => [
  lessonP('친구가 주사위 2개를 몰래 굴려 보고 말했어요. "적어도 하나는 6이야!" 그러면 둘 다 6일 확률은 얼마일까요?'),
  lessonP('1/6이라고 생각하기 쉽지만, 아래 표에서 조건(사건 B)을 "6이 적어도 하나"로 바꿔 보세요.'),
  TwoDiceExplorer(events: _condEvents, conditions: _conditions, initialCondition: 1, tags: true),
  richBullets(context, [
    '"6이 적어도 하나"라는 사실을 알면, 가능한 경우가 36칸에서 11칸으로 줄어요. 그중 둘 다 6은 (6,6) 1칸 → 1/11',
    '"①이 6"이라는 사실을 알면 가능한 경우는 6칸, 그중 둘 다 6은 1칸 → 1/6',
    '비슷해 보이는 말이지만 남는 칸이 달라서 확률도 달라요!',
  ]),
  lessonP('이미 알고 있는 사실(사건 B)이 생기면, 모든 경우 대신 B에 맞는 경우만 "전체"로 보고 세요. 이것을 식으로 쓰면:'),
  const ConditionalFormulaCard(),
  lessonP('예: B = "6이 적어도 하나"(11칸), A와 B가 함께 = "둘 다 6"(1칸) → P(A|B) = 1/11'),
  lessonH(context, '야추 게임 속 조건부 확률'),
  lessonP('차례를 시작할 때, 3번 굴려서 야추를 만들 확률은 (가장 잘 고정해도) 약 4.6%뿐이에요. 그런데 첫 굴림을 보고 나면 이야기가 달라져요.'),
  lessonBullets(context, [
    '첫 굴림에서 같은 눈이 4개 나왔다면 → 야추 확률 11/36 (약 31%)',
    '첫 굴림에서 같은 눈이 3개 나왔다면 → 121/1296 (약 9.3%)',
  ]),
  lessonP('힌트 창의 확률은 언제나 "지금 주사위가 이렇게 나왔다"는 조건에서의 조건부 확률이에요. 그래서 굴릴 때마다 확률이 바뀌어요.'),
  lessonH(context, '곱셈정리: 식을 뒤집어 봐요'),
  lessonP('단추를 눌러 조건부 확률의 식이 어떻게 곱셈 식으로 바뀌는지 보세요.'),
  const FormulaFlipDemo(),
  lessonP('"다시 굴릴 기회가 두 번" 단원에서 "1번째에 실패하고(B, 5/6) 그다음 2번째에 성공(A, 1/6)"을 5/6 × 1/6으로 곱한 것이 바로 이 식이에요. '
      'P(A|B)는 "1번째에 실패했을 때 2번째에 성공할 확률"이고, 주사위는 독립이라 그대로 1/6이에요.'),
];

List<Widget> _unitExpected(BuildContext context) => [
  lessonP('주사위 하나를 아주 많이 굴려 눈의 평균을 내면 얼마쯤 될까요? 직접 굴려 보세요.'),
  const AverageSimulator(),
  lessonP('많이 굴릴수록 평균이 3.5에 가까워져요. 눈마다 1/6씩 나오니 (1 + 2 + 3 + 4 + 5 + 6) × 1/6 = 21/6 = 3.5예요.'),
  lessonKey(context, '기댓값 = (나올 수 있는 값 × 그 값이 나올 확률)을 모두 더한 것\n= 아주 많이 했을 때의 평균', icon: Icons.balance_rounded),
  lessonH(context, '찬스 칸: 언제 다시 굴릴까?'),
  lessonP('찬스 칸은 눈 5개의 합이에요. 주사위 하나씩 따져 봐요.'),
  lessonBullets(context, [
    '마지막 굴림이면 다시 굴린 주사위의 기댓값은 3.5예요.',
    '그래서 한 번 남았을 때는 4, 5, 6은 남기고 1, 2, 3만 다시 굴려요 (3.5보다 작으니까).',
    '이렇게 하면 주사위 하나의 기댓값은 (4 + 5 + 6) × 1/6 + 3.5 × 3/6 = 2.5 + 1.75 = 4.25',
    '두 번 남았을 때는 4.25보다 큰 5, 6만 남겨요 → (5 + 6) × 1/6 + 4.25 × 4/6 = 14/3 (약 4.67)',
    '주사위 5개면 14/3 × 5 = 70/3, 찬스만 노리면 평균 약 23.3점이에요.',
  ]),
  lessonH(context, '힌트의 "최적의 행동"'),
  lessonP('힌트는 "지금 어떻게 하면 게임이 끝날 때 총점의 기댓값이 가장 커질까?"를 계산해요. 남은 칸, 보너스까지 모든 경우를 따져서 만든 표를 쓰기 때문에, '
      '"이번에 13점을 적는 것"과 "다시 굴려서 야추를 노리는 것" 중 평균적으로 더 좋은 쪽을 알려 줘요.'),
  lessonP('평균이 더 좋다고 매번 이기는 건 아니에요. 확률은 "많이 했을 때"의 이야기니까요!'),
];

/// 퀴즈 글: "3/36" 같은 분수를 진짜 분수 모양으로.
Widget _fracText(String text, TextStyle style) => yachtRich(text, style, fractions: true);

List<Widget> _unitQuiz(BuildContext context) => [
  const LessonQuiz(
    textBuilder: _fracText,
    question: '주사위 2개를 굴려서 눈의 합이 4가 될 확률은?',
    options: ['1/12', '1/11', '1/18'],
    answer: 0,
    explain: '(1,3), (2,2), (3,1) 3가지 → 3/36 = 1/12',
  ),
  const LessonQuiz(
    textBuilder: _fracText,
    question: '주사위 3개를 다시 굴릴 때, 5가 적어도 하나 나올 확률은?',
    options: ['3/6', '91/216', '125/216'],
    answer: 1,
    explain: '5가 하나도 안 나올 경우는 5 × 5 × 5 = 125가지라서 확률은 125/216 → 1 - 125/216 = 91/216',
  ),
  const LessonQuiz(
    textBuilder: _fracText,
    question: '6이 세 번 연속으로 안 나왔어요. 다음에 굴릴 때 6이 나올 확률은?',
    options: ['1/6보다 크다', '1/6', '1/6보다 작다'],
    answer: 1,
    explain: '주사위는 기억이 없어요(독립). 앞에서 무엇이 나왔든 언제나 1/6이에요.',
  ),
  const LessonQuiz(
    textBuilder: _fracText,
    question: '같은 눈 4개를 고정했고 다시 굴릴 기회가 2번 남았어요. 야추가 될 확률은?',
    options: ['2/6', '11/36', '1/36'],
    answer: 1,
    explain: '1 - (두 번 다 실패) = 1 - 5/6 × 5/6 = 1 - 25/36 = 11/36. 1/6 + 1/6 = 2/6으로 더하면 두 번 다 성공하는 경우를 겹쳐 세요.',
  ),
  const LessonQuiz(
    textBuilder: _fracText,
    question: '주사위 2개를 굴렸더니 합이 10 이상이래요. 두 눈이 같을(더블) 확률은?',
    options: ['1/6', '1/3', '1/18'],
    answer: 1,
    explain: '합이 10 이상: (4,6) (5,5) (6,4) (5,6) (6,5) (6,6) 6가지. 그중 더블은 (5,5) (6,6) 2가지 → 2/6 = 1/3',
  ),
  const LessonQuiz(
    textBuilder: _fracText,
    question: '찬스 칸을 노리는 중이고, 마지막 한 번만 더 굴릴 수 있어요. 주사위 하나가 4예요. 어떻게 할까요?',
    options: ['남긴다', '다시 굴린다', '어느 쪽이든 똑같다'],
    answer: 0,
    explain: '다시 굴리면 기댓값이 3.5라서 4보다 작아요. 평균적으로 남기는 게 이득이에요.',
  ),
];
