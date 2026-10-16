import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/quoridor_ai.dart';
import '../core/quoridor_rules.dart';

/// 쿼리도 한 판의 진행 (규칙 + 말·벽 고르기 + CPU + 되돌리기).
///
/// 2명 또는 4명이 한다. 자리는 0번부터 차례대로 돈다 (4명이면 아래 → 왼쪽 → 위 → 오른쪽).
///  - [PlayMode.local2p]: 한 기기에서 모두 사람이 번갈아 한다 (쿼리도는 숨길 정보가 없다).
///  - [PlayMode.vsCpu]: 나는 [humanSeat]번이고 나머지는 CPU.
///  - [PlayMode.wifi]: 같은 Wi‑Fi의 다른 기기들과 한다 (2명 또는 4명, 기기마다 한 자리). 내 수는 [onLocalMove]로 알리고,
///    다른 사람의 수는 [receiveMove]로 받는다.
class QuoridorController extends ChangeNotifier {
  QuoridorController({
    required this.mode,
    this.players = 2,
    this.humanSeat = 0,
    this.level = QLevel.normal,
  }) {
    assert(players == 2 || players == 4);
    _rebuild();
  }

  final PlayMode mode;
  final int players;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 자리. 한 판 더 할 때마다 한 칸씩 돈다.
  int humanSeat;
  final QLevel level;

  bool get vsCpu => mode == PlayMode.vsCpu;
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한 자리만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;

  bool isCpuSeat(int seat) => vsCpu && seat != humanSeat;

  /// 내가 둔 수를 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(int move)? onLocalMove;

  /// 소리/진동 알림 ('move' | 'wall' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  /// 지금까지 둔 수들.
  final List<int> moves = [];

  late QState state;
  final CpuTurnRunner _cpu = CpuTurnRunner();
  final Random _rng = Random();

  bool get thinking => _cpu.thinking;
  bool get isOver => state.isOver;
  int get moveCount => moves.length;
  int get turn => state.turn;

  /// 방금 둔 수 (없으면 -1).
  int get lastMove => moves.isEmpty ? -1 : moves.last;

  /// 방금 수를 둔 자리 (없으면 -1). 벽이 어느 더미에서 날아오는지 보여 주는 데 쓴다.
  int lastMover = -1;

  /// 수를 둘 때마다 늘어나는 번호 (애니메이션을 다시 시작하는 신호).
  int moveSerial = 0;

  /// 누군가 기권해서 멈춘 판인가 ([restart]하면 풀린다).
  bool halted = false;

  /// 벽을 세우려고 고르는 중인가, 그 벽의 방향(0 가로 / 1 세로)과 고른 자리 (없으면 -1).
  bool wallMode = false;
  int wallOrientPick = 0;
  int wallRowPick = -1, wallColPick = -1;

  /// 지금 사람이 둘 수 있는가.
  bool get humanCanAct => !isOver && !halted && !thinking && !autoPlaying && (!oneSeat || turn == humanSeat);

  // ── 자동 이동 (모든 벽을 다 썼을 때) ──

  /// 자동 이동 한 걸음마다 기다리는 시간 (시험에서는 줄인다).
  Duration autoStepDelay = const Duration(milliseconds: 700);

  bool _auto = false;
  bool _autoStopped = false;
  int _autoEpoch = 0;
  bool _disposed = false;

  /// 모든 사람이 벽을 다 써서, 말들이 가장 짧은 길로 저절로 움직이는 중인가.
  /// 벽이 없으면 결과는 사실상 정해져 있어서, 끝까지 자동으로 보여 준다.
  bool get autoPlaying => _auto;

  bool get _shouldAuto => !isOver && !halted && !_autoStopped && state.wallsLeft.every((w) => w <= 0);

