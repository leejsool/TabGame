part of 'yacht_screen.dart';

/// 같은 Wi‑Fi 대결 조각: 소식 주고받기 · 나간 사람 돌보기 · 한 판 더 · 나가기.
extension _YachtNet on _YachtScreenState {
  void _startNet() {
    final links = _links;
    final desk = widget.rejoinDesk;
    if (_hub && desk != null) {
      _keeper = LanHubKeeper(
        desk: desk,
        seatOfLink: (link) => widget.linkSeats![link],
        isActive: () => !c.isOver,
        cover: c.coverSeat,
        uncover: c.uncoverSeat,
        snapshot: (_) => c.wifiSnapshot(),
        sendAll: _sendAll,
      );
    }
    c.onLocalAction = _sendAll;
    for (var i = 0; i < links.length; i++) {
      _linkSubs.add(links[i].messages.listen((m) => _onNet(i, m)));
      links[i].closed.then((_) => _onLinkClosed());
    }
  }

  void _stopNet() {
    _leaving = true;
    _keeper?.dispose();
    for (final s in _linkSubs) {
      s.cancel();
    }
    for (final link in _links) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.onLocalAction = null;
  }

  /// 모든 연결로 (방장이면 모든 손님에게, 손님이면 방장에게) 보낸다. [except]번 연결은 빼고.
  void _sendAll(Map<String, dynamic> m, {int? except}) {
    final links = _links;
    for (var i = 0; i < links.length; i++) {
      if (i != except) links[i].send(m);
    }
  }

  void _onNet(int from, Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'roll' || 'hold' || 'score':
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || widget.linkSeats![from] == c.game.turn;
        if (!fromOk || !c.receive(m)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'again':
        final seat = _hub ? widget.linkSeats![from] : m['seat'];
        if (seat is! int || seat < 0 || seat >= c.players) return;
        _update(() => _againSeats.add(seat));
        if (_hub) _sendAll({'t': 'again', 'seat': seat}, except: from);
        _checkRematch();
      case 'bye':
        // 방장은 나간 손님을 바로 내보내지 않고 기다린다 (CPU가 대신하거나, 돌아오면 이어 간다)
        if (_hub && !c.isOver && _links[from].suspend()) return;
        if (!_hub) _hostLeft = true; // 방장이 일부러 나갔다: 다시 들어갈 방이 없다
        _onLinkClosed();
      case 'cpu':
        final seat = m['seat'];
        if (seat is! int) return;
        c.coverSeat(seat);
        lanToast(context, '${c.name(seat)} 자리는 CPU가 대신해요');
      case 'back':
        final seat = m['seat'];
        if (seat is! int) return;
        c.uncoverSeat(seat);
        lanToast(context, '${c.name(seat)} 님이 돌아왔어요');
    }
  }

  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    for (final link in _links) {
      await link.close();
    }
    if (!mounted) return;
    await showVsNotice(context, '판이 서로 어긋났어요', '기기들의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    _update(() => _opponentGone = true);
    if (c.isOver) return;
    Future<void> notice() => showVsNotice(context, '상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 누군가 나갔어요. 이 판은 기록하지 않아요.');
    if (_hub || _hostLeft) {
      if (_hostLeft) RejoinTickets.forget('yacht');
      notice().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      // 손님: 방이 아직 열려 있으면 하던 판으로 다시 들어갈 수 있다
      lanGuestDropped(context, game: 'yacht', build: yachtResume, fallbackNotice: notice);
    }
  }

  /// 판이 끝났다: 나가 있는 손님의 연결을 정리하고, 손님은 "다시 들어가기" 표를 버린다.
  void _onNetGameOver() {
    _keeper?.settleIfEnded();
    if (!_hub && !_ticketDropped) {
      _ticketDropped = true;
      RejoinTickets.forget('yacht');
    }
  }

  String get _rematchLabel {
    if (_opponentGone) return '상대가 나갔어요';
    if (_rematchAsked) return '상대를 기다려요…';
    return _againSeats.isNotEmpty ? '한 판 더 (상대가 원해요)' : '한 판 더';
  }

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    _update(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  /// 사람이 모두 한 판 더를 눌렀으면 (시작하는 순서가 한 칸 돌아) 새 판을 시작한다.
  void _checkRematch() {
    if (!c.isOver || _againSeats.length < c.humans) return;
    _update(_againSeats.clear);
    _ticketDropped = false;
    c.restart(rotate: true);
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    if (await confirmVsLeave(context) && mounted) {
      if (!_hub) RejoinTickets.forget('yacht'); // 일부러 나간 것이니 "다시 들어가기"를 남기지 않는다
      Navigator.of(context).pop();
    }
  }
}
