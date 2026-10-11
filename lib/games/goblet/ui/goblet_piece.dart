import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../core/goblet_rules.dart';

/// 팀 색.
class TeamPalette {
  const TeamPalette({
    required this.main,
    required this.light,
    required this.dark,
    required this.earInner,
  });

  final Color main;
  final Color light;
  final Color dark;
  final Color earInner;

  static const red = TeamPalette(
    main: Color(0xFFF0545B),
    light: Color(0xFFFF8F94),
    dark: Color(0xFFB92D3A),
    earInner: Color(0xFFFFC2C6),
  );
  static const blue = TeamPalette(
    main: Color(0xFF3F86F5),
    light: Color(0xFF8DBBFF),
    dark: Color(0xFF2358BE),
    earInner: Color(0xFFC3DAFF),
  );

  static TeamPalette of(Team t) => t == Team.red ? red : blue;
}

enum PieceMood { normal, lifted, happy }

/// 크기별 말 폭 (칸 크기 대비).
const List<double> kPieceScale = [0.46, 0.68, 0.9];

/// 귀여운 고블러 말. 크기는 실제 크기 + 아랫단 점(1·2·3개)으로, 팀은 색 + 귀 모양
/// (빨강 = 뾰족한 고양이 귀, 파랑 = 둥근 곰 귀)으로 구분한다.
class GobblerPainter extends CustomPainter {
  const GobblerPainter({required this.team, required this.size, this.mood = PieceMood.normal});

  final Team team;
  final int size;
  final PieceMood mood;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final pal = TeamPalette.of(team);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, w * 0.035)
      ..strokeJoin = StrokeJoin.round
      ..color = pal.dark;

    // ── 귀 (몸 뒤) ──
    if (team == Team.red) {
      for (final flip in [false, true]) {
        Offset p(double x, double y) => Offset((flip ? 1 - x : x) * w, y * h);
        final ear = Path()
          ..moveTo(p(0.08, 0.40).dx, p(0.08, 0.40).dy)
          ..lineTo(p(0.13, 0.0).dx, p(0.13, 0.0).dy)
          ..lineTo(p(0.40, 0.16).dx, p(0.40, 0.16).dy)
          ..close();
        canvas.drawPath(ear, Paint()..color = pal.main);
        final inner = Path()
          ..moveTo(p(0.15, 0.30).dx, p(0.15, 0.30).dy)
          ..lineTo(p(0.17, 0.10).dx, p(0.17, 0.10).dy)
          ..lineTo(p(0.30, 0.19).dx, p(0.30, 0.19).dy)
          ..close();
        canvas.drawPath(inner, Paint()..color = pal.earInner);
        canvas.drawPath(ear, outline);
      }
    } else {
      for (final x in [0.19, 0.81]) {
        final c = Offset(x * w, 0.15 * h);
        canvas.drawCircle(c, w * 0.13, Paint()..color = pal.main);
        canvas.drawCircle(c, w * 0.07, Paint()..color = pal.earInner);
        canvas.drawCircle(c, w * 0.13, outline);
      }
    }

    // ── 몸 (돔 모양 컵) ──
    final body = Path()
      ..moveTo(0.05 * w, 0.88 * h)
      ..cubicTo(0.03 * w, 0.34 * h, 0.24 * w, 0.06 * h, 0.5 * w, 0.06 * h)
      ..cubicTo(0.76 * w, 0.06 * h, 0.97 * w, 0.34 * h, 0.95 * w, 0.88 * h)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.light, pal.main],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(body, outline);

    // 반짝이는 하이라이트
    canvas.save();
    canvas.translate(0.29 * w, 0.24 * h);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.2 * w, height: 0.1 * h),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.restore();

    // ── 아랫단 + 크기 점 ──
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(0.01 * w, 0.78 * h, 0.99 * w, 0.95 * h),
      Radius.circular(0.08 * h),
    );
    canvas.drawRRect(rim, Paint()..color = pal.dark);
    final dotR = max(0.042 * w, 1.7);
    final gap = 0.14 * w;
    for (var i = 0; i < size; i++) {
      final x = 0.5 * w + (i - (size - 1) / 2) * gap;
      canvas.drawCircle(Offset(x, 0.865 * h), dotR, Paint()..color = Colors.white);
    }

    // ── 얼굴 ──
    const ink = Color(0xFF3A2A3C);
    final eyeY = 0.46 * h;
    final eyeDx = 0.17 * w;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.4, w * 0.035)
      ..color = ink;

    if (mood == PieceMood.happy) {
      // ^ ^ 웃는 눈
      for (final sx in [-1.0, 1.0]) {
        final c = Offset(0.5 * w + sx * eyeDx, eyeY + 0.02 * h);
        canvas.drawArc(
          Rect.fromCenter(center: c, width: 0.13 * w, height: 0.12 * h),
          pi,
          pi,
          false,
          stroke,
        );
      }
    } else {
      final er = (mood == PieceMood.lifted ? 0.085 : 0.07) * w;
      for (final sx in [-1.0, 1.0]) {
        final c = Offset(0.5 * w + sx * eyeDx, eyeY);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: er * 2, height: er * 2.5),
          Paint()..color = ink,
        );
        canvas.drawCircle(
          c + Offset(-er * 0.3, -er * 0.55),
          er * 0.38,
          Paint()..color = Colors.white,
        );
      }
    }

    // 볼터치
    final blush = Paint()..color = const Color(0xFFFF9EB5).withValues(alpha: 0.55);
    for (final sx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.5 * w + sx * 0.27 * w, 0.59 * h),
          width: 0.13 * w,
          height: 0.075 * h,
        ),
        blush,
      );
    }

    // 입
    final mouthC = Offset(0.5 * w, 0.61 * h);
    if (mood == PieceMood.lifted) {
      canvas.drawOval(
        Rect.fromCenter(center: mouthC + Offset(0, 0.02 * h), width: 0.09 * w, height: 0.1 * h),
        Paint()..color = ink,
      );
    } else if (mood == PieceMood.happy) {
      final mouth = Path()
        ..moveTo(mouthC.dx - 0.08 * w, mouthC.dy - 0.01 * h)
        ..quadraticBezierTo(mouthC.dx, mouthC.dy + 0.12 * h, mouthC.dx + 0.08 * w, mouthC.dy - 0.01 * h)
        ..close();
      canvas.drawPath(mouth, Paint()..color = ink);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: mouthC, width: 0.15 * w, height: 0.09 * h),
        0.15,
        pi - 0.3,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(GobblerPainter old) =>
      old.team != team || old.size != size || old.mood != mood;
}

