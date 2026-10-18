part of 'davinci_controller.dart';

/// moves 조각 (화면 코드를 역할별로 나눈 파일)
extension DavinciControllerMoves on DavinciController {
  /// 더미([color] 0 검정 / 1 흰색)에서 타일을 뽑는다.
  bool draw(int color) => _play(DvMove.drawMove(color));

  /// 뽑은 조커를 내 줄 [pos]번째 칸에 놓는다.
  bool placeJoker(int pos) => _play(DvMove.placeJoker(pos));

  /// 맞힐 상대 타일을 고른다 (이미 고른 타일을 다시 누르면 고름을 푼다).
  void selectTarget(int seat, int index) {
    if (!humanCanAct || (phase != DvPhase.guess && phase != DvPhase.decide)) return;
    if (seat == humanSeat || seat < 0 || seat >= players || state.isOut(seat)) return;
    if (index < 0 || index >= state.rows[seat].length || state.isRevealed(state.rows[seat][index])) return;
    if (selSeat == seat && selIndex == index) {
      selSeat = -1;
      selIndex = -1;
    } else {
      selSeat = seat;
      selIndex = index;
    }
    _notify();
    onLocalSelect?.call(selSeat, selIndex);
  }

  void clearSelection() {
    if (selSeat < 0) return;
    selSeat = -1;
    selIndex = -1;
    _notify();
    onLocalSelect?.call(-1, -1);
  }

  /// 고른 타일이 [number](조커는 [kJokerGuess])라고 맞힌다.
  bool guess(int number) {
    if (selSeat < 0) return false;
    final seat = selSeat, index = selIndex;
    return _play(DvMove.guess(seat, index, number));
  }

  /// 맞힌 뒤 멈추고 차례를 넘긴다.
  bool stop() => _play(DvMove.stop);

  /// (더미가 비어 틀렸을 때) 내 숨은 타일 하나를 직접 공개한다.
  bool revealOwn(int index) => _play(DvMove.reveal(index));

  bool _play(List<int> move) {
    if (!humanCanAct || !state.isLegal(move)) {
      onFeedback?.call('bad');
      return false;
    }
    _apply(move);
    onLocalMove?.call(move);
    _next();
    return true;
  }

  void _apply(List<int> move) {
    final before = state.lastGuess;
    remoteSel = null; // (수를 두면 고르던 타일 표시는 그 수의 연출로 이어진다)
    final actor = state.turn;
    final preDrawn = state.drawn;
    final tile = move[0] == 2 ? state.rows[move[1]][move[2]] : null;
    moves.add(move);
    state.apply(move);
    if (move[0] == 0 || move[0] == 1) {
      final t = state.drawn;
      if (t != null) drawnBy[actor] = t;
    }
    selSeat = -1;
    selIndex = -1;
    moveSerial++;
    final g = state.lastGuess;
    // 상대(CPU·다른 기기)가 둔 수는 한 단계씩 보여 준다. 내가 맞힌 결과는 막지 않고 바로 표시만 한다.
    final mine = actor == humanSeat;
    // 남이 조커를 뽑았다: 자리를 정할 때까지 아무것도 보여 주지 않는다 (소리도, 날아가는 타일도 없다).
    // 자리를 정하면 그제서야 일반 타일을 뽑을 때와 똑같은 연출 하나로 보여 준다. (그래야 조커를 뽑았는지 알 수 없다)
    if (!mine && move[0] == 0 && state.phase == DvPhase.placeJoker) {
      _heldDrawColor = move[1];
      return;
    }
    final heldColor = move[0] == 1 && !mine ? _heldDrawColor : null;
    _heldDrawColor = null;
    if (move[0] == 2 && g != null && !identical(g, before)) {
      _enqueue(DvEffect(
        actor: actor,
        kind: 2,
        target: move[1],
        index: move[2],
        tile: tile,
        number: move[3],
        correct: g.correct,
        guesserTile: !g.correct ? preDrawn : null,
        blocking: !mine,
        ask: !mine,
      ));
    } else if (!mine) {
      // 뽑기는 어느 더미에서 어느 타일을 뽑았는지도 담아 둔다. 조커는 자리를 정한 뒤 "뽑기" 하나로 합쳐 보여 준다.
      final isDraw = move[0] == 0 || heldColor != null;
      _enqueue(DvEffect(
        actor: actor,
        kind: isDraw ? 0 : move[0],
        number: isDraw ? (heldColor ?? move[1]) : null,
        tile: isDraw ? (state.pendingJoker ?? state.drawn) : null,
        blocking: true,
        ask: true,
      ));
    }
    if (state.isOver) {
      onFeedback?.call('win');
    } else if (move[0] == 2 && g != null && !identical(g, before)) {
      onFeedback?.call(g.correct ? 'right' : 'wrong');
    } else if (move[0] == 0 || heldColor != null) {
      onFeedback?.call('draw');
    }
    _notify();
  }

  /// 다른 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  ///
  /// 앞의 수를 보여 주는 연출이 아직 끝나지 않았으면 판에 바로 반영하지 않고 줄 세워 두었다가, 연출이 끝나는 대로 하나씩 반영한다.
  /// (규칙에 맞는지는 줄 서 있는 수까지 둔 모습으로 미리 확인한다)
  bool receiveMove(List<int> move, {int? index}) {
    final latest = _latest;
    if (!online || latest.isOver || halted || latest.turn == humanSeat) return false;
    if (index != null && index != moveCount + _incoming.where((e) => e.move != null).length) return false;
    if (!latest.isLegal(move)) return false;
    if (!animate || (_incoming.isEmpty && !_pumping && _effects.isEmpty)) {
      _apply(move);
      _next(); // (다음이 CPU 차례이면 방장 기기가 CPU의 수를 둔다)
      return true;
    }
    (_shadow ??= state.clone()).apply(move);
    _incoming.add(_Incoming.move(move));
    _notify();
    return true;
  }

  /// 다른 기기의 사람이 맞히려고 상대 타일([seat]의 [index]번째)을 골랐다는 소식 (고름을 풀면 둘 다 -1).
  /// 앞의 수를 보여 주는 동안이면 그 연출이 끝난 뒤에 보여 준다.
  void receiveSelection(int actor, int seat, int index) {
    if (!online || isOver || halted || actor == humanSeat || actor < 0 || actor >= players) return;
    if (!animate || (_incoming.isEmpty && !_pumping && _effects.isEmpty)) {
      _showSelection(actor, seat, index);
      return;
    }
    _incoming.add(_Incoming.selection(actor, seat, index));
  }

  void _showSelection(int actor, int seat, int index) {
    // 지금 그 사람 차례이고, 판에 있는 숨은 타일일 때만 보여 준다 (엉뚱한 소식은 무시)
    var ok = actor == state.turn && seat >= 0 && seat < players && seat != actor && index >= 0;
    if (ok) {
      final row = state.rows[seat];
      ok = index < row.length && !state.isRevealed(row[index]) && !state.isOut(seat);
    }
    final next = ok ? (actor: actor, seat: seat, index: index) : null;
    if (next == remoteSel) return;
    remoteSel = next;
    _notify();
  }
}
