part of 'sprouts_lesson_screen.dart';

// 연결 단원 내용 (파일을 역할별로 나눈 것)

List<Widget> _unitNetwork(BuildContext context) {
  List<Offset> ring(List<int> order) {
    // 오각형 꼭짓점 5개에 번호를 order 순서로 놓는다
    final pos = <Offset>[
      for (var k = 0; k < 5; k++) Offset(0.5 + 0.38 * cos(-pi / 2 + k * 2 * pi / 5), 0.52 + 0.38 * sin(-pi / 2 + k * 2 * pi / 5)),
    ];
    return [for (var i = 0; i < 5; i++) pos[order[i]]];
  }

  const cycle = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)];
  final a = ring([0, 1, 2, 3, 4]); // 오각형
  final b = ring([0, 2, 4, 1, 3]); // 같은 고리를 별 모양으로 펼친 것
  const other = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 1)]; // 다른 네트워크
  final c = ring([0, 1, 2, 3, 4]);
  Widget panel(List<Offset> nodes, List<(int, int)> edges, String label) => Expanded(
        child: Column(
          children: [
            Expanded(child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: GraphPainter(nodes, edges)))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
  return [
    lessonP('위상수학에서 유명한 문제가 있어요. 점과 선으로 된 두 그림이 있을 때, 겉모습은 달라도 사실은 같은 네트워크(같은 이어짐)인지 알아내는 거예요. 이것을 그래프 동형 문제라고 해요.'),
    lessonP('콩나물에서도 서로 다른 곳에 놓인 것처럼 보이는 판이 실은 같은 구조일 수 있어요. 아래 세 그림에서 같은 네트워크는 어느 것일까요?'),
    lessonArt(
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            panel(a, cycle, '가'),
            const SizedBox(width: 8),
            panel(b, cycle, '나'),
            const SizedBox(width: 8),
            panel(c, other, '다'),
          ],
        ),
      ),
      height: 150,
    ),
    const LessonQuiz(
      question: '"가"와 같은 네트워크(같은 이어짐)는?',
      options: ['나', '다', '둘 다'],
      answer: 0,
      explain: '"가"는 점 5개가 한 바퀴로 이어진 고리예요. "나"는 같은 고리를 별 모양으로 펼쳐 그린 것일 뿐이에요. "다"는 한 점에 선이 3개 모이고 다른 점은 1개라서 달라요.',
    ),
    lessonKey(context, '이런 "이어짐 비교"는 실제로 회로도, 컴퓨터, 화학, 지도(도로망) 등 곳곳에서 쓰여요. 자세한 쓰임새는 뒤의 "위상수학은 어디에 쓰일까?" 단원에서 봐요.'),
  ];
}

