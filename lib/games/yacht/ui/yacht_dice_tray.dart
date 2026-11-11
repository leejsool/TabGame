import 'dart:math';

import 'package:flutter/material.dart';

import 'yacht_cube.dart';
import 'yacht_look.dart';

/// 주사위 5개가 놓인 줄. 굴리면 안 잡은 주사위가 아래에서 던져져 입체로 구르다가 [target] 눈으로 멈춘다.
class YachtDiceTray extends StatefulWidget {
  const YachtDiceTray({
    super.key,
    required this.dice,
    required this.held,
    required this.rolling,
    required this.target,
    required this.rollTime,
    required this.accent,
    this.onTap,
    this.maxDie = 64,
  });

  /// 지금 놓인 눈 (0이면 아직 안 굴린 빈 주사위).
  final List<int> dice;
  final List<bool> held;

  /// 구르는 중인가. 구르는 동안에는 [target](멈출 눈)을 향해 굴러간다.
  final bool rolling;
  final List<int> target;
  final Duration rollTime;
  final Color accent;

  /// 주사위를 눌러 잡거나 놓는다 (누를 수 없는 때는 null).
  final void Function(int index)? onTap;
  final double maxDie;

  @override
  State<YachtDiceTray> createState() => _YachtDiceTrayState();
}

/// 주사위 하나가 굴러오는 길.
class _Throw {
  _Throw(Random rng, int order)
      : spinX = _spin(rng, 1.4, 2.6),
        spinY = _spin(rng, 1.4, 2.6),
        spinZ = _spin(rng, 0.3, 0.9),
        side = rng.nextDouble() - 0.5,
        depth = 1.0 + rng.nextDouble() * 0.5,
        span = 0.72 + 0.07 * order;

  static double _spin(Random rng, double lo, double hi) => (rng.nextBool() ? 1 : -1) * 2 * pi * (lo + rng.nextDouble() * (hi - lo));

  /// 처음에 돌아가 있는 각도 (멈출 때 0이 된다).
  final double spinX, spinY, spinZ;

  /// 던져지는 자리 (주사위 크기의 몇 배만큼 옆 · 아래).
  final double side, depth;

  /// 전체 시간 중 이 주사위가 구르는 비율 (주사위마다 조금씩 늦게 멈춘다).
  final double span;
}

class _YachtDiceTrayState extends State<YachtDiceTray> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: widget.rollTime);
  final Random _rng = Random();
  List<_Throw> _throws = const [];

  @override
  void initState() {
    super.initState();
    if (widget.rolling) _startRoll();
  }

  @override
  void didUpdateWidget(YachtDiceTray old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) _startRoll();
    if (!widget.rolling && old.rolling) _anim.stop();
  }

  void _startRoll() {
    final order = [0, 1, 2, 3, 4]..shuffle(_rng);
    _throws = [for (var i = 0; i < widget.dice.length; i++) _Throw(_rng, order[i])];
    _anim
      ..duration = widget.rollTime
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool _flying(int i) => widget.rolling && _throws.isNotEmpty && !(widget.dice[i] != 0 && widget.held[i]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 8.0;
      final n = widget.dice.length;
      final die = min(widget.maxDie, (box.maxWidth - gap * (n - 1)) / n);
      final width = die * n + gap * (n - 1);
      return SizedBox(
        width: width,
        height: die + 22,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              // (구르는 주사위가 놓인 주사위 위로 지나가게 나중에 그린다)
              for (var i = 0; i < n; i++)
                if (!_flying(i)) Positioned(left: i * (die + gap), top: 0, child: _resting(i, die)),
              for (var i = 0; i < n; i++)
                if (_flying(i)) Positioned(left: i * (die + gap), top: 0, child: _rollingDie(i, die, width, gap)),
            ],
          ),
        ),
      );
    });
  }

  Widget _resting(int i, double die) {
    final held = widget.held[i] && widget.dice[i] != 0;
    return GestureDetector(
      key: ValueKey('yacht-die-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : () => widget.onTap!(i),
      child: SizedBox(
        width: die,
        height: die + 22,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 140),
              top: held ? 0 : 8,
              left: 0,
              child: YachtDie(value: widget.dice[i], size: die, held: held, accent: widget.accent),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: held ? 1 : 0,
                child: Text('잡음', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 구르는 주사위: 줄의 아래 가운데에서 던져져, 통통 튀고 빙글빙글 돌면서 제자리로 온다.
  Widget _rollingDie(int i, double die, double width, double gap) {
    final t = _throws[i];
    final p = (_anim.value / t.span).clamp(0.0, 1.0);
    final ease = 1 - pow(1 - p, 3).toDouble(); // 처음엔 빠르고 끝에서 느려진다
    final left = 1 - ease;
    final hop = (sin(p * pi * 2.5).abs() * pow(1 - p, 1.5)).toDouble().clamp(0.0, 1.0); // 튀어 오른 높이 (0~1)
    final slotX = i * (die + gap) + die / 2;
    final from = Offset((width / 2 - slotX) * 0.85 + t.side * die, t.depth * die);
    final scale = 1 + 0.32 * hop;
    return Transform.translate(
      offset: from * left + Offset(0, 8 - hop * die * 0.45),
      child: Transform.scale(
        scale: scale,
        child: CustomPaint(
          size: Size.square(die),
          painter: YachtCubePainter(value: widget.target[i], ax: t.spinX * left, ay: t.spinY * left, az: t.spinZ * left, lift: hop),
        ),
      ),
    );
  }
}
