import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import '../core/park_rules.dart';
import 'park_board.dart';
import 'park_lesson_widgets.dart';

/// 공원 길찾기 "교과학습": 최단경로 = 같은 것이 있는 순열.
class ParkLessonScreen extends StatelessWidget {
  const ParkLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '길을 글자로 적기', subtitle: '최단경로 = R과 D 늘어놓기', icon: Icons.route_rounded, build: _unitWord),
    LessonUnit(title: '같은 것이 있는 순열', subtitle: 'n! ÷ (p! × q!)', icon: Icons.functions_rounded, build: _unitPerm),
    LessonUnit(title: '공원의 최단경로 수', subtitle: '모든 길을 눈으로 확인해요', icon: Icons.grid_on_rounded, build: _unitCount),
    LessonUnit(title: '덧셈으로 세기', subtitle: '교차점마다 위 + 왼쪽', icon: Icons.add_rounded, build: _unitAdd),
    LessonUnit(title: '조건에 맞는 길 세기', subtitle: '전체에서 빼기 (여사건)', icon: Icons.park_rounded, build: _unitForest),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: kParkColor,
      heroArt: ParkBoard(stage: kParkStages[0], steps: const [Walk.right, Walk.down, Walk.down, Walk.right], compact: true),
      heroText: '길 찾기도 수학이에요!\n가장 짧은 길은 "오른쪽(R)"과 "아래(D)"를 늘어놓는 방법의 수, 즉 같은 것이 있는 순열로 셀 수 있어요.',
      units: _units,
    );
  }
}

Future<void> openParkLesson(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParkLessonScreen()));

const _r = Walk.right, _d = Walk.down;

// ───────────────────────── 단원 내용 ─────────────────────────

List<Widget> _unitWord(BuildContext context) => [
  lessonP('A에서 B까지 가장 짧게 가려면 오른쪽과 아래로만 걸어야 해요. 왼쪽이나 위로 한 번이라도 가면 돌아가는 길이 되거든요.'),
  lessonP('오른쪽 한 칸을 R, 아래 한 칸을 D라고 적어 봐요. 그러면 길 하나가 글자 하나의 줄이 돼요.'),
  lessonArt(
    Padding(
      padding: const EdgeInsets.all(16),
      child: ParkBoard(stage: kParkStages[0], steps: const [_r, _d, _d, _r]),
    ),
    height: 260,
    caption: '이 길은 R → D → D → R, 즉 "RDDR"',
  ),
  lessonKey(context, '2×2 공원에서는 어떤 최단경로든 R 2개, D 2개로 이루어져요. 다른 건 순서뿐이에요!'),
  lessonP('그러니 "최단경로가 몇 개?"는 "R, R, D, D 네 글자를 한 줄로 늘어놓는 방법이 몇 가지?"와 같은 문제예요.'),
];

List<Widget> _unitPerm(BuildContext context) => [
  lessonH(context, '모두 다를 때'),
  lessonP('서로 다른 4개를 한 줄로 늘어놓는 방법은 4 × 3 × 2 × 1 = 24가지예요. 이것을 4!(4 팩토리얼)이라고 써요.'),
  lessonH(context, '같은 것이 섞여 있을 때'),
  lessonP(
    '그런데 R, R, D, D처럼 같은 것이 있으면 24가지 중 겹치는 것이 생겨요. '
    'R 두 개에 R₁, R₂ 이름표를 붙여 보면, "R₁R₂DD"와 "R₂R₁DD"는 이름표를 떼면 똑같은 "RRDD"예요.',
  ),
  lessonBullets(context, ['R끼리 자리를 바꾸는 2! = 2가지가 모두 같은 줄이에요.', 'D끼리 자리를 바꾸는 2! = 2가지도 마찬가지예요.', '그래서 24를 2! × 2! = 4로 나눠요 → 24 ÷ 4 = 6가지']),
  lessonKey(context, '같은 것이 있는 순열: n개 중 같은 것이 p개, q개, r개, … 있으면\n늘어놓는 방법의 수 = n! ÷ (p! × q! × r! × …)', icon: Icons.functions_rounded),
  lessonH(context, '해 보기'),
  lessonP('글자 카드를 직접 늘어놓아 보세요. 같은 줄이 나오면 한 번만 세요.'),
  const PermExplorer(),
  lessonH(context, '다른 예'),
  lessonBullets(context, [
    '"토마토": 3글자 중 "토"가 2개 → 3! ÷ 2! = 3가지 (토마토, 토토마, 마토토)',
    '숫자 카드 1, 1, 2, 2, 3으로 다섯 자리 수 만들기 → 5! ÷ (2! × 2!) = 120 ÷ 4 = 30가지',
    '"BANANA": A 3개, N 2개 → 6! ÷ (3! × 2!) = 720 ÷ 12 = 60가지',
  ]),
];

