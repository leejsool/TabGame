/// 검을 내려치는 방향 (= 화면에서 탭하는 쪽).
enum Side { left, right }

/// 한 박(beat) 안에서 치는 한 번의 동작.
class Motif {
  const Motif(this.hits, {this.holdBeats = 0, this.swipe = false});

  /// (박 안에서의 위치 0 ≤ t < 1, 방향).
  final List<(double, Side)> hits;

  /// 0보다 크면 "꾹 누르기": 첫 동작에서 누르기 시작해 이만큼(박) 뒤에 손을 떼며 내려친다.
  final double holdBeats;

  /// true면 "옆으로 긋기": 화면을 가로로 쓱 그으면 내려친다. 방향은 칼이 휘둘러지는 쪽(= 손가락이 가는 쪽).
  final bool swipe;

  bool get isDouble => hits.length > 1;
  bool get isHold => holdBeats > 0;

  /// 이 동작이 끝난 뒤 다음 물결까지 필요한 박 수 (꾹 누르기는 한 박 더 쉰다).
  double get waveBeats => isHold ? 5 : 4;

  static const left = Motif([(0.0, Side.left)]);
  static const right = Motif([(0.0, Side.right)]);
  static const leftDouble = Motif([(0.0, Side.left), (0.5, Side.left)]);
  static const rightDouble = Motif([(0.0, Side.right), (0.5, Side.right)]);
  static const leftRight = Motif([(0.0, Side.left), (0.5, Side.right)]);
  static const rightLeft = Motif([(0.0, Side.right), (0.5, Side.left)]);
  static const holdLeft = Motif([(0.0, Side.left)], holdBeats: 1);
  static const holdRight = Motif([(0.0, Side.right)], holdBeats: 1);

  /// 왼쪽에서 오른쪽으로 긋기 (→).
  static const swipeRight = Motif([(0.0, Side.right)], swipe: true);

  /// 오른쪽에서 왼쪽으로 긋기 (←).
  static const swipeLeft = Motif([(0.0, Side.left)], swipe: true);
}

/// 코스 안의 한 단계.
class TutorialStage {
  const TutorialStage({
    required this.title,
    required this.hint,
    required this.waves,
    this.cue = true,
  });

  final String title;

  /// 교관의 말풍선.
  final String hint;

  /// 이 단계의 물결들.
  final List<Motif> waves;

  /// 내가 칠 타이밍에 안내 링을 보여 줄지.
  final bool cue;
}

/// 검사들 앞에 서 있는 상대.
enum Foe { dummy, slime }

/// 코스 하나 (여러 단계로 이루어짐).
class RhythmCourse {
  const RhythmCourse({
    required this.title,
    required this.subtitle,
    required this.stages,
    this.bpm = 100,
    this.foe = Foe.dummy,
    this.welcome = '훈련소에 온 걸 환영한다!',
  });

  final String title;
  final String subtitle;
  final List<TutorialStage> stages;
  final double bpm;

  /// 검사들이 내려치는 상대 (허수아비 / 슬라임).
  final Foe foe;

  /// 시작 전 교관의 한마디.
  final String welcome;

  /// 이 별 개수 이상이면 통과해서 다음 코스가 열린다.
  static const passStars = 2;

  static const all = <RhythmCourse>[
    RhythmCourse(
      title: '훈련소 입소',
      subtitle: '왼쪽·오른쪽·2연속 탭 익히기',
      stages: RhythmChart.tutorialStages,
    ),
    RhythmCourse(
      title: '꾹 눌러 모으기',
      subtitle: '검에 힘을 모았다가 내려치기',
      stages: RhythmChart.holdStages,
    ),
    RhythmCourse(
      title: '마을 밖으로',
      subtitle: '옆으로 쓱 긋기! 슬라임 네 마리',
      stages: RhythmChart.slimeStages,
      bpm: 104,
      foe: Foe.slime,
      welcome: '마을 밖이다! 슬라임이 나타났다!',
    ),
  ];
}

/// 곡 안의 박자 하나하나에 일어나는 일.
class ChartEvent {
  const ChartEvent({
    required this.time,
    required this.actor,
    required this.side,
    required this.stage,
    required this.wave,
    double? pressTime,
    this.isSwipe = false,
  }) : pressTime = pressTime ?? time;

  /// 내려치는(= 손을 떼는) 순간. 곡 시작부터의 시간(초).
  final double time;

  /// 누르기 시작하는 순간. 꾹 누르기가 아니면 [time]과 같다.
  final double pressTime;

  /// 0~2: 선배들, 3: 플레이어.
  final int actor;
  final Side side;
  final int stage;
  final int wave;

  /// 화면을 옆으로 긋는 박자인가 ([side]는 긋는 방향).
  final bool isSwipe;

  bool get isPlayer => actor == 3;
  bool get isHold => pressTime < time;
}

/// 코스 하나의 곡 전체.
class RhythmChart {
  RhythmChart._(this.bpm, this.stages, this.events, this.countInBeats, this.endTime);

  final double bpm;
  final List<TutorialStage> stages;

  /// 시간 순으로 정렬된 이벤트.
  final List<ChartEvent> events;
  final int countInBeats;
  final double endTime;

  double get beat => 60.0 / bpm;

  Iterable<ChartEvent> get playerEvents => events.where((e) => e.isPlayer);

  /// 각 단계가 시작하는 시간(초) — 단계 전환 표시용.
  List<double> get stageStarts {
    final out = <double>[];
    for (var s = 0; s < stages.length; s++) {
      final first = events.where((e) => e.stage == s).map((e) => e.pressTime).reduce((a, b) => a < b ? a : b);
      out.add(first);
    }
    return out;
  }

