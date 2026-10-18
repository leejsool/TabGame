import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../tutorial/lesson_kit.dart';
import '../core/prophecy_examples.dart';
import '../core/prophecy_lessons.dart';
import 'prophecy_board.dart';
import 'prophecy_lesson_widgets.dart';
import 'prophecy_setup_screen.dart';

part 'prophecy_lesson_screen_units.dart';

const Color _accent = kProphColor;

/// 예언 "교과학습": 스스로를 가리키는 예언에서 시작해, 집합론·힐베르트·러셀·괴델·튜링까지 수학의 "자기 참조"를 배운다.
class ProphecyLessonScreen extends StatelessWidget {
  const ProphecyLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '예언 한눈에 보기', subtitle: '게임 규칙을 한 번에 정리해요', icon: Icons.auto_awesome_rounded, build: _unitGame),
    LessonUnit(title: '스스로 이루는 예언, 스스로 무너지는 예언', subtitle: '말이 미래를 바꾸는 이야기', icon: Icons.autorenew_rounded, build: _unitSelfFulfilling),
    LessonUnit(title: '맛보기 노트: 스스로를 망치는 숫자', subtitle: '내 숫자가 내 예언을 깨뜨려요', icon: Icons.sentiment_very_dissatisfied_rounded, build: _unitTaste),
    LessonUnit(title: '자기 자신을 설명하는 표와 문장', subtitle: '숫자 맞물리기 퍼즐', icon: Icons.table_chart_rounded, build: _unitSelfDescribing),
    LessonUnit(title: '거짓말쟁이와 불시 시험', subtitle: '자기를 가리키는 말의 함정', icon: Icons.record_voice_over_rounded, build: _unitLiar),
    LessonUnit(title: '수학의 탑과 힐베르트', subtitle: '튼튼한 바닥을 찾는 계획', icon: Icons.account_balance_rounded, build: _unitHilbert),
    LessonUnit(title: '집합으로 수를 만들어요', subtitle: '빈 주머니에서 시작하는 모든 수', icon: Icons.bubble_chart_rounded, build: _unitSets),
    LessonUnit(title: '러셀의 역설과 이발사', subtitle: '집합론을 흔든 질문', icon: Icons.content_cut_rounded, build: _unitRussell),
    LessonUnit(title: '더 많은 역설들', subtitle: '자기 자신을 가리키면 생기는 일', icon: Icons.psychology_alt_rounded, build: _unitMoreParadoxes),
    LessonUnit(title: '괴델과 튜링: 증명할 수 없는 것', subtitle: '힐베르트의 꿈은 어떻게 되었을까', icon: Icons.memory_rounded, build: _unitGodel),
    LessonUnit(title: '공리계와 형식주의, ZFC', subtitle: '수학을 규칙 게임으로 보는 눈', icon: Icons.rule_rounded, build: _unitAxioms),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: _accent,
      heroArt: ProphBoardView(state: bookBoard(), showCounts: false, reveal: 1),
      heroText: '게임도 하고, 예언의 비밀도 배워요!\n내 말이 미래를 바꾸는 "예언"에서 수학의 가장 깊은 수수께끼까지 가 봐요.',
      units: _units,
    );
  }
}

/// 교과학습 화면을 연다.
Future<void> openProphecyLesson(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProphecyLessonScreen()));
}

/// 게임 하러 가기 단추 (교과학습 → 바로 CPU 대결/둘이서).
Widget _playButtons(BuildContext context) {
  void play(PlayMode mode) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProphecySetupScreen(mode: mode)));
  }

  return Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: () => play(PlayMode.vsCpu),
          icon: const Icon(Icons.smart_toy_rounded),
          label: const Text('CPU와 한 판'),
          style: FilledButton.styleFrom(backgroundColor: _accent),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => play(PlayMode.local2p),
          icon: const Icon(Icons.people_rounded),
          label: const Text('둘이서 한 판'),
        ),
      ),
    ],
  );
}

// ───────────────────────── 단원 내용 ─────────────────────────