List<Widget> _unitCount(BuildContext context) => [
  lessonP('n×n 공원의 최단경로는 R n개, D n개를 늘어놓는 방법이에요.'),
  lessonBullets(context, [
    '2×2 공원: 4! ÷ (2! × 2!) = 6가지',
    '3×3 공원: 6! ÷ (3! × 3!) = 720 ÷ 36 = 20가지',
    '4×4 공원: 8! ÷ (4! × 4!) = 40320 ÷ 576 = 70가지',
  ]),
  lessonP('정말 그런지 모든 길을 그려 봤어요. 공원 크기를 바꿔 보세요.'),
  const AllPathsExplorer(),
  lessonKey(context, '가로 m칸, 세로 n칸인 공원이라면? R m개, D n개 → (m + n)! ÷ (m! × n!)가지'),
];

List<Widget> _unitAdd(BuildContext context) => [
  lessonP('식 말고 덧셈으로도 셀 수 있어요. 어떤 교차점에 오려면 바로 위에서 내려오거나 바로 왼쪽에서 오는 수밖에 없어요.'),
  lessonKey(context, '그 점까지 가는 길의 수 = (위 점까지 가는 길의 수) + (왼쪽 점까지 가는 길의 수)', icon: Icons.add_rounded),
  lessonP('맨 윗줄과 맨 왼쪽 줄은 가는 길이 1가지뿐이니 1을 적고, 나머지는 위 + 왼쪽을 더해 가요.'),
  lessonArt(CustomPaint(painter: PathCountPainter(4)), height: 320, caption: '4×4 공원: B에 70이 나와요. 6! ÷ (3! × 3!) = 20도 가운데쯤 보여요.'),
  lessonP('순열 공식으로 구한 6, 20, 70이 덧셈으로도 똑같이 나와요. 이 수의 모양을 "파스칼의 삼각형"이라고도 불러요.'),
];

