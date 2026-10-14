import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../core/sprouts_ai.dart';
import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';
import '../core/sprouts_planner.dart';

class _Snapshot {
  _Snapshot(this.board, this.turn, this.moves);

  final SproutsBoard board;
  final int turn;
  final int moves;
}

/// 콩나물 한 판의 진행: 곡선 긋기, 차례, 끝 판정, CPU, 되돌리기, 힌트.
///
/// 플레이어는 0(먼저 시작)과 1. 마지막으로 수를 둔 사람이 이긴다.
class SproutsController extends ChangeNotifier {
  SproutsController({
    required this.mode,
    this.dotCount = 3,
    this.humanSide = 0,
    this.level = SproutsLevel.normal,
    Random? rng,
    SproutsBoard? board,
  })  : _rng = rng ?? Random(),
        board = board ?? SproutsBoard.initial(dotCount, rng ?? Random());

  final PlayMode mode;
  final int dotCount;

  /// CPU 대결에서 사람이 맡은 쪽 (0 = 먼저, 1 = 나중).
  final int humanSide;
  final SproutsLevel level;
  final Random _rng;

  SproutsBoard board;

  /// 지금 수를 둘 차례 (0 / 1).
  int turn = 0;

  /// 지금까지 둔 수.
  int moveCount = 0;

  /// 이긴 사람 (끝났을 때). null이면 진행 중.
  int? winner;

  /// 기권으로 끝났는가.
  bool resigned = false;

  /// CPU가 생각하는 중.
  bool thinking = false;

  /// 안 되는 수를 그렸을 때의 안내 (다음 동작에서 지워진다).
  String? message;

  /// 방금 둔 수 (애니메이션용): 번호와 새 점.
  int moveSerial = 0;
  int lastMid = -1;

  /// 자리를 만들려고 점과 선을 밀었다면, 밀기 전의 판 (화면이 천천히 옮겨 가는 모습을 보여 줄 때 쓴다).
  SproutsBoard? morphFrom;

  /// 방금 둔 수를 사람이 직접 그었는가 (그렇다면 곡선을 다시 그려 보이지 않고 새 점만 나타낸다).
  bool lastByHuman = false;

  /// 힌트로 보여 주는 곡선 (잠깐 보였다 사라진다).
  List<P>? hintPath;
  Timer? _hintTimer;

  /// 소리/진동 알림 ('draw' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  final List<_Snapshot> _history = [];
  int _epoch = 0;
  bool _disposed = false;

  bool get vsCpu => mode == PlayMode.vsCpu;
  int get cpuSide => 1 - humanSide;
  bool get isOver => winner != null;

  /// 지금 사람이 그을 수 있는가.
  bool get humanCanAct => !isOver && !thinking && (!vsCpu || turn == humanSide);

  bool get canUndo => !thinking && _undoTo() != null;
  bool get canResign => !isOver && moveCount > 0;

  /// 남은 목숨의 합 (한 수마다 1씩 줄어든다).
  int get livesLeft => board.totalLives;

  // ── 사람이 그은 곡선 ──

  /// 손가락이 그린 궤적 [stroke] 으로 한 수를 둔다. 안 되면 [message]를 정하고 false.
  bool tryStroke(List<P> stroke) {
    if (!humanCanAct) return false;
    _clearHint();
    if (stroke.length < 2) {
      return _bad('점에서 점으로 곡선을 그어 주세요');
    }
    final s = board.nearestDot(stroke.first);
    final e = board.nearestDot(stroke.last);
    if (s < 0) return _bad('점에서 시작해 주세요');
    if (e < 0) return _bad('점에서 끝내 주세요');
    final r = board.validate(s, e, stroke);
    if (!r.ok) return _bad(r.reason);
    _commit(s, e, r, byHuman: true);
    return true;
  }

  bool _bad(String reason) {
    message = reason;
    onFeedback?.call('bad');
    notifyListeners();
    return false;
  }

