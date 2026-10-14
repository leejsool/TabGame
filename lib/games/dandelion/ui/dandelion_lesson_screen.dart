import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../tutorial/lesson_kit.dart';
import '../core/dandelion_rules.dart';
import 'dandelion_art.dart';
import 'dandelion_screen.dart';

/// 협력 예시: 바람과 민들레가 힘을 합치면 7송이로 초원을 가득 채울 수 있다.
/// (민들레 1, 바람 1, 민들레 2, 바람 2, … 순서. 불지 않는 방향은 위쪽.)
const List<int> kCoopMoves = [8, 2, 1, 1, 12, 4, 5, 3, 11, 6, 9, 5, 6, 7];

/// "보장된 칸 찾기" 문제: 꽃 칸들과 이미 분 방향들.
class GuaranteeScenario {
  const GuaranteeScenario(this.title, this.flowers, this.used, this.note);

  final String title;
  final List<int> flowers;
  final List<WindDir> used;
  final String note;
}

const List<GuaranteeScenario> kGuaranteeScenarios = [
  GuaranteeScenario('문제 1', [3, 11], [], '꽃이 두 송이 있고, 바람은 아직 한 번도 불지 않았어요.'),
  GuaranteeScenario('문제 2', [12], [], '꽃이 한 송이뿐이에요. 바람은 아직 한 번도 불지 않았어요.'),
  GuaranteeScenario('문제 3', [4, 12, 20], [WindDir.down, WindDir.left], '꽃이 세 송이 있고, 아래쪽과 왼쪽으로는 이미 불었어요.'),
];

const Color _accent = kDandelionColor;
const Color _ink = Color(0xFF333333);
const Color _good = Color(0xFF2E9E4F);
const Color _bad = Color(0xFFD64545);

/// 민들레 "교과학습": 공간 게임이 시간 게임이기도 하다는 것을 배운다.
class DandelionLessonScreen extends StatelessWidget {
  const DandelionLessonScreen({super.key});

  static final List<LessonUnit> _units = [
    LessonUnit(title: '민들레 한눈에 보기', subtitle: '게임 규칙을 한 번에 정리해요', icon: Icons.local_florist_rounded, build: _unitGame),
    LessonUnit(title: '반드시 채워지는 칸', subtitle: '바람이 피할 수 없는 길', icon: Icons.verified_rounded, build: _unitGuaranteed),
    LessonUnit(title: '보장된 칸 찾기', subtitle: '직접 눌러서 확인해요', icon: Icons.search_rounded, build: _unitPuzzle),
    LessonUnit(title: '먼저 심은 꽃이 더 힘이 세요', subtitle: '꽃이 맞는 바람의 횟수', icon: Icons.timelapse_rounded, build: _unitFirst),
    LessonUnit(title: '협력하면 초원이 가득!', subtitle: '시간을 미리 짜 보기', icon: Icons.handshake_rounded, build: _unitCoop),
    LessonUnit(title: '공간 게임은 시간 게임', subtitle: '순서가 곧 전략이에요', icon: Icons.hourglass_bottom_rounded, build: _unitTime),
    LessonUnit(title: '퀴즈로 확인하기', subtitle: '배운 내용을 풀어 봐요', icon: Icons.quiz_rounded, build: _unitQuiz),
  ];

  @override
  Widget build(BuildContext context) {
    return LessonListScreen(
      accent: _accent,
      heroArt: CustomPaint(painter: DandScenePainter(cells: DandState.fromMoves(const [7, 6, 19, 5]).cells)),
      heroText: '게임도 하고, 시간도 배워요!\n민들레는 "공간 게임"처럼 보이지만, 사실은 "시간 게임"이에요.',
      units: _units,
    );
  }
}

/// 교과학습 화면을 연다.
Future<void> openDandelionLesson(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DandelionLessonScreen()));
}