List<Widget> _unitCup(BuildContext context) => [
      lessonP('위상수학자는 커피잔과 도넛을 같은 모양이라고 해요. 정말일까요? 찰흙으로 손잡이 달린 컵을 만들었다고 생각해 봐요. 찢거나 붙이지 않고 주무르기만 해서 도넛으로 만들 수 있어요.'),
      lessonArt(
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              for (final (i, label) in const ['컵', '', '', '', '도넛'].indexed)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: CustomPaint(painter: CupToDonutPainter(i / 4), size: const Size.square(100))),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        height: 130,
        caption: '컵 몸통이 점점 납작해지고, 손잡이가 몸통으로 번져서 도넛이 돼요 (구멍은 늘 하나!)',
      ),
      lessonH(context, '구멍이 몇 개인가?'),
      lessonP('찢거나 붙이지 않고 변형할 수 있는 두 모양은 위상수학에서 "같은 모양"이에요. 이때 변하지 않고 남는 것이 구멍의 수예요.'),
      lessonBullets(context, [
        '손잡이 달린 컵 = 구멍 1개 (손잡이 구멍). 컵 속의 오목한 곳은 구멍이 아니에요. 뚫려 있지 않거든요.',
        '도넛 = 구멍 1개. 그래서 컵과 도넛은 같은 모양이에요.',
        '공(구) = 구멍 0개. 컵이나 도넛과는 달라요. 손잡이를 없애려면 찢거나 붙여야 해요.',
        '안경테 = 구멍 2개. 구멍이 3개, 4개… 도 있어요.',
      ]),
      lessonP('다만 실제 도넛이나 단단한 머그컵을 정말로 주무른다는 뜻은 아니에요. 물체가 고무처럼 자유롭게 늘어난다고 정해 놓고 생각하는 수학적 사고실험이에요. 이렇게 끊거나 붙이지 않고 연속적으로 변형해서 서로 바꿀 수 있는 관계를 "위상동형"이라고 불러요.'),
      lessonKey(context, '구멍의 수는 위상수학에서 가장 대표적인 "변하지 않는 값(위상 불변량)"이에요. 콩나물에서 선이 닫혀 둘러싸인 영역(빈 공간)의 수를 세는 것과 닮았어요.'),
      lessonH(context, '구멍의 수와 오일러 공식'),
      lessonP('앞에서 본 "점 + 영역 = 선 + 부분" 식은 평평한 판에서의 이야기예요. 입체 도형에서도 비슷한 식이 있어요. 꼭짓점 수에서 모서리 수를 빼고 면의 수를 더한 값(오일러 특성)은 구멍이 g개인 모양이면 늘 2-2g예요.'),
      lessonBullets(context, [
        '구멍 0개(공, 정육면체 같은 도형): 2',
        '구멍 1개(도넛, 컵): 0',
        '구멍 2개(안경테): -2',
      ]),
      lessonP('정육면체는 꼭짓점 8, 모서리 12, 면 6이라 8 - 12 + 6 = 2예요. 겉모습이 아무리 달라도 구멍 수가 같으면 이 값이 같아요.'),
      const LessonQuiz(
        question: '손잡이 달린 머그컵과 위상수학적으로 같은 모양은?',
        options: ['도넛 (구멍 1개)', '공 (구멍 없음)', '안경테 (구멍 2개)'],
        answer: 0,
        explain: '머그컵은 손잡이 구멍이 1개예요. 도넛도 구멍이 1개라서, 찢거나 붙이지 않고 주물러 서로 바꿀 수 있어요.',
      ),
    ];

List<Widget> _unitPillars(BuildContext context) => [
      lessonP('위상수학을 이해할 때 꼭 알아야 할 기초 개념은 세 가지예요.'),
      _pillarCard(context, '1', '위상공간', '"얼마나 가까운가"를 자로 재는 거리에 기대지 않고, "열린집합"이라는 도구로 정해요. 거리가 없어도 점과 공간의 관계(어디가 이웃인지)를 말할 수 있게 해 주는 틀이에요.'),
      _pillarCard(context, '2', '위상동형', '서로 다른 두 공간이 연속적인 변형으로 같아질 수 있는 관계예요. 두 모양이 본질적으로 같은지 판단하는 기준이고, 컵과 도넛이 바로 이 관계예요.'),
      _pillarCard(context, '3', '연결성과 콤팩트성', '연결성은 공간이 여러 조각으로 끊어지지 않고 하나로 이어져 있는지를, 콤팩트성은 복잡한 공간을 한정된 범위 안에서 효율적으로 다룰 수 있는지를 나타내요.'),
      lessonH(context, '콩나물에서 찾아보기'),
      lessonBullets(context, [
        '연결성: "점 + 영역 = 선 + 부분"의 부분이 바로 "이어진 덩어리의 수"예요. 서로 다른 덩어리의 점을 이으면 두 덩어리가 하나로 합쳐져요.',
        '위상동형: 곡선을 어떻게 그렸는지는 중요하지 않고, 어느 점이 어느 점과 이어졌는지(이어진 구조)만 같으면 같은 판이에요. 이 앱이 점과 선을 살짝 밀어서 자리를 만드는 것도 같은 판을 늘이고 구부리는 일이에요.',
        '위상공간: "같은 영역 안에 있는 점끼리만 이을 수 있다"는 규칙은, 거리가 아니라 영역(이웃)이 이어져 있는지로 정해져요.',
      ]),
      lessonKey(context, '공간의 본질적인 구조를 이해하는 데 꼭 필요한 개념들이에요. 낯설어 보여도 게임 안에서 이미 쓰고 있었어요!'),
      const LessonQuiz(
        question: '콩나물의 "점 + 영역 = 선 + 부분"에서 "부분"과 가장 닮은 위상수학 개념은?',
        options: ['연결성 (이어진 덩어리)', '콤팩트성', '넓이'],
        answer: 0,
        explain: '부분은 서로 이어진 덩어리의 수예요. 공간이 하나로 이어져 있는지 보는 연결성과 같은 생각이에요.',
      ),
    ];

