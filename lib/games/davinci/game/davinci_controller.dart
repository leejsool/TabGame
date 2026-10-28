import '../../../core/game_speed.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../core/davinci_ai.dart';
import '../core/davinci_rules.dart';

part 'davinci_controller_effects.dart';
part 'davinci_controller_rejoin.dart';
part 'davinci_controller_moves.dart';
part 'davinci_controller_turns.dart';

/// 다빈치 코드 한 판의 진행 (규칙 + 타일 고르기 + CPU + 같은 Wi‑Fi 상대의 수 받기).
///
/// 남의 타일이 보이면 안 되니 사람끼리는 같은 Wi‑Fi로 각자 기기에서만 한다 ([PlayMode.wifi], 2~4명).
/// [PlayMode.vsCpu]는 내가 한 명이고 나머지(1~3명)는 CPU다. 나는 [humanSeat]번째 자리다.
/// 모든 기기가 같은 씨앗으로 시작해서 서로의 수(뽑기·맞히기·멈추기 …)만 주고받으면 같은 판이 된다.
class DavinciController extends ChangeNotifier {
  /// 다른 파일(part)에 나눠 둔 조각에서 화면에 바뀐 것을 알릴 때 쓴다.
  void _notify() => notifyListeners();

  DavinciController({
    required this.mode,
    this.players = 2,
    this.humanSeat = 0,
    this.level = DvLevel.normal,
    int? seed,
    bool? animate,
    Iterable<int>? cpuSeats,
    this.cpuHost = false,
  })  : seed = seed ?? Random().nextInt(1 << 30),
        animate = animate ?? animateByDefault {
    // CPU 대결은 나 말고 모두 CPU다. 같은 Wi‑Fi 방에서는 [cpuSeats]에 든 자리들이 CPU다.
    this.cpuSeats = {...?cpuSeats};
    if (mode == PlayMode.vsCpu && cpuSeats == null) {
      this.cpuSeats.addAll([for (var p = 0; p < players; p++) if (p != humanSeat) p]);
    }
    _deal();
  }