/// 게임 하러 가기 단추 (교과학습 → 바로 CPU 대결/둘이서).
Widget _playButtons(BuildContext context) {
  void play(PlayMode mode) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DandelionScreen(mode: mode)));
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
      lessonP('민들레는 5×5칸 초원에서 "꽃을 심는 민들레"와 "씨앗을 날리는 바람"이 번갈아 두는 게임이에요.'),
      lessonArt(
        CustomPaint(painter: DandScenePainter(cells: DandState.fromMoves(const [7, 6, 19, 5]).cells, windDir: WindDir.downLeft, streaksStatic: true)),
        height: 280,
        caption: '꽃 두 송이에서 왼쪽 아래로 분 바람 (씨앗이 비스듬히 날아가요)',
      ),
      lessonH(context, '규칙 한눈에 보기'),
      lessonBullets(context, [
        '민들레가 먼저 아무 칸에나 꽃을 심어요. (빈칸이나 씨앗 위에 심을 수 있어요)',
        '바람은 방향을 하나 골라요. 모든 꽃에서 그 방향으로 씨앗이 날아가 길에 있는 빈칸을 채워요.',
        '씨앗은 꽃에서만 날아가고, 씨앗에서는 날아가지 않아요.',
        '바람은 8방향 가운데 7방향만 불 수 있어요. 같은 방향은 한 번뿐이고, 빠지는 방향은 딱 하나예요.',
        '일곱 번째 바람이 지난 뒤 초원이 가득 차면 민들레, 한 칸이라도 비면 바람이 이겨요.',
      ]),
      lessonKey(context, '이 게임의 열쇠는 "언제"예요. 어느 칸에 심느냐만큼, 몇 번째 바람 전에 심느냐가 중요해요. 뒤 단원에서 알아봐요.'),
      const SizedBox(height: 6),
      _playButtons(context),
    ];

List<Widget> _unitGuaranteed(BuildContext context) => [
      lessonP('바람은 8방향 가운데 딱 한 방향만 빼고 불어요. 이 사실만으로도 앞으로 일어날 일을 미리 알 수 있어요.'),
      lessonH(context, '두 방향에서 오는 칸'),
      lessonP('아래 초원에는 꽃이 두 송이 있어요. 동그라미 친 칸은 위쪽 꽃의 "아래쪽(남쪽)"이면서, 왼쪽 꽃의 "오른쪽(동쪽)"이에요. 나침반 화살표를 눌러 바람을 불어 보세요.'),
      const _GuaranteeDemo(),
      lessonKey(context, '바람은 아래쪽을 피할 수도, 오른쪽을 피할 수도 있어요. 하지만 둘 다 피할 수는 없어요! 빠지는 방향이 딱 하나뿐이니까요. 그래서 이 칸은 앞으로 씨앗이 반드시 앉아요.'),
      lessonH(context, '"이미 채워짐"과 "채워질 것이 보장됨"'),
      lessonBullets(context, [
        '이미 채워짐: 지금 보이는 씨앗이 앉은 칸이에요. (과거)',
        '채워질 것이 보장됨: 지금은 비어 있지만 바람이 어떻게 불어도 나중에 채워지는 칸이에요. (미래)',
        '민들레도 바람도 보장된 칸은 신경 쓸 필요가 없어요. "아직 의심스러운 칸"에 집중하면 돼요.',
      ]),
      lessonP('보장된 칸을 알아보는 규칙은 간단해요. 지금 있는 꽃에서 아직 안 분 방향으로 두 가지 이상의 길이 닿는 빈칸은 보장돼요. 길이 하나뿐이면 바람이 그 방향을 빼 버릴 수 있어요.'),
    ];

List<Widget> _unitPuzzle(BuildContext context) => [
      lessonP('빈칸을 눌러서 "반드시 채워지는 칸"인지 알아맞혀 보세요. 누르면 바로 이유를 알려 줘요.'),
      const _GuaranteePuzzle(),
      lessonKey(context, '꽃이 한 송이뿐이면 보장된 칸이 하나도 없어요. 길이 하나뿐인 칸은 바람이 그 방향만 빼면 끝이니까요. 꽃이 여러 송이일수록 두 길이 겹치는 칸이 생겨요.'),
    ];

