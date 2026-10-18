part of 'rummikub_screen.dart';

/// fly 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkFly on _RummikubScreenState {
  GlobalKey _tileKey(int id) => _tileKeys.putIfAbsent(id, GlobalKey.new);

  GlobalKey _floorKey(int id) => _floorKeys.putIfAbsent(id, GlobalKey.new);

  GlobalKey _chipKey(int seat) => _chipKeys.putIfAbsent(seat, GlobalKey.new);

  Offset? _globalCenter(GlobalKey? key) {
    final rb = key?.currentContext?.findRenderObject();
    if (rb is! RenderBox || !rb.attached || !rb.hasSize) return null;
    return rb.localToGlobal(rb.size.center(Offset.zero));
  }

  void _startFly({required Offset fromGlobal, required Offset toGlobal, required double width, required Duration duration, VoidCallback? onEnd}) {
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !mounted) {
      onEnd?.call();
      return;
    }
    _update(() {
      _fly = _Fly(
        from: stack.globalToLocal(fromGlobal),
        to: stack.globalToLocal(toGlobal),
        width: width,
        duration: duration,
        serial: ++_flySerial,
        onEnd: onEnd,
      );
    });
  }

  /// 날아가는 타일 한 장: 바닥에서 도착 자리까지 살짝 위로 휘어서 날아간다.
  Widget _flyOverlay() {
    final f = _fly!;
    return TweenAnimationBuilder<double>(
      key: ValueKey('fly${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: f.duration,
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (!mounted) return;
        _update(() {
          if (_fly?.serial == f.serial) _fly = null;
        });
        f.onEnd?.call();
      },
      builder: (context, t, _) {
        final pos = Offset.lerp(f.from, f.to, t)! - Offset(0, sin(pi * t) * 36);
        final w = f.width * (1 + 0.35 * sin(pi * t));
        return Positioned(
          key: const ValueKey('fly'),
          left: pos.dx - w / 2,
          top: pos.dy - w * 1.35 / 2,
          child: IgnorePointer(child: RkTileBack(width: w, glow: true)),
        );
      },
    );
  }

  /// 상대가 바닥에서 타일을 고르면, 그 타일이 상대 표시 쪽으로 날아간다.
  void _maybeFlyOpponentPick() {
    final pick = c.opponentPick;
    if (pick == null) {
      _flownPick = null;
      return;
    }
    if (_flownPick == pick) return;
    _flownPick = pick;
    final seat = c.turn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final from = _globalCenter(_floorKeys[pick]);
      final to = _globalCenter(_chipKeys[seat]);
      if (from == null || to == null) return;
      _startFly(fromGlobal: from, toGlobal: to, width: 22, duration: c.stepDelay * 1.1);
    });
  }
}
