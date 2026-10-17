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

/// 같은 Wi‑Fi 대결에서 상대에게 보내는 (상대에게서 받는) 판 하나.
///
/// 콩나물은 자리를 만들려고 점과 선이 밀리거나 선 정리하기로 좌표가 바뀌니, 새 선의 좌표만 보내면 두 기기의 판이 달라진다.
/// 그래서 한 수를 둘 때마다(또는 선을 정리할 때마다) 결과 판을 통째로 보내고, 받는 쪽이 그 판으로 바꾼다.
class SproutsSync {
  const SproutsSync({required this.kind, required this.moveCount, required this.data});

  /// 'move' (선을 그었다) | 'tidy' (선 정리하기).
  final String kind;

  /// 보낸 쪽에서 이 일이 끝난 뒤의 수 번호.
  final int moveCount;

  /// 결과 판 ([SproutsBoard.toData]).
  final List<double> data;
}

class _Snapshot {
  _Snapshot(this.board, this.turn, this.moves);

  final SproutsBoard board;
  final int turn;
  final int moves;
}

/// 콩나물 한 판의 진행: 곡선 긋기, 차례, 끝 판정, CPU, 되돌리기, 힌트.
///
/// 플레이어는 0(먼저 시작)과 1. 마지막으로 수를 둔 사람이 이긴다.
/// 같은 Wi‑Fi 대결([PlayMode.wifi])에서는 내가 둔 결과 판을 [onSync]로 알리고, 상대의 판은 [receiveSync]로 받는다.
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

  /// 저장해 둔 판([toJson])을 되살린다 (한 기기·CPU 대결). 맞지 않는 내용이면 null.
  static SproutsController? fromJson(Map<String, dynamic> j) {
    try {
      final mode = PlayMode.values.byName(j['mode'] as String);
      if (mode != PlayMode.vsCpu && mode != PlayMode.local2p) return null;
      final humanSide = j['humanSide'] as int;
      final levelIndex = j['level'] as int;
      if ((humanSide != 0 && humanSide != 1) || levelIndex < 0 || levelIndex >= SproutsLevel.values.length) return null;
      List<double> data(Object? raw) => [for (final v in raw as List) (v as num).toDouble()];
      final c = SproutsController(
        mode: mode,
        dotCount: j['dotCount'] as int,
        humanSide: humanSide,
        level: SproutsLevel.values[levelIndex],
        board: SproutsBoard.fromData(data(j['board'])),
      );
      c.turn = j['turn'] as int;
      c.moveCount = j['moveCount'] as int;
      if (c.turn != 0 && c.turn != 1) return null;
      for (final h in j['history'] as List) {
        final m = h as Map<String, dynamic>;
        c._history.add(_Snapshot(SproutsBoard.fromData(data(m['board'])), m['turn'] as int, m['moves'] as int));
      }
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 지금 판의 모습을 JSON으로 (이어하기용). 되돌리기에 쓰는 최근 몇 수의 판도 함께 담는다.
  Map<String, dynamic> toJson() {
    List<double> round(List<double> d) => [for (final v in d) (v * 100).roundToDouble() / 100];
    final recent = _history.length > 12 ? _history.sublist(_history.length - 12) : _history;
    return {
      'v': 1,
      'mode': mode.name,
      'dotCount': dotCount,
      'humanSide': humanSide,
      'level': level.index,
      'turn': turn,
      'moveCount': moveCount,
      'board': round(board.toData()),
      'history': [
        for (final h in recent) {'board': round(h.board.toData()), 'turn': h.turn, 'moves': h.moves},
      ],
    };
  }

  /// 이어하기로 보관할 만한 판인가 (같은 Wi‑Fi가 아니고, 한 수라도 뒀고, 끝나지 않았다).
  bool get savable => !online && !isOver && moveCount > 0;

  final PlayMode mode;
  final int dotCount;

  /// CPU 대결·Wi‑Fi 대결에서 내가 맡은 쪽 (0 = 먼저, 1 = 나중).
  final int humanSide;
  final SproutsLevel level;
  final Random _rng;

  /// 같은 Wi‑Fi의 다른 기기와 겨루는 판인가.
  bool get online => mode == PlayMode.wifi;

  /// 이 기기에서 한쪽만 맡는 판인가 (CPU 대결이거나 Wi‑Fi 대결).
  bool get oneSeat => vsCpu || online;

  /// 내가 둔(또는 정리한) 결과 판을 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(SproutsSync sync)? onSync;

  /// 방금 바뀐 판이 상대 기기에서 온 것인가 (그렇다면 화면이 상대의 선을 천천히 그려 보여 준다).
  bool lastRemote = false;

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
  bool get humanCanAct => !isOver && !thinking && !tidying && (!oneSeat || turn == humanSide);

  bool get canUndo => !online && !thinking && _undoTo() != null; // (Wi‑Fi 대결은 되돌릴 수 없다)
  bool get canResign => !isOver && moveCount > 0;

  /// 선 정리하기를 누를 수 있는가 (그어진 선이 있고, 계산 중이 아닐 때).
  bool get canTidy => !isOver && !thinking && !tidying && board.curves.isNotEmpty && (!online || turn == humanSide);

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
      if (s != e && board.dots[s].lives >= 1 && board.dots[e].lives >= 1) _repair(s, e, stroke, r.reason);
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

  Future<void> _repair(int s, int e, List<P> stroke, String reason) async {
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
    if (_cpu.disposed || epoch != _repairEpoch || serial != moveSerial || !humanCanAct) return;
    final move = out.isEmpty ? null : decodeCpuMove(out);
    if (move == null) {
      // 그은 길과 같은 길로는 고칠 수 없었다 (다른 쪽으로 돌아가면 그은 뜻과 위상이 달라지니 고치지 않는다)
      message = '$reason\n그은 길 그대로는 둘 자리가 없어요. "선 정리하기"로 간격을 넓힌 뒤 다시 그어 보세요';
      notifyListeners();
      return;
    }
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
    lastRemote = false;
    notice = spread ? '선을 정리하고 점도 옮겨서 이을 자리를 만들었어요' : '선을 정리하고 선끼리 간격을 고르게 벌렸어요';
    message = null;
    moveSerial++;
    if (online) onSync?.call(SproutsSync(kind: 'tidy', moveCount: moveCount, data: board.toData()));
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
    lastRemote = false;
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
    // (자리를 만들려고 판이 밀렸다면 그것까지 끝난 판을 보낸다)
    if (online) onSync?.call(SproutsSync(kind: 'move', moveCount: moveCount, data: board.toData()));
    notifyListeners();
    _maybeCpu();
  }

  // ── 상대 기기에서 온 판 (Wi‑Fi 대결) ──

  /// 상대가 둔 결과 판을 받는다. 지금 판과 맞지 않는 (차례가 아니거나, 한 수 이상 차이가 나거나, 선이 가로지르는) 판이면
  /// false (그러면 두 기기의 판이 어긋난 것이다).
  bool receiveSync(SproutsSync s) {
    if (!online || isOver || turn == humanSide) return false;
    final SproutsBoard nb;
    try {
      nb = SproutsBoard.fromData(s.data);
    } catch (_) {
      return false;
    }
    if (s.kind == 'move') {
      if (s.moveCount != moveCount + 1) return false;
      if (nb.dots.length != board.dots.length + 1 || nb.curves.length != board.curves.length + 1) return false;
      if (nb.totalLives != board.totalLives - 1 || nb.curves.last.owner != turn) return false;
    } else if (s.kind == 'tidy') {
      if (s.moveCount != moveCount || tidying) return false;
      if (nb.dots.length != board.dots.length || nb.curves.length != board.curves.length || nb.totalLives != board.totalLives) return false;
    } else {
      return false;
    }
    if (!boardIsPlanar(nb)) return false;

    final before = board;
    final moved = _geometryChanged(before, nb);
    _clearHint();
    board = nb;
    message = null;
    lastRemote = true;
    lastByHuman = false;
    if (s.kind == 'tidy') {
      lastWasTidy = true;
      morphFrom = before;
      notice = '상대가 선을 정리했어요';
      moveSerial++;
      notifyListeners();
      return true;
    }
    lastWasTidy = false;
    notice = null;
    lastMid = nb.curves.last.mid;
    // 점과 선이 밀렸거나 판의 범위가 바뀌었으면 천천히 옮겨 가는 모습을 먼저 보여 준다
    morphFrom = moved ? before : null;
    moveCount++;
    moveSerial++;
    final mover = turn;
    if (!analyzeRegions(board).hasMove(board)) {
      winner = mover; // 마지막으로 수를 둔 사람이 이긴다
      onFeedback?.call('win');
    } else {
      turn = 1 - turn;
      onFeedback?.call('draw');
    }
    notifyListeners();
    return true;
  }

  /// 새 판([after])에서 기존 점과 선(앞의 [before])의 자리나 판의 범위가 달라졌는가.
  static bool _geometryChanged(SproutsBoard before, SproutsBoard after) {
    if (before.bounds != after.bounds) return true;
    for (var i = 0; i < before.dots.length; i++) {
      if (before.dots[i].pos.dist(after.dots[i].pos) > 0.3) return true;
    }
    for (var i = 0; i < before.curves.length; i++) {
      final a = before.curves[i].pts, b = after.curves[i].pts;
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j += 4) {
        if (a[j].dist(b[j]) > 0.3) return true;
      }
    }
    return false;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결): 내가 이긴다.
  void opponentResigned() {
    if (!online || isOver) return;
    resigned = true;
    winner = humanSide;
    _clearHint();
    notifyListeners();
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
    final loser = oneSeat ? humanSide : turn;
    winner = 1 - loser;
    _clearHint();
    notifyListeners();
    return true;
  }

  /// 같은 설정의 새 판. [swapStart]면 CPU·Wi‑Fi 대결에서 먼저/나중을 바꾼다. [board]를 주면 그 처음 판으로 시작한다 (Wi‑Fi 대결은 두 기기가 같은 판으로).
  SproutsController fresh({bool swapStart = true, SproutsBoard? board}) => SproutsController(
        mode: mode,
        dotCount: dotCount,
        humanSide: oneSeat && swapStart ? 1 - humanSide : humanSide,
        level: level,
        board: board,
      );

  @override
  void dispose() {
    _cpu.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }
}