List<Widget> _unitFirst(BuildContext context) => [
      lessonP('꽃을 심은 뒤에 남은 바람의 횟수만큼만 그 꽃은 씨앗을 보낼 수 있어요. 슬라이더를 움직여 보세요.'),
      const _ReachDemo(),
      lessonH(context, '초원이 가득 찰수록 뒤에 심은 꽃이 중요할까?'),
      lessonP('바람이 불수록 초원에 씨앗이 쌓여서 새로 채울 칸이 줄어요. 그래서 나중에 심는 꽃이 더 중요해 보여요. 하지만 반대예요!'),
      lessonBullets(context, [
        '첫 번째 꽃은 일곱 번의 바람을 모두 맞아요. 꽃 한 송이가 일곱 방향으로 씨앗을 보낼 수 있어요.',
        '마지막 꽃은 단 한 번의 바람만 맞아요. 한 방향으로 한 줄밖에 못 보내요.',
        '그래서 처음에 어디에 심느냐가 결과에 훨씬 큰 영향을 줘요.',
      ]),
      lessonH(context, '시간표로 보기'),
      lessonP('민들레는 "꽃 → 바람 → 꽃 → 바람 …"으로 차례를 주고받아요. 숫자는 바람의 번호예요. 꽃을 심은 뒤에 오는 바람만 그 꽃의 씨앗을 날려요. (표시한 꽃과 진한 바람이 서로 짝이에요)'),
      _panel(child: const _Timeline(flower: 1)),
      _panel(child: const _Timeline(flower: 7)),
      lessonKey(context, '꽃의 가치는 "어느 칸이냐"에 "언제 심느냐"를 곱한 것과 같아요. 일찍 심은 꽃일수록 힘이 세요.'),
    ];

List<Widget> _unitCoop(BuildContext context) => [
      lessonP('이번에는 바람과 민들레가 한 편이 되어 "가능한 한 많은 칸을 덮는" 협력 놀이를 해 봐요. 이때 가장 좋은 생각은 시간을 완전히 새로 짜 보는 거예요.'),
      lessonBullets(context, [
        '먼저 "불지 않을 방향"을 하나 정해요. 바람은 그 방향만 빼고 일곱 방향을 모두 불어요.',
        '첫 번째 꽃은 일곱 방향으로, 두 번째 꽃은 여섯 방향으로, … 마지막 꽃은 한 방향으로 씨앗을 보내요.',
        '꽃을 심는 칸과 바람의 순서를 함께 짜서 초원을 빈틈없이 덮어요.',
      ]),
      lessonP('아래는 협력으로 초원을 가득 채운 한 가지 계획이에요. 화살표 단추로 한 수씩 넘겨 보세요.'),
      const _CoopReplay(),
      lessonKey(context, '두 사람이 맞서면 바람이 유리해 보여도, 서로 돕는다면 초원을 가득 채울 수 있어요. 같은 판이라도 "어떤 시간표"를 쓰느냐에 따라 결과가 완전히 달라져요.'),
    ];

List<Widget> _unitTime(BuildContext context) => [
      lessonP('민들레의 판은 그냥 5×5칸이에요. 그런데 이 게임이 어려운 까닭은 판(공간)이 아니라 순서(시간) 때문이에요.'),
      lessonH(context, '공간의 눈 + 시간의 눈'),
      lessonBullets(context, [
        '공간의 눈: 어느 칸에 꽃이 있고, 어느 칸이 비었는지 봐요.',
        '시간의 눈: 몇 번째 바람이 남았는지, 어느 방향이 아직 안 불었는지 봐요.',
        '같은 칸이어도 지금 심는 꽃과 마지막에 심는 꽃은 값어치가 전혀 달라요.',
      ]),
      lessonH(context, '체스와 바둑을 닮았어요'),
      lessonP('체스나 바둑도 판은 눈에 보이는 공간이지만, 정말 중요한 것은 앞으로 어떻게 이어질지에 대한 생각이에요. 내가 한 수에 상대가 어떻게 답할지, 그다음 나는 어떻게 할지 서로 대화하듯 앞뒤를 주고받아요.'),
      lessonP('민들레는 그 대화가 아주 작은 판에서 또렷하게 보이는 게임이에요. 과거(이미 채워진 칸)와 미래(채워질 것이 보장된 칸)가 한 판 위에서 만나요.'),
      lessonKey(context, '공간과 시간은 따로가 아니라 서로 얽혀 있어요. 좋은 수는 "어디에"와 "언제"를 함께 생각해서 나와요.', icon: Icons.hourglass_bottom_rounded),
    ];

