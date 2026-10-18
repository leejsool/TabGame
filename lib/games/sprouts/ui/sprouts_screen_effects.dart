part of 'sprouts_screen.dart';

// 깜빡임·색종이 효과 (파일을 역할별로 나눈 것)

/// 0~1~0을 되풀이하는 숨쉬기 값을 만들어 [builder]에 넘긴다 (끝 표시가 살아 있는 느낌이 나게).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.builder, this.active = true});

  final Widget Function(BuildContext context, double pulse) builder;

  /// false면 숨쉬지 않고 가만히 있다 (기권처럼 차분해야 할 때).
  final bool active;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => widget.builder(context, widget.active ? Curves.easeInOut.transform(_c.value) : 0.0),
      );
}

/// 이겼을 때 판 위로 터졌다가 떨어지는 색종이. 짧게(약 3초) 흩날리고 사라진다.
class FinishConfetti extends StatefulWidget {
  const FinishConfetti({super.key, required this.color});

  final Color color;

  @override
  State<FinishConfetti> createState() => _FinishConfettiState();
}

class _FinishConfettiState extends State<FinishConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value, widget.color)),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.color) : _pieces = _make(color);

  final double t;
  final Color color;
  final List<_Piece> _pieces;

  static List<_Piece> _make(Color base) {
    final rng = Random(7);
    final palette = [base, const Color(0xFFFFC21A), const Color(0xFFFF6FAE), const Color(0xFF3DD6A5), const Color(0xFF5AA9FF), Colors.white];
    return [
      for (var i = 0; i < 90; i++)
        _Piece(
          x: 0.12 + rng.nextDouble() * 0.76,
          vx: (rng.nextDouble() - 0.5) * 0.9,
          vy: -(0.9 + rng.nextDouble() * 1.1),
          size: 6 + rng.nextDouble() * 7,
          spin: (rng.nextDouble() - 0.5) * 14,
          phase: rng.nextDouble() * 6.28,
          circle: rng.nextBool(),
          color: palette[rng.nextInt(palette.length)],
          delay: rng.nextDouble() * 0.12,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final u = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final time = u * 2.6;
      final x = size.width * (p.x + p.vx * time * 0.35) + sin(time * 3 + p.phase) * 14;
      // 아래 가운데에서 위로 솟았다가 중력으로 떨어진다
      final y = size.height * (0.9 + p.vy * time * 0.45 + 0.95 * time * time * 0.45);
      final alpha = u > 0.78 ? (1 - u) / 0.22 : 1.0;
      if (alpha <= 0 || y > size.height + 20) continue;
      final paint = Paint()..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * time + p.phase);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.phase,
    required this.circle,
    required this.color,
    required this.delay,
  });

  final double x, vx, vy, size, spin, phase, delay;
  final bool circle;
  final Color color;
}
