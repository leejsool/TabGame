import 'dart:math';

import 'package:flutter/material.dart';

import 'yacht_cube.dart';
import 'yacht_look.dart';

/// 주사위 5개가 놓인 줄. 굴리면 안 잡은 주사위가 아래에서 던져져 입체로 구르다가 [target] 눈으로 멈추고,
/// 다 멈추면 왼쪽부터 눈이 작은 순서로 부드럽게 자리를 옮겨 정렬된다 (보이는 자리만 바뀌고, 누르는 주사위 번호는 그대로).
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
    this.launchDelays,
    this.twoRows = false,
    this.daesungIndex,
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

  /// 굴러가는 주사위들이 던져지기 시작하는 순간(밀리초). 굴러가는 주사위를 번호 순서로 하나씩 받는다 (남는 주사위는 바로 시작).
  /// 소리와 같은 값을 써서 서로 어긋나게 던진다. 없으면 모두 한꺼번에 던진다.
  final List<int>? launchDelays;

  /// 주사위를 두 줄(위 3개 · 아래 2개, 가운데 맞춤)로 놓는다. 폭이 좁은 핸드폰 가로 모드에서 주사위를 크게 보이려고 쓴다.
  final bool twoRows;

  /// 대성One Rule 판에서 대성One(초록 · 로고) 주사위의 번호. 기본 규칙이면 null.
  final int? daesungIndex;

  @override
  State<YachtDiceTray> createState() => _YachtDiceTrayState();
}

/// 주사위 하나가 굴러오는 길.
class _Throw {
  _Throw(Random rng, int order, {this.start = 0})
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

  /// 던져지기 시작하는 때 (전체 시간 중 비율). 이 전에는 보이지 않는다.
  final double start;
}

class _YachtDiceTrayState extends State<YachtDiceTray> with SingleTickerProviderStateMixin {
  /// 정렬 자리옮김에 걸리는 시간.
  static const Duration _sortTime = Duration(milliseconds: 460);

  late final AnimationController _anim = AnimationController(vsync: this, duration: widget.rollTime);
  final Random _rng = Random();
  List<_Throw> _throws = const [];

  /// 눈 순서대로 자리를 잡았는가 (멈춘 직후 한 프레임 뒤에 켜져서, 놓인 자리에서 정렬 자리로 미끄러진다).
  bool _sorted = false;

  bool get _allRolled => widget.dice.every((d) => d != 0);

  @override
  void initState() {
    super.initState();
    if (widget.rolling) _startRoll();
    _sorted = !widget.rolling && _allRolled; // 이어하던 판은 처음부터 정렬된 모습
  }

  @override
  void didUpdateWidget(YachtDiceTray old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _sorted = false; // 다시 굴리면 정렬 자리에서 원래 자리로 돌아간다
      _startRoll();
    }
    if (!widget.rolling && old.rolling) {
      _anim.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.rolling && _allRolled) setState(() => _sorted = true);
      });
    }
    if (!_allRolled) _sorted = false; // 새 판
  }

  /// 주사위마다 보일 자리 번호: 정렬됐으면 눈이 작은 것부터 0, 1, 2… (눈이 같으면 원래 순서대로), 아니면 제 번호 그대로.
  List<int> _slots() {
    final n = widget.dice.length;
    if (!(_sorted && _allRolled && !widget.rolling)) return [for (var i = 0; i < n; i++) i];
    final order = yachtSortedOrder(widget.dice);
    final slots = List<int>.filled(n, 0);
    for (var r = 0; r < n; r++) {
      slots[order[r]] = r;
    }
    return slots;
  }

  void _startRoll() {
    final order = [0, 1, 2, 3, 4]..shuffle(_rng);
    final delays = widget.launchDelays ?? const <int>[];
    final ms = max(1, widget.rollTime.inMilliseconds);
    var next = 0; // 굴러가는(고정하지 않은) 주사위가 몇 번째인가
    final starts = List<double>.filled(widget.dice.length, 0);
    for (var i = 0; i < widget.dice.length; i++) {
      final kept = widget.dice[i] != 0 && widget.held[i];
      if (kept) continue;
      if (next < delays.length) starts[i] = delays[next] / ms;
      next++;
    }
    _throws = [for (var i = 0; i < widget.dice.length; i++) _Throw(_rng, order[i], start: starts[i])];
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
      final two = widget.twoRows;
      final die = two ? min(widget.maxDie, (box.maxWidth - gap * 2) / 3) : min(widget.maxDie, (box.maxWidth - gap * (n - 1)) / n);
      final width = two ? die * 3 + gap * 2 : die * n + gap * (n - 1);
      final slots = _slots();
      // 자리 번호 → 놓이는 곳. 한 줄이면 가로로 나란히, 두 줄이면 위 3개 · 아래 2개를 가운데 맞춤
      Offset place(int slot) {
        if (!two) return Offset(slot * (die + gap), 0);
        if (slot < 3) return Offset(slot * (die + gap), 0);
        return Offset((width - (2 * die + gap)) / 2 + (slot - 3) * (die + gap), die + 22 + 4);
      }

      return SizedBox(
        width: width,
        height: two ? (die + 22) * 2 + 4 : die + 22,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              // (구르는 주사위가 놓인 주사위 위로 지나가게 나중에 그린다)
              for (var i = 0; i < n; i++)
                if (!_flying(i))
                  AnimatedPositioned(
                    key: ValueKey('rest-$i'),
                    duration: _sortTime,
                    curve: Curves.easeInOutCubic,
                    left: place(slots[i]).dx,
                    top: place(slots[i]).dy,
                    child: _resting(i, die),
                  ),
              for (var i = 0; i < n; i++)
                if (_flying(i)) Positioned(key: ValueKey('fly-$i'), left: place(i).dx, top: place(i).dy, child: _rollingDie(i, die, width, place(i).dx + die / 2)),
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
              child: YachtDie(value: widget.dice[i], size: die, held: held, accent: widget.accent, daesung: i == widget.daesungIndex),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: held ? 1 : 0,
                child: Text('고정', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 구르는 주사위: 줄의 아래 가운데에서 던져져, 통통 튀고 빙글빙글 돌면서 제자리로 온다.
  Widget _rollingDie(int i, double die, double width, double slotX) {
    final t = _throws[i];
    if (_anim.value < t.start) return SizedBox.square(dimension: die); // 아직 던지기 전: 보이지 않는다
    final p = ((_anim.value - t.start) / (t.span - t.start)).clamp(0.0, 1.0);
    final ease = 1 - pow(1 - p, 3).toDouble(); // 처음엔 빠르고 끝에서 느려진다
    final left = 1 - ease;
    final hop = (sin(p * pi * 2.5).abs() * pow(1 - p, 1.5)).toDouble().clamp(0.0, 1.0); // 튀어 오른 높이 (0~1)
    final from = Offset((width / 2 - slotX) * 0.85 + t.side * die, t.depth * die);
    final scale = 1 + 0.32 * hop;
    return Transform.translate(
      offset: from * left + Offset(0, 8 - hop * die * 0.45),
      child: Transform.scale(
        scale: scale,
        child: CustomPaint(
          size: Size.square(die),
          painter: YachtCubePainter(value: widget.target[i], ax: t.spinX * left, ay: t.spinY * left, az: t.spinZ * left, lift: hop, daesung: i == widget.daesungIndex),
        ),
      ),
    );
  }
}
