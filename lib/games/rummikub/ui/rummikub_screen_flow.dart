part of 'rummikub_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkFlow on _RummikubScreenState {
  /// 내 차례가 되면(상대의 수가 다 보여진 뒤) 잠깐 "내 차례예요!"가 뜨고 살짝 진동한다. 눌러서 닫을 필요 없이 저절로 사라진다.
  void _maybeAnnounceTurn() {
    final can = c.canAct && !c.isOver;
    final arrived = can && !_prevCanAct;
    _prevCanAct = can;
    if (!arrived || !c.animate || !mounted || c.moveCountForBanner == 0) return;
    _feedback('turn');
    _turnTimer?.cancel();
    _update(() => _turnBanner = true);
    _turnTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _update(() => _turnBanner = false);
    });
  }

  Widget _turnBannerOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('turn-banner'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: 0.8 + 0.2 * t, child: child)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: kRkWood.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('내 차례예요!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onChanged() {
    if (c.online && (c.isOver || c.halted)) {
      _keeper?.settleIfEnded();
      if (!_hub && !_ticketDropped) {
        _ticketDropped = true;
        RejoinTickets.forget('rummikub'); // 끝난 판에는 다시 들어갈 수 없다
      }
    }
    _maybeAnnounceTurn();
    _maybeFlyOpponentPick();
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner);
      if (c.state.winner == c.humanSeat) _celebrateWin();
    } else if (!c.isOver && !c.halted) {
      if (_resultHandled) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
      _celebrate = false;
    }
    if (!c.online) _autosave();
  }

  /// 한 차례가 지날 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void _autosave() {
    if (c.moveCount == 0 && !c.isOver) _saver.rearm(); // 새 판이 시작됐다
    if (c.isOver || c.halted) {
      _saver.finish();
    } else if (c.moveCount != _savedAtMove) {
      _savedAtMove = c.moveCount;
      _saver.save();
    }
  }

  /// 내가 이기면 색종이가 쏟아지고 "승리!" 현판이 튀어 오르며 진동이 길게 울린다.
  void _celebrateWin() {
    if (!c.animate || !mounted) return;
    WinSound.play(context); // 이겼을 때 "짜잔"
    _update(() => _celebrate = true);
    if (SettingsScope.of(context).haptics) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.mediumImpact);
      Future<void>.delayed(const Duration(milliseconds: 360), HapticFeedback.lightImpact);
    }
  }

  String _name(int seat) {
    if (seat == c.humanSeat) return '나';
    final given = widget.names;
    // (이름표는 처음 앉은 자리 기준이라, 한 판 더 해서 자리가 돈 만큼 되돌려 찾는다)
    if (c.online && given != null && given.length == c.players) return given[(seat - c.rotation) % c.players];
    if (c.online) return _links.isEmpty ? '상대' : _links.first.peerNick;
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final ok = await confirmGiveUp(context, detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '상대의 승리로 기록돼요.', retry: false, verb: '기권');
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _sendAll(const {'t': 'resign'});
    await _record(winner: (c.humanSeat + 1) % c.players, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}차례' : '${c.moveCount}차례',
      againLabel: c.online ? '한 판 더' : '새 판',
      offerAgain: !_opponentGone,
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again && c.online) {
      _requestRematch();
    } else if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }
}
