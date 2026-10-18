part of 'solitaire_table.dart';

/// drag 조각 (화면 코드를 역할별로 나눈 파일)
extension _StDrag on _SolitaireTableState {
  void _startCelebration() {
    final m = _m;
    if (m == null) return;
    _celebrating = true;
    _show?.dispose();
    _show = WinCelebration(
      view: m.view,
      cardSize: m.cardSize,
      foundationPositions: [for (var suit = 0; suit < 4; suit++) m.topPos(3 + suit)],
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

  Map<int, _Loc> _locations(SolMetrics m) {
    final s = c.state;
    final out = <int, _Loc>{};
    // 더미: 전부 같은 자리에 뒷면으로
    for (var i = 0; i < s.stock.length; i++) {
      out[s.stock[i]] = _Loc(m.topPos(0), 1 + i / 100, false);
    }
    // 버린 카드: 맨 위 [fan]장만 옆으로 펼친다
    final wLen = s.waste.length;
    for (var i = 0; i < wLen; i++) {
      final j = i - (wLen - s.fan);
      final off = j > 0 ? j * m.fanOff : 0.0;
      final top = i == wLen - 1;
      out[s.waste[i]] = _Loc(
        m.topPos(1) + Offset(off, 0),
        50 + i / 100,
        true,
        src: top ? _Src.waste : null,
      );
    }
    // 열
    for (var col = 0; col < 7; col++) {
      final t = s.tableau[col];
      final down = t.length - s.up[col];
      for (var k = 0; k < t.length; k++) {
        final faceUp = k >= down;
        out[t[k]] = _Loc(
          m.colPos(col, k, t.length, s.up[col]),
          100 + k.toDouble(),
          faceUp,
          src: faceUp ? _Src.column : null,
          index: col,
          count: t.length - k,
        );
      }
    }
    // 완성 칸
    for (var suit = 0; suit < 4; suit++) {
      for (var r = 0; r < s.found[suit]; r++) {
        final top = r == s.found[suit] - 1;
        out[r * 4 + suit] = _Loc(
          m.topPos(3 + suit),
          10 + r.toDouble(),
          true,
          src: top ? _Src.found : null,
          index: suit,
          count: 1,
        );
      }
    }
    return out;
  }

  Set<int> _hintCards() {
    final h = c.hint;
    if (h == null) return const {};
    final s = c.state;
    switch (h.kind) {
      case SolKind.draw:
      case SolKind.recycle:
        return const {};
      case SolKind.wasteToCol:
      case SolKind.wasteToFound:
        return {s.waste.last};
      case SolKind.colToCol:
        final col = s.tableau[h.from];
        return col.sublist(col.length - h.count).toSet();
      case SolKind.colToFound:
        return {s.tableau[h.from].last};
      case SolKind.foundToCol:
        return {s.cardOfFound(h.from)};
    }
  }

  void _onTapCard(int card, _Loc loc) {
    if (!c.canAct) return;
    switch (loc.src) {
      case _Src.waste:
        c.smartMoveWaste();
      case _Src.column:
        c.smartMoveColumn(loc.index, loc.count);
      case _Src.found:
        c.smartMoveFoundation(loc.index);
      case null:
        break;
    }
  }

  void _dragStart(int card, _Loc loc, DragStartDetails d) {
    final m = _m;
    final src = loc.src;
    if (m == null || src == null || !c.canAct) return;
    final s = c.state;
    final List<int> cards;
    final List<SolMove> targets;
    switch (src) {
      case _Src.waste:
        cards = [s.waste.last];
        targets = c.targetsForWaste();
      case _Src.column:
        final t = s.tableau[loc.index];
        cards = t.sublist(t.length - loc.count);
        targets = c.targetsForColumn(loc.index, loc.count);
      case _Src.found:
        cards = [card];
        targets = c.targetsForFoundation(loc.index);
    }
    _update(() {
      _drag = _Drag(
        src: src,
        index: loc.index,
        cards: cards,
        grab: _local(d.globalPosition) - loc.pos,
        topLeft: loc.pos,
        targets: targets,
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
  SolMove? _resolveTarget(SolMetrics m, _Drag drag) {
    final cx = drag.topLeft.dx + m.cw / 2;
    final cy = drag.topLeft.dy + m.ch * 0.3;
    final slot = ((cx - m.left) / (m.cw + m.gap)).floor().clamp(0, 6);
    final inTopRow = cy < m.colY - m.gap;
    for (final t in drag.targets) {
      if (inTopRow) {
        if ((t.kind == SolKind.wasteToFound || t.kind == SolKind.colToFound) && slot >= 3) return t;
      } else if ((t.kind == SolKind.wasteToCol || t.kind == SolKind.colToCol || t.kind == SolKind.foundToCol) &&
          t.to == slot) {
        return t;
      }
    }
    return null;
  }
}
