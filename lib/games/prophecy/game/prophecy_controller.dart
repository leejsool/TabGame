import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/prophecy_ai.dart';
import '../core/prophecy_rules.dart';

/// 예언 한 판의 진행 (규칙 + 칸 고르기 + CPU + 되돌리기).
///
/// 플레이어는 0(먼저 쓰는 쪽)과 1. 사람은 칸을 눌러 고른([select]) 뒤 숫자나 X를 쓴다([write]).
/// 같은 Wi‑Fi 대결([PlayMode.wifi])에서는 내 수를 [onLocalMove]로 알리고, 상대의 수는 [receiveMove]로 받는다.
class ProphecyController extends ChangeNotifier {
  ProphecyController({
    required this.mode,
    this.rows = 5,
    this.cols = 5,
    this.humanSide = 0,
    this.level = ProphLevel.normal,
  }) {
    _rebuild();
  }

  final PlayMode mode;
  final int rows, cols;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 쪽 (0 = 먼저, 1 = 나중). Wi‑Fi 대결은 한 판 더 할 때마다 서로 바뀐다.
  int humanSide;
  final ProphLevel level;

  bool get vsCpu => mode == PlayMode.vsCpu;

  /// 같은 Wi‑Fi의 다른 기기와 겨루는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한쪽만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;
  int get cpuSide => 1 - humanSide;

  /// 내가 둔 수를 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(int move)? onLocalMove;

  /// 지금까지 둔 수들 (encodeMove). 저절로 생기는 X는 여기 없다.
  final List<int> moves = [];

  late ProphState state;
  final CpuTurnRunner _cpu = CpuTurnRunner();

  /// CPU가 수를 고르는 중인가.
  bool get thinking => _cpu.thinking;

  /// 사람이 고른 칸 (없으면 -1).
  int selected = -1;

  /// 방금 쓴 칸 (없으면 -1)과 그 수 때문에 저절로 X가 된 칸들.
  int lastCell = -1;
  List<int> lastAuto = const [];

  /// 수를 둘 때마다 늘어나는 번호 (애니메이션을 다시 시작하는 신호).
  int moveSerial = 0;

  final Random _rng = Random();

  /// 소리/진동 알림 ('write' | 'cross' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  /// 누군가 기권해서 중단된 판인가 (더는 둘 수 없다. [restart]하면 풀린다).
  bool halted = false;

  bool get isOver => state.isOver;
  int get moveCount => moves.length;

  /// 지금 사람이 쓸 수 있는가.
  bool get humanCanAct => !isOver && !halted && !thinking && (!oneSeat || state.turn == humanSide);

  void _rebuild() {
    state = ProphState.fromMoves(rows, cols, moves);
  }

  /// 화면이 준비되면 부른다 (CPU가 먼저 쓰는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  /// 새 판을 시작한다. [swapSides]가 true면 먼저/나중을 서로 바꾼다 (Wi‑Fi 대결의 한 판 더).
  void restart({bool swapSides = false}) {
    if (swapSides) humanSide = 1 - humanSide;
    halted = false;
    moves.clear();
    selected = -1;
    lastCell = -1;
    lastAuto = const [];
    _cpu.cancel();
    moveSerial++;
    _rebuild();
    notifyListeners();
    _maybeCpu();
  }

  // ── 두기 ──

  /// 칸 [cell]을 고른다 (빈칸만). 이미 고른 칸을 다시 누르면 고름을 푼다.
  void select(int cell) {
    if (!humanCanAct) return;
    if (cell < 0 || cell >= state.cells.length || state.cells[cell] != kBlank) {
      onFeedback?.call('bad');
      return;
    }
    selected = selected == cell ? -1 : cell;
    notifyListeners();
  }

  /// 고른 칸에 [value](숫자 또는 [kCross])를 쓴다. 쓸 수 없으면 false.
  bool write(int value) {
    if (!humanCanAct || selected < 0 || !state.canPlay(selected, value)) {
      onFeedback?.call('bad');
      return false;
    }
    final cell = selected;
    selected = -1;
    final move = encodeMove(cell, value);
    _apply(move);
    onLocalMove?.call(move);
    _maybeCpu();
    return true;
  }

  /// 상대 기기에서 온 수를 둔다 (Wi‑Fi 대결). 상대 차례가 아니거나 둘 수 없는 수면 false (그러면 판이 어긋난 것이다).
  bool receiveMove(int move) {
    if (!online || isOver || halted || state.turn == humanSide) return false;
    if (!state.canPlay(moveCell(move), moveValue(move))) return false;
    selected = -1;
    _apply(move);
    return true;
  }

  void _apply(int move) {
    moves.add(move);
    lastCell = moveCell(move);
    lastAuto = state.play(lastCell, moveValue(move));
    moveSerial++;
    onFeedback?.call(state.isOver ? 'win' : (moveValue(move) == kCross ? 'cross' : 'write'));
    notifyListeners();
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_cpu.disposed || !vsCpu || isOver || state.turn != cpuSide) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final args = [rows, cols, level.index, _rng.nextInt(1 << 30), ...moves];
    final move = await _cpu.run(
      task: () => compute(_cpuTask, args),
      minTime: const Duration(milliseconds: 700),
      onStart: notifyListeners,
    );
    if (move == null) return;
    selected = -1;
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
    selected = -1;
    halted = true;
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결). 판은 거기서 멈춘다.
  void opponentResigned() {
    if (!online || isOver || halted) return;
    selected = -1;
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
      if (k % 2 == humanSide) return k;
    }
    return null;
  }

  bool get canUndo => !isOver && _undoTarget != null;

  /// 내 마지막 수를 되돌린다. (CPU 대결이면 CPU의 응답 수까지 함께)
  void undo() {
    final k = _undoTarget;
    if (k == null || isOver) return;
    moves.length = k;
    _cpu.cancel();
    _rebuild();
    selected = -1;
    lastCell = moves.isEmpty ? -1 : moveCell(moves.last);
    lastAuto = const [];
    moveSerial++;
    notifyListeners();
    _maybeCpu();
  }

  @override
  void dispose() {
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [행, 열, 난이도, seed, ...지금까지의 수]
int _cpuTask(List<int> args) {
  final state = ProphState.fromMoves(args[0], args[1], args.sublist(4));
  return ProphAi.choose(state, ProphLevel.values[args[2]], Random(args[3]));
}