List<Widget> _unitForest(BuildContext context) => [
  lessonP('공원 길찾기의 조건은 "숲이 왼편인 구간"과 "숲이 오른편인 구간"이 모두 있는 길이에요.'),
  lessonP('조건에 맞는 길을 바로 세기 어렵다면, 전체에서 조건에 맞지 않는 길을 빼면 돼요. 이런 생각을 "여사건"이라고 해요.'),
  lessonH(context, '조건에 맞지 않는 길은 세 종류'),
  lessonBullets(context, [
    '숲이 오른편에만 있는 길',
    '숲이 왼편에만 있는 길',
    '숲이 아예 없는 길 → 이런 길은 없어요! A 바로 옆에 숲이 있어서, 첫 걸음을 오른쪽(R)으로 가면 숲이 오른편, 아래(D)로 가면 왼편에 와요.',
  ]),
  lessonKey(context, '조건에 맞는 길 = 전체 - (숲이 오른편에만 있는 길) - (숲이 왼편에만 있는 길)'),
  lessonH(context, '① 숲이 오른편에만 있는 길은 어떤 길?'),
  lessonArt(
    Padding(
      padding: const EdgeInsets.all(16),
      child: ParkBoard(stage: kParkStages[2], steps: const [_r, _d, _r, _r, _d, _r, _d, _d]),
    ),
    height: 280,
    caption: 'RDRRDRDD: 숲이 모두 오른편에만 있어요',
  ),
  lessonBullets(context, [
    '숲은 A에서 B로 비스듬히(대각선으로) 놓여 있어요.',
    '숲 바로 왼쪽 위 모서리 점(대각선 위의 점)에서 오른쪽으로 가면 숲이 오른편에, 아래로 내려가면 그 숲이 왼편에 와요.',
    '그래서 숲이 오른편에만 있으려면, 대각선 위의 점에서는 늘 오른쪽으로 가야 해요.',
    '즉, 숲 줄을 넘어 왼쪽 아래 구역으로 한 번도 내려가지 않는 길이에요.',
  ]),
  lessonKey(context, '숲이 오른편에만 있는 길 = 숲 줄 아래(왼쪽 아래 구역)로 내려가지 않는 길'),
  lessonH(context, '② 덧셈으로 세기: 갈 수 없는 점은 빼고'),
  lessonP('"덧셈으로 세기"처럼 교차점마다 위 + 왼쪽을 더해요. 다만 숲 줄 아래의 점(회색)은 갈 수 없으니 0으로 생각해요.'),
  lessonBullets(context, ['맨 윗줄은 모두 1이에요.', '대각선 위의 점은 왼쪽 점이 회색(0)이라, 바로 위의 수를 그대로 내려 적어요.', '나머지는 위 + 왼쪽을 더해요.']),
  LessonDepthExplorer(
    painter: (n) => PathCountPainter(n, oneSide: true),
    minDepth: 2,
    maxDepth: 4,
    initial: 4,
    height: 320,
    caption: (n) => '$n×$n 공원: B까지 ${const {2: 2, 3: 5, 4: 14}[n]}가지 (단계 = 공원 크기)',
  ),
  lessonP('4×4 공원을 한 줄씩 적어 보면:'),
  lessonBullets(context, [
    '첫째 줄: 1, 1, 1, 1, 1',
    '둘째 줄: 1(위의 1을 그대로), 1+1=2, 1+2=3, 1+3=4',
    '셋째 줄: 2(위의 2를 그대로), 3+2=5, 4+5=9',
    '넷째 줄: 5(위의 5를 그대로), 9+5=14',
    'B: 위의 14를 그대로 → 14가지',
  ]),
  lessonH(context, '③ 숲이 왼편에만 있는 길'),
  lessonP(
    '그림을 A와 B를 잇는 대각선으로 접어 보세요. 오른쪽(R)과 아래(D)가 서로 바뀌면서, 숲이 오른편에만 있는 길이 숲이 왼편에만 있는 길로 딱 바뀌어요. '
    '예를 들어 RDRRDRDD를 접으면 DRDDRDRR이 돼요. 그래서 수가 똑같아요.',
  ),
  lessonH(context, '④ 정리'),
  lessonBullets(context, [
    '2×2 공원: 전체 6 - 오른편만 2 - 왼편만 2 = 2가지',
    '3×3 공원: 전체 20 - 오른편만 5 - 왼편만 5 = 10가지',
    '4×4 공원: 전체 70 - 오른편만 14 - 왼편만 14 = 42가지',
  ]),
  lessonP('더 알아보기: 대각선을 넘지 않는 길의 수 1, 2, 5, 14, 42, …를 "카탈랑 수"라고 해요. 중학교·고등학교에서 다시 만나요!'),
  lessonP('게임에서 3×3, 4×4 공원의 길을 직접 찾아 수가 맞는지 확인해 보세요.'),
];

List<Widget> _unitQuiz(BuildContext context) => [
  const LessonQuiz(
    question: 'R, R, R, D를 한 줄로 늘어놓는 방법은 몇 가지일까요?',
    options: ['4가지', '12가지', '24가지'],
    answer: 0,
    explain: '4! ÷ 3! = 24 ÷ 6 = 4가지 (RRRD, RRDR, RDRR, DRRR)',
  ),
  const LessonQuiz(
    question: '가로 3칸, 세로 2칸인 공원에서 A에서 B까지의 최단경로는?',
    options: ['6가지', '10가지', '20가지'],
    answer: 1,
    explain: 'R 3개, D 2개 → 5! ÷ (3! × 2!) = 120 ÷ 12 = 10가지',
  ),
  const LessonQuiz(
    question: '"사과사과"의 네 글자를 늘어놓는 방법은?',
    options: ['4가지', '6가지', '24가지'],
    answer: 1,
    explain: '"사" 2개, "과" 2개 → 4! ÷ (2! × 2!) = 6가지. 2×2 공원의 길 수와 같아요!',
  ),
  LessonQuiz(
    figure: SizedBox(width: 200, height: 200, child: ParkBoard(stage: kParkStages[1], steps: const [])),
    question: '그림의 3×3 공원에서 A에서 B까지의 최단경로 중, 숲이 진행 방향의 오른편에만 있는 길은 5가지예요. '
        '숲이 왼편인 구간과 오른편인 구간이 모두 있는 길(조건에 맞는 길)은 몇 가지일까요?',
    options: const ['5가지', '10가지', '15가지'],
    answer: 1,
    explain: '최단경로는 모두 6! ÷ (3! × 3!) = 20가지예요. 그림을 대각선으로 접으면 오른편만 있는 길이 왼편만 있는 길로 바뀌니 왼편만 있는 길도 5가지, '
        '숲이 아예 없는 길은 없어요. 그래서 20 - 5 - 5 = 10가지예요.',
  ),
];
