part of 'rummikub_screen.dart';

/// hand 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkHand on _RummikubScreenState {
  Widget _bottomPanel(double tileWidth, double width, {int maxRows = 2}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rack(tileWidth, width, maxRows),
            if (c.isOver) _resultPanel() else _actions(),
          ],
        );
      },
    );
  }

  /// 내 손: 타일을 끌어서 마음대로 순서를 바꿀 수 있다 (다른 타일 앞에 놓으면 그 앞에 끼고, 빈 곳에 놓으면 맨 뒤로 간다).
  /// 위의 정렬 단추는 한 번 색/숫자 순서로 가지런히 늘어놓아 주는 단추일 뿐이다.
  Widget _rack(double tileWidth, double width, int maxRows) {
    final tiles = c.rackTiles;
    const pad = 4.0, border = 2.0;
    final innerW = width - 2 * (_edge + pad + border);
    final plan = _rackPlan(tiles.length, innerW, tileWidth, maxRows);
    final th = tileWidth * 1.35, rowH = th + 3, lift = 6.0;
    final bodyH = lift + plan.rows * rowH;
    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (d) => c.canArrange,
      onAcceptWithDetails: (d) => c.moveInHand(d.data),
      builder: (context, candidate, _) => Padding(
        padding: const EdgeInsets.fromLTRB(_edge, 3, _edge, 3),
        child: TurnGlow(
          active: c.canAct && !c.isOver, // 내 차례에는 금빛 테두리가 돌면서 은은하게 빛난다
          child: Container(
            key: _rackAreaKey,
            padding: const EdgeInsets.fromLTRB(pad, 3, pad, 3),
            decoration: BoxDecoration(
              color:
                  (candidate.isNotEmpty
                          ? const Color(0xFFCFA668)
                          : const Color(0xFFC79A5B))
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kRkWood.withValues(alpha: 0.7),
                width: border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '내 타일 ${tiles.length}장',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _sortButton('색 정렬', () => c.sortHand(byColor: true)),
                    const SizedBox(width: 6),
                    _sortButton('숫자 정렬', () => c.sortHand(byColor: false)),
                  ],
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: c.canArrange && c.selected.isNotEmpty
                      ? () => c.moveInHand(c.selected.toList())
                      : null,
                  child: SizedBox(
                    height: bodyH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < tiles.length; i++)
                          Positioned(
                            key: ValueKey('slot${tiles[i]}'),
                            left: (i % plan.perRow) * plan.step,
                            top: lift + (i ~/ plan.perRow) * rowH,
                            child: DragTarget<List<int>>(
                              onWillAcceptWithDetails: (d) =>
                                  c.canArrange && !d.data.contains(tiles[i]),
                              onAcceptWithDetails: (d) =>
                                  c.moveInHand(d.data, beforeId: tiles[i]),
                              builder: (context, cand, _) => Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 방금 뽑은 타일은 바닥에서 날아오는 동안 숨겨 둔다
                                  Opacity(
                                    key: ValueKey('hand${tiles[i]}'),
                                    opacity: tiles[i] == _hiddenTile ? 0 : 1,
                                    child: KeyedSubtree(
                                      key: _tileKey(tiles[i]),
                                      child: _tile(tiles[i], tileWidth),
                                    ),
                                  ),
                                  if (cand.isNotEmpty)
                                    Positioned(
                                      left: -2,
                                      top: 0,
                                      bottom: 0,
                                      width: 3,
                                      child: ColoredBox(
                                        color: kRkWood.withValues(alpha: 0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRkWood.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: kRkWood,
          ),
        ),
      ),
    );
  }

  /// 맨 아래 단추들: 글자가 두 줄로 꺾여 자리를 먹지 않도록 아이콘으로만 만들고, 이름은 길게 누르면 뜨는 설명으로 알려 준다.
  Widget _actions() {
    final modified = c.canAct && (c.changed || !_sameAsTable());
    final style = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      minimumSize: const Size(44, 38),
    );
    Widget icon(IconData data, String tip, VoidCallback? onTap) =>
        IconButton.outlined(
          style: style,
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(data, size: 22),
        );
    // 설명은 단추 위에 띄운다 (아래로 띄우면 안드로이드 내비게이션 바에 가려진다)
    return TooltipTheme(
      data: const TooltipThemeData(preferBelow: false, verticalOffset: 26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_edge, 0, _edge, 3),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (c.canAct &&
                c.selected.isNotEmpty &&
                c.selected.any(c.placed.contains))
              icon(
                Icons.south_west_rounded,
                '손으로',
                () => c.returnToHand(c.selected.toList()),
              ),
            // 늘 보이되, 묶음을 못 이룬 타일이 없으면 흐리게 눌리지 않는다 (뜻은 튜토리얼에서 알려 준다)
            icon(
              Icons.rule_rounded,
              '미완성 타일만 손으로 (맞게 만든 묶음은 그대로)',
              c.wrongTiles.isNotEmpty ? c.returnWrongToHand : null,
            ),
            icon(Icons.undo_rounded, '되돌리기', c.canUndoStep ? c.undoStep : null),
            icon(
              Icons.restart_alt_rounded,
              '처음으로',
              c.canAct && modified ? c.reset : null,
            ),
            icon(
              Icons.auto_fix_high_rounded,
              '정리 (묶음은 그대로, 자리만 가지런히)',
              c.canAct && c.work.isNotEmpty ? c.tidySets : null,
            ),
            // 바닥이 비면 뽑을 타일이 없으니 넘기기만 한다 (바닥에 타일이 있으면 그중 한 장을 직접 골라 뽑는다)
            if (c.state.poolCount == 0)
              icon(Icons.skip_next_rounded, '넘기기', c.canAct ? c.draw : null),
            IconButton.filled(
              tooltip: '끝내기',
              onPressed: c.canAct ? _endTurn : null,
              icon: const Icon(Icons.check_rounded, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: kRkWood,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(52, 38),
              ),
            ),
            icon(Icons.flag_outlined, '기권', c.canResign ? _resign : null),
          ],
        ),
      ),
    );
  }

  /// 판이 처음과 같은 모습인가 (옮기기만 하고 도로 돌려놓았을 때 "처음으로"를 막으려고).
  bool _sameAsTable() {
    String key(List<int> s) => ([...s]..sort()).join(',');
    final a = [for (final s in c.work) key(s)]..sort();
    final b = [for (final s in c.state.table) key(s)]..sort();
    return a.join('|') == b.join('|');
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(_edge, 0, _edge, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var p = 0; p < c.players; p++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    s.winner == p
                        ? Icons.emoji_events_rounded
                        : Icons.person_rounded,
                    size: 18,
                    color: s.winner == p ? const Color(0xFFF2A900) : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _name(p),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    s.racks[p].isEmpty
                        ? '손이 비었어요'
                        : '남은 타일 ${s.racks[p].length}장 · 벌점 ${s.rackPoints(p)}점',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('메뉴로'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.online
                    ? (_rematchAsked || _opponentGone ? null : _requestRematch)
                    : () {
                        _resultHandled = false;
                        c.restart();
                      },
                child: Text(
                  !c.online
                      ? '한 판 더'
                      : _opponentGone
                      ? '상대가 나갔어요'
                      : _rematchAsked
                      ? '상대를 기다려요…'
                      : _rematchOffered
                      ? '한 판 더 (상대가 원해요)'
                      : '한 판 더',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
