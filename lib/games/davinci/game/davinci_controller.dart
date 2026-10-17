import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../core/davinci_ai.dart';
import '../core/davinci_rules.dart';

/// 다빈치 코드 한 판의 진행 (규칙 + 타일 고르기 + CPU + 같은 Wi‑Fi 상대의 수 받기).
///
/// 남의 타일이 보이면 안 되니 사람끼리는 같은 Wi‑Fi로 각자 기기에서만 한다 ([PlayMode.wifi], 2~4명).
/// [PlayMode.vsCpu]는 내가 한 명이고 나머지(1~3명)는 CPU다. 나는 [humanSeat]번째 자리다.
/// 모든 기기가 같은 씨앗으로 시작해서 서로의 수(뽑기·맞히기·멈추기 …)만 주고받으면 같은 판이 된다.
class DavinciController extends ChangeNotifier {
  DavinciController({
    required this.mode,
    this.players = 2,
    this.humanSeat = 0,
    this.level = DvLevel.normal,
    int? seed,
    bool? animate,
  })  : seed = seed ?? Random().nextInt(1 << 30),
        animate = animate ?? animateByDefault {
    _deal();
  }

  final PlayMode mode;
  final int players;

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

  bool isCpuSeat(int seat) => vsCpu && seat != humanSeat;

  /// 내가 한 수를 알린다 (Wi‑Fi 대결에서 다른 기기에 보내려고).
  void Function(List<int> move)? onLocalMove;

  /// 소리/진동 알림 ('draw' | 'right' | 'wrong' | 'win' | 'bad').
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

  /// 상대의 수를 보여 주는 중이라 내가 아직 못 두는가.
  bool get effectBusy => animate && ((effect?.blocking ?? false) || _effects.any((e) => e.blocking));

  /// 연출 동안 (실제로는 이미 공개됐더라도) 아직 숨은 타일로 보여야 하는 타일들.
  /// 맞힌 타일은 "추측 중"일 때까지, 틀렸을 때 내가 뽑았던 타일은 결과가 다 보일 때까지 세워 둔다.
  Set<int> get hiddenOverride {
    final e = effect;
    if (e == null || e.kind != 2) return const {};
    return {
      if (e.correct == true && e.stage != DvEffectStage.result) e.tile!,
      if (e.correct == false && e.guesserTile != null) e.guesserTile!,
    };
  }

  /// 연출 중 맞히려고 떠올라 있는 타일.
  int? get liftedTile {
    final e = effect;
    return e != null && e.kind == 2 && e.stage != DvEffectStage.result ? e.tile : null;
  }

  /// 아직 다 보여 주지 못한 연출(지금 보이는 것과 줄 서 있는 것)이 있는가.
  bool get effectsPending => animate && (effect != null || _effects.isNotEmpty);

  /// 연출이 끝나기 전에는 아직 "탈락"으로 보이면 안 되는 자리들: 맞혔다고 보여 주는 중인(또는 줄 서 있는) 추측의 대상.
  /// (판 자체는 이미 반영돼 있어서, 이렇게 하지 않으면 ○ / ✕가 뜨기도 전에 탈락이 떠 버린다)
  Set<int> get outPendingSeats => {
        if (animate)
          for (final e in [?effect, ..._effects])
            if (e.kind == 2 && e.correct == true && e.target != null) e.target!,
      };

  /// 끝난 판의 결과를 보여 줘도 되는가 (마지막 추측의 ○ / ✕까지 다 보인 뒤).
  bool get showOver => isOver && !effectsPending;

  Duration _ms(double factor) => cpuStepDelay * factor;

