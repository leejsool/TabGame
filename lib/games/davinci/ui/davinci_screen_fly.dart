part of 'davinci_screen.dart';

/// fly 조각 (화면 코드를 역할별로 나눈 파일)
extension _DvFly on _DavinciScreenState {
  GlobalKey _pileKey(int color) => _pileKeys.putIfAbsent(color, GlobalKey.new);

  GlobalKey _tileKey(int id) => _tileKeys.putIfAbsent(id, GlobalKey.new);

  GlobalKey _rowKey(int seat) => _rowKeys.putIfAbsent(seat, GlobalKey.new);

  Offset? _globalCenter(GlobalKey? key) {
    final rb = key?.currentContext?.findRenderObject();
    if (rb is! RenderBox || !rb.attached || !rb.hasSize) return null;
    return rb.localToGlobal(rb.size.center(Offset.zero));
  }

  bool get _hovering => _hover != null && _hoverTile != null && c.state.phase == DvPhase.placeJoker && c.turn == c.humanSeat;

  /// [tile]이 더미에서 [seat]의 손패 한가운데로 날아갔다가 자기 자리를 찾아간다. (조커든 아니든 똑같이 움직인다)
  /// 아직 줄에 없는 타일(내가 뽑은 조커)은 한가운데에 떠서 자리를 정하기를 기다린다.
  /// 줄에 이미 들어 있는 타일은 도착할 때까지 숨겨 둔다.
  void _flyDraw({required int? tile, required int seat, required Offset? from, required Duration duration}) {
    if (tile == null || from == null) return;
    final inRow = c.state.rows[seat].contains(tile);
    if (!inRow && seat != c.humanSeat) return; // 남의 줄에 없는 타일은 보여 주지 않는다 (조커는 자리를 정한 뒤에야 보인다)
    if (inRow) _hiddenTile = tile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = seat == c.humanSeat;
      final width = me ? 44.0 : 38.0;
      final row = c.state.rows[seat];
      final rowCenter = _globalCenter(_rowKeys[seat]);
      final mid = row.isEmpty ? null : _globalCenter(_tileKeys[row[row.length ~/ 2]]);
      final center = rowCenter == null ? null : Offset(rowCenter.dx, (mid?.dy ?? rowCenter.dy) - width * 0.7);
      final to = inRow ? _globalCenter(_tileKeys[tile]) : null;
      final stack = _stackKey.currentContext?.findRenderObject();
      void arrive() {
        if (mounted && _hiddenTile == tile) _update(() => _hiddenTile = null);
      }

      if (center == null || stack is! RenderBox || (inRow && to == null)) {
        arrive();
        return;
      }
      _update(() {
        _fly = _Fly(
          from: stack.globalToLocal(from),
          via: stack.globalToLocal(center),
          to: to == null ? null : stack.globalToLocal(to),
          tile: tile,
          faceUp: me,
          width: width,
          duration: inRow ? duration : duration * 0.55,
          serial: ++_flySerial,
          onEnd: arrive,
        );
      });
    });
  }

  /// 상대(CPU·다른 기기)가 뽑으면 그 더미에서 상대 손패 한가운데로, 그리고 제 자리로 타일이 날아간다.
  void _maybeFlyOpponentDraw() {
    final e = c.effect;
    if (e == null || e.kind != 0 || identical(e, _flownEffect)) return;
    _flownEffect = e;
    _flyDraw(tile: e.tile, seat: e.actor, from: _globalCenter(_pileKeys[e.number ?? 0]), duration: c.cpuStepDelay * 1.1);
  }

  Widget _flyOverlay() {
    final f = _fly!;
    return TweenAnimationBuilder<double>(
      key: ValueKey('fly${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: f.duration,
      onEnd: () {
        if (!mounted) return;
        _update(() {
          if (_fly?.serial == f.serial) {
            _fly = null;
            if (f.to == null && f.via != null) {
              _hover = f.via;
              _hoverTile = f.tile;
            }
          }
        });
        f.onEnd();
      },
      builder: (context, t, _) {
        final p = f.at(t);
        final w = f.width * (1 + 0.3 * p.pop);
        return Positioned(
          key: const ValueKey('fly'),
          left: p.pos.dx - w / 2,
          top: p.pos.dy - p.lift - w * 1.4 / 2,
          child: IgnorePointer(child: DvTile(id: f.tile, width: w, faceUp: f.faceUp)),
        );
      },
    );
  }

  /// 내가 뽑은 조커가 손패 한가운데 떠서 자리를 기다린다.
  Widget _hoverOverlay() {
    const w = 44.0;
    return Positioned(
      key: const ValueKey('hover'),
      left: _hover!.dx - w / 2,
      top: _hover!.dy - w * 1.4 / 2,
      child: IgnorePointer(child: DvTile(id: _hoverTile!, width: w, faceUp: true)),
    );
  }

  /// 내가 더미에서 뽑는다 (뽑은 타일이 더미에서 내 손패 한가운데로 날아온 뒤 자리를 찾아간다. 조커는 자리를 정할 때까지 떠 있다).
  void _drawFromPile(int color) {
    final from = _globalCenter(_pileKeys[color]);
    if (!c.draw(color) || !c.animate) return;
    _flyDraw(tile: c.state.pendingJoker ?? c.state.drawn, seat: c.humanSeat, from: from, duration: const Duration(milliseconds: 1100));
    if (_hiddenTile != null) _update(() {});
  }

  /// 뽑은 조커를 [pos]번째 칸에 놓는다 (떠 있던 조커가 그 자리로 날아간다).
  void _placeJoker(int pos) {
    final tile = c.state.pendingJoker;
    final from = _hover;
    if (!c.placeJoker(pos)) return;
    _hover = null;
    _hoverTile = null;
    if (!c.animate || tile == null || from == null) {
      _update(() {});
      return;
    }
    _hiddenTile = tile;
    _update(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final to = _globalCenter(_tileKeys[tile]);
      final stack = _stackKey.currentContext?.findRenderObject();
      void arrive() {
        if (mounted && _hiddenTile == tile) _update(() => _hiddenTile = null);
      }

      if (to == null || stack is! RenderBox) {
        arrive();
        return;
      }
      _update(() {
        _fly = _Fly(from: from, to: stack.globalToLocal(to), tile: tile, faceUp: true, width: 44, duration: const Duration(milliseconds: 500), serial: ++_flySerial, onEnd: arrive);
      });
    });
  }

  bool get _rematchAsked => _againSeats.contains(c.humanSeat);

  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);
}