List<Widget> _unitQuiz(BuildContext context) => [
      lessonP('그림을 보면서 풀어 봐요. 보기를 고르면 바로 정답과 설명이 나와요.'),
      LessonQuiz(
        question: '나침반에는 바람 방향이 8개 있어요. 게임에서 바람은 이 가운데 몇 방향으로 불게 될까요?',
        figure: const DandelionCompass(size: 130, usedMask: 0),
        options: const ['8방향 모두', '7방향 (한 방향은 안 불어요)', '4방향'],
        answer: 1,
        explain: '바람은 일곱 번 불고 끝나요. 같은 방향은 두 번 못 부니까 7방향을 불고, 한 방향은 끝까지 안 불어요.',
      ),
      LessonQuiz(
        question: '꽃이 두 송이 있어요. 파란 화살표처럼, 동그라미 칸은 위쪽 꽃에서는 "아래쪽", 왼쪽 꽃에서는 "오른쪽"이에요. 바람이 아래쪽·오른쪽으로 아직 한 번도 안 불었다면, 이 칸은?',
        figure: _Meadow(
          cells: DandState.sow(const [3, 11], const []),
          rings: const {13},
          ringColors: const {13: _accent},
          links: const [(3, 13), (11, 13)],
          size: 230,
        ),
        options: const ['바람이 피할 수 있어서 비어 있을 수 있다', '반드시 씨앗이 앉는다', '꽃을 심어야만 채울 수 있다'],
        answer: 1,
        explain: '바람은 한 방향만 뺄 수 있어요. 아래쪽을 빼면 오른쪽으로, 오른쪽을 빼면 아래쪽으로 불어서 이 칸에 씨앗이 앉아요.',
      ),
      LessonQuiz(
        question: '꽃이 한 송이뿐이에요. 동그라미 칸에 씨앗이 갈 수 있는 길은 꽃에서 "오른쪽"으로 가는 길 하나뿐이에요. 이 칸은 반드시 채워질까요?',
        figure: _Meadow(
          cells: DandState.sow(const [12], const []),
          rings: const {14},
          ringColors: const {14: _accent},
          links: const [(12, 14)],
          size: 230,
        ),
        options: const ['네, 반드시 채워진다', '아니요, 바람이 오른쪽만 안 불면 비어 있다', '아니요, 바람이 한 번도 안 분다'],
        answer: 1,
        explain: '길이 하나뿐인 칸은 바람이 그 방향을 빼 버리면 끝이에요. 두 방향 이상에서 오는 칸만 보장돼요.',
      ),
      const LessonQuiz(
        question: '아래 시간표처럼 민들레와 바람이 번갈아 해요. 맨 처음에 심은 꽃(노란 동그라미)은 앞으로 바람을 몇 번 맞게 될까요?',
        figure: _Timeline(flower: 1),
        options: ['1번', '4번', '7번'],
        answer: 2,
        explain: '첫 꽃을 심은 뒤로 바람이 일곱 번 모두 불어요. 그래서 첫 꽃은 일곱 방향으로 씨앗을 보낼 수 있어요. (마지막 꽃은 한 번만 맞아요.)',
      ),
      LessonQuiz(
        question: '이 초원은 바람과 민들레가 협력해서 끝낸 모습이에요. 빈칸이 하나도 없어요. 이 판은 누가 이겼을까요?',
        figure: _Meadow(cells: DandState.fromMoves(kCoopMoves).cells, size: 230),
        options: const ['민들레', '바람', '비겼다'],
        answer: 0,
        explain: '초원이 꽃과 씨앗으로 가득 차면 민들레의 승리예요. 협력하면 이렇게 7송이로 초원을 가득 채울 수 있어요.',
      ),
      lessonH(context, '이제 직접 해 보세요!'),
      _playButtons(context),
    ];

// ───────────────────────── 만져 보는 그림들 ─────────────────────────

Widget _panel({required Widget child}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: _ink), child: child),
    );

/// 칸을 누를 수 있는 초원 그림.
class _Meadow extends StatelessWidget {
  const _Meadow({
    required this.cells,
    this.rings = const {},
    this.ringColors = const {},
    this.badges = const {},
    this.links = const [],
    this.onTap,
    this.size = 300,
  });