  /// 저장해 둔 판([toJson])을 되살린다 (CPU 대결만). 같은 씨앗으로 나눠서 저장된 수들을 다시 둔다. 맞지 않는 내용이면 null.
  static DavinciController? fromJson(Map<String, dynamic> j, {bool? animate}) {
    try {
      final players = j['players'] as int, humanSeat = j['humanSeat'] as int, levelIndex = j['level'] as int;
      if (players < 2 || players > 4 || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= DvLevel.values.length) return null;
      final c = DavinciController(
        mode: PlayMode.vsCpu,
        players: players,
        humanSeat: humanSeat,
        level: DvLevel.values[levelIndex],
        seed: j['seed'] as int,
        animate: animate,
      );
      c.rotation = j['rotation'] as int;
      for (final raw in j['moves'] as List) {
        final move = [for (final v in raw as List) v as int];
        if (!c.state.isLegal(move)) return null;
        final actor = c.state.turn;
        c.moves.add(move);
        c.state.apply(move);
        if (move[0] == 0 || move[0] == 1) {
          final t = c.state.drawn;
          if (t != null) c.drawnBy[actor] = t;
        }
      }
      c.moveSerial = c.moves.length;
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 지금 판의 모습을 JSON으로 (CPU 대결의 이어하기용). 씨앗과 둔 수만 있으면 판이 그대로 되살아난다.
  Map<String, dynamic> toJson() => {
        'v': 1,
        'players': players,
        'humanSeat': humanSeat,
        'level': level.index,
        'seed': seed,
        'rotation': rotation,
        'moves': moves,
      };

  /// 이어하기로 보관할 만한 판인가 (CPU 대결이고, 한 수라도 뒀고, 끝나지 않았다).
  bool get savable => vsCpu && !isOver && !halted && moves.isNotEmpty;

  final PlayMode mode;
  final int players;

  /// CPU가 앉은 자리들. 한 판 더 할 때마다 사람과 함께 한 칸씩 돈다.
  late final Set<int> cpuSeats;

  /// 같은 Wi‑Fi 방에서 CPU의 수를 이 기기가 정해서 다른 기기들에 알리는가 (방을 연 기기만).
  final bool cpuHost;

  /// 한 판 더 한 횟수 (자리가 이만큼 돌았다).
  int rotation = 0;

  /// 상대(CPU·다른 기기)가 둔 수를 한 단계씩 보여 주는 연출을 쓰는가.
  final bool animate;

  /// [animate]를 안 정했을 때의 기본값 (시험에서는 끄고 필요한 시험만 켠다).
  static bool animateByDefault = true;

  /// 이 기기에서 내가 맡은 자리 (0 = 먼저). 한 판 더 할 때마다 한 칸씩 돈다.
  int humanSeat;
  final DvLevel level;

  /// 패를 나눈 씨앗 (같은 Wi‑Fi 대결에서는 모든 기기가 같은 값으로 시작한다).
  int seed;

  bool get vsCpu => mode == PlayMode.vsCpu;
  bool get online => mode == PlayMode.wifi;

  late DvState state;

  /// 지금까지 둔 수들.
  final List<List<int>> moves = [];

  int get moveCount => moves.length;
  bool get isOver => state.isOver;
  int get turn => state.turn;
  DvPhase get phase => state.phase;

  /// 누군가 기권해서 멈춘 판인가.
  bool halted = false;

  /// 기권으로 끝났을 때 이긴 사람 (기권이 아니면 null).
  int? resignWinner;

  /// 사람이 모두 탈락한 뒤 "여기서 끝내기"를 골라서 멈춘 판인가 ([halted]도 함께 true다).
  bool endedWatching = false;

  /// 사람이 모두 탈락했을 때 계속 볼지 끝낼지 이미 물어봤는가 (판마다 한 번만 묻는다).
  bool watchPrompted = false;

  bool isCpuSeat(int seat) => cpuSeats.contains(seat);

  /// 내가 고른 타일이 바뀔 때 (다른 기기에 알리려고). 고름을 풀면 seat와 index가 -1이다.
  void Function(int seat, int index)? onLocalSelect;

  /// 사람(CPU가 아닌 자리)이 모두 탈락해서 CPU끼리 순위만 가리는 중인가.
  /// 판이 끝나지 않았고 CPU가 둘 이상 남아 있다. (마지막으로 맞힌 추측의 ○ 연출이 끝나기 전에는 아직 아니다)
  bool get humansAllOut => !effectsPending && _humansOutNow;

  bool get _humansOutNow {
    if (isOver || halted || cpuSeats.isEmpty) return false;
    var humanSeats = 0;
    for (var p = 0; p < players; p++) {
      if (isCpuSeat(p)) continue;
      humanSeats++;
      if (!state.isOut(p)) return false;
    }
    return humanSeats > 0;
  }

  /// 사람에게 계속 볼지 끝낼지 묻는 동안 CPU가 수를 두지 않고 기다린다 (CPU 대결에서만 쓴다).
  bool cpuHold = false;

  /// 이 기기가 CPU의 수를 정하는가 (CPU 대결, 또는 CPU가 낀 Wi‑Fi 방의 방장).
  bool get runsCpu => cpuSeats.isNotEmpty && (vsCpu || cpuHost);

  /// 판에 앉은 사람 수 (CPU 빼고).
  int get humans => players - cpuSeats.length;

  /// 내가 한 수를 알린다 (Wi‑Fi 대결에서 다른 기기에 보내려고).
  void Function(List<int> move)? onLocalMove;

  /// 소리/진동 알림 ('draw' | 'right' | 'wrong' | 'win' | 'bad' | 'think0'~'think2' = 상대 타일을 눌러 고민하는 소리).
  void Function(String kind)? onFeedback;

  /// CPU가 수를 두기 전에 생각하는 시간이자 상대 수 연출의 기준 시간 (추측 1.7배, 결과 1.4배). 사람이 따라볼 수 있게 느긋하게. 시험에서는 줄인다.
  Duration cpuStepDelay = const Duration(milliseconds: 1300);

  final Random _rng = Random();
  int _epoch = 0;
  bool _disposed = false;

  /// CPU가 생각하며 두는 중인가.
  bool _cpuRunning = false;
  bool get thinking => _cpuRunning;

  /// 내가 고른 상대 타일 (상대 자리, 줄에서의 순서). 없으면 -1.
  int selSeat = -1, selIndex = -1;

  /// 수가 둬질 때마다 늘어나는 번호 (화면의 안내·애니메이션을 다시 시작하는 신호).
  int moveSerial = 0;

  /// 지금 내가 수를 둘 수 있는가.
  bool get humanCanAct => !isOver && !halted && !thinking && !effectBusy && turn == humanSeat;

  // ── 상대가 둔 수 보여 주기 ──

  /// 지금 보여 주는 연출 (없으면 null).
  DvEffect? effect;
  final List<DvEffect> _effects = [];
  bool _pumping = false;
  int _fxEpoch = 0;
  Completer<void>? _idle;

  // ── 다른 기기의 수를 연출 순서대로 반영하기 (Wi‑Fi 대결) ──

  /// 아직 판에 반영하지 않고 줄 세워 둔 소식들 (다른 기기가 둔 수, 상대가 고르는 중인 타일).
  /// 상대가 연달아 여러 번 맞히면 소식은 한꺼번에 오는데, 판을 바로 바꾸면 화면이 마지막 상태로 먼저 가 버려서
  /// 연출이 보여 주는 순서와 어긋난다. 그래서 앞의 연출이 다 끝난 뒤에 하나씩 판에 반영한다.
  final List<_Incoming> _incoming = [];

  /// 줄 서 있는 수까지 모두 둔 모습 (줄 서 있는 수가 규칙에 맞는지, 누구 차례인지 알아보려고). 줄이 비면 null.
  DvState? _shadow;


  /// 지금 남이 맞히려고 고르고 있는 타일: 고르는 사람 자리, 고른 타일의 주인 자리, 그 줄에서의 순서.
  /// (맞히기 전에 "무슨 숫자일까" 고민하는 모습을 다른 기기에서도 볼 수 있게 한다)
  ({int actor, int seat, int index})? remoteSel;


  /// 사람(자리)마다 가장 최근에 가져온 타일. 그 타일에 별표를 달아 누가 무엇을 가져갔는지 알 수 있게 한다.
  final Map<int, int> drawnBy = {};

  /// 남이 뽑았지만 아직 보여 주지 않는 조커의 더미 색 (자리를 정하면 보여 준다).
  int? _heldDrawColor;

  void _deal() {
    _heldDrawColor = null;
    drawnBy.clear();
    state = DvState.deal(players, seed);
    moves.clear();
    selSeat = -1;
    selIndex = -1;
  }

  /// 화면이 준비되면 부른다 (CPU가 먼저 시작하는 판이면 CPU가 둔다).
  void start() => _next();

  /// 새 판. 씨앗이 바뀌고 자리가 한 칸 돈다. Wi‑Fi 대결에서는 모든 기기가 같은 순서로 부르면 같은 판이 된다.
  void restart() {
    _epoch++;
    _clearEffects();
    _cpuRunning = false;
    seed = nextSeed(seed);
    humanSeat = (humanSeat + 1) % players;
    rotation++;
    final rotated = {for (final s in cpuSeats) (s + 1) % players};
    cpuSeats
      ..clear()
      ..addAll(rotated);
    halted = false;
    endedWatching = false;
    watchPrompted = false;
    resignWinner = null;
    _deal();
    moveSerial++;
    notifyListeners();
    _next();
  }

  /// 한 판 더 할 때의 다음 씨앗 (모든 기기가 똑같이 계산한다).
  static int nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x3fffffff;

  // ── 내가 두기 ──


  // ── 다른 기기의 수 (Wi‑Fi 대결) ──




  // ── CPU ──



  // ── 기권 ──


  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _fxEpoch++;
    _idle?.complete();
    super.dispose();
  }
}

/// 줄 서서 기다리는 소식 하나: 다른 기기가 둔 수, 또는 상대가 고르는 중인 타일.
class _Incoming {
  _Incoming.move(List<int> this.move)
      : actor = null,
        seat = null,
        index = null;

