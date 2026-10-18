part of 'rummikub_controller.dart';

/// board 조각 (화면 코드를 역할별로 나눈 파일)
extension RummikubControllerBoard on RummikubController {
  bool get animating => _animating;

  bool get thinking => _cpu.thinking;

  bool get isOver => state.over;

  int get turn => state.turn;

  /// 판이 시작된 뒤 지금까지 지나간 차례 수 (첫 차례에는 "내 차례" 알림을 띄우지 않으려고).
  int get moveCountForBanner => state.turnCount;

  bool get myTurn => !isOver && !halted && turn == humanSeat;

  /// 내가 지금 판을 만질 수 있는가.
  bool get canAct => myTurn && !thinking && !_animating;

  /// 내 손의 타일 순서를 바꿀 수 있는가. 손은 나만 보고 만지는 것이라, 상대 차례에도 마음대로 정리할 수 있다.
  bool get canArrange => !isOver && !halted;

  void _deal() {
    _queuedMoves.clear();
    state = RkState.deal(players, seed);
    moveCount = 0;
    hand = [...state.racks[humanSeat]]..sort(compareByColor);
    anchors.clear();
    _undo.clear();
    _recent.clear();
    _animEpoch++;
    _animating = false;
    flying.clear();
    opponentPick = null;
    work = _copyTable();
    _liveActive = false;
    _liveSig = _workSig();
    selected.clear();
    lastDrawn = null;
    notice = null;
  }

  List<List<int>> _copyTable() => [for (final s in state.table) [...s]];

  /// 화면이 준비되면 부른다 (CPU가 먼저 시작하는 판이면 CPU가 둔다).
  void start() => _maybeCpu();

  /// 새 판. 씨앗이 바뀌고 자리가 한 칸 돈다. Wi‑Fi 대결에서는 두 기기가 같은 순서로 부르면 같은 판이 된다.
  void restart() {
    _cpu.cancel();
    seed = RummikubController.nextSeed(seed);
    humanSeat = (humanSeat + 1) % players;
    rotation++;
    final rotated = {for (final s in cpuSeats) (s + 1) % players};
    cpuSeats
      ..clear()
      ..addAll(rotated);
    halted = false;
    _deal();
    _notify();
    _maybeCpu();
  }

  /// 판 위에 올려 둔(아직 손에서 내놓은) 타일들.
  Set<int> get placed {
    final onTable = {for (final s in state.table) ...s};
    return {for (final s in work) for (final t in s) if (!onTable.contains(t)) t};
  }

  /// 손에 남아 보이는 타일들 (내가 늘어놓은 순서 그대로).
  List<int> get rackTiles {
    final p = placed;
    return [for (final t in hand) if (!p.contains(t)) t];
  }

  /// 이번 차례에 판을 만졌는가 (손에서 한 장이라도 내려놓았는가).
  bool get changed => placed.isNotEmpty;

  /// 지금 판의 모습을 내놓을 수 있는지 살핀 결과 (내놓을 수 있으면 null).
  PlayError? get error => state.checkPlay(work);

  bool get canEnd => canAct && error == null;

  /// 손을 색 순서나 숫자 순서로 한 번 정렬한다. (그 뒤로는 끌어서 마음대로 바꿀 수 있다)
  void sortHand({required bool byColor}) {
    hand.sort(byColor ? compareByColor : compareByNumber);
    _notify();
  }

  /// 손 안에서 타일 [ids]를 끌어 옮긴다: [beforeId] 타일 앞에 끼워 넣고, 없으면 맨 뒤에 놓는다.
  /// 이번 차례에 판에 올려 둔 타일이면 손으로 되돌아온다 (원래 판 위에 있던 타일은 못 옮긴다).
  void moveInHand(Iterable<int> ids, {int? beforeId}) {
    if (!canArrange) return;
    final p = canAct ? placed : const <int>{}; // (상대 차례에는 판에서 타일을 가져올 수 없다)
    final order = [for (final t in ids) if (hand.contains(t)) t];
    if (order.isEmpty || (beforeId != null && order.contains(beforeId))) {
      selected.clear();
      _notify();
      return;
    }
    if (canAct) _remember();
    for (final s in work) {
      s.removeWhere((t) => order.contains(t) && p.contains(t));
    }
    work.removeWhere((s) => s.isEmpty);
    hand.removeWhere(order.contains);
    var at = beforeId == null ? -1 : hand.indexOf(beforeId);
    if (at < 0) at = hand.length;
    hand.insertAll(at, order);
    selected.clear();
    onFeedback?.call('place');
    _notify();
  }

  /// 묶음의 자리 (타일 중 자리를 기억하는 것이 있으면 그 자리).
  Offset? anchorOf(List<int> set) {
    for (final t in set) {
      final a = anchors[t];
      if (a != null) return a;
    }
    return null;
  }

