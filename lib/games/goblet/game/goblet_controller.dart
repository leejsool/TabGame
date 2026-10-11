import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';

/// 말 하나를 가리키는 번호 (0~11): 팀*6 + (크기-1)*2 + 같은 크기 중 몇 번째(0/1).
typedef PieceId = int;

PieceId pieceId(Team team, int size, int idx) => team.index * 6 + (size - 1) * 2 + idx;
Team teamOfPiece(PieceId id) => id < 6 ? Team.red : Team.blue;
int sizeOfPiece(PieceId id) => (id % 6) ~/ 2 + 1;

enum ResultKind { win, draw }

class GobbletResult {
  const GobbletResult.win(this.winner, this.line, {this.byReveal = false})
      : kind = ResultKind.win;
  const GobbletResult.draw()
      : kind = ResultKind.draw,
        winner = null,
        line = const [],
        byReveal = false;

  final ResultKind kind;
  final Team? winner;
  final List<int> line;

  /// 상대가 말을 들어 올리는 바람에 내 줄이 드러나서 이긴 경우.
  final bool byReveal;
}

class _Snapshot {
  _Snapshot(GobbletController c)
      : owners = List.of(c.board.owners),
        turn = c.board.turn,
        loc = List.of(c.loc),
        seen = Map.of(c._seen);

  final List<int> owners;
  final int turn;
  final List<int> loc;
  final Map<String, int> seen;
}

/// 고블렛 고블러스 한 판의 진행(규칙 + 말 위치 + CPU + 되돌리기).
class GobbletController extends ChangeNotifier {
  GobbletController({
    required this.mode,
    this.humanTeam = Team.red,
    this.level = CpuLevel.normal,
    this.startingTeam = Team.red,
  }) {
    _reset();
  }

  final PlayMode mode;

  /// 아래쪽(내 쪽)에 놓이는 팀. CPU 대전이면 사람의 팀.
  final Team humanTeam;
  final CpuLevel level;
  Team startingTeam;

  bool get vsCpu => mode == PlayMode.vsCpu;
  Team get cpuTeam => humanTeam.other;

  late GobbletBoard board;

  /// 말 위치: -1 = 대기(손), 0~8 = 판 위 칸.
  final List<int> loc = List.filled(12, -1);

  GobbletResult? result;
  PieceId? selected;
  Set<int> targets = {};
  bool thinking = false;

  /// 마지막으로 움직인 말과 움직임 번호 (화면 애니메이션·겹침 순서용).
  PieceId? lastMoved;
  int moveSerial = 0;

  final Map<String, int> _seen = {};
  final List<_Snapshot> _history = [];
  int _epoch = 0;
  bool _disposed = false;
  final Random _rng = Random();

  /// 말을 집거나 놓을 때 알림 (진동 등).
  void Function(String kind)? onFeedback;

  Team get turn => board.turnTeam;
  bool get isOver => result != null;

  /// 지금까지 둔 수 (양쪽 합계).
  int get moveCount => _history.length;
  bool get canUndo => _history.isNotEmpty && !thinking;

  /// 지금 사람이 말을 움직일 수 있는가.
  bool get humanCanAct => !isOver && !thinking && (!vsCpu || turn == humanTeam);

  void _reset() {
    board = GobbletBoard();
    board.turn = startingTeam.owner;
    loc.fillRange(0, 12, -1);
    result = null;
    selected = null;
    targets = {};
    thinking = false;
    lastMoved = null;
    _history.clear();
    _seen
      ..clear()
      ..[board.key] = 1;
    _epoch++;
  }

  /// 새 판. [swapStart]면 먼저 시작하는 팀을 바꾼다.
  void restart({bool swapStart = true}) {
    if (swapStart) startingTeam = startingTeam.other;
    _reset();
    notifyListeners();
    _maybeCpu();
  }

  // ── 조회 ──

  /// 대기 중인 말 중 지금 집을 수 있는 말(같은 크기끼리는 번호가 작은 것부터).
  PieceId? reserveFront(Team team, int size) {
    for (var idx = 0; idx < 2; idx++) {
      final id = pieceId(team, size, idx);
      if (loc[id] == -1) return id;
    }
    return null;
  }

  /// 대기 중인 같은 크기 말의 순번 (0이 맨 앞, 없으면 -1).
  int reserveRank(PieceId id) {
    if (loc[id] != -1) return -1;
    final team = teamOfPiece(id), size = sizeOfPiece(id);
    var rank = 0;
    for (var idx = 0; idx < 2; idx++) {
      final other = pieceId(team, size, idx);
      if (other == id) return rank;
      if (loc[other] == -1) rank++;
    }
    return rank;
  }

  /// 칸에 쌓인 말들 (아래→위, 크기순).
  List<PieceId> stackAt(int cell) {
    final ids = [
      for (var id = 0; id < 12; id++)
        if (loc[id] == cell) id,
    ]..sort((a, b) => sizeOfPiece(a).compareTo(sizeOfPiece(b)));
    return ids;
  }

  PieceId? topAt(int cell) {
    final s = stackAt(cell);
    return s.isEmpty ? null : s.last;
  }

