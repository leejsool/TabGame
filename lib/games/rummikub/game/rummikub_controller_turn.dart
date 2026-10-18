part of 'rummikub_controller.dart';

/// turn 조각 (화면 코드를 역할별로 나눈 파일)
extension RummikubControllerTurn on RummikubController {
  /// 지금 판의 모습으로 차례를 마친다. 안 되면 이유를 [notice]에 두고 false.
  bool endTurn() {
    if (!canAct) return false;
    if (error != null) _autoSplit(); // (잘못 묶인 것을 쪼개서 맞출 수 있으면 알아서 쪼갠다)
    final err = error;
    if (err != null) {
      notice = err.message;
      onFeedback?.call('bad');
      _notify();
      return false;
    }
    final table = [for (final s in work) if (s.isNotEmpty) [...s]];
    _applyPlay(table);
    onLocalMove?.call(_withIndex({'table': table}));
    _maybeCpu();
    return true;
  }

  /// 바닥에 엎어 둔 타일들 중 [index]번째를 직접 골라 뽑고 차례를 넘긴다 (만져 둔 것은 되돌려진다).
  /// [index]를 안 주면 맨 뒤 한 장. 더미가 비었으면 그냥 넘긴다.
  void draw({int? index}) {
    if (!canAct) return;
    final pick = state.pool.isEmpty ? null : (index ?? state.pool.length - 1);
    if (pick != null && (pick < 0 || pick >= state.pool.length)) return;
    _record(drew: true, count: 0);
    final drawn = state.applyDraw(pick);
    lastDrawn = drawn;
    _afterMove(drawn: drawn);
    onLocalMove?.call(_withIndex({'draw': 1, 'pick': ?pick}));
    _maybeCpu();
  }

  Map<String, dynamic> _withIndex(Map<String, dynamic> m) => {'i': moveCount - 1, ...m};

  void _applyPlay(List<List<int>> table) {
    _record(drew: false, count: table.fold<int>(0, (a, s) => a + s.length) - state.tableTiles.length);
    state.applyPlay(table);
    lastDrawn = null;
    _afterMove();
  }

  void _record({required bool drew, required int count}) {
    lastActor = state.turn;
    lastDrew = drew;
    lastCount = count;
  }

  /// 한 차례가 끝난 뒤의 정리: 손 목록을 맞추고, 내 차례면 판을 새로 복사한다.
  void _afterMove({int? drawn}) {
    moveCount++;
    final mine = state.racks[humanSeat].toSet();
    hand.removeWhere((t) => !mine.contains(t));
    if (drawn != null && mine.contains(drawn) && !hand.contains(drawn)) {
      // 방금 뽑은 사람이 나일 때만 손에 들어온다
      hand.add(drawn);
    }
    work = _copyTable();
    _liveActive = false;
    _liveSig = _workSig(); // (내 차례가 시작될 때의 모습은 따로 알릴 필요가 없다)
    _undo.clear();
    selected.clear();
    notice = null;
    if (isOver) {
      onFeedback?.call('win');
    } else if (drawn != null) {
      onFeedback?.call('draw');
    }
    _notify();
  }

  String _workSig() => [
        for (final set in work)
          '${set.join(',')}@${anchorOf(set)?.dx.toStringAsFixed(2)},${anchorOf(set)?.dy.toStringAsFixed(2)}',
      ].join('|');

  void _maybeSendLive() {
    final send = onLocalLive;
    if (send == null || !online || !canAct) return;
    final sig = _workSig();
    if (sig == _liveSig) return;
    _liveSig = sig;
    send({
      'i': moveCount,
      'sets': [for (final set in work) [...set]],
      'a': [
        for (final set in work)
          if (anchorOf(set) case final a?) [a.dx, a.dy] else null,
      ],
    });
  }

