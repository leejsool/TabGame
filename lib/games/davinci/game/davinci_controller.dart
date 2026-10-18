import '../../../core/game_speed.dart';
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
  bool get effectsPending => animate && (effect != null || _effects.isNotEmpty || _incoming.isNotEmpty);

  /// 연출이 끝나기 전에는 아직 "탈락"으로 보이면 안 되는 자리들: 맞혔다고 보여 주는 중인(또는 줄 서 있는) 추측의 대상.
  /// (판 자체는 이미 반영돼 있어서, 이렇게 하지 않으면 ○ / ✕가 뜨기도 전에 탈락이 떠 버린다)
  Set<int> get outPendingSeats => {
        if (animate)
          for (final e in [?effect, ..._effects])
            if (e.kind == 2 && e.correct == true && e.target != null) e.target!,
      };

  /// 끝난 판의 결과를 보여 줘도 되는가 (마지막 추측의 ○ / ✕까지 다 보인 뒤).
  bool get showOver => isOver && !effectsPending;

  Duration _ms(double factor) => GameSpeed.scale(cpuStepDelay) * factor;

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
      _drainIncoming(); // 줄 서 있던 다음 소식을 반영한다 (수면 새 연출이 시작된다)
      if (!_pumping && _effects.isEmpty && _incoming.isEmpty) {
        _idle?.complete();
        _idle = null;
      }
      if (!_disposed) notifyListeners();
    }
  }

  /// 줄 서 있는 소식을 연출이 쉬는 동안 하나씩 판에 반영한다. 수를 반영하면 새 연출이 시작되니 거기서 멈추고, 그 연출이 끝나면 이어서 한다.
  void _drainIncoming() {
    while (_incoming.isNotEmpty && !_pumping && _effects.isEmpty && !_disposed) {
      final item = _incoming.removeAt(0);
      if (item.move != null) {
        if (!state.isLegal(item.move!)) continue; // (줄 세울 때 이미 확인한 수라 여기까지 오지 않는다)
        _apply(item.move!);
        _next(); // (다음이 CPU 차례이면 방장 기기가 CPU의 수를 둔다)
      } else {
        _showSelection(item.actor!, item.seat!, item.index!);
      }
    }
    if (_incoming.isEmpty) _shadow = null;
  }

  void _clearEffects() {
    _fxEpoch++;
    _effects.clear();
    _incoming.clear();
    _shadow = null;
    remoteSel = null;
    effect = null;
    _pumping = false;
    _idle?.complete();
    _idle = null;
  }

  Future<void> _effectsIdle() {
    if (!_pumping && _effects.isEmpty && _incoming.isEmpty) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  // ── 다른 기기의 수를 연출 순서대로 반영하기 (Wi‑Fi 대결) ──

  /// 아직 판에 반영하지 않고 줄 세워 둔 소식들 (다른 기기가 둔 수, 상대가 고르는 중인 타일).
  /// 상대가 연달아 여러 번 맞히면 소식은 한꺼번에 오는데, 판을 바로 바꾸면 화면이 마지막 상태로 먼저 가 버려서
  /// 연출이 보여 주는 순서와 어긋난다. 그래서 앞의 연출이 다 끝난 뒤에 하나씩 판에 반영한다.
  final List<_Incoming> _incoming = [];

  /// 줄 서 있는 수까지 모두 둔 모습 (줄 서 있는 수가 규칙에 맞는지, 누구 차례인지 알아보려고). 줄이 비면 null.
  DvState? _shadow;

  DvState get _latest => _shadow ?? state;

  /// 지금 남이 맞히려고 고르고 있는 타일: 고르는 사람 자리, 고른 타일의 주인 자리, 그 줄에서의 순서.
  /// (맞히기 전에 "무슨 숫자일까" 고민하는 모습을 다른 기기에서도 볼 수 있게 한다)
  ({int actor, int seat, int index})? remoteSel;

  /// 내가 고른 타일이 바뀔 때 (다른 기기에 알리려고). 고름을 풀면 seat와 index가 -1이다.
  void Function(int seat, int index)? onLocalSelect;

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
    onLocalSelect?.call(selSeat, selIndex);
  }

  void clearSelection() {
    if (selSeat < 0) return;
    selSeat = -1;
    selIndex = -1;
    notifyListeners();
    onLocalSelect?.call(-1, -1);
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
    remoteSel = null; // (수를 두면 고르던 타일 표시는 그 수의 연출로 이어진다)
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
    // 남이 조커를 뽑았다: 자리를 정할 때까지 아무것도 보여 주지 않는다 (소리도, 날아가는 타일도 없다).
    // 자리를 정하면 그제서야 일반 타일을 뽑을 때와 똑같은 연출 하나로 보여 준다. (그래야 조커를 뽑았는지 알 수 없다)
    if (!mine && move[0] == 0 && state.phase == DvPhase.placeJoker) {
      _heldDrawColor = move[1];
      return;
    }
    final heldColor = move[0] == 1 && !mine ? _heldDrawColor : null;
    _heldDrawColor = null;
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
      // 뽑기는 어느 더미에서 어느 타일을 뽑았는지도 담아 둔다. 조커는 자리를 정한 뒤 "뽑기" 하나로 합쳐 보여 준다.
      final isDraw = move[0] == 0 || heldColor != null;
      _enqueue(DvEffect(
        actor: actor,
        kind: isDraw ? 0 : move[0],
        number: isDraw ? (heldColor ?? move[1]) : null,
        tile: isDraw ? (state.pendingJoker ?? state.drawn) : null,
        blocking: true,
        ask: true,
      ));
    }
    if (state.isOver) {
      onFeedback?.call('win');
    } else if (move[0] == 2 && g != null && !identical(g, before)) {
      onFeedback?.call(g.correct ? 'right' : 'wrong');
    } else if (move[0] == 0 || heldColor != null) {
      onFeedback?.call('draw');
    }
    notifyListeners();
  }

  // ── 다른 기기의 수 (Wi‑Fi 대결) ──

  /// 다른 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  ///
  /// 앞의 수를 보여 주는 연출이 아직 끝나지 않았으면 판에 바로 반영하지 않고 줄 세워 두었다가, 연출이 끝나는 대로 하나씩 반영한다.
  /// (규칙에 맞는지는 줄 서 있는 수까지 둔 모습으로 미리 확인한다)
  bool receiveMove(List<int> move, {int? index}) {
    final latest = _latest;
    if (!online || latest.isOver || halted || latest.turn == humanSeat) return false;
    if (index != null && index != moveCount + _incoming.where((e) => e.move != null).length) return false;
    if (!latest.isLegal(move)) return false;
    if (!animate || (_incoming.isEmpty && !_pumping && _effects.isEmpty)) {
      _apply(move);
      _next(); // (다음이 CPU 차례이면 방장 기기가 CPU의 수를 둔다)
      return true;
    }
    (_shadow ??= state.clone()).apply(move);
    _incoming.add(_Incoming.move(move));
    notifyListeners();
    return true;
  }

  /// 다른 기기의 사람이 맞히려고 상대 타일([seat]의 [index]번째)을 골랐다는 소식 (고름을 풀면 둘 다 -1).
  /// 앞의 수를 보여 주는 동안이면 그 연출이 끝난 뒤에 보여 준다.
  void receiveSelection(int actor, int seat, int index) {
    if (!online || isOver || halted || actor == humanSeat || actor < 0 || actor >= players) return;
    if (!animate || (_incoming.isEmpty && !_pumping && _effects.isEmpty)) {
      _showSelection(actor, seat, index);
      return;
    }
    _incoming.add(_Incoming.selection(actor, seat, index));
  }

  void _showSelection(int actor, int seat, int index) {
    // 지금 그 사람 차례이고, 판에 있는 숨은 타일일 때만 보여 준다 (엉뚱한 소식은 무시)
    var ok = actor == state.turn && seat >= 0 && seat < players && seat != actor && index >= 0;
    if (ok) {
      final row = state.rows[seat];
      ok = index < row.length && !state.isRevealed(row[index]) && !state.isOut(seat);
    }
    final next = ok ? (actor: actor, seat: seat, index: index) : null;
    if (next == remoteSel) return;
    remoteSel = next;
    notifyListeners();
  }

  // ── CPU ──

  void _next() {
    if (_disposed || !runsCpu || isOver || halted || !isCpuSeat(turn) || _cpuRunning) return;
    _cpuLoop();
  }

  /// CPU 차례 동안 수를 하나씩 둔다 (사람이 볼 수 있게 수마다 잠깐 쉰다). 사람 차례가 오면 멈춘다.
  Future<void> _cpuLoop() async {
    final epoch = ++_epoch;
    _cpuRunning = true;
    notifyListeners();
    while (!_disposed && epoch == _epoch && !isOver && !halted && isCpuSeat(turn)) {
      await Future<void>.delayed(GameSpeed.scale(cpuStepDelay));
      await _effectsIdle(); // (직전에 다른 사람이 둔 수를 다 보여 준 뒤에 둔다)
      while (cpuHold && !_disposed && epoch == _epoch) {
        await Future<void>.delayed(const Duration(milliseconds: 100)); // (사람이 고르는 동안 기다린다)
      }
      if (_disposed || epoch != _epoch || isOver || halted || !isCpuSeat(turn)) break;
      final move = DvAi.choose(state, level, _rng);
      _apply(move);
      if (online) onLocalMove?.call(move); // (같은 Wi‑Fi 방이면 CPU의 수도 다른 기기들에 알린다)
      // 조커를 뽑았으면 자리도 바로 정한다 (보는 사람에게는 뽑기 하나로 보인다)
      if (state.phase == DvPhase.placeJoker && isCpuSeat(turn)) {
        final place = DvAi.choose(state, level, _rng);
        _apply(place);
        if (online) onLocalMove?.call(place);
      }
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

  /// 사람이 모두 탈락한 판을 여기서 끝낸다 (CPU끼리의 남은 순위 싸움은 보지 않는다).
  /// 이긴 사람은 [resignWinner]: 그 시점에 숨은 타일이 가장 많이 남은 CPU. 끝냈으면 true.
  bool endWatching() {
    if (!_humansOutNow) return false;
    _epoch++;
    _clearEffects();
    _cpuRunning = false;
    clearSelection();
    var best = -1, bestN = -1;
    for (var p = 0; p < players; p++) {
      if (state.isOut(p)) continue;
      final n = state.hiddenCount(p);
      if (n > bestN) {
        bestN = n;
        best = p;
      }
    }
    halted = true;
    endedWatching = true;
    resignWinner = best;
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