  void _commit(int s, int e, StrokeResult r, {required bool byHuman}) {
    final before = board.copy();
    _history.add(_Snapshot(before, turn, moveCount));
    message = null;
    lastMid = board.apply(s, e, r, turn);
    // 점과 선이 밀렸거나 판의 범위(화면의 확대·축소)가 바뀌었으면 천천히 옮겨 가는 모습을 보여 준다
    morphFrom = (r.layout != null || before.bounds != board.bounds) ? before : null;
    lastByHuman = byHuman;
    moveCount++;
    moveSerial++;
    final mover = turn;
    if (!hasMove(board)) {
      winner = mover; // 마지막으로 수를 둔 사람이 이긴다
      onFeedback?.call('win');
    } else {
      turn = 1 - turn;
      onFeedback?.call('draw');
    }
    notifyListeners();
    _maybeCpu();
  }

  // ── CPU ──

  /// 화면이 준비되면 부른다 (CPU가 먼저 두는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  void _maybeCpu() {
    if (_disposed || !vsCpu || isOver || turn != cpuSide) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final epoch = _epoch;
    thinking = true;
    notifyListeners();
    final args = <Object>[board.toData(), level.index, _rng.nextInt(1 << 30)];
    final results = await Future.wait<Object?>([
      compute(sproutsCpuTask, args),
      Future<void>.delayed(const Duration(milliseconds: 700)),
    ]);
    if (_disposed || epoch != _epoch) return;
    thinking = false;
    final move = decodeCpuMove(results[0]! as List<double>);
    if (move == null) {
      // 둘 곳이 없다 (정상이라면 직전에 끝났을 것이다): 상대가 이긴 것으로 끝낸다
      winner = 1 - turn;
      notifyListeners();
      return;
    }
    _commit(move.s, move.e, move.result, byHuman: false);
  }

  // ── 되돌리기 / 힌트 / 기권 / 새 판 ──

  /// 되돌아갈 스냅샷 번호 (CPU 대결이면 내 차례가 되는 가장 가까운 시점).
  int? _undoTo() {
    if (_history.isEmpty) return null;
    if (!vsCpu) return _history.length - 1;
    for (var k = _history.length - 1; k >= 0; k--) {
      if (_history[k].turn == humanSide) return k;
    }
    return null;
  }

  void undo() {
    final k = _undoTo();
    if (k == null || thinking) return;
    final snap = _history[k];
    board = snap.board;
    turn = snap.turn;
    moveCount = snap.moves;
    _history.removeRange(k, _history.length);
    winner = null;
    resigned = false;
    message = null;
    morphFrom = null;
    lastMid = -1;
    moveSerial++;
    _epoch++;
    _clearHint();
    notifyListeners();
  }

  /// 힌트: 둘 수 있는 수 하나를 잠깐 점선으로 보여 준다. 둘 수가 없으면 false.
  bool showHint() {
    if (!humanCanAct) return false;
    // 자리가 넉넉한 수를 먼저 보여 주고, 없을 때만 점과 선을 밀어야 하는 수를 보여 준다
    var moves = findMoves(board, allowRelax: false);
    if (moves.isEmpty) moves = findMoves(board);
    if (moves.isEmpty) return false;
    final m = moves[_rng.nextInt(moves.length)];
    hintPath = m.path;
    message = null;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      _clearHint();
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void _clearHint() {
    hintPath = null;
    _hintTimer?.cancel();
    _hintTimer = null;
  }

  /// 기권한다: 상대(또는 CPU)가 이긴 것으로 끝난다. CPU가 생각 중이었으면 그 수는 버린다.
  bool resign() {
    if (!canResign) return false;
    _epoch++;
    thinking = false;
    resigned = true;
    final loser = vsCpu ? humanSide : turn;
    winner = 1 - loser;
    _clearHint();
    notifyListeners();
    return true;
  }

  /// 같은 설정의 새 판. [swapStart]면 CPU 대결에서 사람이 먼저/나중을 바꾼다.
  SproutsController fresh({bool swapStart = true}) => SproutsController(
        mode: mode,
        dotCount: dotCount,
        humanSide: vsCpu && swapStart ? 1 - humanSide : humanSide,
        level: level,
      );

  @override
  void dispose() {
    _disposed = true;
    _hintTimer?.cancel();
    super.dispose();
  }
}
