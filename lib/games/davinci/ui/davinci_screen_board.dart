part of 'davinci_screen.dart';

/// board 조각 (화면 코드를 역할별로 나눈 파일)
extension _DvBoard on _DavinciScreenState {
  Widget _scaffold() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF1F262B), Color(0xFF171C20)] : const [Color(0xFFE7ECEF), Color(0xFFD3DBE0)],
          ),
        ),
        child: SafeArea(
          // 태블릿에서는 폰 배치를 통째로 키워 화면을 채운다 (날아가는 타일도 함께 커진다)
          child: TabletScale(
            child: Stack(
              key: _stackKey,
              children: [
                Positioned.fill(child: _scaffoldBody()),
                if (_fly == null && _hovering) _hoverOverlay(),
                if (_fly != null) _flyOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaffoldBody() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // 4명이 폰으로 할 때 위아래로 밀지 않고 한눈에 보이도록, 높이가 모자라면 간격과 타일을 줄인다
              _dense = (c.players >= 4 && box.maxHeight < 900) || (c.players == 3 && box.maxHeight < 760);
              final gap = _dense ? 4.0 : 8.0;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, _dense ? 6 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statusBanner(),
                          SizedBox(height: gap),
                          for (var seat = 0; seat < c.players; seat++)
                            if (seat != c.humanSeat) ...[_playerRow(seat), SizedBox(height: gap)],
                          if (!c.showOver && !c.halted) ...[_pilesStrip(), SizedBox(height: gap)],
                          _actionPanel(),
                          SizedBox(height: gap),
                          _playerRow(c.humanSeat),
                          SizedBox(height: gap),
                          if (c.showOver) _resultPanel() else _bottomBar(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _topBar() => VsTopBar(title: '다빈치 코드', gameId: 'davinci_code', onRules: () => showDavinciRules(context));

  /// 위쪽 안내 띠. 글이 한 줄이든 두 줄이든 높이가 늘 같다 (높이가 바뀌면 아래 화면 전체가 출렁여서 어지럽다).
  Widget _statusBanner() {
    final color = c.showOver || c.halted ? Colors.grey : (c.turn == c.humanSeat ? kDavinciColor : const Color(0xFF6B7A85));
    final event = _lastEvent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: _dense ? 46 : 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_status, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          if (event != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(event, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              ),
            ),
        ],
      ),
    );
  }

  /// 한 사람의 타일 줄. 남의 줄은 숨은 타일이 색만 보이고, 내 줄은 전부 보인다.
  Widget _playerRow(int seat) {
    final s = c.state;
    final row = s.rows[seat];
    final me = seat == c.humanSeat;
    final active = !c.showOver && !c.halted && c.turn == seat;
    // 탈락은 ○ / ✕ 연출이 다 끝난 뒤에 보인다
    final out = s.isOut(seat) && !c.outPendingSeats.contains(seat);
    final scheme = Theme.of(context).colorScheme;
    final canPick = c.humanCanAct && !me && !out && (s.phase == DvPhase.guess || s.phase == DvPhase.decide);
    final placing = me && c.humanCanAct && s.phase == DvPhase.placeJoker;
    final revealing = me && c.humanCanAct && s.phase == DvPhase.reveal;
    final e = c.effect;
    final override = c.hiddenOverride;
    final liftedTile = c.liftedTile;
    final rs = c.remoteSel; // 다른 사람이 맞히려고 고르고 있는 타일

    return LayoutBuilder(
      builder: (context, box) {
        final n = row.length + (placing ? 1 : 0);
        final tw = (_dense ? (me ? 38.0 : 28.0) : (me ? 44.0 : 38.0)).clamp(20.0, (box.maxWidth - 34) / max(1, n) - 4);
        Widget slot(int pos) => GestureDetector(
              key: ValueKey('slot$pos'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _placeJoker(pos),
              child: Container(
                width: tw * 0.5,
                height: tw * 1.4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF5B8DEF), width: 1.6),
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF5B8DEF)),
              ),
            );
        final tiles = <Widget>[];
        for (var i = 0; i < row.length; i++) {
          if (placing) tiles.add(slot(i));
          final t = row[i];
          // 공개된 타일은 눕혀서 보이고, 숨은 타일은 세워서 둔다. (상대의 수를 보여 주는 동안에는 아직 숨은 것으로 보여야 하는 타일이 있다)
          final revealed = s.isRevealed(t) && !override.contains(t);
          final isEffectTile = e != null && e.kind == 2 && e.tile == t && e.target == seat;
          tiles.add(Opacity(
            opacity: t == _hiddenTile ? 0 : 1, // 더미에서 날아오는 동안은 줄에서 숨겨 둔다
            child: Padding(
            key: _tileKey(t),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DvTile(
              key: ValueKey('tile-$seat-$i'),
              id: t,
              width: tw,
              faceUp: me || revealed,
              lying: revealed,
              lifted: (isEffectTile && liftedTile == t) || (rs != null && rs.seat == seat && rs.index == i),
              selected: c.selSeat == seat && c.selIndex == i,
              mark: isEffectTile && e.stage == DvEffectStage.result ? e.correct : null,
              fresh: c.drawnBy[seat] == t && !revealed && !s.isOver, // 가장 최근에 가져온 타일 (내 것도, 상대 것도)
              onTap: canPick && !revealed
                  ? () => c.selectTarget(seat, i)
                  : (revealing && !revealed ? () => c.revealOwn(i) : null),
            ),
          )));
        }
        if (placing) tiles.add(slot(row.length));

        // 지금 차례인 사람의 줄은 테두리를 따라 은은한 빛이 돈다
        return TurnGlow(
          active: active,
          color: const Color(0xFF5B8DEF),
          radius: 16,
          child: Container(
          key: _rowKey(seat),
          padding: _dense ? const EdgeInsets.fromLTRB(10, 4, 10, 6) : const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: (active ? kDavinciColor : Colors.white).withValues(alpha: active ? 0.1 : 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? kDavinciColor : scheme.outlineVariant, width: 2.2), // (두께가 바뀌면 줄 높이가 움찔한다)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _dense ? 26 : 32, // 말풍선이 떠도 줄 높이가 변하지 않게 늘 같은 높이
                child: Row(
                children: [
                  Icon(me ? Icons.person_rounded : (c.isCpuSeat(seat) || !c.online ? Icons.smart_toy_rounded : Icons.wifi_rounded), size: 18, color: kDavinciColor),
                  const SizedBox(width: 5),
                  Text(_name(seat), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (out)
                    Text('탈락', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.error))
                  else if (active)
                    const Text('차례', style: TextStyle(fontWeight: FontWeight.w800, color: kDavinciColor)),
                  // 이 사람이 지금 하는 일: 말풍선 ("7?" → 맞으면 ○, 틀리면 ✕)
                  // (타일을 고르는 동안에는 아직 말하지 않는다: 고른 다음에 숫자를 말한다)
                  if (e != null && e.actor == seat && !(e.kind == 2 && e.stage == DvEffectStage.pick)) ...[
                    const SizedBox(width: 8),
                    DvBubble(key: ValueKey('bubble$seat'), text: _bubbleText(e), result: e.kind == 2 && e.stage == DvEffectStage.result ? e.correct : null),
                  ] else if (rs != null && rs.actor == seat) ...[
                    // 타일을 골랐고 아직 숫자를 말하지 않았다: 무슨 숫자일까 고민하는 중
                    const SizedBox(width: 8),
                    DvBubble(key: ValueKey('thinking$seat'), text: '고민 중…'),
                  ],
                  const Spacer(),
                  if (me) Text('숨은 타일 ${s.hiddenCount(seat)}장', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65))),
                ],
                ),
              ),
              SizedBox(height: _dense ? 1 : 4),
              Opacity(
                opacity: out ? 0.6 : 1,
                // 떠오르는 타일과 ○/✕ 표시가 들어갈 위쪽 여유, 눕힌 타일도 바닥에 맞춰 놓이게 아래 정렬
                child: Padding(
                  padding: EdgeInsets.only(top: _dense ? 6 : 14),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: tw * 1.4 + 4),
                    child: Wrap(runSpacing: _dense ? 6 : 10, crossAxisAlignment: WrapCrossAlignment.end, children: tiles),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  /// 말풍선에 쓸 글: 맞히기는 "7?", 그 밖의 수는 짧은 말.
  String _bubbleText(DvEffect e) => switch (e.kind) {
        0 => '${e.number == 0 ? '검정' : '흰색'} 뽑기',
        // 남이 놓는 타일이 조커인지는 알 수 없어야 한다 (그래서 "조커"라고 말하지 않는다)
        1 => e.actor == c.humanSeat ? '조커 놓기' : '타일 놓기',
        2 => e.number == kJokerGuess ? '‑ ?' : '${e.number} ?',
        3 => '멈춤',
        _ => '타일 공개',
      };
}