  final List<int> cells;
  final Set<int> rings;
  final Map<int, Color> ringColors;
  final Map<int, bool> badges;
  final List<(int, int)> links;
  final void Function(int cell)? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth.isFinite ? (box.maxWidth < size ? box.maxWidth : size) : size;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onTap == null
                  ? null
                  : (d) {
                      final cell = DandLayout(side).hit(d.localPosition);
                      if (cell != null) onTap!(cell);
                    },
              child: CustomPaint(painter: DandScenePainter(cells: cells, rings: rings, ringColors: ringColors, badges: badges, links: links)),
            ),
          ),
        );
      },
    );
  }
}

String _cellName(int cell) => '${cell ~/ kSize + 1}줄 ${cell % kSize + 1}칸';

/// 바람을 불어 "두 방향에서 오는 칸"이 채워지는 것을 본다.
class _GuaranteeDemo extends StatefulWidget {
  const _GuaranteeDemo();

  @override
  State<_GuaranteeDemo> createState() => _GuaranteeDemoState();
}

class _GuaranteeDemoState extends State<_GuaranteeDemo> {
  static const _flowers = [3, 11];
  static const _target = 13; // 위쪽 꽃(0,3)의 아래쪽이면서 왼쪽 꽃(2,1)의 오른쪽인 칸
  int _used = 0;

  List<WindDir> get _winds => [for (final d in WindDir.values) if (_used & (1 << d.index) != 0) d];

  @override
  Widget build(BuildContext context) {
    final cells = DandState.sow(_flowers, _winds);
    final filled = cells[_target] == kSeed;
    return _panel(
      child: Column(
        children: [
          _Meadow(
            cells: cells,
            rings: const {_target},
            ringColors: {_target: filled ? _good : _accent},
            links: filled ? const [] : const [(3, _target), (11, _target)],
            size: 280,
          ),
          const SizedBox(height: 8),
          DandelionCompass(
            size: 150,
            usedMask: _used,
            enabled: true,
            onBlow: (d) => setState(() => _used |= 1 << d.index),
          ),
          const SizedBox(height: 6),
          Text(
            filled
                ? '동그라미 친 칸에 씨앗이 앉았어요! ${_down() && _right() ? '(아래쪽·오른쪽 둘 다 불었어요)' : ''}'
                : (_used == 0 ? '화살표를 눌러 바람을 불어 보세요.' : '아직 비어 있어요. 아래쪽이나 오른쪽으로 불면 채워져요.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _used == 0 ? null : () => setState(() => _used = 0),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('처음으로'),
          ),
        ],
      ),
    );
  }

  bool _down() => _used & (1 << WindDir.down.index) != 0;
  bool _right() => _used & (1 << WindDir.right.index) != 0;
}

/// 빈칸을 눌러 "반드시 채워지는 칸"인지 알아맞히는 문제.
class _GuaranteePuzzle extends StatefulWidget {
  const _GuaranteePuzzle();

  @override
  State<_GuaranteePuzzle> createState() => _GuaranteePuzzleState();
}

class _GuaranteePuzzleState extends State<_GuaranteePuzzle> {
  int _index = 0;
  final Map<int, bool> _tried = {};
  String _message = '비어 있는 칸을 눌러 보세요.';
  bool _reveal = false;

  GuaranteeScenario get _s => kGuaranteeScenarios[_index];

  int get _usedMask {
    var m = 0;
    for (final d in _s.used) {
      m |= 1 << d.index;
    }
    return m;
  }

  List<int> get _cells => DandState.sow(_s.flowers, _s.used);

  void _pick(int i) {
    final cells = _cells;
    setState(() {
      if (cells[i] != kEmpty) {
        _message = cells[i] == kFlower ? '꽃이 있는 칸이에요. 빈칸을 눌러 보세요.' : '이미 씨앗이 앉은 칸이에요. (과거에 채워짐) 비어 있는 칸을 눌러 보세요.';
        return;
      }
      final masks = DandState.reachMasks(cells, _usedMask);
      final dirs = [for (final d in WindDir.values) if (masks[i] & (1 << d.index) != 0) d.label];
      final ok = dirs.length >= 2;
      _tried[i] = ok;
      if (ok) {
        _message = '${_cellName(i)}: 보장돼요! ${dirs.join('·')} 방향 ${dirs.length}가지 길이 있어서, 바람이 한 방향을 빼도 나머지로 씨앗이 닿아요.';
      } else if (dirs.length == 1) {
        _message = '${_cellName(i)}: 보장되지 않아요. 닿는 길이 ${dirs.first} 방향 하나뿐이라, 바람이 그 방향을 빼면 비어 있어요.';
      } else {
        _message = '${_cellName(i)}: 보장되지 않아요. 지금은 씨앗이 닿는 길이 없어요. 꽃을 더 심어야 해요.';
      }
    });
  }

