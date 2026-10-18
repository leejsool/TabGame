part of 'freecell_table.dart';

/// layers 조각 (화면 코드를 역할별로 나눈 파일)
extension _FtLayers on _FreecellTableState {
  Widget _stack(FcMetrics m) {
    final hintCards = _hintCards();
    final dragCards = _drag?.cards.toSet() ?? const <int>{};
    final entries = <(double, Widget)>[];
    for (var card = 0; card < 52; card++) {
      final place = _placeOf(m, card);
      var pos = place.pos;
      var z = place.z;
      final dragging = dragCards.contains(card);
      if (dragging) {
        final drag = _drag!;
        final j = drag.cards.indexOf(card);
        pos = drag.topLeft + Offset(0, j * m.off);
        z = 1000 + j.toDouble();
      } else if (c.recentlyMoved.contains(card)) {
        z += 500;
      }
      // 완성 연출 중에는 완성 칸의 카드를 숨긴다 (연출 쪽에서 날아간다)
      final hidden = _celebrating && c.state.found[suitOf(card)] > rankOf(card);
      if (hidden) continue;
      entries.add((
        z,
        _CardView(
          key: ValueKey('card-$card'),
          card: card,
          pos: pos,
          size: m.cardSize,
          compact: _faceCompact,
          animate: !dragging,
          glow: hintCards.contains(card) ? const Color(0xFFFFD84D) : null,
          pulse: _pulse,
          onTap: () => _onTapCard(card),
          onDragStart: (d) => _dragStart(card, d),
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
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.1,
                colors: const [Color(0xFF2A7F58), Color(0xFF175B3D)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        ..._slots(m),
        ..._targetHighlights(m),
        ..._hintTarget(m), // 카드 뒤에 깔아서, 위쪽 카드를 덮어 물들이지 않게 한다
        for (final e in entries) e.$2,
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

  /// 프리셀 4칸 + 완성 칸 4칸 + 비어 있는 열 자리.
  List<Widget> _slots(FcMetrics m) {
    final slotColor = Colors.white.withValues(alpha: 0.10);
    final border = Colors.white.withValues(alpha: 0.28);
    Widget box(Offset p, {Widget? child}) => Positioned(
          left: p.dx,
          top: p.dy,
          width: m.cw,
          height: m.ch,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: slotColor,
              borderRadius: BorderRadius.circular(m.cw * 0.12),
              border: Border.all(color: border, width: 1.4),
            ),
            child: child,
          ),
        );
    return [
      for (var k = 0; k < 4; k++) box(m.topPos(k)),
      for (var s = 0; s < 4; s++)
        box(
          m.topPos(4 + s),
          child: Center(
            child: Opacity(
              opacity: 0.4,
              child: SizedBox(
                width: m.cw * 0.5,
                height: m.cw * 0.5,
                child: CustomPaint(painter: _SuitIconPainter(s)),
              ),
            ),
          ),
        ),
      for (var i = 0; i < 8; i++)
        if (c.state.columns[i].isEmpty) box(m.colPos(i, 0)),
    ];
  }

  /// 끌고 있을 때 놓을 수 있는 자리를 초록으로 알려준다.
  List<Widget> _targetHighlights(FcMetrics m) {
    final drag = _drag;
    if (drag == null) return const [];
    final out = <Widget>[];
    for (final t in drag.targets) {
      final Offset p;
      switch (t.to) {
        case Place.cell:
          p = m.topPos(t.toIndex);
        case Place.foundation:
          p = m.topPos(4 + t.toIndex);
        case Place.column:
          final len = c.state.columns[t.toIndex].length;
          p = m.colPos(t.toIndex, len == 0 ? 0 : len);
      }
      final hovered = drag.hover == t;
      out.add(Positioned(
        left: p.dx,
        top: p.dy,
        width: m.cw,
        height: m.ch,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF7CFFB2).withValues(alpha: hovered ? 0.45 : 0.18),
              borderRadius: BorderRadius.circular(m.cw * 0.12),
              border: Border.all(
                color: const Color(0xFF7CFFB2).withValues(alpha: hovered ? 1 : 0.7),
                width: hovered ? 3 : 2,
              ),
            ),
          ),
        ),
      ));
    }
    return out;
  }

  /// 힌트가 알려주는 도착 자리.
  List<Widget> _hintTarget(FcMetrics m) {
    final h = c.hint;
    if (h == null) return const [];
    final t = h.move;
    final Offset p;
    switch (t.to) {
      case Place.cell:
        p = m.topPos(t.toIndex);
      case Place.foundation:
        p = m.topPos(4 + t.toIndex);
      case Place.column:
        final len = c.state.columns[t.toIndex].length;
        p = m.colPos(t.toIndex, len);
    }
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
