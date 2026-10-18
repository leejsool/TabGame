part of 'solitaire_table.dart';

/// layers 조각 (화면 코드를 역할별로 나눈 파일)
extension _StLayers on _SolitaireTableState {
  Widget _stack(SolMetrics m) {
    final s = c.state;
    final locs = _locations(m);
    final hintCards = _hintCards();
    final dragCards = _drag?.cards.toSet() ?? const <int>{};
    final entries = <(double, Widget)>[];
    for (var card = 0; card < 52; card++) {
      final loc = locs[card]!;
      var pos = loc.pos;
      var z = loc.z;
      final dragging = dragCards.contains(card);
      if (dragging) {
        final drag = _drag!;
        final j = drag.cards.indexOf(card);
        pos = drag.topLeft + Offset(0, j * m.offU);
        z = 1000 + j.toDouble();
      } else if (c.recentlyMoved.contains(card)) {
        z += 500;
      }
      // 완성 연출 중에는 완성 칸의 카드를 숨긴다 (연출 쪽에서 날아간다)
      if (_celebrating && s.found[suitOf(card)] > rankOf(card)) continue;
      entries.add((
        z,
        _CardView(
          key: ValueKey('card-$card'),
          card: card,
          pos: pos,
          size: m.cardSize,
          faceUp: loc.faceUp,
          animate: !dragging,
          interactive: loc.src != null || (!loc.faceUp && s.stock.isNotEmpty && s.stock.last == card),
          glow: hintCards.contains(card) ? const Color(0xFFFFD84D) : null,
          pulse: _pulse,
          onTap: () {
            if (!loc.faceUp && s.stock.contains(card)) {
              c.drawFromStock();
            } else {
              _onTapCard(card, loc);
            }
          },
          onDragStart: (d) => _dragStart(card, loc, d),
          onDragUpdate: _dragUpdate,
          onDragEnd: _dragEnd,
        ),
      ));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.hardEdge,
      children: [
        // 판(펠트)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.1,
                colors: [Color(0xFF2A7F58), Color(0xFF175B3D)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        ..._slots(m),
        ..._targetHighlights(m),
        ..._hintTarget(m), // 카드 뒤에 깔아서, 위쪽 카드를 덮어 물들이지 않게 한다
        for (final e in entries) e.$2,
        if (s.stock.isNotEmpty) _stockCount(m),
        if (_celebrating && _show != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCelebrationTap,
              child: CustomPaint(painter: WinCelebrationPainter(_show!, _winTick)),
            ),
          ),
      ],
    );
  }

  /// 더미 위의 남은 장수 표시.
  Widget _stockCount(SolMetrics m) {
    final p = m.topPos(0);
    return Positioned(
      left: p.dx,
      top: p.dy + m.ch - m.cw * 0.34,
      width: m.cw,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: m.cw * 0.14, vertical: m.cw * 0.02),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(m.cw * 0.2),
            ),
            child: Text(
              '${c.state.stock.length}',
              style: TextStyle(color: Colors.white, fontSize: m.cw * 0.2, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  /// 더미 자리 + 버린 카드 자리 + 완성 칸 4칸 + 비어 있는 열 자리.
  List<Widget> _slots(SolMetrics m) {
    final s = c.state;
    final slotColor = Colors.white.withValues(alpha: 0.10);
    final border = Colors.white.withValues(alpha: 0.28);
    Widget box(Offset p, {Widget? child, VoidCallback? onTap}) => Positioned(
          left: p.dx,
          top: p.dy,
          width: m.cw,
          height: m.ch,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: slotColor,
                borderRadius: BorderRadius.circular(m.cw * 0.12),
                border: Border.all(color: border, width: 1.4),
              ),
              child: child,
            ),
          ),
        );
    return [
      // 더미가 비었을 때: 눌러서 버린 카드를 다시 넘긴다
      box(
        m.topPos(0),
        onTap: () => c.drawFromStock(),
        child: s.stock.isEmpty
            ? Center(
                child: Icon(
                  Icons.refresh_rounded,
                  size: m.cw * 0.55,
                  color: Colors.white.withValues(alpha: s.waste.isEmpty ? 0.2 : 0.7),
                ),
              )
            : null,
      ),
      box(m.topPos(1)),
      for (var suit = 0; suit < 4; suit++)
        box(
          m.topPos(3 + suit),
          child: Center(
            child: Opacity(
              opacity: 0.4,
              child: SizedBox(
                width: m.cw * 0.5,
                height: m.cw * 0.5,
                child: CustomPaint(painter: _SuitIconPainter(suit)),
              ),
            ),
          ),
        ),
      for (var i = 0; i < 7; i++)
        if (s.tableau[i].isEmpty)
          box(
            Offset(m.slotX(i), m.colY),
            child: Center(
              child: Icon(Icons.horizontal_rule_rounded, color: Colors.white.withValues(alpha: 0.18), size: m.cw * 0.4),
            ),
          ),
    ];
  }

  Offset _targetPos(SolMetrics m, SolMove t) {
    final s = c.state;
    switch (t.kind) {
      case SolKind.wasteToFound:
        return m.topPos(3 + suitOf(s.waste.last));
      case SolKind.colToFound:
        return m.topPos(3 + suitOf(s.tableau[t.from].last));
      case SolKind.wasteToCol:
      case SolKind.colToCol:
      case SolKind.foundToCol:
        return m.nextColPos(t.to, s.tableau[t.to].length, s.up[t.to]);
      case SolKind.draw:
      case SolKind.recycle:
        return m.topPos(0);
    }
  }

  /// 끌고 있을 때 놓을 수 있는 자리를 초록으로 알려준다.
  List<Widget> _targetHighlights(SolMetrics m) {
    final drag = _drag;
    if (drag == null) return const [];
    return [
      for (final t in drag.targets)
        Positioned(
          left: _targetPos(m, t).dx,
          top: _targetPos(m, t).dy,
          width: m.cw,
          height: m.ch,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7CFFB2).withValues(alpha: drag.hover == t ? 0.45 : 0.18),
                borderRadius: BorderRadius.circular(m.cw * 0.12),
                border: Border.all(
                  color: const Color(0xFF7CFFB2).withValues(alpha: drag.hover == t ? 1 : 0.7),
                  width: drag.hover == t ? 3 : 2,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// 힌트가 알려주는 도착 자리 (뽑기 힌트면 더미 자리).
  List<Widget> _hintTarget(SolMetrics m) {
    final h = c.hint;
    if (h == null) return const [];
    final p = _targetPos(m, h);
    return [
      Positioned(
        left: p.dx,
        top: p.dy,
        width: m.cw,
        height: m.ch,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFD84D).withValues(alpha: 0.12 + 0.18 * _pulse.value),
                borderRadius: BorderRadius.circular(m.cw * 0.12),
                border: Border.all(
                  color: const Color(0xFFFFD84D).withValues(alpha: 0.5 + 0.5 * _pulse.value),
                  width: 3,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
