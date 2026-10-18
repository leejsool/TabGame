part of 'quoridor_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _QdFlow on _QuoridorScreenState {
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
      case 'move':
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || _seatOfLink(from) == c.turn;
        if (!fromOk || m['m'] is! int || !c.receiveMove(m['m'] as int, index: m['i'] as int?)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
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
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 누군가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
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

  /// 모든 사람이 한 판 더를 눌렀으면 (자리가 한 칸씩 돌아) 새 판을 시작한다.
  void _checkRematch() {
    if (_againSeats.length >= c.humans) _startRematch();
  }

  void _startRematch() {
    _update(_againSeats.clear);
    _resultHandled = false;
    c.restart(rotate: true);
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    if (await confirmVsLeave(context) && mounted) Navigator.of(context).pop();
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _record({required int winner, bool resigned = false}) {
    return QuoridorHistory.add(QuoridorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      moves: c.moveCount,
      human: c.oneSeat ? c.humanSeat : null,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      if (!c.oneSeat || c.state.winner == c.humanSeat) WinSound.play(context); // 이겼을 때 "짜잔"
      _record(winner: c.state.winner!);
    } else if (!c.isOver && !c.halted) {
      if (_resultHandled) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
    }
    if (!c.online) _autosave();
  }

  /// 수를 둘 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void _autosave() {
    if (c.moveCount == 0 && !c.isOver) _saver.rearm(); // 새 판이 시작됐다
    if (c.isOver || c.halted) {
      _saver.finish();
    } else if (c.moveCount != _savedAtMove) {
      _savedAtMove = c.moveCount;
      _saver.save();
    }
  }

  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (_saver.active && !await confirmNewGame(context)) return;
    if (!mounted) return;
    c.restart();
  }

  /// 플레이어 이름: 한 기기는 "플레이어 N", CPU 대결은 "나/CPU N", Wi‑Fi 대결은 "나/상대 별명".
  String _name(int seat) {
    if (!c.oneSeat) return '플레이어 ${seat + 1}';
    if (seat == c.humanSeat) return '나';
    final given = widget.names;
    // (이름표는 처음 앉은 자리 기준이라, 한 판 더 해서 자리가 돈 만큼 되돌려 찾는다)
    if (c.online && given != null && given.length == c.players) return given[(seat - c.rotation) % c.players];
    if (c.online) return _links.isEmpty ? '상대' : _links.first.peerNick;
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  /// 기권한 사람이 [seat]일 때 이긴 것으로 기록할 자리: 2명이면 상대, 4명이면 남은 사람 중 가장 앞선 사람.
  int _winnerWhenResigned(int seat) {
    if (c.players == 2) return 1 - seat;
    var best = -1, bestD = 1 << 20;
    for (var p = 0; p < c.players; p++) {
      if (p == seat) continue;
      final d = c.state.distance(p);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final seat = c.resigningSeat;
    final winner = _winnerWhenResigned(seat);
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? '${_name(winner)}의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${_name(seat)}이(가) 기권하고, ${_name(winner)}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _sendAll(const {'t': 'resign'});
    await _record(winner: winner, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${_name(seat)} 기권 · ${c.moveCount}수',
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
      c.restart(rotate: c.oneSeat);
    } else {
      Navigator.of(context).pop();
    }
  }

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner!;
      if (c.oneSeat) return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
      return '${_name(w)} 승리! 🎉';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.autoPlaying) return '모두 벽을 다 썼어요 · 가장 짧은 길로 저절로 움직여요…';
    if (c.thinking) return '${_name(s.turn)}이(가) 생각하는 중…';
    final mine = !c.oneSeat || s.turn == c.humanSeat;
    final who = c.oneSeat ? (mine ? '내 차례' : '${_name(s.turn)} 차례') : '${_name(s.turn)} 차례';
    if (!mine) return c.online ? '$who · 기다리는 중이에요' : who;
    if (c.wallMode) {
      if (!c.hasWallPick) return '$who · 막대를 판에 끌어다 놓아요';
      return c.canConfirmWall ? '$who · 이 자리에 벽을 세울까요? (체크로 확정)' : '$who · 여기에는 벽을 세울 수 없어요';
    }
    return '$who · 점이 찍힌 칸을 눌러 말을 옮기거나, 막대로 벽을 세워요';
  }

  /// 벽을 못 세우는 이유 (고른 자리가 있을 때).
  String? get _wallProblem {
    if (!c.wallMode || !c.hasWallPick || c.canConfirmWall) return null;
    final s = c.state;
    final o = c.wallOrientPick, r = c.wallRowPick, col = c.wallColPick;
    if (s.wallsLeft[s.turn] <= 0) return '남은 벽이 없어요';
    // 겹침/십자인지, 길이 막히는지 가린다
    final fits = !(o == 0
        ? (s.hWallAt(r, col) || s.vWallAt(r, col) || s.hWallAt(r, col - 1) || s.hWallAt(r, col + 1))
        : (s.vWallAt(r, col) || s.hWallAt(r, col) || s.vWallAt(r - 1, col) || s.vWallAt(r + 1, col)));
    return fits ? '모든 길을 막는 벽은 세울 수 없어요' : '이미 있는 벽과 겹치거나 엇갈려요';
  }
}