  /// 자동 이동을 멈추고 (돌고 있던 것은 버리고) 상태를 처음 모습으로 돌려 둔다.
  void _cancelAuto({bool allowAgain = true}) {
    _autoEpoch++;
    _auto = false;
    if (allowAgain) _autoStopped = false;
  }

  /// 수를 둔 뒤나 판이 바뀐 뒤에 부른다: 자동 이동을 시작하거나, CPU 차례면 CPU가 둔다.
  void _next() {
    if (_shouldAuto) {
      _autoPlay();
    } else {
      _maybeCpu();
    }
  }

  Future<void> _autoPlay() async {
    if (_auto) return;
    _auto = true;
    final epoch = ++_autoEpoch;
    final seen = <String>{};
    notifyListeners();
    while (true) {
      await Future<void>.delayed(autoStepDelay);
      if (_disposed || epoch != _autoEpoch) return;
      if (isOver || halted) break;
      // 말들이 서로 길을 막아 같은 모양이 되풀이되면 자동 이동을 멈추고 직접 두게 한다 (끝없이 돌지 않도록)
      if (!seen.add('${state.turn}|${state.pawn.join(',')}')) {
        _autoStopped = true;
        break;
      }
      _apply(QAi.autoStep(state));
    }
    if (_disposed || epoch != _autoEpoch) return;
    _auto = false;
    notifyListeners();
    if (!isOver) _maybeCpu();
  }

  void _rebuild() {
    state = QState.fromMoves(players, moves);
  }

  /// 화면이 준비되면 부른다 (CPU가 먼저 두는 판이면 CPU가 시작한다).
  void start() => _next();

  /// 새 판. [rotate]가 true면 내 자리가 한 칸 돈다 (CPU·Wi‑Fi 대결의 한 판 더).
  void restart({bool rotate = false}) {
    if (rotate && oneSeat) humanSeat = (humanSeat + 1) % players;
    halted = false;
    moves.clear();
    _clearPick();
    wallMode = false;
    _cpu.cancel();
    _cancelAuto();
    moveSerial++;
    _rebuild();
    notifyListeners();
    _next();
  }

  void _clearPick() {
    wallRowPick = -1;
    wallColPick = -1;
  }

  // ── 말 ──

  /// 지금 사람이 말을 옮길 수 있는 칸들 (벽 고르는 중이거나 사람이 둘 수 없으면 비어 있다).
  List<int> get targets => humanCanAct && !wallMode ? state.legalPawnMoves() : const [];

  /// 칸 [cell]을 눌렀다: 갈 수 있는 칸이면 말을 옮긴다.
  bool tapCell(int cell) {
    if (!humanCanAct || wallMode) return false;
    if (!state.legalPawnMoves().contains(cell)) {
      onFeedback?.call('bad');
      return false;
    }
    _play(cell);
    return true;
  }

  // ── 벽 ──

  /// 벽 고르기를 켜고 끈다.
  void setWallMode(bool on) {
    if (on && (!humanCanAct || state.wallsLeft[turn] <= 0)) {
      onFeedback?.call('bad');
      return;
    }
    wallMode = on;
    _clearPick();
    notifyListeners();
  }

  /// 나무막대를 판의 격자점 (r, c)에 놓아 둔다 (끌어다 놓았을 때). 벽 고르기가 저절로 켜지고, 확정은 [confirmWall]로 따로 한다.
  void placeWall(int r, int c) {
    if (!humanCanAct || state.wallsLeft[turn] <= 0) {
      onFeedback?.call('bad');
      return;
    }
    wallMode = true;
    pickWall(r, c);
  }

  /// 놓아 둔 막대를 거두고 벽 고르기를 끈다.
  void cancelWall() {
    if (!wallMode) return;
    wallMode = false;
    _clearPick();
    notifyListeners();
  }

  void toggleWallOrient() {
    wallOrientPick = 1 - wallOrientPick;
    notifyListeners();
  }