  void _enqueue(DvEffect e) {
    if (!animate || _disposed) return;
    _effects.add(e);
    _pump();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    final epoch = _fxEpoch;
    while (_effects.isNotEmpty && !_disposed && epoch == _fxEpoch) {
      final e = _effects.removeAt(0);
      effect = e;
      if (!e.ask) e.stage = DvEffectStage.result;
      if (e.ask) {
        // 맞히기는 두 단계로 보여 준다: 먼저 타일을 고르고(떠오른다), 잠깐 뒤에 말풍선으로 숫자를 말한다. (동시에 보이면 따라가기 어렵다)
        if (e.kind == 2) {
          e.stage = DvEffectStage.pick;
          notifyListeners();
          await Future<void>.delayed(_ms(1.2));
          if (_disposed || epoch != _fxEpoch) break;
        }
        e.stage = DvEffectStage.ask;
        notifyListeners();
        await Future<void>.delayed(_ms(e.kind == 2 ? 1.5 : (e.kind == 0 ? 1.2 : 0.9)));
        if (_disposed || epoch != _fxEpoch) break;
      }
      if (e.kind == 2) {
        e.stage = DvEffectStage.result;
        notifyListeners();
        await Future<void>.delayed(_ms(1.4));
        if (_disposed || epoch != _fxEpoch) break;
      }
      effect = null;
      notifyListeners();
    }
    if (epoch == _fxEpoch) {
      effect = null;
      _pumping = false;
      _idle?.complete();
      _idle = null;
      if (!_disposed) notifyListeners();
    }
  }

  void _clearEffects() {
    _fxEpoch++;
    _effects.clear();
    effect = null;
    _pumping = false;
    _idle?.complete();
    _idle = null;
  }

  Future<void> _effectsIdle() {
    if (!_pumping && _effects.isEmpty) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  /// 사람(자리)마다 가장 최근에 가져온 타일. 그 타일에 별표를 달아 누가 무엇을 가져갔는지 알 수 있게 한다.
  final Map<int, int> drawnBy = {};

  void _deal() {
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
    halted = false;
    resignWinner = null;
    _deal();
    moveSerial++;
    notifyListeners();
    _next();
  }

  /// 한 판 더 할 때의 다음 씨앗 (모든 기기가 똑같이 계산한다).
  static int nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x3fffffff;

  // ── 내가 두기 ──

  /// 더미([color] 0 검정 / 1 흰색)에서 타일을 뽑는다.
  bool draw(int color) => _play(DvMove.drawMove(color));

  /// 뽑은 조커를 내 줄 [pos]번째 칸에 놓는다.
  bool placeJoker(int pos) => _play(DvMove.placeJoker(pos));

  /// 맞힐 상대 타일을 고른다 (이미 고른 타일을 다시 누르면 고름을 푼다).
  void selectTarget(int seat, int index) {
    if (!humanCanAct || (phase != DvPhase.guess && phase != DvPhase.decide)) return;
    if (seat == humanSeat || seat < 0 || seat >= players || state.isOut(seat)) return;
    if (index < 0 || index >= state.rows[seat].length || state.isRevealed(state.rows[seat][index])) return;
    if (selSeat == seat && selIndex == index) {
      selSeat = -1;
      selIndex = -1;
    } else {
      selSeat = seat;
      selIndex = index;
    }
    notifyListeners();
  }

  void clearSelection() {
    if (selSeat < 0) return;
    selSeat = -1;
    selIndex = -1;
    notifyListeners();
  }

  /// 고른 타일이 [number](조커는 [kJokerGuess])라고 맞힌다.
  bool guess(int number) {
    if (selSeat < 0) return false;
    final seat = selSeat, index = selIndex;
    return _play(DvMove.guess(seat, index, number));
  }

  /// 맞힌 뒤 멈추고 차례를 넘긴다.
  bool stop() => _play(DvMove.stop);

  /// (더미가 비어 틀렸을 때) 내 숨은 타일 하나를 직접 공개한다.
  bool revealOwn(int index) => _play(DvMove.reveal(index));

  bool _play(List<int> move) {
    if (!humanCanAct || !state.isLegal(move)) {
      onFeedback?.call('bad');
      return false;
    }
    _apply(move);
    onLocalMove?.call(move);
    _next();
    return true;
  }

  void _apply(List<int> move) {
    final before = state.lastGuess;
    final actor = state.turn;
    final preDrawn = state.drawn;
    final tile = move[0] == 2 ? state.rows[move[1]][move[2]] : null;
    moves.add(move);
    state.apply(move);
    if (move[0] == 0 || move[0] == 1) {
      final t = state.drawn;
      if (t != null) drawnBy[actor] = t;
    }
    selSeat = -1;
    selIndex = -1;
    moveSerial++;
    final g = state.lastGuess;
    // 상대(CPU·다른 기기)가 둔 수는 한 단계씩 보여 준다. 내가 맞힌 결과는 막지 않고 바로 표시만 한다.
    final mine = actor == humanSeat;
    if (move[0] == 2 && g != null && !identical(g, before)) {
      _enqueue(DvEffect(
        actor: actor,
        kind: 2,
        target: move[1],
        index: move[2],
        tile: tile,
        number: move[3],
        correct: g.correct,
        guesserTile: !g.correct ? preDrawn : null,
        blocking: !mine,
        ask: !mine,
      ));
    } else if (!mine) {
      // 뽑기는 어느 더미에서 어느 타일을 뽑았는지도 담아 둔다 (조커는 아직 줄에 놓기 전이다)
      _enqueue(DvEffect(
        actor: actor,
        kind: move[0],
        number: move[0] == 0 ? move[1] : null,
        tile: move[0] == 0 ? (state.pendingJoker ?? state.drawn) : null,
        blocking: true,
        ask: true,
      ));
    }
    if (state.isOver) {
      onFeedback?.call('win');
    } else if (move[0] == 2 && g != null && !identical(g, before)) {
      onFeedback?.call(g.correct ? 'right' : 'wrong');
    } else if (move[0] == 0) {
      onFeedback?.call('draw');
    }
    notifyListeners();
  }

  // ── 다른 기기의 수 (Wi‑Fi 대결) ──

  /// 다른 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  bool receiveMove(List<int> move, {int? index}) {
    if (!online || isOver || halted || turn == humanSeat) return false;
    if (index != null && index != moveCount) return false;
    if (!state.isLegal(move)) return false;
    _apply(move);
    return true;
  }