  void _setAnchor(Iterable<int> tiles, Offset a) {
    for (final t in tiles) {
      anchors[t] = a;
    }
  }

  /// 판 위 묶음들의 자리를 정한다 (화면이 판 크기와 함께 부른다). 자리가 없던 묶음은 빈자리를 찾아 놓고 그 자리를 기억한다.
  List<Offset> layoutSets(double widthUnits, int perRow) {
    layoutWidth = widthUnits;
    layoutPerRow = perRow;
    final n = work.length;
    final want = List<Offset?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      var a = anchorOf(work[i]);
      if (a == null) continue;
      final maxX = max(0.0, widthUnits - setRect(a, work[i].length, perRow).width);
      if (a.dx > maxX) a = Offset(maxX, a.dy);
      want[i] = a;
    }
    // 겹치지 않게 자리를 정한다: 방금 만진 묶음을 가장 먼저 (그 자리를 지킨다), 그다음 이미 자리가 있던 묶음들을 위에서 아래로, 새 묶음은 맨 나중에.
    // 앞서 놓인 묶음과 겹치면 뒤에 오는 묶음이 가장 가까운 빈자리로 비켜 준다.
    final order = List<int>.generate(n, (i) => i)
      ..sort((x, y) {
        int rank(int i) => _recent.isNotEmpty && work[i].any(_recent.contains) ? 0 : (want[i] != null ? 1 : 2);
        final r = rank(x).compareTo(rank(y));
        if (r != 0) return r;
        final ax = want[x], ay = want[y];
        if (ax == null || ay == null) return x.compareTo(y);
        final dy = ax.dy.compareTo(ay.dy);
        return dy != 0 ? dy : ax.dx.compareTo(ay.dx);
      });
    final res = List<Offset?>.filled(n, null);
    final placed = <Rect>[];
    for (final i in order) {
      final size = setRect(Offset.zero, work[i].length, perRow);
      var spot = want[i];
      if (spot == null) {
        spot = findFreeSpot(placed, size, widthUnits);
      } else if (overlapsAny(setRect(spot, work[i].length, perRow), placed, margin: 0.12)) {
        spot = snapToFree(placed, size, widthUnits, spot);
      }
      res[i] = spot;
      placed.add(setRect(spot, work[i].length, perRow));
    }
    for (var i = 0; i < n; i++) {
      _setAnchor(work[i], res[i]!);
    }
    return [for (final a in res) a!];
  }

  /// 정리: 묶음은 그대로 두고 자리만 바꿔서 녹색 판 위쪽부터 가지런히 채운다.
  /// 런(같은 색 연속)은 색별로 작은 숫자부터, 그룹(같은 숫자)은 숫자 순으로, 올바르지 않은 묶음은 맨 끝에 놓고,
  /// 왼쪽에서 오른쪽으로, 넘치면 다음 줄로 이어 놓는다. 한 단계 되돌리기로 되돌릴 수 있다.
  void tidySets() {
    if (!canAct || work.isEmpty || layoutWidth <= 0) return;
    _remember();
    int kindOf(List<int> set) {
      final m = analyzeMeld(set);
      return m == null ? 2 : (m.isRun ? 0 : 1);
    }

    int firstNumber(List<int> set) {
      final m = analyzeMeld(set);
      final order = m?.order ?? arrangeSet(set);
      final plain = order.where((t) => !isJoker(t));
      return plain.isEmpty ? kMaxNumber + 1 : numberOf(plain.first);
    }

    int colorKey(List<int> set) {
      final plain = set.where((t) => !isJoker(t));
      return plain.isEmpty ? kColors : colorOf(plain.first);
    }

    final sorted = [...work]
      ..sort((a, b) {
        final k = kindOf(a).compareTo(kindOf(b));
        if (k != 0) return k;
        if (kindOf(a) == 0) {
          final c = colorKey(a).compareTo(colorKey(b));
          if (c != 0) return c;
        }
        final n = firstNumber(a).compareTo(firstNumber(b));
        return n != 0 ? n : b.length.compareTo(a.length);
      });
    var x = 0.0, y = 0.0, rowH = 1.0;
    for (final set in sorted) {
      final r = setRect(Offset.zero, set.length, layoutPerRow);
      final w = r.width;
      if (x > 0 && x + w > layoutWidth + 0.001) {
        x = 0;
        y += rowH;
        rowH = 1;
      }
      _setAnchor(set, Offset(x, y));
      x += w + 0.15;
      rowH = max(rowH, (set.length / layoutPerRow).ceil().toDouble());
    }
    _recent.clear();
    selected.clear();
    _notify();
  }
}