  /// 벽의 앵커 (r, c)를 골랐다.
  void pickWall(int r, int c) {
    if (!wallMode || !humanCanAct) return;
    if (r < 0 || r >= kAnchors || c < 0 || c >= kAnchors) return;
    wallRowPick = r;
    wallColPick = c;
    notifyListeners();
  }

  bool get hasWallPick => wallRowPick >= 0;

  /// 고른 벽을 지금 세울 수 있는가.
  bool get canConfirmWall => hasWallPick && humanCanAct && state.canPlaceWall(wallOrientPick, wallRowPick, wallColPick);

  /// 고른 벽을 세운다. 안 되면 false.
  bool confirmWall() {
    if (!wallMode || !hasWallPick) return false;
    if (!canConfirmWall) {
      onFeedback?.call('bad');
      return false;
    }
    final move = wallMove(wallOrientPick, wallRowPick, wallColPick);
    wallMode = false;
    _clearPick();
    _play(move);
    return true;
  }

  // ── 두기 ──

  void _play(int move) {
    _apply(move);
    onLocalMove?.call(move);
    _next();
  }

  void _apply(int move) {
    lastMover = state.turn;
    moves.add(move);
    state.apply(move);
    moveSerial++;
    onFeedback?.call(state.isOver ? 'win' : (isWallMove(move) ? 'wall' : 'move'));
    notifyListeners();
  }

  /// 상대 기기에서 온 수를 둔다 (Wi‑Fi 대결). 상대 차례가 아니거나 둘 수 없는 수면 false (그러면 판이 어긋난 것이다).
  bool receiveMove(int move, {int? index}) {
    if (!online || isOver || halted || turn == humanSeat) return false;
    if (index != null && index != moveCount) return false;
    if (!state.isLegal(move)) return false;
    wallMode = false;
    _clearPick();
    _apply(move);
    _next();
    return true;
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_cpu.disposed || !vsCpu || isOver || halted || !isCpuSeat(turn)) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final args = [players, level.index, _rng.nextInt(1 << 30), ...moves];
    final move = await _cpu.run(
      task: () => compute(_cpuTask, args),
      minTime: const Duration(milliseconds: 1000),
      onStart: notifyListeners,
    );
    if (move == null) return;
    _apply(move);
    _next();
  }

  // ── 기권 ──

  /// 기권할 수 있는가 (한 수라도 둔 진행 중인 판). 4명이 한 기기로 하거나 Wi‑Fi로 할 때는 기권하면 누가 이기는 건지 정할 수 없어 기권이 없다.
  bool get canResign => !isOver && !halted && !autoPlaying && moves.isNotEmpty && (vsCpu || players == 2);

  /// 기권하는 사람: CPU 대결·Wi‑Fi 대결이면 나, 한 기기로 할 때는 지금 차례인 사람.
  int get resigningSeat => oneSeat ? humanSeat : turn;

  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    _cancelAuto(allowAgain: false);
    wallMode = false;
    _clearPick();
    halted = true;
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결).
  void opponentResigned() {
    if (!online || isOver || halted) return;
    _cancelAuto(allowAgain: false);
    wallMode = false;
    _clearPick();
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
      if (k % players == humanSeat) return k;
    }
    return null;
  }

  bool get canUndo => !isOver && !autoPlaying && _undoTarget != null;

  /// 내 마지막 수를 되돌린다 (CPU 대결이면 CPU들의 수까지 함께).
  void undo() {
    final k = _undoTarget;
    if (k == null || isOver) return;
    moves.length = k;
    _cpu.cancel();
    _cancelAuto();
    _rebuild();
    wallMode = false;
    _clearPick();
    moveSerial++;
    notifyListeners();
    _next();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoEpoch++;
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [사람 수, 난이도, 씨앗, ...지금까지의 수]
int _cpuTask(List<int> args) {
  final state = QState.fromMoves(args[0], args.sublist(3));
  return QAi.choose(state, QLevel.values[args[1]], Random(args[2]));
}