Widget _pillarCard(BuildContext context, String no, String title, String body) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 6),
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, backgroundColor: _accent, child: Text(no, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

TableRow _tableRow(List<String> cells, {bool header = false}) {
  return TableRow(
    decoration: header ? BoxDecoration(color: _accent.withValues(alpha: 0.12)) : null,
    children: [
      for (final (i, c) in cells.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Text(
            c,
            style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: header || i == 0 ? FontWeight.w800 : FontWeight.w500),
          ),
        ),
    ],
  );
}

List<Widget> _unitUses(BuildContext context) => [
      lessonP('"이렇게 추상적인 수학이 어디에 쓰일까?" 싶지만, 위상수학은 현대 첨단 기술의 바탕이에요. 복잡한 대상의 세세한 모양이 아니라 "이어진 관계와 본질적인 구조"를 보는 데 아주 유리하기 때문이에요.'),
      _useTile(context, Icons.query_stats_rounded, '데이터 분석 · 머신러닝', '수많은 숫자로 된 고차원 데이터가 어떤 "모양"(덩어리, 고리, 구멍)을 이루는지 살펴서 패턴을 찾아요.'),
      _useTile(context, Icons.smart_toy_rounded, 'AI · 로봇공학', '로봇이 장애물을 피해 목적지까지 가는 경로를 설계해요. "장애물 사이로 어느 길이 이어지나"는 위상 문제예요. 이 게임의 CPU가 선에 닿지 않는 길을 찾는 것도 같은 종류의 문제예요.'),
      _useTile(context, Icons.view_in_ar_rounded, '3D 모델링 · 컴퓨터 그래픽스', '입체 캐릭터를 늘리거나 구부려도 그물(망) 구조가 깨지지 않게 다뤄요. 토끼 모양이 변해도 이어진 구조는 그대로예요.'),
      _useTile(context, Icons.hub_rounded, '네트워크 분석', '통신망, 도로망, 인간관계 같은 지점 사이의 연결 구조를 효과적으로 분석해요.'),
      _useTile(context, Icons.biotech_rounded, '생명과학 · 물리학', 'DNA가 꼬이는 복잡한 구조, 단백질이 접히는 현상, 우주 공간의 형태를 연구하는 데 활발히 쓰여요.'),
      lessonKey(context, '크기나 겉모습처럼 쉽게 변하는 것이 아니라, 변해도 남는 "본질적인 구조"를 보는 수학이라서 쓰임새가 넓어요.'),
      const LessonQuiz(
        question: '위상수학이 로봇의 이동 경로 설계에 도움이 되는 이유로 가장 알맞은 것은?',
        options: ['장애물 사이로 어느 길이 이어져 있는지(연결 구조)를 다루기 때문', '로봇의 색을 정해 주기 때문', '로봇의 무게를 재기 때문'],
        answer: 0,
        explain: '위상수학은 길이보다 "이어진 관계"를 봐요. 장애물을 피해 갈 수 있는 길이 이어져 있는지가 경로 설계의 핵심이에요.',
      ),
    ];

