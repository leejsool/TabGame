part of 'rummikub_controller.dart';

/// fix 조각: 잘못 맞춘 묶음 고쳐 주기 (끝낼 때 알아서 쪼개기, 잘못 내려놓은 타일만 손으로)
extension RummikubControllerFix on RummikubController {
  /// 끝내기 전에: 올바르지 않은 묶음을 쪼개서 모두 올바르게 되면 그렇게 고친다. 예: 1-2-3-5-6-7 → 1-2-3 과 5-6-7.
  /// 쪼갠 뒤에도 내놓을 수 없는 판이면 아무것도 바꾸지 않는다. 고쳤으면 true.
  bool _autoSplit() {
    final next = <List<int>>[];
    final fresh = <int>[];
    final firstMeld = !state.melded[turn];
    for (final set in work) {
      final melds = (firstMeld ? _keepOldSets(set) : null) ?? (analyzeMeld(set) == null ? splitIntoMelds(set)?.melds : null);
      if (melds == null) {
        next.add(set);
        continue;
      }
      next.addAll(melds);
      for (final m in melds.skip(1)) {
        fresh.addAll(m);
      }
    }
    if (fresh.isEmpty || state.checkPlay(next) != null) return false;
    work = next;
    _forgetAnchors(fresh);
    _recent.clear();
    selected.clear();
    return true;
  }

  /// 처음 내려놓는 차례에 판에 있던 묶음 옆에 내 타일을 붙여 놓았을 때 (예: 10-11-12 옆에 7-8-9):
  /// 원래 묶음은 그대로 두고 내 타일끼리만으로 올바른 묶음이 되면 그렇게 갈라 준다 (남의 타일을 쓴 것이 아니니 인정한다).
  /// 가를 것이 없거나 내 타일끼리 묶음이 안 되면 null.
  List<List<int>>? _keepOldSets(List<int> set) {
    final olds = [for (final s in state.table) if (s.isNotEmpty && s.every(set.contains)) s];
    if (olds.isEmpty) return null;
    final kept = {for (final s in olds) ...s};
    final mine = [for (final t in set) if (!kept.contains(t)) t];
    if (mine.isEmpty) return null; // (손대지 않은 묶음)
    final onTable = state.tableTiles.toSet();
    if (mine.any(onTable.contains)) return null; // (다른 묶음에서 떼어 온 타일이 섞였다)
    final melds = analyzeMeld(mine) != null ? [mine] : splitIntoMelds(mine)?.melds;
    if (melds == null) return null;
    return [for (final s in olds) [...s], ...melds];
  }

  /// 새로 갈라져 나온 묶음의 타일은 자리를 지우고, 판이 빈자리를 찾아 놓게 한다 (원래 묶음의 자리에 겹쳐 놓이지 않도록).
  void _forgetAnchors(Iterable<int> tiles) {
    for (final t in tiles) {
      anchors.remove(t);
    }
  }

  /// 잘못 놓인 타일을 가려낸 결과: 고친 판([sets]), 손으로 돌아갈 타일([back]), 새로 갈라진 묶음의 타일([fresh]).
  ///
  /// 올바르지 않은 묶음마다, 이번 차례에 내려놓은 타일을 빼면 나머지가 올바른 묶음들이 되는 가장 작은 빼기를 찾는다.
  /// (그렇게 안 되면 그 묶음에서 이번 차례에 내려놓은 타일을 모두 뺀다.) 이미 올바른 묶음에 든 타일은 건드리지 않는다.
  ({List<List<int>> sets, List<int> back, List<int> fresh}) _wrongPlan() {
    final p = placed;
    final sets = <List<int>>[], back = <int>[], fresh = <int>[];
    for (final set in work) {
      if (analyzeMeld(set) != null || !set.any(p.contains)) {
        sets.add(set);
        continue;
      }
      final mine = {for (final t in set) if (p.contains(t)) t};
      final plan = splitIntoMelds(set, removable: mine);
      if (plan == null) {
        back.addAll(mine);
        final rest = [for (final t in set) if (!mine.contains(t)) t];
        if (rest.isNotEmpty) sets.add(rest);
        continue;
      }
      sets.addAll(plan.melds);
      back.addAll(plan.leftover);
      for (final m in plan.melds.skip(1)) {
        fresh.addAll(m);
      }
    }
    return (sets: sets, back: back, fresh: fresh);
  }

  /// 이번 차례에 내려놓았지만 올바른 묶음을 이루지 못한 타일들 ("잘못 놓은 타일만 손으로" 단추가 되돌릴 것).
  List<int> get wrongTiles => canAct ? _wrongPlan().back : const [];

  /// 잘못 내려놓은 타일만 손으로 되돌린다. 이미 올바른 묶음을 이룬 타일은 그대로 둔다.
  void returnWrongToHand() {
    if (!canAct) return;
    final plan = _wrongPlan();
    if (plan.back.isEmpty) {
      onFeedback?.call('bad');
      return;
    }
    _remember();
    work = plan.sets;
    _forgetAnchors(plan.fresh);
    _recent.clear();
    selected.clear();
    notice = null;
    onFeedback?.call('place');
    _notify();
  }
}
