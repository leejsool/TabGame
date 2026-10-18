part of 'rummikub_controller.dart';

/// history 조각 (화면 코드를 역할별로 나눈 파일)
extension RummikubControllerHistory on RummikubController {
  bool get canUndoStep => canAct && _undo.isNotEmpty;

  void _remember() {
    _undo.add((work: [for (final s in work) [...s]], hand: [...hand], anchors: {...anchors}));
    if (_undo.length > 60) _undo.removeAt(0);
  }

  /// 방금 한 것(타일 옮기기·묶음 합치기 …) 하나를 되돌린다.
  void undoStep() {
    if (!canUndoStep) return;
    final prev = _undo.removeLast();
    work = prev.work;
    hand
      ..clear()
      ..addAll(prev.hand);
    anchors
      ..clear()
      ..addAll(prev.anchors);
    _recent.clear();
    selected.clear();
    notice = null;
    _notify();
  }

  /// 끌어 온 타일들 [ids]를 [topLeft](타일 칸 단위, 끌어 온 타일들의 왼쪽 위)에 놓으면 붙게 될 묶음 (없으면 null).
  ///
  /// 자석은 아주 좁게 걸린다: 낱개 한 장은 묶음에 거의 닿았을 때(틈 [singleMagnet]칸 이내), 여러 장이나 묶음 통째로 끌 때는 서로 겹쳐질 때만
  /// 붙는다. 빈 땅에 놓은 것이 가까운 묶음에 달라붙어 새 묶음을 만들 수 없는 일이 없도록 하려는 것이다.
  List<int>? dropTargetFor(Iterable<int> ids, Offset topLeft, {double singleMagnet = 0.12, double groupMagnet = 0.0}) {
    final moving = ids.toSet();
    if (moving.isEmpty) return null;
    final starts = layoutSets(layoutWidth, layoutPerRow);
    final want = _groupRect(topLeft, moving.length);
    final magnet = moving.length > 1 ? groupMagnet : singleMagnet;
    List<int>? near;
    var nearGap = double.infinity;
    for (var i = 0; i < work.length; i++) {
      final set = work[i];
      // 끌어 온 타일로만 이루어진 묶음은 어차피 비게 되니 붙을 대상이 아니다
      if (set.every(moving.contains)) continue;
      final gap = rectGap(want, setRect(starts[i], set.length, layoutPerRow));
      if (gap < nearGap) {
        nearGap = gap;
        near = set;
      }
    }
    return near != null && nearGap <= magnet ? near : null;
  }

  /// 끌어 온 타일들이 차지하는 상자 (타일 칸 단위). 묶음의 여백은 넣지 않고 타일만 센다.
  Rect _groupRect(Offset topLeft, int count) {
    final cols = min(count, layoutPerRow);
    final rows = (count / layoutPerRow).ceil();
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, cols.toDouble(), rows - 0.12);
  }

  /// 끌어 온 타일들 [ids]를 판 위 [topLeft]에 놓는다.
  /// 가까이(위의 자석 거리 안) 다른 묶음이 있으면 그 묶음에 붙고, 아니면 낱개 한 장이라도 그 자리에 새 묶음으로 놓인다.
  void dropTiles(Iterable<int> ids, Offset topLeft, {double? magnet}) {
    if (!canAct) return;
    final moving = ids.toSet();
    if (moving.isEmpty) return;
    final near = magnet == null
        ? dropTargetFor(moving, topLeft)
        : dropTargetFor(moving, topLeft, singleMagnet: magnet, groupMagnet: magnet);
    if (near != null) {
      moveTiles(moving, to: near);
      return;
    }
    // 새 묶음: 끌어 온 타일이 빠져나갈 묶음의 자리는 비는 것으로 보고 빈자리를 찾는다
    final starts = layoutSets(layoutWidth, layoutPerRow);
    final others = <Rect>[
      for (var i = 0; i < work.length; i++)
        if (!work[i].every(moving.contains)) setRect(starts[i], work[i].length, layoutPerRow),
    ];
    final size = setRect(Offset.zero, moving.length, layoutPerRow);
    final spot = snapToFree(others, size, layoutWidth, topLeft);
    moveTiles(moving, at: spot);
  }

  /// 타일 [id]를 눌러 고르거나 고름을 푼다.
  void toggleSelect(int id) {
    if (!canAct && !(canArrange && hand.contains(id))) return; // (상대 차례에는 내 손의 타일만 고를 수 있다)
    if (!selected.remove(id)) selected.add(id);
    _notify();
  }

  void clearSelection() {
    if (selected.isEmpty) return;
    selected.clear();
    _notify();
  }

  /// 고른 타일 [ids]를 묶음 [to]로 옮긴다 ([to]가 null이면 새 묶음). 판 위에 원래 있던 타일은 손으로 못 돌아온다.
  void moveTiles(Iterable<int> ids, {List<int>? to, Offset? at}) {
    if (!canAct) return;
    final moving = ids.toSet();
    if (moving.isEmpty) return;
    _remember();
    final inHand = rackTiles.toSet();
    final onWork = {for (final s in work) ...s};
    if (!moving.every((t) => inHand.contains(t) || onWork.contains(t))) return;
    // 이미 그 묶음에 있는 타일만이면 할 일이 없다.
    if (to != null && moving.every(to.contains)) {
      selected.clear();
      _notify();
      return;
    }
    for (final s in work) {
      s.removeWhere(moving.contains);
    }
    final order = [for (final t in hand) if (moving.contains(t)) t];
    for (final t in moving) {
      if (!order.contains(t)) order.add(t);
    }
    if (to != null && work.any((s) => identical(s, to))) {
      final a = anchorOf(to);
      to.addAll(order);
      if (a != null) _setAnchor(order, a); // 붙은 타일은 그 묶음의 자리를 따른다
    } else {
      work.add([...order]);
      if (at != null) _setAnchor(order, at);
    }
    work.removeWhere((s) => s.isEmpty);
    _recent
      ..clear()
      ..addAll(order);
    for (final s in work) {
      if (s.any(order.contains)) _recent.addAll(s);
    }
    selected.clear();
    notice = null;
    onFeedback?.call('place');
    _notify();
  }

  /// 이번 차례에 판에 올린 타일 [ids]를 다시 손으로 가져온다 (원래 판 위에 있던 타일은 못 가져온다).
  void returnToHand(Iterable<int> ids) {
    if (!canAct) return;
    final p = placed;
    final back = ids.where(p.contains).toSet();
    if (back.isEmpty) {
      onFeedback?.call('bad');
      return;
    }
    _remember();
    for (final s in work) {
      s.removeWhere(back.contains);
    }
    work.removeWhere((s) => s.isEmpty);
    selected.clear();
    onFeedback?.call('place');
    _notify();
  }

  /// 이번 차례에 만진 것을 모두 처음으로 되돌린다.
  void reset() {
    if (!canAct) return;
    _undo.clear();
    work = _copyTable();
    selected.clear();
    notice = null;
    _notify();
  }
}
