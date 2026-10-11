import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/freecell_rules.dart';
import '../game/freecell_controller.dart';
import 'playing_card.dart';
import 'win_celebration.dart';

/// 화면 크기에서 카드 크기와 자리를 계산한다.
class FcMetrics {
  FcMetrics(Size view, int maxColumnLength) : view = view {
    // 가로 기준 카드 폭 (좌우 여백 포함 9.44장 너비)
    var w = view.width / 9.44;
    // 세로가 모자라면 (가로 화면) 카드를 줄여서 열이 12장쯤 쌓여도 읽히게 한다
    w = min(w, view.height / 7.1);
    cw = w;
    ch = w * 1.4;
    gap = w * 0.12;
    left = (view.width - (8 * cw + 7 * gap)) / 2;
    pad = w * 0.25;
    topY = pad;
    colY = topY + ch + w * 0.4;
    final avail = view.height - colY - pad;
    final n = max(2, maxColumnLength);
    off = ((avail - ch) / (n - 1)).clamp(ch * 0.13, ch * 0.36);
  }

  final Size view;
  late final double cw, ch, gap, left, pad, topY, colY, off;

  double slotX(int slot) => left + slot * (cw + gap);

  /// 열 [col]의 [k]번째 카드 위치.
  Offset colPos(int col, int k) => Offset(slotX(col), colY + k * off);

  /// 위쪽 줄: 0~3 = 프리셀, 4~7 = 완성 칸(무늬 순서).
  Offset topPos(int slot) => Offset(slotX(slot), topY);

  Size get cardSize => Size(cw, ch);
}

class _Drag {
  _Drag({
    required this.from,
    required this.index,
    required this.cards,
    required this.grab,
    required this.topLeft,
    required this.targets,
  });

  final Place from;
  final int index;
  final List<int> cards;
  final Offset grab;
  Offset topLeft;
  final List<FcMove> targets;
  FcMove? hover;
}

/// 프리셀 판: 카드 그리기, 끌기, 탭 이동, 힌트 표시, 완성 연출.
class FreecellTable extends StatefulWidget {
  const FreecellTable({super.key, required this.controller, this.onCelebrationTap});

  final FreecellController controller;

  /// 완성 연출 중에 화면을 눌렀을 때 (연출을 건너뛰고 결과를 보여주려고).
  final VoidCallback? onCelebrationTap;

  @override
  State<FreecellTable> createState() => _FreecellTableState();
}

class _FreecellTableState extends State<FreecellTable> with TickerProviderStateMixin {
  FreecellController get c => widget.controller;

  final GlobalKey _stackKey = GlobalKey();
  FcMetrics? _m;
  _Drag? _drag;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  // 완성 연출
  Ticker? _ticker;
  WinCelebration? _show;
  Duration _lastTick = Duration.zero;
  bool _celebrating = false;
  final ValueNotifier<int> _winTick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    _wasCompleted = c.completed;
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _ticker?.dispose();
    _show?.dispose();
    _pulse.dispose();
    _winTick.dispose();
    super.dispose();
  }

  bool _wasCompleted = false;

  void _onController() {
    final hasHint = c.hint != null;
    if (hasHint && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!hasHint && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (c.completed && !_wasCompleted) _startCelebration();
    if (!c.completed && _wasCompleted) _stopCelebration();
    _wasCompleted = c.completed;
  }

  // ── 완성 연출: 윈도우 프리셀처럼 카드가 잔상을 남기며 튀고, 솟구쳐 터지고, 화면으로 날아온다 ──

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
    setState(() {});
  }

  void _stopCelebration() {
    _celebrating = false;
    _ticker?.dispose();
    _ticker = null;
    _show?.dispose();
    _show = null;
    setState(() {});
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

  // ── 위치 계산 ──

  Offset _local(Offset global) =>
      (_stackKey.currentContext!.findRenderObject()! as RenderBox).globalToLocal(global);

  /// 지금 상태에서 카드의 자리: (위치, 겹침 순서, 어느 칸).
  ({Offset pos, double z}) _placeOf(FcMetrics m, int card) {
    final s = c.state;
    for (var i = 0; i < 8; i++) {
      final k = s.columns[i].indexOf(card);
      if (k >= 0) return (pos: m.colPos(i, k), z: 100 + k.toDouble());
    }
    for (var k = 0; k < 4; k++) {
      if (s.cells[k] == card) return (pos: m.topPos(k), z: 50);
    }
    return (pos: m.topPos(4 + suitOf(card)), z: 1 + rankOf(card).toDouble());
  }

  Set<int> _hintCards() {
    final h = c.hint;
    if (h == null) return const {};
    final m = h.move;
    if (m.from == Place.cell) return {c.state.cells[m.fromIndex]};
    final col = c.state.columns[m.fromIndex];
    return col.sublist(col.length - m.count).toSet();
  }

  // ── 입력 ──

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
    setState(() {
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
    setState(() {});
  }

  void _dragEnd(DragEndDetails d) {
    final drag = _drag;
    setState(() => _drag = null);
    if (drag == null) return;
    final target = drag.hover;
    if (target != null) c.tryMove(target);
  }

  /// 끌고 있는 카드가 어느 합법적인 자리 위에 있는가.
  FcMove? _resolveTarget(FcMetrics m, _Drag drag) {
    final cx = drag.topLeft.dx + m.cw / 2;
    final cy = drag.topLeft.dy + m.ch * 0.3;
    final slot = ((cx - m.left) / (m.cw + m.gap)).floor().clamp(0, 7);
    final inTopRow = cy < m.colY - m.gap;
    for (final t in drag.targets) {
      if (inTopRow) {
        if (t.to == Place.cell && t.toIndex == slot) return t;
        if (t.to == Place.foundation && 4 + t.toIndex == slot) return t;
      } else if (t.to == Place.column && t.toIndex == slot) {
        return t;
      }
    }
    return null;
  }

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxLen = c.state.columns.fold<int>(0, (a, col) => max(a, col.length));
        final m = FcMetrics(box.biggest, maxLen);
        _m = m;
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => _stack(m),
        );
      },
    );
  }

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

/// 카드 한 장 (위치 이동은 부드럽게, 끌고 있을 때는 손가락을 바로 따라간다).
class _CardView extends StatelessWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.pos,
    required this.size,
    required this.animate,
    required this.glow,
    required this.pulse,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final int card;
  final Offset pos;
  final Size size;
  final bool animate;
  final Color? glow;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeInOutCubic,
      left: pos.dx,
      top: pos.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: onTap,
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        child: glow == null
            ? RepaintBoundary(child: CustomPaint(painter: PlayingCardPainter(card)))
            : AnimatedBuilder(
                animation: pulse,
                builder: (_, _) => CustomPaint(
                  painter: PlayingCardPainter(
                    card,
                    glow: glow!.withValues(alpha: 0.55 + 0.45 * pulse.value),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SuitIconPainter extends CustomPainter {
  const _SuitIconPainter(this.suit);

  final int suit;

  @override
  void paint(Canvas canvas, Size size) {
    drawSuit(canvas, suit, Offset.zero & size, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SuitIconPainter old) => old.suit != suit;
}