  /// 시간 [t]에 해당하는 단계 번호.
  int stageAt(double t) {
    final starts = stageStarts;
    var s = 0;
    for (var i = 0; i < starts.length; i++) {
      if (t >= starts[i] - beat * 0.5) s = i;
    }
    return s;
  }

  /// 훈련소 튜토리얼 (1코스).
  static RhythmChart tutorial({double bpm = 100}) => build(tutorialStages, bpm: bpm);

  /// [index]번 코스의 곡.
  static RhythmChart course(int index) {
    final c = RhythmCourse.all[index];
    return build(c.stages, bpm: c.bpm);
  }

  static const tutorialStages = <TutorialStage>[
    TutorialStage(
      title: '왼쪽 내려치기',
      hint: '앞사람이 내려치면, 바로 다음 박자에 따라 쳐라!\n화면 왼쪽을 탭!',
      waves: [Motif.left, Motif.left, Motif.left, Motif.left],
    ),
    TutorialStage(
      title: '오른쪽 내려치기',
      hint: '이번엔 반대쪽이다.\n화면 오른쪽을 탭!',
      waves: [Motif.right, Motif.right, Motif.right, Motif.right],
    ),
    TutorialStage(
      title: '왼쪽, 오른쪽 번갈아',
      hint: '앞사람이 친 쪽을 잘 봐라!',
      waves: [Motif.left, Motif.right, Motif.right, Motif.left],
    ),
    TutorialStage(
      title: '2연속 내려치기',
      hint: '따다닥! 같은 쪽을 두 번 빠르게 탭!',
      waves: [Motif.leftDouble, Motif.rightDouble, Motif.leftDouble, Motif.rightDouble],
    ),
    TutorialStage(
      title: '총정리',
      hint: '이제 안내 없이 해 보자! 배운 걸 전부 보여 줘라!',
      cue: false,
      waves: [
        Motif.left,
        Motif.rightDouble,
        Motif.leftRight,
        Motif.right,
        Motif.leftDouble,
        Motif.rightLeft,
      ],
    ),
  ];

  static const holdStages = <TutorialStage>[
    TutorialStage(
      title: '꾹 눌러 모으기',
      hint: '화면을 꾹 누르면 검에 힘이 모인다!\n앞사람이 내려칠 때 손을 떼라!',
      waves: [Motif.holdLeft, Motif.holdLeft, Motif.holdRight, Motif.holdRight],
    ),
    TutorialStage(
      title: '탭과 꾹 섞기',
      hint: '짧게 탭할 때와 꾹 누를 때를 잘 구분해라!',
      waves: [Motif.left, Motif.holdRight, Motif.holdLeft, Motif.right, Motif.holdLeft],
    ),
    TutorialStage(
      title: '총정리',
      hint: '안내 없이 전부 해 보자! 힘을 모아라!',
      cue: false,
      waves: [
        Motif.leftDouble,
        Motif.holdRight,
        Motif.holdLeft,
        Motif.rightDouble,
        Motif.holdRight,
        Motif.left,
      ],
    ),
  ];

  /// 3코스: 마을 밖에서 만난 슬라임 4마리. 새 조작은 "옆으로 긋기"(드래그) 하나 —
  /// 먼저 긋기만 익히고, 탭·2연속·꾹 누르기와 섞으며, 마지막 단계는 안내 링이 없다.
  static const slimeStages = <TutorialStage>[
    TutorialStage(
      title: '옆으로 쓱 베기',
      hint: '마을 밖이다! 슬라임이다!\n화면을 옆으로 쓱 그어서 베어라!',
      waves: [Motif.swipeRight, Motif.swipeLeft, Motif.swipeRight, Motif.swipeLeft],
    ),
    TutorialStage(
      title: '긋기와 탭 섞기',
      hint: '긋는 방향을 잘 봐라! 탭도 섞여 나온다!',
      waves: [Motif.swipeLeft, Motif.right, Motif.swipeRight, Motif.leftDouble, Motif.swipeLeft],
    ),
    TutorialStage(
      title: '말랑말랑 튀어 오른다',
      hint: '탭, 2연속, 꾹 누르기, 긋기! 전부 나온다!',
      waves: [Motif.swipeRight, Motif.holdLeft, Motif.rightDouble, Motif.swipeLeft, Motif.leftRight, Motif.swipeRight],
    ),
    TutorialStage(
      title: '슬라임 소탕',
      hint: '마지막이다! 안내 없이 한 마리도 남기지 마라!',
      cue: false,
      waves: [
        Motif.swipeLeft,
        Motif.rightDouble,
        Motif.swipeRight,
        Motif.holdLeft,
        Motif.swipeLeft,
        Motif.leftRight,
        Motif.holdRight,
        Motif.swipeRight,
      ],
    ),
  ];

  /// 단계 목록으로 곡을 만든다. 물결 하나는 4박(꾹 누르기는 5박): 선배1 → 선배2 → 선배3 → 나.
  static RhythmChart build(List<TutorialStage> stages, {double bpm = 100, int countIn = 4}) {
    final beat = 60.0 / bpm;
    final events = <ChartEvent>[];
    var waveStart = countIn.toDouble();
    var wave = 0;
    for (var s = 0; s < stages.length; s++) {
      for (final motif in stages[s].waves) {
        for (var actor = 0; actor < 4; actor++) {
          final base = waveStart + actor;
          for (final (off, side) in motif.hits) {
            events.add(ChartEvent(
              time: (base + off + motif.holdBeats) * beat,
              pressTime: motif.isHold ? (base + off) * beat : null,
              actor: actor,
              side: side,
              stage: s,
              wave: wave,
              isSwipe: motif.swipe,
            ));
          }
        }
        waveStart += motif.waveBeats;
        wave++;
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    return RhythmChart._(bpm, stages, events, countIn, (waveStart + 1) * beat);
  }
}