Widget _useTile(BuildContext context, IconData icon, String title, String body) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(backgroundColor: _accent.withValues(alpha: 0.14), child: Icon(icon, color: _accent)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(body, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

List<Widget> _unitMobius(BuildContext context) => [
      lessonP('많은 사람이 처음 만나는 위상수학은 뫼비우스의 띠예요. 종이 띠를 반 바퀴 비틀어서 양쪽 끝을 붙이면 돼요. 아래에서 돌려 보세요.'),
      const _MobiusLab(),
      lessonBullets(context, [
        '뫼비우스의 띠에는 "안쪽"과 "바깥쪽"이 따로 없어요. 한 면을 따라가면 어느새 반대쪽에 와 있어요.',
        '그래서 팔찌처럼 장식하려고 안쪽은 파랑, 바깥쪽은 빨강으로 칠하려 하면 실패해요. 어느 색으로 시작해도 결국 띠 전체가 한 색이 돼요.',
        '이건 뫼비우스의 띠가 가진 여러 특징 중 하나일 뿐이에요.',
      ]),
      lessonH(context, '생각해 보세요'),
      lessonP('뫼비우스의 띠를 가운데를 따라 가위로 자르면 어떻게 될까요? 3등분하면 또 어떻게 될까요? 종이 띠로 직접 만들어 잘라 보면 깜짝 놀랄 거예요.'),
      lessonH(context, '위상수학은 아름다워요'),
      lessonP('수학자 데이비드 리치슨은 수학에서 가장 유명한 상인 필즈상 수상자들을 조사했어요. 그의 집계에 따르면 48명의 수상자 중 약 3분의 1이 위상수학 연구로 상을 받았고, 가까운 분야에서 공헌한 수상자까지 포함하면 훨씬 더 많다고 해요.'),
      lessonKey(context, '아름다움이 "단순함과 복잡함의 결혼"에서 나온다면, 콩나물은 틀림없이 가장 예쁨을 받는 아이일 거예요. 규칙은 단순한데 판은 끝없이 복잡해지니까요!', icon: Icons.favorite_rounded),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitQuiz(BuildContext context) => [
      lessonP('배운 내용을 확인해 봐요. 보기를 고르면 바로 정답과 설명이 나와요.'),
      const LessonQuiz(
        question: '콩나물에서 한 수를 둘 때마다 전체 "목숨"(더 이을 수 있는 선의 수의 합)은 어떻게 될까요?',
        options: ['1개 줄어든다', '2개 줄어든다', '그대로다'],
        answer: 0,
        explain: '곡선의 두 끝에서 목숨 2개를 쓰고, 새 점이 목숨 1개를 더해서 모두 1개 줄어요.',
      ),
      const LessonQuiz(
        question: '점 4개로 시작한 콩나물은 아무리 길어도 몇 수 안에 끝날까요?',
        options: ['8수', '11수', '12수'],
        answer: 1,
        explain: '(3n-1)수예요. 3×4-1 = 11수. 처음 목숨은 12개이고 한 수에 1개씩 줄며, 끝났을 때 1개 이상 남아요.',
      ),
      const LessonQuiz(
        question: '위상수학에서 두 도형을 "같다"고 볼 수 있는 경우는?',
        options: ['늘이고 구부려서 한 도형이 다른 도형이 될 때 (찢거나 붙이지 않고)', '크기와 각도가 똑같을 때만', '색이 같을 때'],
        answer: 0,
        explain: '위상수학은 고무줄 도형처럼 늘이고 구부려도 변하지 않는 성질을 봐요. 곡선 모양이 달라도 같은 수로 치는 콩나물과 같아요.',
      ),
      const LessonQuiz(
        question: '어떤 콩나물 판에서든 항상 맞는 식은?',
        options: ['점 + 선 = 영역 + 부분', '점 + 영역 = 선 + 부분', '점 - 영역 = 선 - 부분 + 1'],
        answer: 1,
        explain: '점 + 영역 = 선 + 부분 이에요. (점 3, 선 2, 영역 0, 부분 1이면 3+0 = 2+1 이 맞죠!)',
      ),
      const LessonQuiz(
        question: '위상수학의 다른 이름으로 알맞은 것은?',
        options: ['고무판 기하학', '삼각형 기하학', '자와 컴퍼스 기하학'],
        answer: 0,
        explain: '물체가 고무처럼 늘고 구부러진다고 보고 연구해서 "고무판 기하학"이라고도 불러요.',
      ),
      const LessonQuiz(
        question: '위상수학에서 길이·각도보다 더 중요하게 보는 것은?',
        options: ['이어진 관계와 구멍의 수', '색깔', '무게'],
        answer: 0,
        explain: '위상수학은 늘이고 구부려도 변하지 않는 "연결 상태"와 "구멍의 수"를 중요하게 봐요.',
      ),
      const LessonQuiz(
        question: '정육면체(꼭짓점 8, 모서리 12, 면 6)의 오일러 특성 "꼭짓점 - 모서리 + 면"은?',
        options: ['2', '0', '-2'],
        answer: 0,
        explain: '8 - 12 + 6 = 2예요. 구멍이 없는 모양(공과 같은 모양)은 늘 2이고, 구멍이 g개면 2 - 2g예요.',
      ),
      const LessonQuiz(
        question: '뫼비우스의 띠에 대한 설명으로 맞는 것은?',
        options: ['안쪽과 바깥쪽이 따로 없다', '반드시 두 개의 면이 있다', '종이를 비틀지 않고 붙인 것이다'],
        answer: 0,
        explain: '반 바퀴 비틀어 붙인 띠는 한 면을 따라가면 반대쪽까지 이어져서, 안쪽/바깥쪽을 나눌 수 없어요.',
      ),
      lessonH(context, '이제 직접 해 보세요!'),
      _playButtons(context),
    ];
