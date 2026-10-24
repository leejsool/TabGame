import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../tutorial/lesson_kit.dart';
import '../core/stones_rules.dart';
import 'stones_board.dart';
import 'stones_lesson_31.dart';
import 'stones_menu.dart';

/// 바둑돌 옮기기 "교과학습": 님(Nim) 게임, 베스킨라빈스 31 게임, 이진법으로 찾는 필승법.
class StonesLessonScreen extends StatelessWidget {
  const StonesLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '님(Nim) 게임이란?', subtitle: '돌 더미에서 번갈아 가져가기', icon: Icons.layers_rounded, build: _unitNim),
    LessonUnit(title: '베스킨라빈스 31 게임', subtitle: '31을 부르면 져요', icon: Icons.icecream_rounded, build: _unit31),
    LessonUnit(title: '31 게임의 필승법', subtitle: '4씩 맞추는 열쇠 수', icon: Icons.key_rounded, build: _unit31Win),
    LessonUnit(title: '바둑돌 옮기기도 님 게임', subtitle: '빈칸 수 = 돌 더미', icon: Icons.circle_outlined, build: _unitStonesNim),
    LessonUnit(title: '이진법으로 쪼개기', subtitle: '8·4·2·1 자리의 1의 개수', icon: Icons.looks_one_rounded, build: _unitBinary),
    LessonUnit(title: '바둑돌 옮기기 해법', subtitle: '문제 (1)~(4) 풀이', icon: Icons.emoji_objects_rounded, build: _unitSolve),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: kStonesColor,
      heroArt: StonesBoard(state: kStartBoard.start(), onTapCell: null),
      heroText: '게임하면서 수학을 배워요!\n돌 가져가기(님), 31 게임, 바둑돌 옮기기는 모두 "짝 맞추기"로 이기는 게임이에요.',
      units: _units,
    );
  }
}

Future<void> openStonesLesson(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StonesLessonScreen()));

/// 판 그림 (빈칸 수·2진법 표를 켠 채로). 칸 번호는 문제지처럼 1부터.
Widget _board(List<int> white, List<int> black, {String? caption, (int, int)? moved}) => lessonArt(
      Padding(
        padding: const EdgeInsets.all(8),
        child: StonesBoard(
          state: StonesState([for (final c in white) c - 1], [for (final c in black) c - 1]),
          onTapCell: null,
          showGaps: true,
          showBinary: true,
          lastMove: moved == null ? null : (moved.$1 - 1, moved.$2 - 1),
        ),
      ),
      height: 190,
      caption: caption,
    );

Widget _playButtons(BuildContext context) => FilledButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StonesMenuScreen(mode: PlayMode.vsCpu))),
      icon: const Icon(Icons.smart_toy_rounded),
      label: const Text('바둑돌 옮기기 하러 가기 (컴퓨터와)'),
      style: FilledButton.styleFrom(backgroundColor: kStonesColor, minimumSize: const Size.fromHeight(48)),
    );

// ───────────────────────── 단원 내용 ─────────────────────────

List<Widget> _unitNim(BuildContext context) => [
      lessonP('님(Nim)은 아주 오래된 두 사람 게임이에요. 돌(또는 성냥개비)을 몇 더미로 나누어 놓고 시작해요.'),
      lessonH(context, '규칙'),
      lessonBullets(context, [
        '두 사람이 번갈아 한 더미를 골라, 그 더미에서 돌을 1개 이상 원하는 만큼 가져가요.',
        '한 번에 한 더미에서만 가져갈 수 있어요.',
        '마지막 돌을 가져가는 사람이 이겨요. (= 가져갈 돌이 없는 차례가 된 사람이 져요)',
      ]),
      lessonP('예를 들어 더미가 3개, 1개, 0개라면? 3개짜리에서 2개를 가져가 1개, 1개로 만들면 돼요. '
          '그 뒤로는 상대가 한쪽에서 가져가면 나도 다른 쪽에서 똑같이 가져가요. 마지막 돌은 늘 내 차지예요.'),
      lessonKey(context, '님의 비밀: 상대에게 "짝이 맞는" 상태를 넘겨주면 이겨요. 상대가 무엇을 하든 짝을 다시 맞출 수 있거든요.'),
      lessonP('이런 게임을 "님 게임"이라고 부르고, 수를 부르는 31 게임이나 바둑돌 옮기기도 모두 님 게임의 친척이에요.'),
    ];

List<Widget> _unit31(BuildContext context) => [
      lessonP('"베스킨라빈스 31"은 친구들과 많이 하는 수 부르기 게임이에요.'),
      lessonH(context, '규칙'),
      lessonBullets(context, [
        '1부터 차례대로 수를 불러요.',
        '한 번에 1개, 2개, 3개까지 이어서 부를 수 있어요. (예: "1, 2" → "3, 4, 5" → "6")',
        '31을 부르는 사람이 져요.',
      ]),
      lessonP('아래에서 컴퓨터와 직접 해 보세요. 컴퓨터는 필승법을 알고 있어요. 이길 수 있을까요?'),
      const Lesson31Game(),
      lessonKey(context, '몇 판 해 보며 컴퓨터가 어떤 수에서 멈추는지 살펴보세요. 그 수들에 비밀이 있어요!'),
    ];