List<Widget> _unitGame(BuildContext context) => [
      lessonP('예언은 두 사람이 번갈아 빈칸에 숫자나 X를 쓰는 게임이에요. 쓰는 숫자는 "이 줄(행이나 열)에 숫자가 결국 몇 개 나타날까?"에 대한 예언이에요.'),
      lessonArt(
        ProphBoardView(state: bookBoard(), reveal: 1),
        height: 300,
        caption: '다 채운 표: 동그라미는 맞힌 예언 (좌우 화살표 = 행에서, 위아래 화살표 = 열에서)',
      ),
      lessonH(context, '규칙 한눈에 보기'),
      lessonBullets(context, [
        '행 4~8개, 열 4~8개의 표에서 분홍 펜과 청록 펜이 번갈아 써요.',
        '쓸 수 있는 숫자는 1부터 가장 긴 줄의 칸 수까지예요. X는 칸을 채우기만 하고 숫자로 세지 않아요.',
        '한 행이나 열에는 같은 숫자를 두 번 쓸 수 없어요.',
        '어떤 숫자도 쓸 수 없는 칸은 저절로 X가 돼요. (차례로 세지 않아요)',
        '표가 가득 차면 줄마다 숫자 개수를 세어요. 그 개수와 같은 숫자를 쓴 사람이 그 숫자만큼 점수를 얻어요.',
        '한 숫자가 행과 열에서 모두 맞으면 두 번 얻어요.',
      ]),
      lessonKey(context, '이 게임의 열쇠: 내가 쓰는 숫자는 미래에 대한 "말"이면서 그 미래를 바꾸는 "행동"이기도 해요. 숫자를 쓸 때마다 줄의 숫자 개수가 달라질 수 있으니까요.'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitSelfFulfilling(BuildContext context) => [
      lessonP('예언은 그냥 바라보는 말이 아니에요. 예언을 들은 사람들은 행동을 바꾸고, 그래서 결과까지 바뀔 수 있어요. 이렇게 예언이 사람을 움직이는 이야기를 두 가지로 나눠 볼게요.'),
      lessonH(context, '스스로 이루어지는 예언 (자기충족적 예언)'),
      lessonP('예언을 믿고 행동했더니, 바로 그 행동 때문에 예언이 정말 이루어지는 경우예요. 미국의 사회학자 로버트 머튼이 1948년에 이 말을 널리 알렸어요.'),
      lessonBullets(context, [
        '은행: "이 은행이 곧 망한대!"라는 소문이 퍼져요. 놀란 사람들이 한꺼번에 돈을 찾으러 가요. 은행의 돈이 바닥나서 정말로 문을 닫게 돼요.',
        '주식: "이 회사 주가가 하늘을 찌를 거야!"라는 말에 사려는 사람이 늘어요. 그래서 정말 값이 올라요.',
        '시험: "난 분명히 시험을 망칠 거야"라고 굳게 믿으면 불안해서 실수가 늘고, 정말 망치기 쉬워요.',
        '신화: 오이디푸스 이야기에서 신탁을 피하려던 사람들의 선택이, 오히려 신탁이 이루어지는 길이 되고 말았어요.',
      ]),
      lessonH(context, '스스로 무너지는 예언 (자기패배적 예언)'),
      lessonP('반대로, 예언을 들은 사람들이 그 일을 피하려고 행동해서 예언이 틀려지는 경우예요.'),
      lessonBullets(context, [
        '교통 방송: "내일 ○○도로가 엄청 막힐 거예요!" 하면 모두가 다른 길로 돌아가서 정작 막히지 않아요.',
        '태풍·감염병 경고: "큰 피해가 날 거예요"라는 경고를 듣고 미리 대비해서 피해가 작아져요. (예언이 틀린 게 아니라 경고가 성공한 거예요!)',
        '시험 소문: "이번 시험은 아주 쉽대"라는 소문에 모두 공부를 덜 해서 점수가 떨어져요.',
        '요즘 부모에게 "아기가 자라서 아빠에게 큰 불행을 가져올 거예요"라고 예언한다면, 부모는 아이를 키우는 방식을 크게 바꿀 테니 예언은 빗나갈 가능성이 커요.',
      ]),
      lessonH(context, '기대의 힘'),
      lessonP('1960년대 로젠탈과 제이콥슨의 연구는 "선생님이 이 아이는 크게 성장할 거라고 기대하면 아이가 정말 더 잘하게 된다"는 "피그말리온 효과"로 유명해졌어요. 다만 효과가 얼마나 큰지는 지금도 연구자들이 토론하고 있어요.'),
      lessonKey(context, '좋은 예언자는 "내 말을 들은 사람들이 어떻게 행동할까?"까지 생각해야 해요. 예언 게임의 숫자도 마찬가지예요. 내 숫자가 줄의 결과를 바꾸니까요.'),
      const LessonQuiz(
        question: '"내일 우리 동네 길이 엄청 막힐 거예요!"라는 방송을 들은 모두가 다른 길로 돌아가서 길이 막히지 않았어요. 어떤 예언일까요?',
        options: ['스스로 이루어지는 예언', '스스로 무너지는 예언', '둘 다 아니에요'],
        answer: 1,
        explain: '예언을 들은 사람들이 피하려고 행동해서 예언이 틀려졌어요. 예언이 자기 자신을 무너뜨린 거예요.',
      ),
      const LessonQuiz(
        question: '"이 가게의 쿠키가 곧 동날 거야!"라는 소문에 사람들이 서둘러 사 가서 쿠키가 정말 동났어요. 어떤 예언일까요?',
        options: ['스스로 이루어지는 예언', '스스로 무너지는 예언', '둘 다 아니에요'],
        answer: 0,
        explain: '소문을 믿고 서둘러 산 행동 때문에 소문이 사실이 되었어요. 은행 이야기와 같은 모양이에요.',
      ),
    ];

List<Widget> _unitTaste(BuildContext context) => [
      lessonP('게임에서 가장 답답하고 괴로운 순간은 내 예언이 스스로를 망칠 때예요. 아래 한 줄을 보세요.'),
      const SelfDefeatDemo(),
      lessonH(context, '왜 이런 일이 생길까?'),
      lessonP('숫자 2는 "이 행에 숫자가 2개일 거야"라는 예언이에요. 그런데 이 행에는 이미 4와 3, 두 개가 있어요. 2를 쓰는 순간 숫자는 세 개가 되고 "2개"라는 예언은 거짓이 돼요. 예언이 말하던 바로 그 세상을, 예언 자신이 부숴 버린 거예요.'),
      lessonKey(context, '예언이 자기 자신의 내용을 바꿔 버리는 것. 이것이 수학자들이 오래 고민해 온 "자기 참조"의 맛보기예요.', icon: Icons.loop_rounded),
      const LessonReveal(
        title: '그럼 분홍이 이 줄에서 할 수 있는 가장 좋은 선택은 무엇일까요?',
        child: Text(
          'X를 쓰는 거예요. 그러면 숫자가 4와 3, 두 개가 되어 청록의 3은 틀려져요. 숫자를 쓰고 싶은 마음을 참고 X를 쓰는 것이 이길 때도 있어요!',
          style: TextStyle(fontSize: 15, height: 1.55),
        ),
      ),
      lessonP('예언 게임에서는 이런 줄이 자주 나와요. 내 숫자가 맞게 만들려면 이 줄이 몇 개로 끝날지를 미리 생각하고, 상대의 선택까지 읽어야 해요.'),
    ];

/// "바보" 문장이 말하는 글자들의 실제 개수 (문장에 나오는 알파벳과 부호만, 칩에 보일 이름으로).
Map<String, int> _foolTally() {
  final letters = charTally(kSallowsFoolSentence, [for (var c = 0x61; c <= 0x7A; c++) String.fromCharCode(c)])..removeWhere((_, v) => v == 0);
  final marks = charTally(kSallowsFoolSentence, [',', '’', '-', '!']);
  return {
    ...letters,
    '쉼표 ,': marks[',']!,
    '어포스트로피 ’': marks['’']!,
    '하이픈 -': marks['-']!,
    '느낌표 !': marks['!']!,
  };
}
