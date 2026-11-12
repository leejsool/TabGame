part of 'yacht_controller.dart';

/// 같은 Wi‑Fi 판에서 사람이 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension YachtControllerRejoin on YachtController {
  /// [seat] 자리를 CPU가 대신 맡는다 (자리 주인이 한참 돌아오지 않을 때). 모든 기기가 똑같이 불러 두어야 한다.
  /// CPU의 차례를 진행하는 것은 방장 기기뿐이라, 지금 그 자리 차례이면 방장 기기에서 CPU가 이어서 굴린다.
  void coverSeat(int seat) {
    if (!online || seat == humanSeat || seat < 0 || seat >= players) return;
    if (!cpuSeats.add(seat)) return;
    if (cpuHost) _settleRoll(); // 나간 사람이 굴리던 주사위는 바로 멈추고 CPU가 이어 간다
    _notify();
    _runCpu();
  }

  /// [seat] 자리를 다시 사람에게 돌려준다 (돌아온 사람이 앉는다). CPU가 그 자리에서 하던 일은 거기서 멈춘다.
  void uncoverSeat(int seat) {
    if (!cpuSeats.remove(seat)) return;
    if (cpuHost && game.turn == seat) {
      _settleRoll(); // (굴린 결과는 이미 다른 기기에 알렸으니 그대로 적용한다)
      _epoch++;
      _cpu.cancel();
      _cpuBusy = false;
      pick = null;
    }
    _notify();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 손님에게 보낸다). 구르는 중인 주사위는 멈춘 것으로 담는다.
  Map<String, dynamic> wifiSnapshot() {
    final g = game.toJson();
    var acts = actions;
    final rollingTo = _pendingRoll;
    if (rollingTo != null) {
      g['dice'] = List<int>.of(rollingTo);
      g['rolls'] = game.rollsUsed + 1;
      acts++;
    }
    return {
      'level': level.index,
      'first': first,
      'actions': acts,
      'game': g,
      'cpu': [...cpuSeats],
      if (names != null) 'names': names,
      'last': [lastSeat, lastCategory?.index],
    };
  }

  /// [wifiSnapshot]으로 판을 되살린다. 나는 [humanSeat] 자리다. 맞지 않는 내용이면 null.
  static YachtController? fromWifiSnapshot(Map<String, dynamic> j, {required int humanSeat}) {
    try {
      final game = YachtGame.fromJson(j['game'] as Map<String, dynamic>);
      final players = game.playerCount;
      final levelIndex = j['level'] as int;
      if (players < 2 || players > 4 || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= YachtLevel.values.length) return null;
      if (game.turn < 0 || game.turn >= players || game.rollsUsed < 0 || game.rollsUsed > kYachtRolls) return null;
      if (game.cards.any((card) => card.scores.length != YachtCategory.values.length)) return null;
      if (game.dice.any((d) => d < 0 || d > 6) || (game.rollsUsed > 0) != game.dice.every((d) => d > 0)) return null;
      final rawNames = j['names'];
      final c = YachtController(
        mode: PlayMode.wifi,
        players: players,
        level: YachtLevel.values[levelIndex],
        first: j['first'] as int,
        threeKind: game.threeKind,
        daesung: game.daesung,
        humanSeat: humanSeat,
        cpuSeats: [for (final s in j['cpu'] as List) if (s is int && s >= 0 && s < players && s != humanSeat) s],
        names: rawNames is List && rawNames.length == players ? [for (final n in rawNames) '$n'] : null,
      );
      c.game = game;
      c.actions = j['actions'] as int;
      final last = j['last'];
      if (last is List && last.length == 2 && last[0] is int && last[1] is int) {
        c.lastSeat = last[0] as int;
        c.lastCategory = YachtCategory.values[last[1] as int];
      }
      return c;
    } catch (_) {
      return null;
    }
  }
}
