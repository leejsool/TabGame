import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../tutorial/lesson_kit.dart';
import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';
import '../core/sprouts_planner.dart';
import '../core/sprouts_topology.dart';
import 'sprouts_lesson_art.dart';
import 'sprouts_painter.dart';
import 'sprouts_screen.dart';

part 'sprouts_lesson_screen_network.dart';

part 'sprouts_lesson_screen_labs.dart';

const Color _accent = Color(0xFF5E9E2F);

/// 콩나물 "교과학습": 게임 속에 숨은 위상수학을 배우고, 바로 게임으로 가 본다.
class SproutsLessonScreen extends StatelessWidget {
  const SproutsLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '콩나물 규칙과 목숨 세기', subtitle: '왜 (3n-1)수 안에 끝날까?', icon: Icons.scatter_plot_rounded, build: _unitRules),
    LessonUnit(title: '모양이 아니라 이어진 관계', subtitle: '위상수학은 "어디와 이어졌나"를 봐요', icon: Icons.gesture_rounded, build: _unitShape),
    LessonUnit(title: '점 + 영역 = 선 + 부분', subtitle: '어떤 판에서도 변하지 않는 식', icon: Icons.calculate_rounded, build: _unitEuler),
    LessonUnit(title: '끝 모양은 벌레들', subtitle: '이·풍뎅이·바퀴·집게벌레·전갈', icon: Icons.bug_report_rounded, build: _unitBugs),
    LessonUnit(title: '같은 네트워크일까?', subtitle: '위상수학은 쓸모가 많아요', icon: Icons.hub_rounded, build: _unitNetwork),
    LessonUnit(title: '컵과 도넛은 같은 모양', subtitle: '구멍의 수가 모양을 정해요', icon: Icons.coffee_rounded, build: _unitCup),
    LessonUnit(title: '위상수학의 세 가지 핵심 개념', subtitle: '위상공간 · 위상동형 · 연결성', icon: Icons.account_tree_rounded, build: _unitPillars),
    LessonUnit(title: '위상수학은 어디에 쓰일까?', subtitle: '데이터·로봇·3D·생명과학', icon: Icons.rocket_launch_rounded, build: _unitUses),
    LessonUnit(title: '뫼비우스의 띠', subtitle: '안쪽도 바깥쪽도 없는 띠', icon: Icons.all_inclusive_rounded, build: _unitMobius),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: _accent,
      heroArt: CustomPaint(painter: SproutsBugPainter(SproutsBug.earwig)),
      heroText: '게임도 하고, 위상수학도 배워요!\n콩나물 속에는 "모양이 변해도 그대로인 것"을 찾는 수학이 숨어 있어요.',
      units: _units,
    );
  }
}

/// 교과학습 화면을 연다.
Future<void> openSproutsLesson(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SproutsLessonScreen()));
}

/// 게임 하러 가기 단추 (점 3개로 바로 시작).
Widget _playButtons(BuildContext context) {
  void play(PlayMode mode) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SproutsScreen(mode: mode, dotCount: 3)));
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

