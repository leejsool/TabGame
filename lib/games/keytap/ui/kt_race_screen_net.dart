part of 'kt_race_screen.dart';

/// 경주 화면의 연결 조각: 점수 주고받기, 결과 정하기, 한 번 더, 나갔다 돌아오기.
///
/// 손님 → 방장: `sc` (내 점수, 끝나면 `f: true`), `bye`.
/// 방장 → 손님: `bd` (모든 자리 점수), `res` (마지막 점수), `again` (새 씨앗), `cpu`/`back` (자리 맡김·돌려줌), `bye`.
extension _KtRaceNet on _KtRaceScreenState {
  void _initNet() {
    final links = widget.links;
    for (var i = 0; i < links.length; i++) {
      _subs.add(links[i].messages.listen((m) => _onNet(i, m)));
      links[i].closed.then((_) => _onLinkClosed(i));
    }
    final desk = widget.rejoinDesk;
    if (_host && desk != null) {
      _keeper = LanHubKeeper(
        desk: desk,
        seatOfLink: (link) => widget.linkSeats![link],
        isActive: () => !race.ended && !_leaving,
        cover: race.cover,
        uncover: race.uncover,
        snapshot: (_) => race.snapshot(_t),
        sendAll: _sendAll,
      );
    }
  }

  void _disposeNet() {
    _keeper?.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    for (final l in widget.links) {
      l.send(const {'t': 'bye'});
      l.close();
    }
    if (!_host && race.ranks != null) RejoinTickets.forget(kKeytapLanGame);
  }

  void _sendAll(Map<String, dynamic> m, {int? except}) {
    for (var i = 0; i < widget.links.length; i++) {
      if (i != except) widget.links[i].send(m);
    }
  }

  List<List<int>> get _board => [for (final s in race.scores) s.toJson()];

  /// 매 화면마다: 점수를 알리고, (방장) 끝났으면 잠깐 기다렸다 결과를 정한다.
  void _netTick() {
    if (_host) {
      if (_clock - _lastBoard >= 0.25 && race.ranks == null) {
        _lastBoard = _clock;
        _sendAll({'t': 'bd', 's': _board});
      }
      final end = _endedAt;
      if (end != null && race.ranks == null && _clock - end > 1.2) {
        race.settle();
        _sendAll({'t': 'res', 's': _board});
        _showResult();
      }
      return;
    }
    final changed = run.hits != _sentHits || run.misses != _sentMisses;
    final last = race.ended && !_sentFinal;
    if ((changed && _clock - _lastSent >= 0.15) || last) {
      _lastSent = _clock;
      _sentHits = run.hits;
      _sentMisses = run.misses;
      if (last) _sentFinal = true;
      widget.links.first.send({'t': 'sc', 'h': run.hits, 'm': run.misses, if (last) 'f': true});
    }
  }

  void _onNet(int link, Map<String, dynamic> m) {
    if (!mounted || _leaving) return;
    switch (m['t']) {
      case 'sc' when _host:
        final h = m['h'], mi = m['m'];
        if (h is int && mi is int) race.setScore(widget.linkSeats![link], KtScore(h, mi));
      case 'bd' when !_host:
        final s = m['s'];
        if (s is List) race.setBoard([for (final x in s) KtScore.fromJson(x)]);
      case 'res' when !_host:
        final s = m['s'];
        if (s is! List) return;
        final all = [for (final x in s) KtScore.fromJson(x)];
        all[race.mySeat] = KtScore(run.hits, run.misses);
        if (!race.ended) {
          // 내 시계가 조금 늦었다: 남은 블록은 놓친 것으로 치고 끝낸다
          run.finished = true;
        }
        race.settle(all);
        _showResult();
      case 'again' when !_host:
        final seed = m['seed'];
        if (seed is int) _restart(seed);
      case 'cpu':
        final seat = m['seat'];
        if (seat is int && seat != race.mySeat) lanToast(context, '${race.names[seat]} 님 자리는 CPU가 이어서 쳐요');
      case 'back':
        final seat = m['seat'];
        if (seat is int && seat != race.mySeat) lanToast(context, '${race.names[seat]} 님이 돌아왔어요');
      case 'bye':
        if (_host) {
          _keeper?.takeOver(link);
        } else {
          _hostLeft = true;
        }
    }
  }

  void _again() {
    final seed = Random().nextInt(1 << 30);
    _sendAll({'t': 'again', 'seed': seed});
    _restart(seed);
  }

  void _restart(int seed) {
    _update(() {
      race.again(seed);
      _hitAt.clear();
      _zero = _clock + 3;
      _endedAt = null;
      _resultShown = false;
      _sentHits = _sentMisses = -1;
      _sentFinal = false;
    });
  }

  void _onLinkClosed(int link) {
    if (!mounted || _leaving || _gone) return;
    if (_host) {
      // 손님이 아주 끊겼다: 그 자리는 CPU가 마저 친다
      if (!race.ended) {
        race.cover(widget.linkSeats![link]);
        lanToast(context, '${race.names[widget.linkSeats![link]]} 님 자리는 CPU가 이어서 쳐요');
      }
      return;
    }
    _gone = true;
    if (race.ranks != null) return; // 결과를 이미 봤다
    Future<void> notice() => showVsNotice(context, _hostLeft ? '방장이 나갔어요' : '방장과 연결이 끊겼어요', '이 경주는 여기서 끝나요. 기록은 남기지 않아요.');
    if (_hostLeft) {
      RejoinTickets.forget(kKeytapLanGame);
      notice().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      lanGuestDropped(context, game: kKeytapLanGame, build: keytapResume, fallbackNotice: notice);
    }
  }
}

/// 방장이 보낸 `resume`(나갔다 다시 들어올 때 받는 판의 모습)으로 경주 화면을 만든다. 맞지 않는 내용이면 null.
Widget? keytapResume(Map<String, dynamic> resume, LanConnection conn) {
  final seat = resume['seat'], snap = resume['snap'];
  if (seat is! int || snap is! Map<String, dynamic>) return null;
  final r = KtRace.fromSnapshot(snap, seat);
  if (r == null) return null;
  return KtRaceScreen(race: r.race, links: [conn], resumeAt: r.elapsed);
}
