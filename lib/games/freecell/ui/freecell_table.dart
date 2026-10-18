import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/card_look.dart';
import '../../../core/settings_scope.dart';
import '../core/freecell_rules.dart';
import '../game/freecell_controller.dart';
import 'playing_card.dart';
import 'win_celebration.dart';

part 'freecell_table_drag.dart';
part 'freecell_table_layers.dart';

/// 화면 크기에서 카드 크기와 자리를 계산한다.
class FcMetrics {
  FcMetrics(Size view, int maxColumnLength, {this.compact = false}) : view = view {
    // 가로 기준 카드 폭 (좌우 여백 포함 9.44장 너비). 폰은 좌우를 꽉 채워 카드를 키운다.
    var w = view.width / (compact ? 8.5 : 9.44);
    // 세로가 모자라면 (가로 화면) 카드를 줄여서 열이 12장쯤 쌓여도 읽히게 한다
    w = min(w, view.height / 7.1);
    cw = w;
    ch = w * 1.4;
    gap = w * (compact ? 0.06 : 0.12);
    left = (view.width - (8 * cw + 7 * gap)) / 2;
    pad = w * 0.25;
    topY = pad;
    colY = topY + ch + w * 0.4;
    final avail = view.height - colY - pad;
    final n = max(2, maxColumnLength);
    // 폰 카드는 맨 위 한 줄(숫자+무늬)이 w*0.5쯤이라, 겹치는 간격도 그만큼까지 넓힌다
    off = ((avail - ch) / (n - 1)).clamp(ch * 0.13, compact ? w * 0.52 : ch * 0.36);
  }

  final Size view;
  final bool compact;
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
  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  FreecellController get c => widget.controller;

  final GlobalKey _stackKey = GlobalKey();
  FcMetrics? _m;

  /// 카드 앞면을 폰용(숫자·무늬 한 줄)으로 그리는가 (설정 + 기기 크기).
  bool _faceCompact = false;
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




  // ── 위치 계산 ──


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


  // ── 입력 ──

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxLen = c.state.columns.fold<int>(0, (a, col) => max(a, col.length));
        // 탭(넓은 화면)은 그대로, 폰 화면에서만 카드를 간결하고 크게 그린다
        final shortest = MediaQuery.sizeOf(context).shortestSide;
        final compact = shortest < 600;
        final m = FcMetrics(box.biggest, maxLen, compact: compact);
        _m = m;
        // 카드 그림을 폰용(숫자·무늬 한 줄)으로 그릴지는 설정에서 고른다 (설정이 바뀌면 다시 그려지게 구독)
        SettingsScope.of(context);
        _faceCompact = CardLook.compactFor(shortest);
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => _stack(m),
        );
      },
    );
  }




}

/// 카드 한 장 (위치 이동은 부드럽게, 끌고 있을 때는 손가락을 바로 따라간다).
class _CardView extends StatelessWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.pos,
    required this.size,
    required this.compact,
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
  final bool compact;
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
            ? RepaintBoundary(child: CustomPaint(painter: PlayingCardPainter(card, compact: compact)))
            : AnimatedBuilder(
                animation: pulse,
                builder: (_, _) => CustomPaint(
                  painter: PlayingCardPainter(
                    card,
                    compact: compact,
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
