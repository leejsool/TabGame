part of 'solitaire_table.dart';

// 카드 한 장 위젯과 무늬 그림 (화면 코드를 역할별로 나눈 파일)

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
