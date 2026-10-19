import 'dart:math';

import 'package:flutter/material.dart';

/// 내 차례임을 알리는 금빛 테두리: 둘레를 따라 밝은 금빛이 천천히 돌고, 바깥으로 은은하게 빛이 번진다.
///
/// [active]가 아니면 아무것도 그리지 않는다 (움직임도 멈춘다). 눈이 부시지 않게 번지는 빛은 옅고 천천히 숨 쉬듯 변한다.
class RkTurnGlow extends StatefulWidget {
  const RkTurnGlow({super.key, required this.active, required this.child, this.radius = 14});

  final bool active;
  final Widget child;

  /// 감싸는 상자의 모서리 둥글기.
  final double radius;

  @override
  State<RkTurnGlow> createState() => _RkTurnGlowState();
}

class _RkTurnGlowState extends State<RkTurnGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  /// 시험 환경에서는 계속 도는 움직임을 켜지 않는다 (`pumpAndSettle`이 끝나지 않으니). 그때는 멈춘 모습으로만 그린다.
  static bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(RkTurnGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_inTest) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return CustomPaint(
      foregroundPainter: _GlowPainter(_c, widget.radius),
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t, this.radius) : super(repaint: t);

  final Animation<double> t;
  final double radius;

  static const Color _gold = Color(0xFFFFC83D);
  static const Color _bright = Color(0xFFFFF0B0);
  static const Color _deep = Color(0xFFE0A100);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(1.4), Radius.circular(radius));
    // 바깥으로 번지는 빛: 숨 쉬듯 옅어졌다 짙어진다
    final breathe = 0.5 + 0.5 * sin(v * 2 * pi);
    canvas.drawRRect(
      rr.inflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = _gold.withValues(alpha: 0.28 + 0.22 * breathe),
    );
    // 바탕 금색 테두리
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _deep.withValues(alpha: 0.75),
    );
    // 둘레를 도는 밝은 금빛
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: const [Color(0x00FFC83D), _gold, _bright, _gold, Color(0x00FFC83D), Color(0x00FFC83D)],
          stops: const [0.0, 0.1, 0.2, 0.3, 0.42, 1.0],
          transform: GradientRotation(v * 2 * pi),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.radius != radius;
}
