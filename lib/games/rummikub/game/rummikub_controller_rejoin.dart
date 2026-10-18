part of 'rummikub_controller.dart';

/// 같은 Wi‑Fi 판에서 사람이 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension RummikubControllerRejoin on RummikubController {
  /// 지금 CPU가 생각 중이거나 상대의 수를 보여 주는 중인가 (그동안은 새 CPU 차례를 시작하지 않는다 — 끝나면 저절로 이어진다).
  bool get _cpuBusy => _cpu.thinking || _animating || _queuedMoves.isNotEmpty;

  /// [seat] 자리를 CPU가 대신 맡는다 (자리 주인이 한참 돌아오지 않을 때). 모든 기기가 똑같이 불러 두어야 한다.
  /// CPU의 수를 정하는 것은 방장 기기뿐이라, 지금 그 자리 차례이면 방장 기기에서 CPU가 바로 둔다.
  void coverSeat(int seat) {
    if (!online || seat == humanSeat || seat < 0 || seat >= players) return;
    if (!cpuSeats.add(seat)) return;
    _notify();
    if (!_cpuBusy) _maybeCpu();
  }

  /// [seat] 자리를 다시 사람에게 돌려준다 (돌아온 사람이 앉는다). 그 자리의 수를 고르는 중이던 CPU는 멈춘다.
  void uncoverSeat(int seat) {
    if (!cpuSeats.remove(seat)) return;
    if (turn == seat && _cpu.thinking) _cpu.cancel();
    _notify();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 손님에게 보낸다). 모든 기기가 패를 같이 알고 있으니 판 상태를 통째로 담는다.
  /// 보여 주느라 아직 반영하지 않은 수(`pending`)도 함께 담아서, 받은 쪽이 이어서 반영한다.
  Map<String, dynamic> wifiSnapshot() => {
        'players': players,
        'level': level.index,
        'seed': seed,
        'rotation': rotation,
        'moveCount': moveCount,
        'lastActor': lastActor,
        'lastDrew': lastDrew,
        'lastCount': lastCount,
        'state': state.toJson(),
        'cpu': [...cpuSeats],
        'pending': [
          if (_inflight != null) _inflight,
          for (final q in _queuedMoves) q.m,
        ],
      };

  /// [wifiSnapshot]으로 판을 되살린다. 나는 [humanSeat] 자리다. 맞지 않는 내용이면 null.
  static RummikubController? fromWifiSnapshot(Map<String, dynamic> j, {required int humanSeat, bool animate = true}) {
    try {
      final st = RkState.fromJson(j['state'] as Map<String, dynamic>);
      final players = j['players'] as int, levelIndex = j['level'] as int;
      if (st == null || st.players != players || players < 2 || players > 4 || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= RkLevel.values.length) return null;
      final cpu = [for (final s in j['cpu'] as List) if (s is int && s >= 0 && s < players && s != humanSeat) s];
      final c = RummikubController(
        mode: PlayMode.wifi,
        players: players,
        humanSeat: humanSeat,
        level: RkLevel.values[levelIndex],
        seed: j['seed'] as int,
        animate: animate,
        cpuSeats: cpu,
      );
      c.state = st;
      c.rotation = j['rotation'] as int;
      c.moveCount = j['moveCount'] as int;
      c.lastActor = j['lastActor'] as int;
      c.lastDrew = j['lastDrew'] as bool;
      c.lastCount = j['lastCount'] as int;
      c.hand = [...st.racks[humanSeat]]..sort(compareByColor);
      c.anchors.clear();
      c.work = c._copyTable();
      c._liveSig = c._workSig();
      // 방장이 보여 주던 중이라 아직 판에 없던 수들: 한 번에 반영한다 (내 자리를 CPU가 두던 수일 수도 있다)
      for (final raw in j['pending'] as List) {
        if (!c._applyPendingNow(raw as Map<String, dynamic>)) return null;
      }
      // 보여 주던 수 중에 내 자리가 뽑은 타일이 있었으면 손에도 넣는다
      final rack = c.state.racks[humanSeat];
      c.hand
        ..removeWhere((t) => !rack.contains(t))
        ..addAll([for (final t in rack) if (!c.hand.contains(t)) t]);
      c.work = c._copyTable();
      return c;
    } catch (_) {
      return null;
    }
  }

  /// 확인이 끝난 수 하나를 보여 주기 없이 바로 판에 반영한다. 순서가 어긋났거나 안 맞는 수면 false.
  bool _applyPendingNow(Map<String, dynamic> m) {
    if (isOver || m['i'] != moveCount) return false;
    if (m['draw'] == 1) {
      final pick = m['pick'];
      if (pick != null && (pick is! int || pick < 0 || pick >= state.pool.length)) return false;
      _finishOpponent(null, pick as int?);
      return true;
    }
    final raw = m['table'];
    if (raw is! List) return false;
    final table = [
      for (final s in raw)
        [for (final t in s as List) t as int],
    ];
    if (state.checkPlay(table) != null) return false;
    _finishOpponent(table, null);
    return true;
  }
}