/// 판 위·대기 칸에서 움직이는 말 한 개. 위치 이동(슬라이드), 통통 뛰기, 착지 찌그러짐, 집어 올림 효과를 담당한다.
class PieceView extends StatefulWidget {
  const PieceView({
    super.key,
    required this.team,
    required this.size,
    required this.rect,
    required this.cell,
    required this.animate,
    required this.lifted,
    required this.bob,
    required this.mood,
    required this.pulse,
    required this.onTap,
    this.ignorePointer = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Team team;
  final int size;

  /// 스테이지 좌표에서의 말 상자.
  final Rect rect;

  /// 한 칸의 크기 (뛰는 높이 계산용).
  final double cell;

  /// false면 위치를 즉시 따라간다 (드래그 중).
  final bool animate;
  final bool lifted;

  /// 내가 움직일 수 있는 말: 살짝 들썩여서 알려준다.
  final bool bob;
  final PieceMood mood;
  final Animation<double> pulse;
  final VoidCallback onTap;

  /// 다른 말에 덮여 보이지 않는 말은 터치를 받지 않는다.
  final bool ignorePointer;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  State<PieceView> createState() => _PieceViewState();
}

class _PieceViewState extends State<PieceView> with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _land.forward(from: 0);
    });
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(PieceView old) {
    super.didUpdateWidget(old);
    if (widget.animate && old.rect != widget.rect) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    _land.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rect;
    return AnimatedPositioned(
      duration: widget.animate ? const Duration(milliseconds: 360) : Duration.zero,
      curve: Curves.easeInOutCubic,
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        ignoring: widget.ignorePointer,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 손가락이 처음 닿은 위치를 기준으로 말을 잡는다 (끌기 시작 지점이 튀지 않게)
        dragStartBehavior: DragStartBehavior.down,
        onTap: widget.onTap,
        onPanStart: widget.onDragStart,
        onPanUpdate: widget.onDragUpdate,
        onPanEnd: widget.onDragEnd,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hop, _land, widget.pulse]),
          builder: (context, _) {
            final hop = sin(pi * _hop.value) * widget.cell * 0.32;
            final lift = widget.lifted ? widget.cell * 0.10 : 0.0;
            final bob = widget.bob && !widget.lifted
                ? sin(widget.pulse.value * 2 * pi) * widget.cell * 0.018
                : 0.0;
            final sq = _land.isAnimating ? sin(pi * _land.value) * exp(-_land.value * 2) : 0.0;
            final lifted = widget.lifted;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 바닥 그림자
                Positioned(
                  left: r.width * (lifted ? 0.10 : 0.08),
                  right: r.width * (lifted ? 0.10 : 0.08),
                  bottom: -r.height * 0.02,
                  height: r.height * 0.12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(r.height),
                      color: Colors.black.withValues(alpha: lifted ? 0.16 : 0.22),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -hop - lift + bob),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(
                      (lifted ? 1.14 : 1.0) * (1 + 0.14 * sq),
                      (lifted ? 1.14 : 1.0) * (1 - 0.14 * sq),
                      1,
                    ),
                    child: CustomPaint(
                      size: r.size,
                      painter: GobblerPainter(
                        team: widget.team,
                        size: widget.size,
                        mood: lifted && widget.mood == PieceMood.normal
                            ? PieceMood.lifted
                            : widget.mood,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}
