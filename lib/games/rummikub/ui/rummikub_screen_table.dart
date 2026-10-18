part of 'rummikub_screen.dart';

/// table 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkTable on _RummikubScreenState {
  /// 끌어 온 타일이 고른 타일이면 고른 것 전부를, 아니면 그 한 장만.
  List<int> _dragged(int id) => c.selected.contains(id) ? c.selected.toList() : [id];

  /// 끌고 있는 타일들의 모습 (손가락 밑에 가운데가 오게 한다).
  Widget _dragFeedback(List<int> ids, double width) {
    final shown = ids.length > 8 ? ids.sublist(0, 8) : ids;
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final t in shown) RkTile(id: t, width: width)],
      ),
    );
  }

  Widget _draggable({required List<int> data, required double width, required Widget child, Widget? whileDragging, bool fromTable = false}) {
    // 손의 타일은 상대 차례에도 끌어서 정리할 수 있고, 판 위의 타일은 내 차례에만 끌 수 있다
    if (!(fromTable ? c.canAct : c.canArrange)) return child;
    final shown = data.length > 8 ? 8 : data.length;
    final fw = shown * width, fh = width * 1.35;
    return Draggable<List<int>>(
      data: data,
      dragAnchorStrategy: (draggable, context, position) => Offset(fw / 2, fh / 2),
      feedback: _dragFeedback(data, width),
      childWhenDragging: whileDragging ?? Opacity(opacity: 0.5, child: child),
      child: child,
    );
  }

  /// 손이나 판 위의 타일 한 장: 누르면 고르고, 끌어서 옮길 수 있다.
  ///
  /// 판 위 타일을 여러 장 그릴 때는 [placed](이번 차례에 올린 타일들)와 [setIds](이 타일이 든 묶음을 보기 좋게 늘어놓은 순서)를
  /// 미리 구해서 넘긴다 (타일마다 다시 구하면 판이 클수록 느려진다).
  Widget _tile(int id, double width, {bool fromTable = false, Set<int>? placed, List<int>? setIds}) {
    final selected = c.selected.contains(id);
    final tile = RkTile(
      id: id,
      width: width,
      selected: selected,
      glow: (fromTable && (placed ?? c.placed).contains(id)) || (!fromTable && id == c.lastDrawn),
      onTap: (fromTable ? c.canAct : c.canArrange) ? () => c.toggleSelect(id) : null,
    );
    final single = _draggable(data: _dragged(id), width: width, child: tile, fromTable: fromTable);
    if (!fromTable || !c.canAct) return Opacity(opacity: fromTable && _setDrag.contains(id) ? 0.35 : 1, child: single);
    // 판 위 타일: 그냥 끌면 낱개 한 장, 꾹 눌렀다가 끌면 그 묶음 통째로 옮긴다
    final ids = setIds ?? arrangeSet(c.work.firstWhere((x) => x.contains(id), orElse: () => [id]));
    final shown = ids.length > 8 ? 8 : ids.length;
    final fw = shown * width, fh = width * 1.35;
    return Opacity(
      opacity: _setDrag.contains(id) ? 0.35 : 1,
      child: LongPressDraggable<List<int>>(
        data: ids,
        delay: const Duration(milliseconds: 350),
        dragAnchorStrategy: (d, ctx, pos) => Offset(fw / 2, fh / 2),
        feedback: _dragFeedback(ids, width),
        childWhenDragging: const SizedBox.shrink(),
        onDragStarted: () => _update(() => _setDrag = ids.toSet()),
        onDragEnd: (_) => _update(() => _setDrag = {}),
        child: single,
      ),
    );
  }

  /// 녹색 판: 묶음을 어디에나 놓을 수 있는 넓은 판. 타일을 끌어다 놓으면 근처 묶음에 자석처럼 붙고, 멀면 그 자리에 새 묶음이 된다.
  /// 판 위 타일을 꾹 눌렀다가 끌면 묶음 통째로 옮긴다. 상대의 수는 타일이 한 장씩 날아와 놓이는 모습으로 보인다.
  Widget _tablePanel({required bool landscape}) {
    const pad = _tablePad;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(_edge, 3, _edge, 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6B4A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F4A33), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: LayoutBuilder(
          builder: (context, box) => ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final tileW = _tableTile(box.maxWidth - pad * 2, landscape: landscape);
              final tileH = tileW * 1.35;
              final ux = tileW, uy = tileH + kSetRowGap; // 묶음 안의 타일은 딱 붙이고, 줄 사이도 좁게
              final widthUnits = (box.maxWidth - pad * 2) / ux;
              final perRow = max(3, (widthUnits - kSetPad).floor());
              final spots = c.layoutSets(widthUnits, perRow);
              var bottom = 0.0;
              for (var i = 0; i < c.work.length; i++) {
                bottom = max(bottom, setRect(spots[i], c.work[i].length, perRow).bottom);
              }
              final canvasH = max(box.maxHeight, bottom * uy + uy * 1.5 + 8);
              final frames = <Widget>[];
              final tiles = <Widget>[];
              final placedNow = c.placed; // (타일마다 구하지 않고 한 번만)
              for (var i = 0; i < c.work.length; i++) {
                final set = c.work[i];
                final a = spots[i];
                final meld = analyzeMeld(set); // (묶음마다 한 번만 살핀다)
                final ids = meld?.order ?? ([...set]..sort(compareByNumber));
                final cols = min(ids.length, perRow), rows = (ids.length / perRow).ceil();
                final left = pad + a.dx * ux, top = 1 + a.dy * uy;
                final bad = meld == null && c.canAct;
                frames.add(AnimatedPositioned(
                  key: ValueKey('frame$i'),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  left: left,
                  top: top,
                  width: (cols + kSetPad) * ux,
                  height: rows * uy - 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: c.canAct && c.selected.isNotEmpty ? () => c.moveTiles(c.selected.toList(), to: set) : null,
                    // 색이 순간적으로 바뀌면 눈이 아프니, 테두리 색은 부드럽게 바뀌게 하고 올바르지 않은 묶음도 옅은 주황으로만 알려 준다
                    child: ValueListenableBuilder<List<int>?>(
                      valueListenable: _hoverTarget,
                      builder: (context, target, _) {
                        final hover = identical(target, set);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            // 평소에는 묶음 틀을 그리지 않는다 (타일만 보인다). 붙을 묶음(끌 때)과 올바르지 않은 묶음만 테두리로 알려 준다.
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hover ? const Color(0xFFFFE08A) : (bad ? const Color(0xFFE9B08A) : Colors.transparent),
                              width: hover ? 3 : 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ));
                for (var k = 0; k < ids.length; k++) {
                  final id = ids[k];
                  final dest = Offset(left + kSetPad / 2 * ux + (k % perRow) * ux, top + 1 + (k ~/ perRow) * uy);
                  final begin = c.flying.contains(id) ? Offset(box.maxWidth / 2 - tileW / 2, -tileH * 2) : dest;
                  tiles.add(TweenAnimationBuilder<Offset>(
                    key: ValueKey('tile$id'),
                    tween: Tween(begin: begin, end: dest),
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeInOutCubic,
                    builder: (context, pos, child) => Positioned(left: pos.dx, top: pos.dy, child: child!),
                    child: _tile(id, tileW, fromTable: true, placed: placedNow, setIds: ids),
                  ));
                }
              }
              final empty = c.work.isEmpty;
              Offset? unitsOf(Offset globalTopLeft) {
                final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (rb == null) return null;
                final local = rb.globalToLocal(globalTopLeft);
                return Offset((local.dx - pad) / ux, (local.dy - 1) / uy);
              }

              void preview(List<int>? target) {
                _hoverTarget.value = target;
              }

              return DragTarget<List<int>>(
                onWillAcceptWithDetails: (_) => c.canAct,
                onMove: (d) {
                  final u = unitsOf(d.offset);
                  preview(u == null ? null : c.dropTargetFor(d.data, u));
                },
                onLeave: (_) => preview(null),
                onAcceptWithDetails: (d) {
                  final u = unitsOf(d.offset);
                  preview(null);
                  if (u != null) c.dropTiles(d.data, u);
                },
                builder: (context, candidate, _) => Stack(
                  children: [
                    SingleChildScrollView(
                      child: SizedBox(
                        key: _canvasKey,
                        width: box.maxWidth,
                        height: canvasH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (candidate.isNotEmpty) Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.04))),
                            if (empty)
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    c.canAct ? '타일을 여기로 끌어다 놓으세요' : '아직 판 위에 아무것도 없어요',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                                  ),
                                ),
                              ),
                            ...frames,
                            ...tiles,
                          ],
                        ),
                      ),
                    ),
                    if (c.canAct && c.selected.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 8,
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('고른 타일로 새 묶음'),
                          onPressed: () => c.moveTiles(c.selected.toList()),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 바닥에 엎어 둔 타일들. 내 차례에 낼 수 없으면 이 중 한 장을 직접 골라 뽑는다.
  Widget _floorPool({required double height, required double tileW}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final pool = c.state.pool;
        final canPick = c.canAct && !c.isOver;
        final tileH = tileW * 1.35;
        final rowH = tileH + 8;
        return Container(
          height: rowH + 10,
          margin: const EdgeInsets.fromLTRB(_edge, 2, _edge, 2),
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          decoration: BoxDecoration(
            color: const Color(0xFF6B4A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4A3220).withValues(alpha: 0.7), width: 1.5),
          ),
          // 바닥 n장 + 엎어 둔 타일들을 한 줄에 (타일이 많으면 겹쳐 놓고, 그래도 넘치면 옆으로 밀어서 본다)
          child: Row(
            children: [
              Icon(Icons.layers_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text('바닥 ${pool.length}장', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final n = pool.length;
                    const minStep = 11.0;
                    final fit = n <= 1 ? tileW + 3 : (box.maxWidth - tileW - 4) / (n - 1);
                    final step = fit.clamp(minStep, tileW + 3).toDouble();
                    final width = n == 0 ? box.maxWidth : (n - 1) * step + tileW + 4;
                    final children = <Widget>[];
                    for (var i = 0; i < n; i++) {
                      var h = (pool[i] * 2654435761 + 40503) & 0x7fffffff;
                      h ^= h >> 13;
                      h = (h * 1274126177) & 0x7fffffff;
                      final dy = ((h & 1023) / 1023) * 4, ang = (((h >> 20) & 63) - 32) / 260;
                      children.add(Positioned(
                        key: ValueKey('floor${pool[i]}'),
                        left: i * step,
                        top: 1 + dy,
                        // 상대가 고른 타일은 상대 쪽으로 날아가니 바닥에서는 보이지 않게 한다
                        child: Opacity(
                          opacity: pool[i] == c.opponentPick ? 0 : 1,
                          child: Transform.rotate(
                            angle: ang,
                            child: KeyedSubtree(
                              key: _floorKey(pool[i]),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canPick ? () => _pickFloor(i) : null,
                                child: RkTileBack(width: tileW, active: canPick),
                              ),
                            ),
                          ),
                        ),
                      ));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: max(width, box.maxWidth), height: rowH, child: Stack(clipBehavior: Clip.none, children: children)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 끝내기: 안 되면 이유를 짧은 알림으로 보여 준다 (화면 자리를 쓰지 않으려고 글을 따로 두지 않는다).
  void _endTurn() {
    if (c.endTurn()) return;
    final msg = c.notice;
    if (msg == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2200), behavior: SnackBarBehavior.floating));
  }

  /// 바닥의 [index]번째 타일을 뽑는다. 판을 만져 둔 게 있으면 사라진다고 먼저 알려 준다.
  Future<void> _pickFloor(int index) async {
    if (!c.canAct) return;
    if (c.changed || !_sameAsTable()) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('타일을 뽑을까요?'),
          content: const Text('뽑으면 이번 차례가 끝나고, 지금 판에서 옮겨 둔 것은 모두 처음으로 돌아가요.', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 맞추기')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('뽑기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final id = c.state.pool[index];
    final from = _globalCenter(_floorKeys[id]);
    c.draw(index: index);
    final drawn = c.lastDrawn;
    if (!c.animate || drawn == null || from == null) return;
    // 뽑은 타일이 바닥에서 내 손으로 날아온다 (도착할 때까지 손의 그 타일은 숨겨 둔다)
    _update(() => _hiddenTile = drawn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final to = _globalCenter(_tileKeys[drawn]);
      if (!mounted) return;
      if (to == null) {
        _update(() => _hiddenTile = null);
        return;
      }
      _startFly(fromGlobal: from, toGlobal: to, width: 22, duration: const Duration(milliseconds: 650), onEnd: () {
        if (mounted) _update(() => _hiddenTile = null);
      });
    });
  }
}
