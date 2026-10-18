part of 'davinci_screen.dart';

/// flow 조각 (화면 코드를 역할별로 나눈 파일)
extension _DvFlow on _DavinciScreenState {
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
        final raw = m['mv'];
        final move = raw is List && raw.every((e) => e is int) ? raw.cast<int>() : null;
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || _seatOfLink(from) == c.turn;
        if (move == null || !fromOk || !c.receiveMove(move, index: m['i'] as int?)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'sel':
        // 다른 사람이 맞히려고 고른 타일 (방장은 보낸 손님이 맞는지 확인하고 다른 손님들에게도 전한다)
        final a = m['a'], s = m['s'], n = m['n'];
        if (a is! int || s is! int || n is! int) return;
        if (_hub && _seatOfLink(from) != a) return;
        c.receiveSelection(a, s, n);
        if (_hub) _sendAll(m, except: from);
      case 'resign':
        c.opponentResigned();
      case 'again':
        final seat = _hub ? _seatOfLink(from) : (m['seat'] is int ? m['seat'] as int : (c.players == 2 ? 1 - c.humanSeat : null));
        if (seat == null || seat < 0 || seat >= c.players) return;
        _update(() => _againSeats.add(seat));
        if (_hub) _sendAll({'t': 'again', 'seat': seat}, except: from);
        _checkRematch();
      case 'bye':
        // 방장은 나간 손님을 바로 내보내지 않고 기다린다 (CPU가 대신하거나, 돌아오면 이어 간다)
        if (_hub && !c.isOver && !c.halted && _links[from].suspend()) return;
        if (!_hub) _hostLeft = true; // 방장이 일부러 나갔다: 다시 들어갈 방이 없다
        _onLinkClosed();
      case 'cpu':
        final seat = m['seat'];
        if (seat is! int) return;
        c.coverSeat(seat);
        lanToast(context, '${_name(seat)} 자리는 CPU가 대신해요');
      case 'back':
        final seat = m['seat'];
        if (seat is! int) return;
        c.uncoverSeat(seat);
        lanToast(context, '${_name(seat)} 님이 돌아왔어요');
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
    Future<void> notice() => _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 누군가 나갔어요. 이 판은 기록하지 않아요.');
    if (_hub || _hostLeft) {
      if (_hostLeft) RejoinTickets.forget('davinci_code');
      notice().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      // 손님: 방이 아직 열려 있으면 하던 판으로 다시 들어갈 수 있다
      lanGuestDropped(context, game: 'davinci_code', build: davinciResume, fallbackNotice: notice);
    }
  }