List<Widget> _unit31Win(BuildContext context) => [
      lessonH(context, '거꾸로 생각하기'),
      lessonP('31을 부르면 지니까, 내가 30을 부르면 이겨요. 상대는 31을 부를 수밖에 없거든요.'),
      lessonP('그럼 30을 부르려면? 상대가 27, 28, 29 중 어디에서 멈춰도 내가 30까지 갈 수 있으면 돼요. '
          '즉 내가 26을 부르면 돼요. 같은 방법으로 거꾸로 4씩 빼 보면…'),
      lessonKey(context, '열쇠 수: 2, 6, 10, 14, 18, 22, 26, 30 (4로 나누면 나머지가 2인 수)', icon: Icons.key_rounded),
      lessonH(context, '4씩 맞추기'),
      lessonBullets(context, [
        '상대가 1개를 부르면 나는 3개, 2개면 2개, 3개면 1개를 불러요. 둘이 합쳐 늘 4개!',
        '그러면 열쇠 수에서 다음 열쇠 수(+4)로 정확히 넘어가요.',
        '먼저 하는 사람이 "1, 2"를 부르면 처음부터 열쇠 수를 잡아 반드시 이겨요.',
        '나중에 하는 사람은 상대가 실수로 열쇠 수를 놓칠 때 잡으면 돼요.',
      ]),
      lessonP('왜 하필 4일까요? 한 번에 최대 3개까지 부를 수 있어서, 1+3 = 4 이기 때문이에요. '
          '한 번에 최대 5개까지라면 6씩 맞추면 되겠죠?'),
      lessonP('이제 "열쇠 수 보기"를 켜고 다시 해 보세요.'),
      const Lesson31Game(),
      lessonKey(context, '31 게임의 비법 = 상대가 무엇을 하든 내가 "짝을 맞춰" 원래 모양으로 되돌릴 수 있는 상태를 넘겨주기.'),
    ];

List<Widget> _unitStonesNim(BuildContext context) => [
      lessonP('바둑돌 옮기기에서는 3행마다 흰 돌(갑)과 검은 돌(을)이 마주 보고 있어요. 두 돌 사이 빈칸 수를 a, b, c라고 해 봐요.'),
      _board(const [1, 2, 3], const [12, 11, 10], caption: '처음 판: a = 10, b = 8, c = 6'),
      lessonBullets(context, [
        '돌을 상대 쪽으로 다가가면 그 행의 빈칸이 줄어요 → 님에서 더미의 돌을 가져가는 것과 같아요.',
        '빈칸이 모두 0이 되면, 차례가 된 사람은 뒤로 물러날 수밖에 없어요.',
        '돌을 뒤로 물리면 빈칸이 늘어나지만, 상대가 같은 행에서 그만큼 따라붙으면 다시 원래대로예요.',
      ]),
      lessonKey(context, '그래서 바둑돌 옮기기는 더미가 a, b, c개인 님 게임과 같아요. a, b, c를 모두 0으로 만들어 넘기는 사람이 이겨요.'),
      lessonP('게임에서 빈칸이 0, 0, 0이 되면 승부가 정해진 것이라, 남은 수는 자동으로 둬서 끝내 줘요.'),
    ];

List<Widget> _unitBinary(BuildContext context) => [
      lessonP('더미가 여러 개면 "짝 맞추기"를 어떻게 할까요? 이진법을 쓰면 돼요.'),
      lessonH(context, '이진법'),
      lessonP('모든 수는 8, 4, 2, 1을 한 번씩만 써서 더할 수 있어요. 쓴 자리는 1, 안 쓴 자리는 0으로 적어요.'),
      lessonBullets(context, [
        '10 = 8 + 2 → 1010₍₂₎',
        '8 = 8 → 1000₍₂₎',
        '6 = 4 + 2 → 0110₍₂₎',
        '3 = 2 + 1 → 0011₍₂₎',
      ]),
      lessonH(context, '자리마다 1의 개수 세기'),
      lessonP('a, b, c를 이진법으로 쓰고 8, 4, 2, 1 자리마다 1이 몇 개인지 세요. 이 개수를 p, q, r, s라고 해요.'),
      _board(const [1, 2, 3], const [12, 11, 10], caption: '10, 8, 6 → 8 자리 2개, 4 자리 1개, 2 자리 2개, 1 자리 0개'),
      lessonKey(context, 'p, q, r, s가 모두 0 또는 짝수인 상태를 상대에게 넘겨주면 이겨요!'),
      lessonH(context, '왜 그럴까요?'),
      lessonBullets(context, [
        'a, b, c가 모두 0이면 p, q, r, s도 모두 0이에요. (짝수 상태)',
        '모두 짝수일 때는 a, b, c 중 한 수만 바꿔서 다시 모두 짝수로 만들 수 없어요. (한 수를 바꾸면 어느 자리든 1의 개수가 하나 바뀌거든요)',
        '짝수가 아닌 자리가 있으면, a, b, c 중 한 수를 줄여서 모두 짝수로 만들 수 있어요.',
        '그래서 내가 늘 짝수 상태로 넘기면, 마지막에 0, 0, 0을 넘기는 사람도 나예요.',
      ]),
      lessonP('게임 화면에서 "빈칸 수 보기"를 누르면 판 오른쪽에 이 표가 나와요. 1의 개수가 짝수면 초록, 홀수면 빨강이에요.'),
    ];

