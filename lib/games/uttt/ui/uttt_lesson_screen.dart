import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../tutorial/lesson_kit.dart';
import 'uttt_lesson_art.dart';
import 'uttt_screen.dart';

const Color _accent = Color(0xFFD1495B);

/// 궁극 틱택토 "교과학습": 게임 속에 숨은 프랙털을 배우고, 바로 게임으로 가 본다.
class UtttLessonScreen extends StatelessWidget {
  const UtttLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '틱택토 속의 틱택토', subtitle: '게임 규칙을 한 번에 정리해요', icon: Icons.tag_rounded, build: _unitGame),
    LessonUnit(title: '프랙털이란?', subtitle: '작은 부분이 전체와 똑같은 모양', icon: Icons.change_history_rounded, build: _unitWhat),
    LessonUnit(title: '자연은 프랙털의 정원', subtitle: '나무·강·해안선·구름·산·내 허파', icon: Icons.park_rounded, build: _unitNature),
    LessonUnit(title: '궁극 틱택토는 프랙털!', subtitle: '9칸 → 81칸 → 729칸', icon: Icons.grid_on_rounded, build: _unitGameFractal),
    LessonUnit(title: '두 가지 눈높이 전략', subtitle: '작은 판도 보고, 큰 판도 보기', icon: Icons.psychology_rounded, build: _unitStrategy),
    LessonUnit(title: '이름과 변형 규칙', subtitle: '슈퍼 틱택토? 다수결 규칙?', icon: Icons.menu_book_rounded, build: _unitNames),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: _accent,
      heroArt: const CustomPaint(painter: TicTacToeFractalPainter(3, highlight: false)),
      heroText: '게임도 하고, 프랙털도 배워요!\n궁극 틱택토에는 "작은 부분이 전체를 닮은" 신기한 구조가 숨어 있어요.',
      units: _units,
    );
  }
}

/// 교과학습 화면을 연다.
Future<void> openUtttLesson(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UtttLessonScreen()));
}

