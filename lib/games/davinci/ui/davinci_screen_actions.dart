part of 'davinci_screen.dart';

/// actions 조각 (화면 코드를 역할별로 나눈 파일)
extension _DvActions on _DavinciScreenState {
  Widget _actionPanel() {
    final s = c.state;
    if (c.isOver || c.halted || !c.humanCanAct) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Widget box(Widget child) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
          child: child,
        );

    switch (s.phase) {
      case DvPhase.draw:
        return const SizedBox.shrink(); // 위의 더미를 눌러 뽑는다
      case DvPhase.placeJoker:
      case DvPhase.reveal:
        return const SizedBox.shrink(); // 내 줄에서 직접 고른다 (자리 칸 / 숨은 타일)
      case DvPhase.guess:
      case DvPhase.decide:
        final picking = c.selSeat >= 0;
        return box(Column(
          children: [
            if (picking) _numberPicker() else Text(s.phase == DvPhase.decide ? '계속 맞히려면 상대 타일을 고르고, 아니면 멈춰요' : '위에서 맞힐 상대 타일을 눌러요', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75))),
            if (s.phase == DvPhase.decide) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: c.stop,
                icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
                label: const Text('멈추기 (내 타일은 그대로 숨겨요)'),
                style: FilledButton.styleFrom(backgroundColor: kDavinciColor),
              ),
            ],
          ],
        ));
    }
  }

  /// 검정·흰색 더미 (언제나 보인다). 내가 뽑을 차례면 눌러서 뽑고, 누가 뽑든 타일이 여기서 날아간다.
  Widget _pilesStrip() {
    final canDraw = c.humanCanAct && c.state.phase == DvPhase.draw;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: (canDraw ? kDavinciColor : Colors.white).withValues(alpha: canDraw ? 0.12 : 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: canDraw ? kDavinciColor : scheme.outlineVariant.withValues(alpha: 0.6), width: 2), // (두께가 바뀌면 화면이 움찔한다)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final color in const [0, 1]) ...[
            if (color == 1) const SizedBox(width: 28),
            _pileButton(color, canDraw),
          ],
          if (canDraw) ...[
            const SizedBox(width: 18),
            const Flexible(child: Text('뽑을 더미를\n눌러요', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
          ],
        ],
      ),
    );
  }

  Widget _pileButton(int color, bool canDraw) {
    final count = c.state.poolOf(color);
    return GestureDetector(
      key: ValueKey('pile$color'),
      behavior: HitTestBehavior.opaque,
      onTap: canDraw && count > 0 ? () => _drawFromPile(color) : null,
      child: Opacity(
        opacity: count > 0 ? 1 : 0.45,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: _pileKey(color), child: DvPile(color: color, count: count, width: 30)),
            const SizedBox(width: 6),
            Text(color == 0 ? '검정' : '흰색', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  /// 고른 타일의 숫자를 고르는 판. 이미 보여서 그 색 타일일 수 없는 숫자는 흐리게 막는다.
  Widget _numberPicker() {
    final s = c.state;
    final tile = s.rows[c.selSeat][c.selIndex];
    final color = dvColor(tile);
    final seen = <int>{...s.revealed, ...s.rows[c.humanSeat]};
    final black = color == 0;
    return Column(
      children: [
        Text('${_name(c.selSeat)}의 ${c.selIndex + 1}번째 ${black ? '검정' : '흰색'} 타일은?', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 0; n <= kJokerGuess; n++)
              Builder(builder: (context) {
                final known = n == kJokerGuess ? seen.contains(24 + color) : seen.contains(dvTile(color, n));
                return SizedBox(
                  key: ValueKey('num$n'),
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: black ? const Color(0xFF2A2D32) : const Color(0xFFF6F1E4),
                      foregroundColor: black ? Colors.white : const Color(0xFF2A2D32),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
                      disabledForegroundColor: Colors.grey,
                      side: BorderSide(color: black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: known ? null : () => c.guess(n),
                    child: Text(n == kJokerGuess ? '‑' : '$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final compact = vsOutlinedStyle(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        if (c.selSeat >= 0 && c.humanCanAct)
          OutlinedButton.icon(style: compact, onPressed: c.clearSelection, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('고름 풀기')),
        if (c.vsCpu)
          OutlinedButton.icon(style: compact, onPressed: _newGameNow, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('새 판')),
        if (c.vsCpu || c.players == 2)
          OutlinedButton.icon(style: compact, onPressed: c.canResign ? _resign : null, icon: const Icon(Icons.flag_outlined, size: 20), label: const Text('기권')),
      ],
    );
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2A900)),
              const SizedBox(width: 8),
              Text('${_name(s.winner!)} 승리 · ${s.turnCount}차례', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                        c.restart();
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