  void _select(int i) => setState(() {
        _index = i;
        _tried.clear();
        _reveal = false;
        _message = '비어 있는 칸을 눌러 보세요.';
      });

  @override
  Widget build(BuildContext context) {
    final cells = _cells;
    final sure = DandState.guaranteed(cells, _usedMask);
    final marks = <int, bool>{
      for (final e in _tried.entries) e.key: e.value,
      if (_reveal) for (final c in sure) c: true,
    };
    return _panel(
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < kGuaranteeScenarios.length; i++)
                ChoiceChip(
                  label: Text(kGuaranteeScenarios[i].title),
                  selected: _index == i,
                  onSelected: (_) => _select(i),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_s.note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.4)),
          const SizedBox(height: 6),
          _Meadow(
            cells: cells,
            rings: marks.keys.toSet(),
            ringColors: {for (final e in marks.entries) e.key: e.value ? _good : _bad},
            badges: marks,
            onTap: _pick,
            size: 280,
          ),
          const SizedBox(height: 6),
          DandelionCompass(size: 110, usedMask: _usedMask, windsLeft: 7 - _s.used.length),
          const Text('흐린 화살표 = 이미 분 방향', style: TextStyle(fontSize: 12.5, color: Color(0xFF666666))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF4F1E8), borderRadius: BorderRadius.circular(12)),
            child: Text(_message, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() {
              _reveal = !_reveal;
              if (_reveal) {
                _message = sure.isEmpty ? '이 문제에는 보장된 칸이 하나도 없어요.' : '초록 체크 표시가 반드시 채워지는 칸이에요. (${sure.length}칸)';
              }
            }),
            icon: Icon(_reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            label: Text(_reveal ? '정답 숨기기' : '보장된 칸 모두 보기'),
          ),
        ],
      ),
    );
  }
}

/// 꽃을 심은 뒤 남은 바람 횟수에 따라 씨앗이 갈 수 있는 길이 달라지는 것을 본다.
class _ReachDemo extends StatefulWidget {
  const _ReachDemo();

  @override
  State<_ReachDemo> createState() => _ReachDemoState();
}

class _ReachDemoState extends State<_ReachDemo> {
  double _left = 7;

  @override
  Widget build(BuildContext context) {
    final k = _left.round();
    final winds = WindDir.values.take(k).toList();
    final cells = DandState.sow(const [12], winds);
    var mask = 0;
    for (final d in winds) {
      mask |= 1 << d.index;
    }
    final seeds = cells.where((c) => c == kSeed).length;
    final who = k == 7 ? '첫 번째 꽃' : (k == 1 ? '마지막 꽃' : '${8 - k}번째 꽃');
    return _panel(
      child: Column(
        children: [
          _Meadow(cells: cells, size: 260),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('남은 바람', style: TextStyle(fontWeight: FontWeight.w800)),
              Expanded(
                child: Slider(
                  value: _left,
                  min: 1,
                  max: 7,
                  divisions: 6,
                  label: '$k번',
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _left = v),
                ),
              ),
              SizedBox(width: 36, child: Text('$k번', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DandelionCompass(size: 96, usedMask: 255 & ~mask),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  '$who: 바람을 $k번 맞아서\n최대 $k방향 · 씨앗 $seeds알',
                  style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const Text('(선명한 화살표 = 씨앗이 갈 수 있는 방향)', style: TextStyle(fontSize: 12.5, color: Color(0xFF666666))),
        ],
      ),
    );
  }
}

/// 협력 계획을 한 수씩 넘겨 본다.
class _CoopReplay extends StatefulWidget {
  const _CoopReplay();

  @override
  State<_CoopReplay> createState() => _CoopReplayState();
}

class _CoopReplayState extends State<_CoopReplay> {
  int _step = 0;

