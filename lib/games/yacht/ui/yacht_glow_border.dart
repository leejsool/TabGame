import 'dart:math';

import 'package:flutter/material.dart';

/// 테두리를 따라 빛나는 띠가 빙글빙글 도는 틀. 힌트에서 추천하는 족보를 눈에 띄게 할 때 쓴다.
///
/// 은은한 테두리 위로 꼬리가 달린 밝은 빛이 한 바퀴씩 돌고, 그 뒤로 번지는 빛이 따라온다.
/// 기기의 "애니메이션 줄이기"가 켜져 있으면 돌지 않고 고정된 테두리만 보인다.
class YachtGlowBorder extends StatefulWidget {
  const YachtGlowBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 10,
    this.width = 3.2,
    this.period = const Duration(milliseconds: 2400),
  });

  final Widget child;

  /// 띠의 색 (가장 밝은 머리 부분은 흰빛이 섞인다).
  final Color color;
  final double radius;

  /// 테두리 두께.
  final double width;

  /// 한 바퀴 도는 시간.
  final Duration period;

  @override
  State<YachtGlowBorder> createState() => _YachtGlowBorderState();
}

class _YachtGlowBorderState extends State<YachtGlowBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _GlowPainter(_ctl, widget.color, widget.radius, widget.width),
        child: widget.child,
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.turns, this.color, this.radius, this.width) : super(repaint: turns);

  final Animation<double> turns;
  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.circular(radius));
    // 은은한 바탕 테두리
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.6
        ..color = color.withValues(alpha: 0.55),
    );
    // 도는 띠: 꼬리(점점 밝아짐) → 흰빛 머리 → 뚝 끊김
    // (머리는 흰색이 아니라 밝은 초록 쪽으로: 옅은 바탕 위에서도 또렷하게 보이게)
    final head = Color.lerp(color, const Color(0xFFB6FFD9), 0.45)!;
    final shader = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 1),
        head,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.42, 0.86, 0.985, 1.0],
      transform: GradientRotation(turns.value * 2 * pi),
    ).createShader(rect);
    // 번지는 빛 (띠 뒤에 흐리게)
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.6
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color || old.radius != radius || old.width != width;
}
