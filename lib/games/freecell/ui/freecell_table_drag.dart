part of 'freecell_table.dart';

/// drag 조각 (화면 코드를 역할별로 나눈 파일)
extension _FtDrag on _FreecellTableState {
  void _startCelebration() {
    final m = _m;
    if (m == null) return;
    _celebrating = true;
    _show?.dispose();
    _show = WinCelebration(
      view: m.view,
      cardSize: m.cardSize,
      foundationPositions: [for (var suit = 0; suit < 4; suit++) m.topPos(4 + suit)],
      seed: c.deal,
      pixelRatio: View.of(context).devicePixelRatio,
    );
    _lastTick = Duration.zero;
    _ticker?.dispose();
    _ticker = createTicker(_onTick)..start();
    _update(() {});
  }

  void _stopCelebration() {
    _celebrating = false;
    _ticker?.dispose();
    _ticker = null;
    _show?.dispose();
    _show = null;
    _update(() {});
  }

  void _onTick(Duration t) {
    final show = _show;
    if (show == null) return;
    final dt = ((t - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = t;
    show.update(dt);
    _winTick.value++;
    if (show.finished) _ticker?.stop();
  }

  Offset _local(Offset global) =>
      (_stackKey.currentContext!.findRenderObject()! as RenderBox).globalToLocal(global);

  Set<int> _hintCards() {
    final h = c.hint;
    if (h == null) return const {};
    final m = h.move;
    if (m.from == Place.cell) return {c.state.cells[m.fromIndex]};
    final col = c.state.columns[m.fromIndex];
    return col.sublist(col.length - m.count).toSet();
  }

  void _onTapCard(int card) {
    if (!c.canAct) return;
    final s = c.state;
    for (var i = 0; i < 8; i++) {
      if (s.columns[i].contains(card)) {
        final n = c.grabCount(i, card);
        if (n != null) c.smartMove(Place.column, i, n);
        return;
      }
    }
    for (var k = 0; k < 4; k++) {
      if (s.cells[k] == card) {
        c.smartMove(Place.cell, k, 1);
        return;
      }
    }
  }

  void _dragStart(int card, DragStartDetails d) {
    final m = _m;
    if (m == null || !c.canAct) return;
    final s = c.state;
    Place from;
    int index, count;
    List<int> cards;
    var found = false;
    from = Place.column;
    index = -1;
    count = 0;
    cards = const [];
    for (var i = 0; i < 8 && !found; i++) {
      if (s.columns[i].contains(card)) {
        final n = c.grabCount(i, card);
        if (n == null) return;
        from = Place.column;
        index = i;
        count = n;
        cards = s.columns[i].sublist(s.columns[i].length - n);
        found = true;
      }
    }
    for (var k = 0; k < 4 && !found; k++) {
      if (s.cells[k] == card) {
        from = Place.cell;
        index = k;
        count = 1;
        cards = [card];
        found = true;
      }
    }
    if (!found) return;
    final pos = _placeOf(m, cards.first).pos;
    _update(() {
      _drag = _Drag(
        from: from,
        index: index,
        cards: cards,
        grab: _local(d.globalPosition) - pos,
        topLeft: pos,
        targets: c.targetsFor(from, index, count),
      );
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    final m = _m, drag = _drag;
    if (m == null || drag == null) return;
    drag.topLeft = _local(d.globalPosition) - drag.grab;
    drag.hover = _resolveTarget(m, drag);
    _update(() {});
  }

  void _dragEnd(DragEndDetails d) {
    final drag = _drag;
    _update(() => _drag = null);
    if (drag == null) return;
    final target = drag.hover;
    if (target != null) c.tryMove(target);
  }

  /// 끌고 있는 카드가 어느 합법적인 자리 위에 있는가.
  ///
  /// 카드의 가운데 한 점이 아니라 "얼마나 겹치는가"로 고른다: 합법적인 자리마다 놓을 수 있는 영역(열은
  /// 맨 아래 카드까지 이어진 띠, 프리셀·완성 칸은 칸 하나)을 잡고, 끌고 있는 카드와 겹친 넓이가
  /// 가장 큰 곳을 고른다. 손가락이 그 영역 근처에 있어도 인정해서, 대충 가까이 놓아도 들어간다.
  FcMove? _resolveTarget(FcMetrics m, _Drag drag) {
    final card = drag.topLeft & m.cardSize;
    final finger = drag.topLeft + drag.grab;
    final cardArea = m.cw * m.ch;
    FcMove? best;
    var bestScore = 0.0;
    for (final t in drag.targets) {
      final zone = _dropZone(m, t);
      final overlap = card.intersect(zone);
      var score = (overlap.width > 0 && overlap.height > 0) ? overlap.width * overlap.height / cardArea : 0.0;
      // 손가락이 영역 위(또는 바로 근처)에 있으면 겹침이 적어도 의도한 곳으로 본다
      final near = zone.inflate(m.cw * 0.2);
      if (near.contains(finger)) score = max(score, 0.2) + 0.05;
      if (score < 0.12) continue;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return best;
  }

  /// 도착 자리 [t]에 놓았다고 인정하는 영역.
  Rect _dropZone(FcMetrics m, FcMove t) {
    switch (t.to) {
      case Place.cell:
        return m.topPos(t.toIndex) & m.cardSize;
      case Place.foundation:
        return m.topPos(4 + t.toIndex) & m.cardSize;
      case Place.column:
        final len = c.state.columns[t.toIndex].length;
        final top = m.colPos(t.toIndex, 0);
        final bottom = m.colPos(t.toIndex, max(0, len - 1)).dy + m.ch;
        // 맨 위(열 시작)부터 맨 아래 카드 조금 아래까지: 열 어디에 놓아도 그 열로 본다
        return Rect.fromLTRB(top.dx, m.colY - m.gap, top.dx + m.cw, bottom + m.ch * 0.4);
    }
  }
}