/// 게임 하러 가기 단추 (교과학습 → 바로 CPU 대결/둘이서).
Widget _playButtons(BuildContext context) {
  void play(PlayMode mode) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UtttScreen(mode: mode)));
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
      lessonP('궁극 틱택토는 "틱택토 판 안에 틱택토 판이 들어 있는" 게임이에요. 큰 판 한 개 안에 작은 판이 9개, 모두 81칸이에요.'),
      lessonArt(CustomPaint(painter: const TicTacToeFractalPainter(2)), height: 280, caption: '노란 테두리 = 작은 판 하나 (큰 판과 똑같이 생겼어요)'),
      lessonH(context, '규칙 한눈에 보기'),
      lessonBullets(context, [
        '작은 판에서 세 칸을 한 줄로 이으면 그 작은 판을 차지해요.',
        '내가 둔 칸의 위치가 곧 상대가 다음에 둘 작은 판이에요. (오른쪽 위 칸에 뒀다면 상대는 오른쪽 위 판에서 둬요)',
        '보내진 판이 이미 끝났으면 상대는 아무 판에서나 둘 수 있어요.',
        '차지한 작은 판 세 개를 큰 판에서 한 줄로 이으면 이겨요!',
        '작은 판이 가득 찼는데 줄이 없으면 아무도 차지하지 못하는 무승부 판이 돼요.',
      ]),
      lessonKey(context, '규칙이 "작은 판"과 "큰 판" 두 군데에서 똑같이 쓰여요. 이게 이 게임이 프랙털인 이유예요. 뒤 단원에서 자세히 알아봐요.'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitWhat(BuildContext context) => [
      lessonP('프랙털(fractal)은 "작은 부분이 전체와 똑같은 모양"이 끝없이 되풀이되는 도형이에요. 이것을 자기 유사성이라고 해요.'),
      lessonP('규칙은 아주 간단해요. 한 가지 규칙을 정하고, 그 규칙을 그림의 작은 부분에 계속 똑같이 적용하기만 하면 돼요.'),
      lessonH(context, '시에르핀스키 삼각형'),
      lessonP('삼각형을 작은 삼각형 3개로 나누고, 그 3개를 다시 3개씩으로… 단계를 올려 보세요. 아무 모서리의 작은 삼각형을 확대해도 전체와 똑같아요.'),
      LessonDepthExplorer(
        painter: (d) => SierpinskiTrianglePainter(d),
        minDepth: 0,
        maxDepth: 6,
        initial: 3,
        caption: (d) => '단계 $d: 작은 삼각형 ${_pow(3, d)}개',
      ),
      lessonH(context, '시에르핀스키 카펫'),
      lessonP('정사각형을 3×3 아홉 칸으로 나누고 한가운데 칸을 비워요. 남은 여덟 칸에 같은 일을 되풀이해요. 틱택토 판처럼 3×3이 쓰이는 게 눈에 띄죠?'),
      LessonDepthExplorer(
        painter: (d) => SierpinskiCarpetPainter(d),
        minDepth: 0,
        maxDepth: 4,
        initial: 2,
        caption: (d) => '단계 $d: 남은 작은 정사각형 ${_pow(8, d)}개',
      ),
      lessonH(context, '코흐 눈송이'),
      lessonP('선분을 3등분해서 가운데에 뾰족한 봉우리를 세워요. 모든 선분에 이 일을 되풀이하면 둘레가 점점 들쭉날쭉해져요.'),
      LessonDepthExplorer(
        painter: (d) => KochSnowflakePainter(d),
        minDepth: 0,
        maxDepth: 5,
        initial: 3,
        caption: (d) => '단계 $d: 선분 ${3 * _pow(4, d)}개',
      ),
      lessonKey(context, '프랙털의 비밀: 큰 그림도, 그 안의 작은 그림도, 그 안의 더 작은 그림도 같은 모양이에요. 어디를 확대해도 닮았어요.'),
    ];

List<Widget> _unitNature(BuildContext context) => [
      lessonP('프랙털은 수학책 속에만 있는 게 아니에요. 우리 둘레의 자연이 프랙털로 가득해요.'),
      lessonH(context, '나뭇가지'),
      lessonP('가지 끝마다 더 작은 가지가 갈라져요. 가지 하나만 떼어 놓고 봐도 작은 나무 같아요.'),
      LessonDepthExplorer(
        painter: (d) => BranchingTreePainter(d),
        minDepth: 1,
        maxDepth: 9,
        initial: 6,
        caption: (d) => '단계 $d: 가지 끝 ${_pow(2, d)}개',
      ),
      lessonH(context, '이런 것도 프랙털 닮은꼴이에요'),
      lessonBullets(context, [
        '강: 큰 강에서 시내로, 시내에서 개울로… 갈라지는 모양이 나뭇가지와 닮았어요.',
        '해안선: 지도로 보든 사진 가까이서 보든 들쭉날쭉한 모양이 비슷해서, 축척(지도의 크기 비율)을 알기 어려워요.',
        '구름: 큰 덩어리 둘레에 작은 덩어리, 그 둘레에 더 작은 덩어리가 몽글몽글 붙어 있어요.',
        '산과 바위: 큰 바위 위에 작은 바위, 그 위에 더 작은 바위가 쌓여 있어요.',
        '내 허파: 기관지가 갈라지고 또 갈라져서 맨 끝의 작은 풍선(폐포)까지 이어져요. 평균 스물세 번쯤 갈라진다고 해요. 우리는 프랙털로 숨 쉬고 있는 셈이에요!',
      ]),
      lessonH(context, '유클리드 세계 vs 실제 세계'),
      lessonP('학교에서 배우는 도형(원, 삼각형, 직선)은 매끈해요. 하지만 실제 구름은 동그랗지 않고, 산은 원뿔이 아니고, 나무껍질은 매끄럽지 않아요. 아래 그림을 비교해 보세요.'),
      Row(
        children: [
          Expanded(
            child: Column(
              children: [
                lessonArt(CustomPaint(painter: const EuclidSceneAmbient(fractal: false)), height: 150),
                const Text('유클리드 세계\n(원·삼각형)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                lessonArt(CustomPaint(painter: const EuclidSceneAmbient(fractal: true)), height: 150),
                const Text('프랙털 세계\n(들쭉날쭉)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      lessonH(context, '프랙털을 이름 붙여 준 사람'),
      lessonP('이런 들쭉날쭉한 모양들은 오랫동안 "수학의 골칫덩이"로 여겨져 누구도 한데 묶어 보지 않았어요. 20세기에 수학자 브누아 망델브로가 이것들을 한데 모아 "프랙털"이라는 이름을 붙이고 연구하기 시작했어요. 그는 "구름은 구가 아니고, 산은 원뿔이 아니며, 해안선은 원이 아니다"라고 말했다고 해요.'),
      lessonKey(context, '자연의 모양은 자와 컴퍼스로 그린 도형보다 프랙털에 훨씬 가까워요!'),
    ];

List<Widget> _unitGameFractal(BuildContext context) => [
      lessonP('틱택토는 3×3, 아홉 칸이에요. 그런데 각 칸 안에 또 틱택토 판을 넣으면 어떻게 될까요? 단계를 올려 보세요.'),
      LessonDepthExplorer(
        painter: (d) => TicTacToeFractalPainter(d),
        minDepth: 1,
        maxDepth: 3,
        initial: 2,
        height: 300,
        caption: (d) {
          final side = _pow(3, d);
          final name = d == 1 ? '보통 틱택토' : d == 2 ? '궁극 틱택토' : '한 단계 더 깊이';
          return '단계 $d · $name\n한 줄에 $side칸, 모두 ${_pow(9, d)}칸 (굵은 선 = 큰 판, 얇은 선 = 작은 판)';
        },
      ),
      lessonH(context, '어디가 프랙털일까?'),
      lessonBullets(context, [
        '작은 판 하나는 큰 판과 똑같은 모양(3×3)이에요.',
        '작은 판에서 쓰는 규칙(세 칸 한 줄)을 큰 판에서도 똑같이 써요.',
        '이런 "닮은 층"이 세 겹 이상 되풀이되면 프랙털이라고 부를 만하다는 설명이 있어요. 큰 판 → 작은 판 → 칸, 이렇게 틱택토가 틱택토의 틱택토가 되어 있으니 자격이 충분해요.',
      ]),
      lessonH(context, '자연 프랙털과 다른 점'),
      lessonP('자연의 나무는 가지가 무한히 갈라지지 않고 몇 번 갈라지다 끝나요. 궁극 틱택토도 2단계에서 멈춘 "사람이 만든 프랙털"이에요. 원한다면 한 단계 더 깊이 들어가 729칸짜리 판을 만들 수도 있겠죠? 다만 그 판은 사람이 두기엔 너무 클지도 몰라요.'),
      lessonKey(context, '프랙털 구조에서는 "작은 것도 소우주, 큰 것도 대우주"예요. 크기가 달라도 같은 규칙이 되풀이돼요.'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitStrategy(BuildContext context) => [
      lessonP('프랙털 게임에서는 눈높이가 두 가지예요. 눈앞의 작은 판과, 전체를 이루는 큰 판이에요. 이 둘이 서로 부딪치는 게 궁극 틱택토의 가장 큰 재미예요.'),
      lessonH(context, '작은 판에서의 좋은 수가 큰 판에서는 실수일 수 있어요'),
      lessonP('보통 틱택토에서는 한가운데 칸이 가장 좋은 칸이에요. 그런데 궁극 틱택토에서는 작은 판의 한가운데 칸에 두면 상대가 큰 판의 한가운데 판에서 둘 차례가 돼요. 상대에게 가장 좋은 판을 선물하는 셈일 수 있어요.'),
      lessonBullets(context, [
        '내가 둘 칸은 곧 "상대를 어느 판으로 보낼지"를 고르는 일이에요.',
        '상대가 이미 한 줄 직전인 판으로 보내면 위험해요. 그 판에서 바로 이기거나 차지당할 수 있어요.',
        '이미 끝난 판으로 보내면 상대는 "아무 데나" 둘 수 있어서, 오히려 상대에게 자유를 줘요.',
        '큰 판에서 이어질 줄(가운데·모서리 판)을 생각하며 작은 판을 하나씩 차지해 가세요.',
      ]),
      lessonH(context, '세계적으로 생각하고, 지역적으로 행동하기'),
      lessonP('큰 판 전체의 흐름(세계)을 보면서, 지금 둘 작은 판(지역)에서 최선의 수를 두는 균형이 필요해요. 작은 판 하나를 이기려다 큰 판을 내주면 지는 게임이에요.'),
      lessonKey(context, '작은 이득 하나가 큰 손해가 될 수 있어요. 한 수를 두기 전에 "이 칸이 상대를 어디로 보낼까?"를 꼭 물어보세요.', icon: Icons.psychology_alt_rounded),
      const SizedBox(height: 6),
      lessonP('배운 대로 전략을 시험해 보세요!'),
      _playButtons(context),
    ];

List<Widget> _unitNames(BuildContext context) => [
      lessonH(context, '여러 가지 이름'),
      lessonP('이 게임에는 이름이 아주 많아요. 슈퍼 틱택토, 전략적 틱택토, 메타 틱택토, 틱택틱택토토, 프랙털 틱택토… 그 가운데 "궁극 틱택토"라는 이름이 가장 널리 자리 잡았다고 해요. 이 이름은 미국의 한 고등학교 학생들이 붙였다고 알려져 있어요.'),
      lessonH(context, '규칙이 조금씩 다른 변형들'),
      lessonP('이 게임은 규칙을 바꿔 새로운 게임으로 만들기에 좋아요. 승리 조건만 바꿔도 전략이 확 달라져요.'),
      Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('기본 규칙 (이 앱)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 4),
              Text('작은 판을 차지해서 큰 판에서 한 줄을 이으면 승리.', style: TextStyle(fontSize: 15.5, height: 1.5)),
              Divider(height: 22),
              Text('단일 승리', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 4),
              Text('작은 판 하나를 먼저 차지하는 쪽이 곧바로 이겨요. 게임이 훨씬 빨리 끝나요.', style: TextStyle(fontSize: 15.5, height: 1.5)),
              Divider(height: 22),
              Text('다수결 규칙', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 4),
              Text('상대보다 더 많은 작은 판을 차지하는 쪽이 이겨요. 어느 판인지(배열)는 상관없고 개수만 세요.', style: TextStyle(fontSize: 15.5, height: 1.5)),
              Divider(height: 22),
              Text('9개 중 5개', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 4),
              Text('줄을 잇는 대신, 아홉 개의 작은 판 중 다섯 개를 먼저 차지해야 이기는 변형도 있어요.', style: TextStyle(fontSize: 15.5, height: 1.5)),
            ],
          ),
        ),
      ),
      lessonKey(context, '승리 조건이 바뀌면 "어떤 판이 중요한가"도 바뀌어요. 다수결에서는 가운데 판이 특별하지 않고, 개수만 중요해요.'),
    ];

List<Widget> _unitQuiz(BuildContext context) => [
      lessonP('배운 내용을 확인해 봐요. 보기를 고르면 바로 정답과 설명이 나와요.'),
      const LessonQuiz(
        question: '프랙털의 가장 큰 특징은 무엇일까요?',
        options: ['모서리가 모두 직각이다', '작은 부분이 전체와 닮은 모양이 되풀이된다', '항상 원 모양이다'],
        answer: 1,
        explain: '작은 부분을 확대하면 전체와 같은 모양이 나와요. 이것을 자기 유사성이라고 해요.',
      ),
      const LessonQuiz(
        question: '궁극 틱택토의 큰 판에는 작은 판이 몇 개, 칸은 모두 몇 개일까요?',
        options: ['작은 판 3개, 칸 27개', '작은 판 9개, 칸 81개', '작은 판 81개, 칸 729개'],
        answer: 1,
        explain: '3×3 판의 아홉 칸마다 3×3 판이 들어 있으니 9개의 작은 판, 9×9 = 81칸이에요.',
      ),
      const LessonQuiz(
        question: '내가 어느 작은 판의 "왼쪽 아래" 칸에 두었어요. 상대는 다음에 어디서 두어야 할까요? (보내진 판이 끝나지 않았다면)',
        options: ['큰 판의 왼쪽 아래 판', '내가 둔 바로 그 작은 판', '아무 판이나'],
        answer: 0,
        explain: '내가 둔 칸의 위치가 곧 상대가 둘 작은 판이에요. 왼쪽 아래 칸 → 큰 판의 왼쪽 아래 판!',
      ),
      const LessonQuiz(
        question: '상대를 보낸 판이 이미 끝나 있다면?',
        options: ['상대는 한 번 쉰다', '상대는 아무 판에서나 둘 수 있다', '내가 한 번 더 둔다'],
        answer: 1,
        explain: '끝난 판으로 보내면 상대에게 자유를 주게 돼요. 전략적으로 조심해야 해요.',
      ),
      const LessonQuiz(
        question: '다음 중 프랙털 모양에 가장 가까운 것은?',
        options: ['자로 그은 직선', '나뭇가지가 갈라지는 모양', '컴퍼스로 그린 원'],
        answer: 1,
        explain: '나뭇가지는 가지마다 더 작은 가지로 갈라지며 같은 모양이 되풀이돼요. 강, 번개, 허파의 기관지도 마찬가지예요.',
      ),
      lessonH(context, '이제 직접 해 보세요!'),
      _playButtons(context),
    ];

int _pow(int base, int exp) {
  var r = 1;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