  String _caption() {
    if (_step == 0) return '시작: 아무것도 없는 초원이에요. 이 계획에서는 위쪽 방향은 불지 않아요.';
    final m = kCoopMoves[_step - 1];
    final n = (_step + 1) ~/ 2;
    if (_step.isOdd) {
      return '민들레 $n: ${_cellName(m)}에 꽃을 심어요. (남은 바람 ${8 - n}번)';
    }
    final d = WindDir.values[m].label;
    return '바람 $n: $d${d.endsWith('쪽') ? '으' : ''}로 불어요.';
  }

  @override
  Widget build(BuildContext context) {
    final s = DandState.fromMoves(kCoopMoves.take(_step));
    final empties = s.emptyCount;
    return _panel(
      child: Column(
        children: [
          _Meadow(cells: s.cells, size: 280),
          const SizedBox(height: 6),
          DandelionCompass(size: 110, usedMask: s.usedWinds, windsLeft: s.windsLeft),
          const SizedBox(height: 6),
          Text(_caption(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            empties == 0 ? '초원이 가득 찼어요! 🎉' : '남은 빈칸 $empties칸',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: empties == 0 ? _good : const Color(0xFF666666)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '이전 수',
                onPressed: _step == 0 ? null : () => setState(() => _step--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 12),
              Text('$_step / ${kCoopMoves.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: '다음 수',
                onPressed: _step == kCoopMoves.length ? null : () => setState(() => _step++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 꽃과 바람이 번갈아 나오는 시간표. [flower]번째 꽃과 그 꽃이 맞는 바람들에 표시를 한다.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.flower});

  final int flower;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? (box.maxWidth < 340 ? box.maxWidth : 340.0) : 340.0;
        return SizedBox(width: w, height: 92, child: CustomPaint(painter: _TimelinePainter(flower)));
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter(this.flower);

  final int flower;

  void _text(Canvas canvas, String s, Offset center, double size, Color color, {FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: weight, color: color, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const slots = kWindTurns * 2;
    final w = size.width / slots;
    final y = 22.0;
    for (var i = 0; i < slots; i++) {
      final k = i ~/ 2 + 1; // 몇 번째 짝인지
      final isFlower = i.isEven;
      final c = Offset(w * (i + 0.5), y);
      final hot = isFlower ? k == flower : k >= flower;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      if (isFlower) {
        drawFlower(canvas, Offset.zero, w * 0.46, alpha: hot ? 1 : 0.4);
        if (hot) {
          canvas.drawCircle(Offset.zero, w * 0.62, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFE08A00));
        }
      } else {
        canvas.translate(-w * 0.42, -w * 0.42);
        canvas.saveLayer(Rect.fromLTWH(0, 0, w * 0.84, w * 0.84), Paint()..color = Colors.white.withValues(alpha: hot ? 1 : 0.35));
        paintRoleIcon(canvas, Size(w * 0.84, w * 0.84), Role.wind);
        canvas.restore();
      }
      canvas.restore();
      if (!isFlower) _text(canvas, '$k', Offset(c.dx, y + w * 0.8), 11, hot ? kWindColor : const Color(0xFF999999), weight: FontWeight.w900);
    }
    // 이 꽃이 맞는 바람들을 묶는 괄호
    final startSlot = (flower - 1) * 2 + 1;
    final x0 = w * startSlot + w * 0.15, x1 = size.width - w * 0.15;
    const by = 64.0;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = kWindColor;
    final path = Path()
      ..moveTo(x0, by - 6)
      ..lineTo(x0, by)
      ..lineTo(x1, by)
      ..lineTo(x1, by - 6);
    canvas.drawPath(path, bracket);
    final n = kWindTurns - flower + 1;
    // 괄호가 짧아도 글이 잘리지 않게, 판 안에 들어오도록 옮겨 놓는다
    final label = TextPainter(
      text: const TextSpan(),
      textDirection: TextDirection.ltr,
    );
    label.text = TextSpan(
      text: '$flower번째 꽃이 맞는 바람: $n번',
      style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w800, color: kWindColor, height: 1.0),
    );
    label.layout();
    final left = ((x0 + x1) / 2 - label.width / 2).clamp(0.0, size.width - label.width);
    label.paint(canvas, Offset(left, by + 8));
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.flower != flower;
}
