import 'package:flutter/material.dart';

/// 정해진 크기([width]×[height])로 그림을 짜 두고, 놓일 자리에 맞게 통째로 줄이거나 키운다.
/// (그림 안의 글자와 간격이 함께 커지고 작아져서, 화면 크기가 달라도 같은 모습이 된다.)
class ArtCanvas extends StatelessWidget {
  const ArtCanvas({super.key, required this.width, required this.height, required this.child});

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 그림은 통째로 줄이고 늘리니까, 기기의 글자 크기 설정까지 곱해지면 글자만 커져서 어긋난다.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
  }
}

/// 그림 위에 얹는 짧은 설명표 (알약 모양).
class ArtLabel extends StatelessWidget {
  const ArtLabel(this.text, {super.key, this.color, this.filled = true, this.fontSize = 15});

  final String text;
  final Color? color;
  final bool filled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : c,
        ),
      ),
    );
  }
}

/// 손가락으로 "톡" 누르는 모습: 가운데에서 동그란 물결이 퍼진다.
/// [hold]가 true이면 누르고 있는 동안 테두리가 차오르는 모습이다.
class TapPulse extends StatefulWidget {
  const TapPulse({super.key, this.size = 80, this.color, this.hold = false, this.icon});

  final double size;
  final Color? color;
  final bool hold;
  final IconData? icon;

  @override
  State<TapPulse> createState() => _TapPulseState();
}

class _TapPulseState extends State<TapPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.hold ? 1800 : 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(_c.value, color, widget.hold),
          child: Center(
            child: Icon(
              widget.icon ?? (widget.hold ? Icons.back_hand_rounded : Icons.touch_app_rounded),
              size: widget.size * 0.46,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color, this.hold);

  final double t;
  final Color color;
  final bool hold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..color = color.withValues(alpha: 0.12));
    if (hold) {
      final rect = Rect.fromCircle(center: c, radius: r * 0.82);
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = color.withValues(alpha: 0.18),
      );
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    } else {
      canvas.drawCircle(
        c,
        r * (0.55 + 0.45 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08
          ..color = color.withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.color != color || old.hold != hold;
}

/// 가운데 아이콘이 있는 큰 동그라미 (아이콘 위주의 그림에 쓴다).
class ArtBadge extends StatelessWidget {
  const ArtBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 96,
    this.label,
  });

  final IconData icon;
  final Color color;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(icon, size: size * 0.5, color: color),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ],
    );
  }
}