  /// 말의 쌓인 높이 (0 = 맨 아래, 판 위가 아니면 -1).
  int heightOf(PieceId id) {
    final c = loc[id];
    if (c < 0) return -1;
    return stackAt(c).indexOf(id);
  }

  bool isCovered(PieceId id) {
    final c = loc[id];
    return c >= 0 && topAt(c) != id;
  }

  /// 사람이 지금 집을 수 있는 말인가.
  bool isSelectable(PieceId id) {
    if (!humanCanAct || teamOfPiece(id) != turn) return false;
    if (loc[id] == -1) return reserveFront(turn, sizeOfPiece(id)) == id;
    return topAt(loc[id]) == id;
  }

  Set<int> legalTargets(PieceId id) {
    final result = <int>{};
    for (final m in board.legalMoves()) {
      if (m.isPlace) {
        if (loc[id] == -1 && m.size == sizeOfPiece(id)) result.add(m.to);
      } else if (m.from == loc[id]) {
        result.add(m.to);
      }
    }
    return result;
  }

  // ── 사람 조작 ──

  void select(PieceId id) {
    if (!isSelectable(id)) return;
    selected = id;
    targets = legalTargets(id);
    onFeedback?.call('pick');
    notifyListeners();
  }

  void clearSelection() {
    if (selected == null) return;
    selected = null;
    targets = {};
    notifyListeners();
  }

  /// 선택한 말을 칸으로 옮긴다. 할 수 없으면 false.
  bool moveSelectedTo(int cell) {
    final id = selected;
    if (id == null) return false;
    return dropPiece(id, cell);
  }

  /// 말 [id]를 [cell]에 놓는다. 규칙에 맞지 않으면 false (아무 일도 없음).
  bool dropPiece(PieceId id, int cell) {
    if (!isSelectable(id) || !legalTargets(id).contains(cell)) return false;
    final size = sizeOfPiece(id);
    final move = loc[id] == -1
        ? GobbletMove.place(size, cell)
        : GobbletMove.slide(loc[id], cell, size);
    _applyMove(move, id);
    onFeedback?.call('drop');
    _maybeCpu();
    return true;
  }

  // ── 수 적용 ──

  void _applyMove(GobbletMove move, PieceId id) {
    _history.add(_Snapshot(this));
    final mover = board.turn;
    board.apply(move);
    loc[id] = move.to;
    lastMoved = id;
    moveSerial++;
    selected = null;
    targets = {};

    final w = board.winnerAfter(mover);
    if (w != 0) {
      final line = board.lineOf(w)!;
      result = GobbletResult.win(Team.fromOwner(w), line, byReveal: w != mover);
      onFeedback?.call('win');
    } else {
      final n = (_seen[board.key] ?? 0) + 1;
      _seen[board.key] = n;
      if (n >= 3) result = const GobbletResult.draw();
    }
    notifyListeners();
  }

  PieceId _idForMove(GobbletMove m) {
    if (m.isPlace) return reserveFront(turn, m.size)!;
    return topAt(m.from)!;
  }

  // ── CPU ──

  /// 화면이 준비되면 부른다 (CPU가 먼저 두는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  void _maybeCpu() {
    if (_disposed || !vsCpu || isOver || turn != cpuTeam) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final epoch = _epoch;
    thinking = true;
    notifyListeners();
    final owners = List<int>.of(board.owners);
    final args = [board.turn, level.index, _rng.nextInt(1 << 30), ...owners];
    final results = await Future.wait([
      compute(_cpuTask, args),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (_disposed || epoch != _epoch) return;
    final r = results[0] as List<int>;
    final move = r[0] < 0 ? GobbletMove.place(r[2], r[1]) : GobbletMove.slide(r[0], r[1], r[2]);
    thinking = false;
    _applyMove(move, _idForMove(move));
    onFeedback?.call('drop');
  }

  // ── 되돌리기 ──

  /// 내 마지막 수를 되돌린다. (CPU 대전이면 CPU의 응답 수까지 함께)
  void undo() {
    if (!canUndo) return;
    var steps = 1;
    if (vsCpu) {
      // 사람 차례가 될 때까지 되돌린다
      while (_history.length > steps &&
          Team.fromOwner(_history[_history.length - steps].turn) != humanTeam) {
        steps++;
      }
      if (Team.fromOwner(_history[_history.length - steps].turn) != humanTeam) return;
    }
    late _Snapshot snap;
    for (var i = 0; i < steps; i++) {
      snap = _history.removeLast();
    }
    board = GobbletBoard.raw(List.of(snap.owners), snap.turn);
    loc.setAll(0, snap.loc);
    _seen
      ..clear()
      ..addAll(snap.seen);
    result = null;
    selected = null;
    targets = {};
    lastMoved = null;
    _epoch++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 수를 고른다. args = [turn, level, seed, ...owners(27)]
/// 결과 = [from, to, size] (from = -1 이면 대기 말 올리기)
List<int> _cpuTask(List<int> args) {
  final board = GobbletBoard.raw(args.sublist(3), args[0]);
  final m = GobbletAi.choose(board, CpuLevel.values[args[1]], Random(args[2]));
  return [m.from, m.to, m.size];
}