  _Incoming.selection(int this.actor, int this.seat, int this.index) : move = null;

  final List<int>? move;
  final int? actor, seat, index;
}

/// 연출의 단계: 타일을 고르는 중(고른 타일이 떠오른다) → 추측하는 중(말풍선 "7?") → 결과(○ / ✕).
enum DvEffectStage { pick, ask, result }

/// 상대가 둔 수 하나를 화면에 보여 주기 위한 정보.
class DvEffect {
  DvEffect({
    required this.actor,
    required this.kind,
    this.target,
    this.index,
    this.tile,
    this.number,
    this.correct,
    this.guesserTile,
    this.blocking = true,
    this.ask = true,
    this.heard = false,
    this.resultFx,
  });

  /// 둔 사람의 자리와 수의 종류 (0 뽑기, 1 조커 놓기, 2 맞히기, 3 멈추기, 4 내 타일 공개).
  final int actor, kind;

  /// 맞히기: 맞힌 상대 자리, 그 줄에서의 순서, 그 타일, 말한 숫자(조커 12), 맞았는가.
  /// 뽑기: [number]는 더미 색(0 검정 / 1 흰색), [tile]은 뽑은 타일.
  final int? target, index, tile, number;
  final bool? correct;

  /// 틀렸을 때 함께 공개되는, 그 사람이 방금 뽑았던 타일.
  final int? guesserTile;

  /// 보여 주는 동안 내가 둘 수 없는가 (상대의 수는 막고, 내가 맞힌 결과 표시는 막지 않는다).
  final bool blocking;

  /// "추측하는 중" 단계를 보여 주는가 (내가 맞힐 때는 건너뛰고 결과만 보인다).
  final bool ask;

  /// 이 사람이 타일을 고르는 소식을 이미 받아 "고민" 소리를 낸 수인가 (같은 사람의 고름과 맞히기에서 두 번 울리지 않게).
  final bool heard;

  /// 결과(○ / ✕)가 보이는 순간 낼 소리·진동 ('right' | 'wrong'). (수를 둘 때 바로 내면 표시보다 소리가 먼저 난다)
  final String? resultFx;

  DvEffectStage stage = DvEffectStage.ask;
}
