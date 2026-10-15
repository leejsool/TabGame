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

  /// CPU 대결에서 사람이 맡은 쪽 (0 = 먼저, 1 = 나중).
  final int humanSide;
  final ProphLevel level;

  bool get vsCpu => mode == PlayMode.vsCpu;
  int get cpuSide => 1 - humanSide;

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

  bool get isOver => state.isOver;
  int get moveCount => moves.length;

  /// 지금 사람이 쓸 수 있는가.
  bool get humanCanAct => !isOver && !thinking && (!vsCpu || state.turn == humanSide);

  void _rebuild() {
    state = ProphState.fromMoves(rows, cols, moves);
  }

  /// 화면이 준비되면 부른다 (CPU가 먼저 쓰는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  void restart() {
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
    _apply(encodeMove(cell, value));
    _maybeCpu();
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
  bool get canResign => !isOver && moves.isNotEmpty;

  /// 기권하는 쪽: CPU 대결이면 사람, 둘이서 할 때는 지금 차례인 쪽.
  int get resigningSide => vsCpu ? humanSide : state.turn;

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    selected = -1;
    notifyListeners();
    return true;
  }

  // ── 되돌리기 ──

  /// 되돌렸을 때의 수 개수 (되돌릴 수 없으면 null).
  int? get _undoTarget {
    if (moves.isEmpty || thinking) return null;
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