  /// 상대가 이번 차례에 판을 만지는 모습을 받는다: 그대로 내 화면의 판에 보여 준다 (끝낼 때 오는 수와는 따로, 보여 주기만 한다).
  /// 맞지 않는 내용은 조용히 버린다. 받았으면 true.
  bool receiveLive(Map<String, dynamic> m, {int? fromSeat}) {
    if (!online || isOver || halted || turn == humanSeat || _animating) return false;
    if (fromSeat != null && fromSeat != turn) return false;
    if (m['i'] != moveCount) return false;
    final rawSets = m['sets'];
    if (rawSets is! List) return false;
    final sets = <List<int>>[];
    final seen = <int>{};
    for (final raw in rawSets) {
      if (raw is! List) return false;
      final set = <int>[];
      for (final t in raw) {
        if (t is! int || t < 0 || t >= kTileCount || !seen.add(t)) return false;
        set.add(t);
      }
      if (set.isNotEmpty) sets.add(set);
    }
    // 지금 판에 있던 타일은 모두 그대로 있어야 한다 (상대는 판에서 타일을 가져갈 수 없다)
    if (!state.tableTiles.every(seen.contains)) return false;
    final rawA = m['a'];
    final before = {for (final set in work) ...set};
    flying
      ..removeWhere((t) => !seen.contains(t))
      ..addAll([for (final t in seen) if (!before.contains(t)) t]);
    work = sets;
    if (rawA is List) {
      for (var k = 0; k < sets.length && k < rawA.length; k++) {
        final a = rawA[k];
        if (a is List && a.length == 2 && a[0] is num && a[1] is num) {
          _setAnchor(sets[k], Offset((a[0] as num).toDouble(), (a[1] as num).toDouble()));
        }
      }
    }
    _recent.clear();
    _liveActive = true;
    _notify();
    return true;
  }

  /// 상대 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  ///
  /// 방장은 손님이 보낸 수를 받을 때 그 손님의 자리 [fromSeat]를 알려 준다 (그 손님 차례의 수여야 한다).
  /// 앞선 수를 아직 한 장씩 보여 주는 중이면 대기열에 두었다가, 다 보여 준 뒤에 적용한다.
  bool receiveMove(Map<String, dynamic> m, {int? fromSeat}) {
    if (!online || isOver || halted) return false;
    if (_animating) {
      _queuedMoves.add((m: m, fromSeat: fromSeat));
      return true;
    }
    if (turn == humanSeat || (fromSeat != null && fromSeat != turn)) return false;
    if (m['i'] != moveCount) return false;
    if (m['draw'] == 1) {
      final pick = m['pick'];
      if (pick != null && (pick is! int || pick < 0 || pick >= state.pool.length)) return false;
      if (_liveActive) {
        // 실시간으로 보이던 것은 되돌려진다 (뽑으면 만져 둔 것이 사라진다)
        _liveActive = false;
        flying.clear();
        work = _copyTable();
      }
      _playOpponent(pick: pick as int?); // 뽑은 사람은 상대이니 내 손은 그대로
      return true;
    }
    final raw = m['table'];
    if (raw is! List) return false;
    final table = <List<int>>[];
    for (final s in raw) {
      if (s is! List) return false;
      final set = <int>[];
      for (final t in s) {
        if (t is! int || t < 0 || t >= kTileCount) return false;
        set.add(t);
      }
      table.add(set);
    }
    if (state.checkPlay(table) != null) return false;
    if (_liveActive) {
      // 이미 한 장씩 실시간으로 봤으니, 다시 옮기는 모습을 보이지 않고 바로 반영한다
      _liveActive = false;
      flying.clear();
      _applyPlay(table);
      _maybeCpu();
      return true;
    }
    _playOpponent(table: table);
    return true;
  }

  void _drainQueued() {
    while (!_animating && _queuedMoves.isNotEmpty && !_cpu.disposed) {
      final next = _queuedMoves.removeAt(0);
      if (!receiveMove(next.m, fromSeat: next.fromSeat)) {
        _queuedMoves.clear();
        onDesync?.call();
        return;
      }
    }
  }
}
