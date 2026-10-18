part of 'rummikub_screen.dart';

/// net 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkNet on _RummikubScreenState {
  // ── 같은 Wi‑Fi 대결 ──
  List<LanConnection> get _links => c.online ? (widget.links ?? [if (widget.link != null) widget.link!]) : const [];

  /// 방장인가 (그러면 손님이 보낸 수가 그 손님 차례의 수인지 확인하고, 손님이 여럿이면 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null;

  /// [link]번째 연결의 손님이 지금 앉은 자리 (한 판 더 할 때마다 자리가 한 칸씩 돈다).
  int _seatOfLink(int link) => (widget.linkSeats![link] + c.rotation) % c.players;

  bool get _rematchAsked => _againSeats.contains(c.humanSeat);

  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);

  void _sendAll(Map<String, dynamic> m, {int? except}) {
    final links = _links;
    for (var i = 0; i < links.length; i++) {
      if (i != except) links[i].send(m);
    }
  }

  void _onNet(int from, Map<String, dynamic> m) {
    if (!mounted) return;
    // 방장은 보낸 손님의 자리도 알려서, 그 손님 차례의 수인지 확인하게 한다
    final fromSeat = _hub ? _seatOfLink(from) : null;
    switch (m['t']) {
      case 'move':
        if (!c.receiveMove(m, fromSeat: fromSeat)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'live':
        // (맞지 않는 내용은 조용히 버린다 — 끝낼 때 오는 수가 진짜다)
        if (c.receiveLive(m, fromSeat: fromSeat) && _hub) _sendAll(m, except: from);
      case 'resign':
        _onOpponentResigned();
      case 'again':
        final seat = _hub ? _seatOfLink(from) : (m['seat'] is int ? m['seat'] as int : (c.players == 2 ? 1 - c.humanSeat : null));
        if (seat == null || seat < 0 || seat >= c.players) return;
        _update(() => _againSeats.add(seat));
        if (_hub) _sendAll({'t': 'again', 'seat': seat}, except: from);
        _checkRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    for (final link in _links) {
      await link.close();
    }
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '기기들의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    _update(() => _opponentGone = true);
    if (c.isOver || c.halted) return;
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _notice(String title, String body) => showVsNotice(context, title, body);

  Future<void> _onOpponentResigned() async {
    if (c.isOver || c.halted) return;
    c.opponentResigned();
    _resultHandled = true;
    WinSound.play(context); // 이겼을 때 "짜잔"
    await _record(winner: c.humanSeat, resigned: true);
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, size: 32, color: Color(0xFFF2A900)),
        title: const Text('상대가 기권했어요', textAlign: TextAlign.center),
        content: const Text('이번 판은 내가 이긴 걸로 기록해 두었어요.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          if (!_opponentGone) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _requestRematch();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    _update(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  void _checkRematch() {
    if (_againSeats.length < c.humans) return;
    _update(_againSeats.clear);
    _resultHandled = false;
    c.restart();
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    if (await confirmVsLeave(context) && mounted) Navigator.of(context).pop();
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _record({required int? winner, bool resigned = false}) {
    return RkHistory.add(RkRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      human: c.humanSeat,
      turns: c.moveCount,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  /// 처음 내 차례가 되면 (아직 처음 내려놓기 전이면) 규칙을 한 번만 팝업으로 알려 준다. 화면에 긴 안내 글을 두지 않으려고.
  void _maybeFirstHint() {
    if (!RummikubScreen.showFirstHint || _hintShown || !mounted || !c.myTurn || c.state.melded[c.humanSeat]) return;
    _hintShown = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded),
        title: const Text('처음 내려놓을 때'),
        content: const Text(
          '내 타일로만 묶음을 만들어 숫자 합이 30점 이상이어야 해요.\n\n'
          '• 타일은 끌어서 녹색 판 아무 데나 놓아요 (한 장씩 먼저 놓아 둬도 돼요)\n'
          '• 꾹 눌렀다가 끌면 묶음 통째로 옮겨요\n'
          '• 낼 수 없으면 바닥에서 한 장을 골라 뽑아요',
          style: TextStyle(height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요'))],
      ),
    );
  }
}
