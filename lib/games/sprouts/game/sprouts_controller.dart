import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/sprouts_ai.dart';
import '../core/sprouts_board.dart';
import '../core/sprouts_faces.dart';
import '../core/sprouts_geometry.dart';
import '../core/sprouts_planner.dart';
import '../core/sprouts_relax.dart' show boardIsPlanar;
import '../core/sprouts_tidy.dart';

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
  final CpuTurnRunner _cpu = CpuTurnRunner();

  /// CPU가 수를 고르는 중인가.
  bool get thinking => _cpu.thinking;

  /// 안 되는 수를 그렸을 때의 안내 (다음 동작에서 지워진다).
  String? message;

  /// 손으로 그은 선을 알아서 바로잡아 두었을 때의 알림 (다음 수에서 지워진다).
  String? notice;

  /// 방금 둔 수 (애니메이션용): 번호와 새 점.
  int moveSerial = 0;
  int lastMid = -1;

  /// 자리를 만들려고 점과 선을 밀었다면, 밀기 전의 판 (화면이 천천히 옮겨 가는 모습을 보여 줄 때 쓴다).
  SproutsBoard? morphFrom;

  /// 방금 한 일이 "선 정리하기"인가 (그렇다면 새 곡선·새 점 애니메이션 없이 옮겨 가기만 한다).
  bool lastWasTidy = false;

  /// 선 정리하기를 계산하는 중.
  bool tidying = false;

  /// 방금 둔 수를 사람이 직접 그었는가 (그렇다면 곡선을 다시 그려 보이지 않고 새 점만 나타낸다).
  bool lastByHuman = false;

  /// 힌트로 보여 주는 곡선 (잠깐 보였다 사라진다).
  List<P>? hintPath;
  Timer? _hintTimer;

  /// 소리/진동 알림 ('draw' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  final List<_Snapshot> _history = [];

  bool get vsCpu => mode == PlayMode.vsCpu;
  int get cpuSide => 1 - humanSide;
  bool get isOver => winner != null;

  /// 지금 사람이 그을 수 있는가.
  bool get humanCanAct => !isOver && !thinking && !tidying && (!vsCpu || turn == humanSide);

  bool get canUndo => !thinking && _undoTo() != null;
  bool get canResign => !isOver && moveCount > 0;

  /// 선 정리하기를 누를 수 있는가 (그어진 선이 있고, 계산 중이 아닐 때).
  bool get canTidy => !isOver && !thinking && !tidying && board.curves.isNotEmpty;

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
    var s = board.nearestDot(stroke.first);
    // 손가락이 점에서 조금 벗어나 시작했거나 끝냈어도, 이을 수 있는 가까운 점이 하나뿐이면 그 점으로 본다
    if (s < 0 || board.dots[s].lives <= 0) {
      final guess = _intendedDot(stroke.first, null);
      if (guess >= 0) s = guess;
    }
    if (s < 0) return _bad('점에서 시작해 주세요');
    var e = board.endDotFor(stroke, s);
    if (e < 0 || (board.dots[e].lives <= 0 && e != s)) {
      final guess = _intendedDot(stroke.last, s);
      if (guess >= 0) e = guess;
    }
    if (e < 0) return _bad('점에서 끝내 주세요');
    final r = board.validate(s, e, stroke);
    if (!r.ok) {
      // 규칙에 살짝 어긋난 선(선을 스쳤거나 좁은 틈을 빠듯하게 지나감)은, 위상적으로 이을 수 있는 두 점이면 알아서 바로잡아 그린다
      // (찾는 데 시간이 걸릴 수 있어서 화면이 멈추지 않게 따로 계산한다. 안 되는 이유는 먼저 보여 준다)
      if (s != e && board.dots[s].lives >= 1 && board.dots[e].lives >= 1) _repair(s, e, stroke);
      return _bad(r.reason);
    }
    _commit(s, e, r, byHuman: true);
    return true;
  }

  /// [p] 가까이에서, 이을 수 있는 점 ([from]이 있으면 그 점과 위상적으로 이어질 수 있는 점) 가운데 가장 가까운 점 (없으면 -1).
  int _intendedDot(P p, int? from) {
    final pairs = analyzeRegions(board).allPairs(board);
    var best = -1;
    var bd = kSnap * 2.4 * pow(max(1.0, board.bounds.scale), 0.8);
    for (var i = 0; i < board.dots.length; i++) {
      if (board.dots[i].lives <= 0 || i == from) continue;
      if (from != null && !pairs.contains(from < i ? (from, i) : (i, from))) continue;
      final d = board.dots[i].pos.dist(p);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  int _repairEpoch = 0;

  /// 바로잡는 중인 것을 취소한다 (새로 선을 긋기 시작했을 때).
  void cancelRepair() => _repairEpoch++;

  Future<void> _repair(int s, int e, List<P> stroke) async {
    final epoch = ++_repairEpoch;
    final serial = moveSerial;
    final List<double> out;
    try {
      out = await compute(sproutsGuideTask, <Object>[
        board.toData(),
        s,
        e,
        [for (final p in stroke) ...[p.x, p.y]],
      ]);
    } catch (_) {
      return;
    }
    if (_cpu.disposed || epoch != _repairEpoch || serial != moveSerial || !humanCanAct || out.isEmpty) return;
    final move = decodeCpuMove(out);
    if (move == null) return;
    // 마지막으로 선이 가로지르지 않는지 확인한다
    final check = board.copy()..apply(move.s, move.e, move.result, turn);
    if (!boardIsPlanar(check)) return;
    _commit(move.s, move.e, move.result, byHuman: false, notice: '선을 알아서 맞춰 그렸어요');
  }

  bool _bad(String reason) {
    message = reason;
    onFeedback?.call('bad');
    notifyListeners();
    return false;
  }

  /// 선 정리하기: 점과 선을 위상은 그대로(어느 점이 어떤 순서로 이어졌는지, 어느 영역에 있는지) 두고 단순한 모양으로 정리한다.
  /// 차례도 수도 바뀌지 않는다. 정리할 것이 없었으면 false.
  Future<bool> tidy() async {
    if (!canTidy) return false;
    _clearHint();
    cancelRepair();
    tidying = true;
    message = null;
    notice = '위상적으로 동일한 상황으로 선과 점을 정리합니다';
    notifyListeners();
    final serial = moveSerial;
    final before = board;
    List<List<double>> result;
    try {
      result = await compute(sproutsTidyAndRoomTask, board.toData());
    } catch (_) {
      result = const [<double>[], <double>[]];
    }
    final out = result[0], room = result[1];
    if (_cpu.disposed) return false;
    tidying = false;
    if (serial != moveSerial) {
      notifyListeners();
      return false;
    }
    final spread = room.isNotEmpty;
    if (out.isEmpty && !spread) {
      notice = '이미 단순해서 더 정리할 선이 없어요';
      notifyListeners();
      return false;
    }
    board = SproutsBoard.fromData(spread ? room : out);
    morphFrom = before;
    lastWasTidy = true;
    if (spread) notice = '선을 정리하고 점도 옮겨서 이을 자리를 만들었어요';
    message = null;
    moveSerial++;
    notifyListeners();
    return true;
  }

  /// 위상적으로는 둘 수 있는 수가 남았는데 자리가 모자라면, 점과 선을 옮겨 늘려서 자리를 만든다.
  /// (콩나물은 이어진 구조만 중요하니 그려진 모양이 바뀌어도 같은 판이다.) 옮겼으면 true.
  bool _ensureRoom() {
    final room = makeRoom(board, clock: Stopwatch()..start(), deadline: const Duration(seconds: 3));
    if (room == null) return false;
    morphFrom = board;
    board = room;
    lastWasTidy = true;
    notice = '이을 자리를 만들려고 점과 선을 옮겼어요';
    return true;
  }

  void _commit(int s, int e, StrokeResult r, {required bool byHuman, String? notice}) {
    lastWasTidy = false;
    final before = board.copy();
    _history.add(_Snapshot(before, turn, moveCount));
    message = null;
    this.notice = notice;
    lastMid = board.apply(s, e, r, turn);
    // 점과 선이 밀렸거나 판의 범위(화면의 확대·축소)가 바뀌었으면 천천히 옮겨 가는 모습을 보여 준다
    morphFrom = (r.layout != null || before.bounds != board.bounds) ? before : null;
    lastByHuman = byHuman;
    moveCount++;
    moveSerial++;
    final mover = turn;
    // 끝났는지는 위상으로만 판단한다: 이을 수 있는 점 쌍이 하나도 없을 때만 끝난다 (그림이 빽빽해서 못 긋는 것은 끝이 아니다)
    if (!analyzeRegions(board).hasMove(board)) {
      winner = mover; // 마지막으로 수를 둔 사람이 이긴다
      onFeedback?.call('win');
    } else {
      turn = 1 - turn;
      if (_ensureRoom()) moveSerial++;
      onFeedback?.call('draw');
    }
    notifyListeners();
    _maybeCpu();
  }

  // ── CPU ──

  /// 화면이 준비되면 부른다 (CPU가 먼저 두는 판이면 CPU가 시작한다).
  void start() => _maybeCpu();

  void _maybeCpu() {
    if (_cpu.disposed || !vsCpu || isOver || turn != cpuSide) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final args = <Object>[board.toData(), level.index, _rng.nextInt(1 << 30)];
    final r = await _cpu.run(
      task: () => compute(sproutsCpuTask, args),
      minTime: const Duration(milliseconds: 700),
      onStart: notifyListeners,
    );
    if (r == null) return;
    final move = decodeCpuMove(r);
    if (move == null) {
      // 위상적으로는 둘 수 있는데 못 찾았다면 자리를 만들고 다시 한 번 둔다. 정말 둘 곳이 없으면 상대가 이긴 것으로 끝낸다
      if (analyzeRegions(board).hasMove(board) && _ensureRoom()) {
        moveSerial++;
        notifyListeners();
        _maybeCpu();
        return;
      }
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
    notice = null;
    morphFrom = null;
    lastWasTidy = false;
    lastMid = -1;
    moveSerial++;
    _cpu.cancel();
    _repairEpoch++;
    _clearHint();
    notifyListeners();
  }

  /// 힌트: 둘 수 있는 수 하나를 잠깐 점선으로 보여 준다. 둘 수가 없으면 false.
  bool showHint() {
    if (!humanCanAct) return false;
    // 자리가 넉넉한 수를 먼저 보여 주고, 없을 때만 점과 선을 밀어야 하는 수를 보여 준다
    var moves = findMoves(board, allowRelax: false);
    if (moves.isEmpty && _ensureRoom()) {
      // 자리가 없어서 점과 선을 옮겼다: 새 배치에서 다시 찾는다
      moveSerial++;
      moves = findMoves(board, allowRelax: false);
    }
    if (moves.isEmpty) return false;
    final m = moves[_rng.nextInt(moves.length)];
    hintPath = m.path;
    message = null;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (_cpu.disposed) return;
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
    _cpu.cancel();
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
    _cpu.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }
}