  Future<void> _notice(String title, String body) => showVsNotice(context, title, body);

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    _update(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  void _checkRematch() {
    if (_againSeats.length >= c.humans) {
      _update(_againSeats.clear);
      _heldMove = null;
      _hover = null;
      _hoverTile = null;
      _resultHandled = false;
      c.restart();
    }
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    if (await confirmVsLeave(context) && mounted) {
      if (!_hub) RejoinTickets.forget('davinci_code'); // 일부러 나간 것이니 "다시 들어가기"를 남기지 않는다
      Navigator.of(context).pop();
    }
  }

  void _feedback(String kind) => _fx.play(context, kind);

  Future<void> _record({required int winner, bool resigned = false}) {
    return DvHistory.add(DvRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      human: c.humanSeat,
      turns: c.state.turnCount,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    if (c.online && (c.isOver || c.halted)) {
      _keeper?.settleIfEnded();
      if (!_hub && !_ticketDropped) {
        _ticketDropped = true;
        RejoinTickets.forget('davinci_code'); // 끝난 판에는 다시 들어갈 수 없다
      }
    }
    _maybeFlyOpponentDraw();
    final iWon = (c.showOver && c.state.winner == c.humanSeat) || (c.halted && c.resignWinner == c.humanSeat);
    if (iWon && !_winSounded) {
      _winSounded = true;
      WinSound.play(context); showWinCelebration(context, title: '승리!'); // 이겼을 때 "짜잔"
    } else if (!c.isOver && !c.halted) {
      _winSounded = false;
    }
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner!);
    } else if (c.halted && !_resultHandled && c.resignWinner != null) {
      // 상대가 기권해서 끝났을 때 (내가 기권한 경우는 [_resign]이 기록한다)
      if (c.resignWinner == c.humanSeat) {
        _resultHandled = true;
        _record(winner: c.humanSeat, resigned: true);
      }
    } else if (!c.isOver && !c.halted) {
      _resultHandled = false;
    }
    if (!c.online) _autosave();
    // 사람이 모두 탈락해서 CPU끼리 순위만 가리는 중이면, 계속 볼지 끝낼지 한 번 묻는다
    if (c.humansAllOut && !c.watchPrompted) {
      c.watchPrompted = true;
      if (!c.online) c.cpuHold = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askWatchOrEnd());
    }
  }

  /// 내 타일이 모두 공개돼 탈락했고 CPU끼리만 남았다: 끝까지 지켜볼지, 여기서 끝낼지 고른다.
  Future<void> _askWatchOrEnd() async {
    if (!mounted || c.isOver || c.halted) {
      c.cpuHold = false;
      return;
    }
    final left = c.state.alive;
    final host = c.online && _hub;
    final end = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ListenableBuilder(
        listenable: c,
        builder: (ctx, _) {
          // 기다리는 사이 판이 끝나 버렸으면(다른 기기에서 이어지는 Wi‑Fi 판) 창을 닫는다
          if (c.isOver || c.halted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // (이미 닫히는 중인 창이면 건드리지 않는다: 그러면 그 뒤에 뜬 화면이 대신 닫혀 버린다)
              if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
            });
          }
          return AlertDialog(
            icon: const Icon(Icons.visibility_rounded, size: 32),
            title: const Text('내 타일이 모두 공개됐어요', textAlign: TextAlign.center),
            content: Text(
              '탈락했어요. 이제 남은 CPU $left명이 순위를 가리는 일만 남았어요.\n끝까지 지켜볼까요, 여기서 끝낼까요?'
              '${host ? '\n\n(방을 만든 기기에서 끝내면 다른 기기의 판도 끝나요)' : ''}',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsOverflowAlignment: OverflowBarAlignment.center,
            actions: [
              TextButton(key: const ValueKey('dv-end-game'), onPressed: () => Navigator.pop(ctx, true), child: const Text('게임 끝내기')),
              FilledButton(key: const ValueKey('dv-keep-watching'), onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 지켜보기')),
            ],
          );
        },
      ),
    );
    c.cpuHold = false;
    if (end != true || !mounted || c.isOver || c.halted) return;
    if (!c.endWatching()) return;
    // 내가 탈락했으니 졌다. 이긴 쪽은 그때 숨은 타일이 가장 많이 남은 CPU로 기록한다
    _resultHandled = true;
    await _record(winner: c.resignWinner!);
    if (!mounted) return;
    if (c.online) {
      Navigator.of(context).pop();
      return;
    }
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.flag_rounded, size: 32),
        title: const Text('게임을 끝냈어요', textAlign: TextAlign.center),
        content: Text('CPU ${c.level.label} · ${c.state.turnCount}차례\n내가 탈락해서 진 것으로 기록했어요.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 판')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
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
    _resultHandled = false;
    c.restart();
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
    await _record(winner: c.resignWinner!, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.state.turnCount}차례' : '${c.state.turnCount}차례',
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

  String get _status {
    final s = c.state;
    if (c.showOver) {
      final w = s.winner!;
      return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
    }
    if (c.endedWatching) return '탈락해서 게임을 끝냈어요';
    if (c.halted) {
      final w = c.resignWinner;
      return w == c.humanSeat ? '상대가 기권해서 이겼어요! 🎉' : '기권했어요';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (!c.humanCanAct) {
      final e = c.effect;
      if (e != null && e.actor != c.humanSeat) {
        if (e.kind == 2) return '${_name(e.actor)}이(가) ${e.stage == DvEffectStage.pick ? '타일을 고르는 중…' : '추측하는 중…'}';
        return '${_name(e.actor)}이(가) 두는 중…';
      }
      return c.thinking && c.turn != c.humanSeat ? '${_name(s.turn)}이(가) 생각하는 중…' : '${_name(s.turn)} 차례';
    }
    return switch (s.phase) {
      DvPhase.draw => '내 차례 · 더미에서 타일을 한 장 뽑아요',
      DvPhase.placeJoker => '조커를 뽑았어요 · 내 줄에서 놓을 자리를 골라요',
      DvPhase.guess => c.selSeat < 0 ? '맞힐 상대 타일을 눌러 고르세요' : '고른 타일의 숫자를 골라요',
      DvPhase.decide => c.selSeat < 0 ? '맞혔어요! 계속 맞힐 타일을 고르거나, 멈춰요' : '고른 타일의 숫자를 골라요',
      DvPhase.reveal => '틀렸어요! 내 숨은 타일 하나를 눌러 공개해요',
    };
  }

  /// 가장 최근 맞히기를 한 줄로.
  String? get _lastEvent {
    final g = c.state.lastGuess;
    if (g == null || c.isOver || c.effectsPending) return null;
    if (c.effect != null) return null; // (연출 중에는 결과를 미리 알려 주지 않는다)
    final num = g.number == kJokerGuess ? '조커' : '${g.number}';
    final target = g.target == c.humanSeat ? '내' : '${_name(g.target)}의';
    return '${_name(g.guesser)}: $target ${g.index + 1}번째 타일을 "$num"(이)라고 추측 → ${g.correct ? '맞혔어요!' : '틀렸어요'}';
  }
}
