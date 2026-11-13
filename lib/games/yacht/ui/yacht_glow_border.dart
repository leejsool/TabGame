import 'dart:math';

import 'package:flutter/material.dart';

/// 테두리를 따라 빛나는 띠가 빙글빙글 도는 틀. 힌트에서 추천하는 족보를 눈에 띄게 할 때 쓴다.
///
/// 옅게 물든 칸에 또렷한 테두리를 두르고, 그 위로 꼬리가 달린 밝은 빛줄기가 한 바퀴씩 돈다 (흐림 효과 없이 가볍게).
/// 기기의 "애니메이션 줄이기"가 켜져 있으면 돌지 않고 고정된 테두리만 보인다.
class YachtGlowBorder extends StatefulWidget {
  const YachtGlowBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 10,
    this.width = 3.2,
    this.period = const Duration(milliseconds: 3000),
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

/// 그리기: 옅게 물든 바탕 + 또렷한 테두리 + 테두리를 따라 도는 짧은 빛줄기(꼬리가 점점 옅어진다).
///
/// 저성능 기기를 위해 흐림 효과(MaskFilter.blur)는 쓰지 않는다: 예전에는 번지는 빛을 매 프레임 흐리게 계산해서
/// 힌트 창을 여는 동안 계속 무거웠다. 이제 매 프레임 하는 일은 선 몇 개를 긋는 것뿐이다.
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
    // 옅게 물든 바탕과 또렷한 테두리 (움직이지 않는 부분)
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.07));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.55
        ..color = color.withValues(alpha: 0.7),
    );
    // 도는 빛줄기: 옅은 꼬리 → 진한 몸통 → 밝은 머리
    final head = Color.lerp(color, Colors.white, 0.55)!;
    final shader = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.9),
        head,
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.62, 0.92, 0.985, 1.0],
      transform: GradientRotation(turns.value * 2 * pi),
    ).createShader(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color || old.radius != radius || old.width != width;
}
