part of 'sprouts_controller.dart';

/// strokes 조각 (화면 코드를 역할별로 나눈 파일)
extension ScStrokes on SproutsController {
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
      _notify();
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
    _notify();
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
    _notify();
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
      _notify();
      return false;
    }
    final spread = room.isNotEmpty;
    if (out.isEmpty && !spread) {
      notice = '이미 단순해서 더 정리할 선이 없어요';
      _notify();
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
    _notify();
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
    _notify();
    _maybeCpu();
  }
}