List<Widget> _unitSolve(BuildContext context) => [
      lessonH(context, '문제 (1)  a = 3, b = 1, c = 0  (갑 차례)'),
      lessonP('3 = 0011₍₂₎, 1 = 0001₍₂₎, 0 = 0000₍₂₎ → 2 자리의 1이 1개(홀수). 두 가지 방법이 있어요.'),
      _board(const [6, 2, 3], const [8, 4, 4], moved: (1, 6), caption: '① a = 1로: 1행 흰 돌을 오른쪽으로 두 칸 (1, 1, 0)'),
      _board(const [4, 2, 1], const [8, 4, 4], moved: (3, 1), caption: '② c = 2로: 3행 흰 돌을 왼쪽으로 두 칸 물러나기 (3, 1, 2)'),
      lessonH(context, '문제 (2)  a = 0, b = 8, c = 6  (을 차례)'),
      lessonP('8 = 1000₍₂₎, 6 = 0110₍₂₎ → 8·4·2 자리가 모두 홀수. b나 c를 바꿔 b = c로 맞춰요.'),
      _board(const [11, 2, 3], const [12, 9, 10], moved: (2, 9), caption: '① b = 6으로: 2행 검은 돌을 왼쪽으로 두 칸 (0, 6, 6)'),
      _board(const [11, 2, 3], const [12, 11, 12], moved: (3, 12), caption: '② c = 8로: 3행 검은 돌을 오른쪽으로 두 칸 물러나기 (0, 8, 8)'),
      lessonH(context, '문제 (3)  a = 10, b = 1, c = 6  (을 차례)'),
      lessonP('10 = 1010₍₂₎, 1 = 0001₍₂₎, 6 = 0110₍₂₎ → a = 7 = 0111₍₂₎로 바꾸는 방법 하나뿐이에요.'),
      _board(const [1, 9, 3], const [9, 11, 10], moved: (1, 9), caption: '1행 검은 돌을 왼쪽으로 세 칸 (7, 1, 6)'),
      lessonH(context, '처음 판  a = 10, b = 8, c = 6  (갑 차례)'),
      lessonP('8 자리 2개, 4 자리 1개, 2 자리 2개 → 4 자리가 홀수. c = 6을 2 = 0010₍₂₎로 바꿔요.'),
      _board(const [1, 2, 7], const [12, 11, 10], moved: (3, 7), caption: '3행 흰 돌을 오른쪽으로 네 칸 (10, 8, 2) → 먼저 하는 갑이 이겨요'),
      lessonKey(context, '물러나는 수도 정답이 될 수 있어요! 빈칸을 늘려도 1의 개수가 모두 짝수가 되면 이기는 수예요.'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitQuiz(BuildContext context) => [
      const LessonQuiz(
        question: '31 게임에서 상대가 "25, 26, 27"까지 불렀어요. 나는 어디까지 불러야 할까요?',
        options: ['28', '28, 29', '28, 29, 30'],
        answer: 2,
        explain: '30이 마지막 열쇠 수예요. 30까지 부르면 상대는 31을 부를 수밖에 없어요.',
      ),
      const LessonQuiz(
        question: '13을 이진법으로 쓰면?',
        options: ['1101₍₂₎', '1011₍₂₎', '0111₍₂₎'],
        answer: 0,
        explain: '13 = 8 + 4 + 1 이라서 8·4·1 자리가 1이에요 → 1101₍₂₎',
      ),
      const LessonQuiz(
        question: '바둑돌 옮기기에서 빈칸이 5, 3, 6이고 내 차례예요. 나는 유리할까요?',
        options: ['유리해요 (이기는 수가 있어요)', '불리해요 (상대가 잘하면 져요)'],
        answer: 1,
        explain: '5 = 0101, 3 = 0011, 6 = 0110 → 8 자리 0개, 4 자리 2개, 2 자리 2개, 1 자리 2개. 모두 짝수라 이미 짝이 맞은 상태예요. 내가 무엇을 해도 짝이 깨져요.',
      ),
      const LessonQuiz(
        question: '빈칸이 2, 3, 0이고 내 차례예요. 이기는 수는?',
        options: ['3을 2로 (한 칸 다가가기)', '2를 0으로 (두 칸 다가가기)', '3을 0으로 (세 칸 다가가기)'],
        answer: 0,
        explain: '2, 2, 0이 되면 2 자리의 1이 2개, 1 자리는 0개로 모두 짝수예요. 그다음엔 상대를 따라 하면 돼요.',
      ),
    ];
