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
  }) : seed = seed ?? Random().nextInt(1 << 30) {
    _deal();
  }

  final PlayMode mode;
  final int players;

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

  /// CPU가 한 수 두고 다음 수를 두기까지 기다리는 시간 (맞히는 수는 1.5배). 시험에서는 줄인다.
  Duration cpuStepDelay = const Duration(milliseconds: 900);

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
  bool get humanCanAct => !isOver && !halted && !thinking && turn == humanSeat;

  void _deal() {
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
    moves.add(move);
    state.apply(move);
    selSeat = -1;
    selIndex = -1;
    moveSerial++;
    final g = state.lastGuess;
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
      if (move[0] == 2) {
        // 맞히는 수는 결과를 볼 시간을 조금 더 준다
        await Future<void>.delayed(cpuStepDelay ~/ 2);
      }
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
    super.dispose();
  }
}
