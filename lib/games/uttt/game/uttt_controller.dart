import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';

/// 궁극 틱택토 한 판의 진행(규칙 + CPU + 되돌리기).
/// 같은 Wi‑Fi 대결([PlayMode.wifi])에서는 내 수를 [onLocalMove]로 알리고, 상대의 수는 [receiveMove]로 받는다.
class UtttController extends ChangeNotifier {
  UtttController({
    required this.mode,
    this.humanSide = kX,
    this.level = UttLevel.normal,
    this.firstTurn = kX,
  }) {
    _rebuild();
  }

  final PlayMode mode;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 쪽 (kX / kO).
  final int humanSide;
  final UttLevel level;

  /// 먼저 시작하는 쪽. 다음 판에서는 번갈아 바뀐다.
  int firstTurn;

  bool get vsCpu => mode == PlayMode.vsCpu;

  /// 같은 Wi‑Fi의 다른 기기와 겨루는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한쪽만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;
  int get cpuSide => 1 - humanSide;

  /// 내가 둔 수를 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(int move)? onLocalMove;

  /// 누군가 기권해서 중단된 판인가 (더는 둘 수 없다. [restart]하면 풀린다).
  bool halted = false;

  /// 지금까지 둔 수들.
  final List<int> moves = [];

  late UttState state;
  final CpuTurnRunner _cpu = CpuTurnRunner();

  /// CPU가 수를 고르는 중인가.
  bool get thinking => _cpu.thinking;

  /// 방금 둔 수 (없으면 -1)와 두는 횟수 (애니메이션 트리거용).
  int lastMove = -1;
  int moveSerial = 0;

  /// 방금 둔 수로 차지(또는 무승부로 닫힘)된 작은 판 (없으면 -1).
  int lastCaptured = -1;

  final Random _rng = Random();

  /// 수를 둘 때/이겼을 때 알림 ('place' | 'win').
  void Function(String kind)? onFeedback;

  bool get isOver => state.isOver;
  Outcome get outcome => state.outcome;
  int get moveCount => moves.length;

  /// 지금 사람이 둘 수 있는가.
  bool get humanCanAct => !isOver && !halted && !thinking && (!oneSeat || state.turn == humanSide);

  void _rebuild() {
    state = UttState.fromMoves(moves, firstTurn: firstTurn);
  }

  /// 화면이 준비되면 부른다 (CPU가 먼저 두는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  /// 새 판. [swapStart]면 먼저 시작하는 쪽을 바꾼다.
  void restart({bool swapStart = true}) {
    if (swapStart) firstTurn = 1 - firstTurn;
    halted = false;
    moves.clear();
    lastMove = -1;
    lastCaptured = -1;
    _cpu.cancel();
    _rebuild();
    notifyListeners();
    _maybeCpu();
  }

  // ── 두기 ──

  /// 사람이 [move]를 둔다. 합법이 아니거나 차례가 아니면 false.
  bool play(int move) {
    if (!humanCanAct || !state.isLegal(move)) return false;
    _apply(move);
    onLocalMove?.call(move);
    _maybeCpu();
    return true;
  }

  /// 상대 기기에서 온 수를 둔다 (Wi‑Fi 대결). 상대 차례가 아니거나 둘 수 없는 수면 false (그러면 판이 어긋난 것이다).
  bool receiveMove(int move) {
    if (!online || isOver || halted || state.turn == humanSide || !state.isLegal(move)) return false;
    _apply(move);
    return true;
  }

  void _apply(int move) {
    final before = state.bigX | state.bigO | state.bigDraw;
    moves.add(move);
    state.apply(move);
    final after = state.bigX | state.bigO | state.bigDraw;
    final changed = after ^ before;
    lastCaptured = changed == 0 ? -1 : changed.bitLength - 1;
    lastMove = move;
    moveSerial++;
    onFeedback?.call(state.isOver ? 'win' : 'place');
    notifyListeners();
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_cpu.disposed || !vsCpu || isOver || state.turn != cpuSide) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final args = [level.index, _rng.nextInt(1 << 30), firstTurn, ...moves];
    final move = await _cpu.run(
      task: () => compute(_cpuTask, args),
      minTime: const Duration(milliseconds: 650),
      onStart: notifyListeners,
    );
    if (move == null) return;
    _apply(move);
  }

  // ── 기권 ──

  /// 기권할 수 있는가 (한 수라도 둔 진행 중인 판).
  bool get canResign => !isOver && !halted && moves.isNotEmpty;

  /// 기권하는 쪽: CPU 대결·Wi‑Fi 대결이면 나, 둘이서 할 때는 지금 차례인 쪽.
  int get resigningSide => oneSeat ? humanSide : state.turn;

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    halted = true;
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결). 판은 거기서 멈춘다.
  void opponentResigned() {
    if (!online || isOver || halted) return;
    halted = true;
    notifyListeners();
  }

  // ── 되돌리기 ──

  /// 되돌렸을 때의 수 개수 (되돌릴 수 없으면 null).
  int? get _undoTarget {
    if (moves.isEmpty || thinking || online || halted) return null; // (Wi‑Fi 대결은 되돌릴 수 없다)
    if (!vsCpu) return moves.length - 1;
    // 사람 차례가 되는 가장 가까운 시점까지
    for (var k = moves.length - 1; k >= 0; k--) {
      if ((firstTurn + k) % 2 == humanSide) return k;
    }
    return null;
  }

  bool get canUndo => _undoTarget != null;

  /// 내 마지막 수를 되돌린다. (CPU 대결이면 CPU의 응답 수까지 함께)
  void undo() {
    final k = _undoTarget;
    if (k == null) return;
    moves.length = k;
    _cpu.cancel();
    _rebuild();
    lastMove = moves.isEmpty ? -1 : moves.last;
    lastCaptured = -1;
    moveSerial++;
    notifyListeners();
  }

  @override
  void dispose() {
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [난이도, seed, 먼저 시작한 쪽, ...지금까지의 수]
int _cpuTask(List<int> args) {
  final state = UttState.fromMoves(args.sublist(3), firstTurn: args[2]);
  return UttAi.choose(state, UttLevel.values[args[0]], Random(args[1]));
}