  // ── CPU ──

  void _next() {
    if (_disposed || !vsCpu || isOver || halted || !isCpuSeat(turn) || _cpuRunning) return;
    _cpuLoop();
  }

  /// CPU 차례 동안 수를 하나씩 둔다 (사람이 볼 수 있게 수마다 잠깐 쉰다). 사람 차례가 오면 멈춘다.
  Future<void> _cpuLoop() async {
    final epoch = ++_epoch;
    _cpuRunning = true;
    notifyListeners();
    while (!_disposed && epoch == _epoch && !isOver && !halted && isCpuSeat(turn)) {
      await Future<void>.delayed(cpuStepDelay);
      if (_disposed || epoch != _epoch || isOver || halted) break;
      final move = DvAi.choose(state, level, _rng);
      _apply(move);
      // 이 수가 어떤 수였는지 다 보여 줄 때까지 기다렸다가 다음 수를 둔다
      await _effectsIdle();
    }
    if (_disposed || epoch != _epoch) return;
    _cpuRunning = false;
    notifyListeners();
  }

  // ── 기권 ──

  /// 기권할 수 있는가. 3~4명이 Wi‑Fi로 할 때는 누가 이기는 건지 정할 수 없어 기권이 없다.
  bool get canResign => !isOver && !halted && moves.isNotEmpty && (vsCpu || players == 2);

  /// 기권한다 (CPU가 두던 수는 버린다). 이긴 사람은 [resignWinner]. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _epoch++;
    _clearEffects();
    _cpuRunning = false;
    clearSelection();
    halted = true;
    resignWinner = _winnerWhenResigned(humanSeat);
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결). 내가 이긴 것으로 끝난다.
  void opponentResigned() {
    if (!online || isOver || halted) return;
    _epoch++;
    _clearEffects();
    clearSelection();
    halted = true;
    resignWinner = humanSeat;
    notifyListeners();
  }

  /// [seat]이 기권했을 때 이긴 사람: 2명이면 상대, 그 이상이면 숨은 타일이 가장 많이 남은 사람.
  int _winnerWhenResigned(int seat) {
    var best = -1, bestN = -1;
    for (var p = 0; p < players; p++) {
      if (p == seat) continue;
      final n = state.hiddenCount(p);
      if (n > bestN) {
        bestN = n;
        best = p;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _fxEpoch++;
    _idle?.complete();
    super.dispose();
  }
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

  DvEffectStage stage = DvEffectStage.ask;
}
