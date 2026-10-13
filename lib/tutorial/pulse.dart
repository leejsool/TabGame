import 'package:flutter/material.dart';

/// 안내 중에 "여기를 눌러 보세요" 하고 알려주는, 깜빡이는 테두리.
/// [active]가 false이면 아무 효과 없이 [child]만 보인다.
class PulseHighlight extends StatefulWidget {
  const PulseHighlight({
    super.key,
    required this.active,
    required this.child,
    this.radius = 14,
    this.color,
  });

  final bool active;
  final Widget child;
  final double radius;
  final Color? color;

  @override
  State<PulseHighlight> createState() => _PulseHighlightState();
}

class _PulseHighlightState extends State<PulseHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PulseHighlight old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
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
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: color.withValues(alpha: 0.35 + 0.65 * _c.value),
            width: 3,
          ),
          color: color.withValues(alpha: 0.06 + 0.08 * _c.value),
        ),
        child: child,
      ),
    );
  }
}
