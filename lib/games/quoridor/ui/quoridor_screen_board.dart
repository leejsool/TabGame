part of 'quoridor_screen.dart';

/// board 조각 (화면 코드를 역할별로 나눈 파일)
extension _QdBoard on _QuoridorScreenState {
  Widget _scaffold() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF2E2128), Color(0xFF241A20)] : const [Color(0xFFF8E9EF), Color(0xFFEBD0DC)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.2;
              return Column(
                children: [
                  _topBar(),
                  Expanded(child: landscape ? _landscape() : _portrait()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 판과, 각자 앞에 쌓인 나무막대 더미. 막대를 판으로 끌어다 놓으면 가장 가까운 격자점에 붙고, 놓아 둔 막대 위의 돌리기·체크 아이콘으로 확정한다.
  /// 더미 자리: 아래 = 0번, 2명이면 위 = 1번, 4명이면 왼쪽 = 1번, 위 = 2번, 오른쪽 = 3번 (말이 시작하는 자리와 같다).
  Widget _boardArea() => Padding(
        padding: const EdgeInsets.all(10),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              const t = 52.0; // 더미 한 줄의 두께
              final four = c.players == 4;
              final side = max(80.0, min(box.maxWidth - (four ? 2 * t : 0), box.maxHeight - 2 * t));

              Widget stock(int seat, {required bool vertical}) => QWallStock(
                    key: ValueKey('wall-stock-$seat'),
                    seat: seat,
                    count: c.state.wallsLeft[seat],
                    boardSide: side,
                    vertical: vertical,
                    active: c.humanCanAct && c.turn == seat && c.state.wallsLeft[seat] > 0,
                    orient: c.wallOrientPick,
                  );

              final board = SizedBox(
                width: side,
                height: side,
                child: QBoardView(
                  state: c.state,
                  targets: c.targets,
                  lastMove: c.lastMove,
                  animate: true,
                  moveCount: c.moveCount,
                  lastMover: c.lastMover,
                  wallMode: c.wallMode,
                  wallOrient: c.wallOrientPick,
                  pickRow: c.wallRowPick,
                  pickCol: c.wallColPick,
                  pickOk: c.canConfirmWall,
                  // 칸을 누르면 말이 움직인다 (막대를 놓아 둔 채로 누르면 막대를 거둔다)
                  onCell: (cell) => c.wallMode ? c.cancelWall() : c.tapCell(cell),
                  onAnchor: c.pickWall,
                  onWallDrop: c.humanCanAct ? c.placeWall : null,
                  onWallCancel: c.cancelWall,
                  onRotate: c.toggleWallOrient,
                  onConfirm: c.confirmWall,
                  onCancel: c.cancelWall,
                  confirmEnabled: c.canConfirmWall,
                ),
              );
              final bottom = stock(0, vertical: false);
              final top = stock(four ? 2 : 1, vertical: false);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: t, child: Center(child: top)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (four) SizedBox(width: t, height: side, child: Center(child: stock(1, vertical: true))),
                      board,
                      if (four) SizedBox(width: t, height: side, child: Center(child: stock(3, vertical: true))),
                    ],
                  ),
                  SizedBox(height: t, child: Center(child: bottom)),
                ],
              );
            },
          ),
        ),
      );

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _boardArea()),
          _panel(),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _boardArea()),
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _playerChips(),
                  _statusBanner(),
                  const SizedBox(height: 8),
                  _panel(),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _topBar() => VsTopBar(title: '쿼리도', gameId: 'quoridor', onRules: () => showQuoridorRules(context));

  /// 사람마다 칩: 이름과 남은 벽 수. 지금 차례인 사람이 강조된다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int seat) {
          final active = !c.isOver && !c.halted && c.turn == seat;
          final win = c.isOver && c.state.winner == seat;
          final color = kPawnColors[seat];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active || win ? 0.2 : 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active || win ? 1 : 0.3), width: active || win ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_name(seat), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                const SizedBox(width: 8),
                Icon(Icons.horizontal_rule_rounded, size: 16, color: color.withValues(alpha: 0.9)),
                Text('${c.state.wallsLeft[seat]}', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
          child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [for (var i = 0; i < c.players; i++) chip(i)]),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final color = c.isOver || c.halted ? Colors.grey : kPawnColors[c.turn];
        final problem = _wallProblem;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (problem != null) Text(problem, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  /// 아래 칸: 진행 중에는 조작 안내 글, 끝나면 결과.
  Widget _panel() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isOver) return _resultPanel();
        return _controls();
      },
    );
  }

  /// 안내 글: 말은 점이 찍힌 칸을 누르고, 벽은 내 앞의 나무막대를 끌어다 놓는다.
  Widget _controls() {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (c.wallMode && c.humanCanAct) {
      text = '막대의 돌리기로 방향을 바꾸고, 체크(✓)로 세워요. 막대를 끌어서 옮기거나 판 밖으로 끌면 취소돼요';
    } else if (c.humanCanAct && c.state.wallsLeft[c.turn] > 0) {
      text = '벽을 세우려면 내 앞의 나무막대를 판으로 끌어다 놓으세요';
    } else {
      text = '가장 먼저 맞은편 줄에 닿으면 이겨요';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.3, color: scheme.onSurface.withValues(alpha: 0.7))),
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (!c.online) ...[
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canUndo ? c.undo : null,
                icon: const Icon(Icons.undo_rounded, size: 20),
                label: const Text('되돌리기'),
              ),
              OutlinedButton.icon(
                style: compact,
                onPressed: _newGameNow,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('새 판'),
              ),
            ],
            if (c.oneSeat || c.players == 2)
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canResign ? _resign : null,
                icon: const Icon(Icons.flag_outlined, size: 20),
                label: const Text('기권'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: kPawnColors[s.winner!]),
              const SizedBox(width: 8),
              Text('${_name(s.winner!)} 승리 · ${c.moveCount}수', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.online
                    ? (_rematchAsked || _opponentGone ? null : _requestRematch)
                    : () {
                        _resultHandled = false;
                        c.restart(rotate: c.oneSeat);
                      },
                child: Text(!c.online
                    ? '한 판 더'
                    : _opponentGone
                        ? '상대가 나갔어요'
                        : _rematchAsked
                            ? '상대를 기다려요…'
                            : _rematchOffered
                                ? '한 판 더 (상대가 원해요)'
                                : '한 판 더'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
