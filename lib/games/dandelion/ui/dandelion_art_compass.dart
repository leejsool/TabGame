part of 'dandelion_art.dart';

// 바람 나침반 위젯 (파일을 역할별로 나눈 것)

/// 바람의 나침반: 8방향 화살표. 이미 분 방향은 흐려진다.
///
/// 바람 차례([enabled])에는 화살표를 톡 눌러서 불 수도 있고, 조이스틱처럼 가운데 동그라미를 잡고
/// 원하는 방향으로 끌었다가 놓아도 된다. 끄는 동안에는 가리키는 화살표가 커지고, 놓으면 분다.
/// (가운데로 되돌려 놓으면 취소)
class DandelionCompass extends StatefulWidget {
  const DandelionCompass({
    super.key,
    required this.usedMask,
    this.enabled = false,
    this.onBlow,
    this.size = 160,
    this.windsLeft,
  });

  final int usedMask;
  final bool enabled;
  final void Function(WindDir dir)? onBlow;
  final double size;

  /// 가운데에 쓸 남은 바람 횟수 (null이면 안 쓴다).
  final int? windsLeft;

  /// 가운데에서 이만큼(반지름의 비율) 안쪽은 "아직 방향을 안 정한" 자리.
  static const double deadZone = 0.3;

  /// 나침반 한가운데에서 본 위치([size]는 한 변)가 가리키는 방향 (가운데 가까이면 null).
  static WindDir? dirAt(Offset p, double size) {
    final r = size / 2;
    final d = p - Offset(r, r);
    if (d.distance < r * deadZone) return null;
    final idx = (((atan2(d.dy, d.dx) + pi / 2) / (pi / 4)).round()) % 8;
    return WindDir.values[idx];
  }

  @override
  State<DandelionCompass> createState() => _DandelionCompassState();
}

class _DandelionCompassState extends State<DandelionCompass> {
  /// 끄는 중인 손가락의 자리 (한 변 기준 좌표). 안 끄는 중이면 null.
  Offset? _finger;
  int? _pointer;

  bool get _interactive => widget.enabled && widget.onBlow != null;

  WindDir? get _selected {
    final p = _finger;
    if (p == null) return null;
    final d = DandelionCompass.dirAt(p, widget.size);
    if (d == null || widget.usedMask & (1 << d.index) != 0) return null;
    return d;
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    setState(() => _finger = e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _finger = e.localPosition);
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _finger = e.localPosition;
    final dir = _selected;
    _pointer = null;
    setState(() => _finger = null);
    if (dir != null) widget.onBlow?.call(dir);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _finger = null);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    // 동그라미(손잡이)는 손가락을 따라가되 판 안쪽까지만 간다
    var knob = Offset.zero;
    final p = _finger;
    if (p != null) {
      final d = p - Offset(r, r);
      final maxLen = r * 0.5;
      knob = d.distance <= maxLen ? d : d / d.distance * maxLen;
    }
    final paint = CustomPaint(
      painter: _CompassPainter(
        usedMask: widget.usedMask,
        enabled: widget.enabled,
        windsLeft: widget.windsLeft,
        selected: _selected,
        knob: knob,
        showKnob: _interactive || widget.windsLeft != null,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    Widget body = paint;
    if (_interactive) {
      // 끌기를 바로 우리가 받는다: 스크롤되는 목록 안에 있어도 화면이 같이 움직이지 않는다
      body = RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: paint,
        ),
      );
    }
    return SizedBox(width: widget.size, height: widget.size, child: body);
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.usedMask,
    required this.enabled,
    required this.windsLeft,
    required this.selected,
    required this.knob,
    required this.showKnob,
    required this.dark,
  });

  final int usedMask;
  final bool enabled;
  final int? windsLeft;

  /// 끌어서 가리키고 있는 방향 (크게 보인다).
  final WindDir? selected;

  /// 가운데 동그라미의 이동량.
  final Offset knob;
  final bool showKnob;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r * 0.97, Paint()..color = kWindColor.withValues(alpha: enabled ? 0.16 : 0.08));
    canvas.drawCircle(
      c,
      r * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = kWindColor.withValues(alpha: enabled ? 0.7 : 0.3),
    );
    final muted = (dark ? Colors.white : Colors.black).withValues(alpha: 0.22);
    for (final d in WindDir.values) {
      final used = usedMask & (1 << d.index) != 0;
      final pick = d == selected;
      final a = -pi / 2 + d.index * pi / 4;
      final u = Offset(cos(a), sin(a));
      final color = used ? muted : (pick ? const Color(0xFF0B5CB5) : kWindColor.withValues(alpha: enabled ? 1 : 0.55));
      final w = used ? r * 0.05 : (pick ? r * 0.16 : r * 0.1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w
        ..color = color;
      final tip = c + u * r * (pick ? 0.94 : 0.86);
      if (pick) {
        // 고른 방향 뒤에 부드러운 빛
        canvas.drawLine(
          c + u * r * 0.38,
          tip,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.3
            ..color = kWindColor.withValues(alpha: 0.25),
        );
      }
      canvas.drawLine(c + u * r * 0.38, tip, paint);
      final head = pick ? 0.3 : 0.24;
      final left = Offset(cos(a + 2.6), sin(a + 2.6)), right = Offset(cos(a - 2.6), sin(a - 2.6));
      canvas.drawLine(tip, tip + left * r * head, paint);
      canvas.drawLine(tip, tip + right * r * head, paint);
      if (used) {
        // 이미 분 방향에는 작은 가위표
        final m = c + u * r * 0.62;
        final x = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.04
          ..color = muted;
        canvas.drawLine(m + Offset(-r * 0.06, -r * 0.06), m + Offset(r * 0.06, r * 0.06), x);
        canvas.drawLine(m + Offset(r * 0.06, -r * 0.06), m + Offset(-r * 0.06, r * 0.06), x);
      }
    }
    if (showKnob) {
      final center = c + knob;
      final dragging = knob != Offset.zero;
      canvas.drawCircle(center + Offset(0, r * 0.03), r * 0.3, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(center, r * 0.3, Paint()..color = dark ? const Color(0xFF1F2430) : Colors.white);
      canvas.drawCircle(
        center,
        r * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (dragging ? 0.06 : 0.035)
          ..color = kWindColor.withValues(alpha: dragging ? 1 : 0.6),
      );
      final left = windsLeft;
      if (left != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$left',
            style: TextStyle(fontSize: r * 0.34, fontWeight: FontWeight.w900, color: kWindColor, height: 1.0),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      } else {
        // 잡을 수 있다는 표시: 작은 점 세 개짜리 손잡이
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(center + Offset(i * r * 0.1, 0), r * 0.027, Paint()..color = kWindColor.withValues(alpha: 0.7));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.usedMask != usedMask ||
      old.enabled != enabled ||
      old.windsLeft != windsLeft ||
      old.dark != dark ||
      old.selected != selected ||
      old.knob != knob ||
      old.showKnob != showKnob;
}