List<Widget> _unitRules(BuildContext context) => [
      lessonP('콩나물(Sprouts)은 점 몇 개로 시작하는 두 사람의 게임이에요. 차례마다 점에서 점으로 곡선을 긋고, 그 선 위에 새 점을 하나 찍어요.'),
      lessonBullets(context, [
        '선은 다른 선이나 자기 자신과 만나면 안 돼요.',
        '점 하나에는 선을 3개까지만 이을 수 있어요. (점 안의 숫자가 앞으로 더 이을 수 있는 선의 수예요)',
        '더 이을 수 없게 되면 끝나고, 마지막으로 수를 둔 사람이 이겨요.',
      ]),
      lessonH(context, '목숨을 세어 보면 보여요'),
      lessonP('점마다 "목숨"이 3개씩 있다고 생각해 봐요. 한 수를 두면 어떻게 될까요?'),
      lessonBullets(context, [
        '곡선의 두 끝 점에서 목숨이 1개씩, 모두 2개를 써요. (한 점으로 돌아오는 고리는 그 점의 목숨 2개를 써요)',
        '새로 찍은 점은 선이 이미 2개 이어져 있으니 목숨이 1개 남아서, 목숨이 1개 늘어요.',
        '그러니 한 수를 둘 때마다 전체 목숨은 정확히 1개씩 줄어요!',
      ]),
      const _LivesCalculator(),
      lessonKey(context, '수를 두려면 목숨이 적어도 2개 필요해서, 게임이 끝났을 때는 목숨이 1개 이상 남아 있어요. 그래서 처음 점이 n개면 아무리 길어도 (3n-1)수 안에 끝나요.'),
      lessonP('반대로 너무 일찍 끝나지도 않아요. 점 n개로 시작하면 적어도 2n수는 두게 된다고 알려져 있어요. (이 앱에서 수많은 판을 끝까지 두어 봐도 그랬어요!)'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitShape(BuildContext context) {
  final dots = [const P(60, 150), const P(340, 150)];
  final boards = [
    demoBoard(dots, [(0, 1, demoCurve(dots[0], dots[1]))]),
    demoBoard(dots, [(0, 1, demoCurve(dots[0], dots[1], bend: 90))]),
    demoBoard(dots, [(0, 1, demoCurve(dots[0], dots[1], bend: -90))]),
    demoBoard(dots, [(0, 1, demoCurve(dots[0], dots[1], bend: 60, shape: 'wave'))]),
  ];
  return [
    lessonP('콩나물에서 곡선이 곧은지, 휘었는지, 구불구불한지는 아무 상관이 없어요. 중요한 것은 "어느 점이 어느 점과 이어졌나"뿐이에요.'),
    lessonArt(
      GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
        children: [
          for (final b in boards)
            CustomPaint(painter: SproutsPainter(board: b, showGrid: false)),
        ],
      ),
      height: 400,
      caption: '모양은 모두 다르지만, 두 점을 잇고 새 점을 찍은 같은 수예요 (위상수학적으로 같아요)',
    ),
    lessonH(context, '위상수학'),
    lessonP('이렇게 "늘이고 구부려도 변하지 않는 성질"을 연구하는 수학이 위상수학이에요. 고무줄로 만든 도형이라고 생각하면 쉬워요. 당겨서 모양이 바뀌어도, 찢거나 붙이지 않는 한 같은 도형으로 봐요.'),
    lessonP('변해도 그대로 남는 성질을 위상 불변량이라고 불러요. 위상수학자들은 늘어나는 풍선, 녹는 아이스크림처럼 계속 모양이 변하는 세계에서 "끝까지 변하지 않는 것"을 찾아내요.'),
    lessonH(context, '고무판 기하학'),
    lessonP('위상수학은 영어로 Topology라고 해요. 물체가 고무로 되어 있다고 생각하고 연구해서 "고무판 기하학"이라고도 불러요.'),
    Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _accent.withValues(alpha: 0.35))),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(inside: BorderSide(color: _accent.withValues(alpha: 0.2))),
        columnWidths: const {0: FlexColumnWidth(1.0), 1: FlexColumnWidth(1.6), 2: FlexColumnWidth(1.6)},
        children: [
          _tableRow(['', '학교에서 배운 기하학', '위상수학'], header: true),
          _tableRow(['중요한 것', '변의 길이, 각도, 넓이', '이어진 관계, 구멍의 수']),
          _tableRow(['바꿔도 되나?', '길이나 각이 바뀌면 다른 도형', '늘이기·줄이기·구부리기·비틀기는 OK']),
          _tableRow(['안 되는 것', '(자와 각도기로 재서 달라지면 다름)', '찢거나 붙이기']),
        ],
      ),
    ),
    lessonKey(context, '겉모습이 달라도 본질적인 구조(이어진 관계)가 같으면 같은 형태로 봐요.'),
    lessonKey(context, '그렇다고 모든 수가 똑같은 건 아니에요. 점 2개로 시작하는 판만 해도, 둘째 수까지 가면 위상수학적으로 서로 다른 선택지가 여섯 가지나 돼요. 거기서부터 자유도가 크게 늘어나요.'),
  ];
}

List<Widget> _unitEuler(BuildContext context) => [
      lessonP('콩나물 판에서 이 네 가지를 세어 봐요.'),
      lessonBullets(context, [
        '점: 점의 수 (새로 찍힌 점도 포함)',
        '선: 점과 점 사이의 선. 곡선 하나는 그 위의 새 점 때문에 선 둘로 세요.',
        '부분: 서로 이어진 덩어리의 수 (아직 아무것도 안 이은 점도 하나의 덩어리)',
        '영역: 선으로 빙 둘러싸인 빈 공간의 수 (바깥은 빼요)',
      ]),
      lessonP('신기하게도 어떤 판이든 어느 수에서든 항상 다음 식이 맞아요.'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withValues(alpha: 0.45)),
        ),
        child: const FittedBox(
          child: Text('점 + 영역 = 선 + 부분', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ),
      ),
      lessonP('아래에서 직접 확인해 보세요. "한 수 두기"를 누르면 컴퓨터가 곡선을 그어요. 숫자가 바뀌어도 양쪽은 늘 같아요.'),
      const _EulerPlayground(),
      lessonKey(context, '이 식은 점 2개로 시작하든 200만 개로 시작하든 똑같이 맞아요. 거칠어 보이는 모양 밑에 깔린 변하지 않는 규칙을 찾는 것, 이것이 위상수학이에요. (수학에서는 오일러의 공식이라고 불러요)'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitBugs(BuildContext context) => [
      lessonP('콩나물을 가장 적은 수로 끝내는 판은 어떤 모양으로 끝날까요? 수학자 존 콘웨이가 재미있는 사실을 알아냈어요.'),
      lessonKey(context, '가장 빨리 끝난 판은 (대략) 아래 다섯 가지 "벌레" 모양 중 하나로 끝나요. 거기에 "이"가 얼마든지 붙은 모양이에요.', icon: Icons.bug_report_rounded),
      lessonArt(
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              for (final bug in SproutsBug.values)
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: CustomPaint(painter: SproutsBugPainter(bug), size: const Size.square(100))),
                      const SizedBox(height: 4),
                      Text(bug.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        height: 150,
        caption: '(손으로 그린 대략의 모양이에요. 선은 구부려도 같은 모양으로 쳐요)',
      ),
      lessonP('"이"가 붙는다는 건, 끝 모양 어디에든 이런 작은 조각이 감염되듯 더 달라붙을 수 있다는 뜻이에요. 이도 이끼리 서로 옮을 수 있고요. 그만큼 이가 많아서, 콘웨이는 재치 있게 "이가 이토록 많다"고 말했대요.'),
      lessonP('판 모양은 매번 달라 보여도, 위상수학으로 보면 몇 가지 틀로 정리돼요. 이것도 "복잡한 것 밑의 규칙"을 찾는 일이에요.'),
    ];
