part of 'sprouts_controller.dart';

/// turns 조각 (화면 코드를 역할별로 나눈 파일)
extension ScTurns on SproutsController {
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
    final moved = SproutsController._geometryChanged(before, nb);
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
      _notify();
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
    _notify();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결): 내가 이긴다.
  void opponentResigned() {
    if (!online || isOver) return;
    resigned = true;
    winner = humanSide;
    _clearHint();
    _notify();
  }

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
      onStart: _notify,
    );
    if (r == null) return;
    final move = decodeCpuMove(r);
    if (move == null) {
      // 위상적으로는 둘 수 있는데 못 찾았다면 자리를 만들고 다시 한 번 둔다. 정말 둘 곳이 없으면 상대가 이긴 것으로 끝낸다
      if (analyzeRegions(board).hasMove(board) && _ensureRoom()) {
        moveSerial++;
        _notify();
        _maybeCpu();
        return;
      }
      winner = 1 - turn;
      _notify();
      return;
    }
    _commit(move.s, move.e, move.result, byHuman: false);
  }

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
    _notify();
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
      _notify();
    });
    _notify();
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
    _notify();
    return true;
  }
}
