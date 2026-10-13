import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/card_look.dart';
import '../../../core/settings_scope.dart';
import '../../freecell/ui/playing_card.dart';
import '../../freecell/ui/win_celebration.dart';
import '../core/solitaire_rules.dart';
import '../game/solitaire_controller.dart';
import 'card_back.dart';

/// 화면 크기에서 카드 크기와 자리를 계산한다.
class SolMetrics {
  SolMetrics(this.view, double stackWeight) {
    var w = view.width / 8.1;
    // 세로가 모자라면 (가로 화면) 카드를 줄인다
    w = min(w, view.height / 6.0);
    cw = w;
    ch = w * 1.4;
    gap = w * 0.14;
    left = (view.width - (7 * cw + 6 * gap)) / 2;
    pad = w * 0.2;
    topY = pad;
    colY = topY + ch + w * 0.38;
    final avail = view.height - colY - pad;
    final n = max(10.0, stackWeight);
    offU = ((avail - ch) / n).clamp(ch * 0.12, ch * 0.36);
    offD = offU * 0.38;
    fanOff = cw * 0.3;
  }

  final Size view;
  late final double cw, ch, gap, left, pad, topY, colY, offU, offD, fanOff;

  double slotX(int slot) => left + slot * (cw + gap);

  Size get cardSize => Size(cw, ch);

  /// 위쪽 줄: 0 = 더미, 1 = 버린 카드, 3~6 = 완성 칸(무늬 순서).
  Offset topPos(int slot) => Offset(slotX(slot), topY);

  /// 열 [col]의 [k]번째 카드 위치 (열 길이 [len], 앞면 [up]장).
  Offset colPos(int col, int k, int len, int up) {
    final down = len - up;
    final y = k < down ? k * offD : down * offD + (k - down) * offU;
    return Offset(slotX(col), colY + y);
  }

  /// 앞으로 한 장 더 놓일 자리.
  Offset nextColPos(int col, int len, int up) {
    if (len == 0) return Offset(slotX(col), colY);
    return colPos(col, len, len + 1, up + 1);
  }
}

/// 열의 높이를 "앞면 카드 몇 장 분량"으로.
double stackWeightOf(SolState s) {
  var m = 0.0;
  for (var i = 0; i < 7; i++) {
    final len = s.tableau[i].length;
    if (len == 0) continue;
    final w = (len - s.up[i]) * 0.38 + (s.up[i] - 1);
    if (w > m) m = w;
  }
  return m;
}

enum _Src { waste, column, found }

class _Drag {
  _Drag({
    required this.src,
    required this.index,
    required this.cards,
    required this.grab,
    required this.topLeft,
    required this.targets,
  });

  final _Src src;
  final int index; // 열 번호 또는 무늬
  final List<int> cards;
  final Offset grab;
  Offset topLeft;
  final List<SolMove> targets;
  SolMove? hover;
}

class _Loc {
  const _Loc(this.pos, this.z, this.faceUp, {this.src, this.index = 0, this.count = 0});

  final Offset pos;
  final double z;
  final bool faceUp;

  /// 이 카드를 집을 수 있다면 어디서 (집을 수 없으면 null) / 열 번호·무늬 / 같이 집히는 장수.
  final _Src? src;
  final int index;
  final int count;
}

/// 솔리테어 판: 카드 그리기, 끌기, 탭 이동, 힌트 표시, 완성 연출.
class SolitaireTable extends StatefulWidget {
  const SolitaireTable({super.key, required this.controller, this.onCelebrationTap});

  final SolitaireController controller;

  /// 완성 연출 중에 화면을 눌렀을 때 (연출을 건너뛰고 결과를 보여주려고).
  final VoidCallback? onCelebrationTap;

  @override
  State<SolitaireTable> createState() => _SolitaireTableState();
}

class _SolitaireTableState extends State<SolitaireTable> with TickerProviderStateMixin {
  SolitaireController get c => widget.controller;

  final GlobalKey _stackKey = GlobalKey();
  SolMetrics? _m;
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
  bool _wasCompleted = false;

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

  // ── 완성 연출: 윈도우 솔리테어처럼 카드가 잔상을 남기며 튀고, 솟구쳐 터지고, 화면으로 날아온다 ──

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

  // ── 카드 자리 계산 ──

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

  // ── 입력 ──

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
    setState(() {
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

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final m = SolMetrics(box.biggest, stackWeightOf(c.state));
        _m = m;
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => _stack(m),
        );
      },
    );
  }

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

/// 카드 한 장 (위치 이동은 부드럽게, 뒤집힐 때는 가로로 한 번 접혔다 펴진다).
class _CardView extends StatefulWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.pos,
    required this.size,
    required this.faceUp,
    required this.animate,
    required this.interactive,
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
  final bool faceUp;
  final bool animate;
  final bool interactive;
  final Color? glow;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  State<_CardView> createState() => _CardViewState();
}

class _CardViewState extends State<_CardView> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late bool _from = widget.faceUp;

  @override
  void didUpdateWidget(_CardView old) {
    super.didUpdateWidget(old);
    if (old.faceUp != widget.faceUp) {
      _from = old.faceUp;
      _flip.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Widget _face(bool up) {
    if (!up) {
      final style = SettingsScope.of(context).cardBackStyle;
      return RepaintBoundary(child: CustomPaint(painter: CardBackPainter(style: style)));
    }
    final glow = widget.glow;
    SettingsScope.of(context); // 설정이 바뀌면 다시 그리려고
    final compact = CardLook.compactFor(MediaQuery.sizeOf(context).shortestSide);
    if (glow == null) return RepaintBoundary(child: CustomPaint(painter: PlayingCardPainter(widget.card, compact: compact)));
    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (_, _) => CustomPaint(
        painter: PlayingCardPainter(widget.card, compact: compact, glow: glow.withValues(alpha: 0.55 + 0.45 * widget.pulse.value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final child = AnimatedBuilder(
      animation: _flip,
      builder: (_, _) {
        final t = _flip.value;
        if (t >= 1) return _face(w.faceUp);
        final first = t < 0.5;
        final scale = first ? 1 - 2 * t : 2 * t - 1;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(max(scale, 0.02), 1, 1),
          child: _face(first ? _from : w.faceUp),
        );
      },
    );
    return AnimatedPositioned(
      duration: w.animate ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeInOutCubic,
      left: w.pos.dx,
      top: w.pos.dy,
      width: w.size.width,
      height: w.size.height,
      child: IgnorePointer(
        ignoring: !w.interactive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: w.onTap,
          onPanStart: w.onDragStart,
          onPanUpdate: w.onDragUpdate,
          onPanEnd: w.onDragEnd,
          child: child,
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
