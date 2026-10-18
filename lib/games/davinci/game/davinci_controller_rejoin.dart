part of 'davinci_controller.dart';

/// 같은 Wi‑Fi 판에서 사람이 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension DavinciControllerRejoin on DavinciController {
  /// [seat] 자리를 CPU가 대신 맡는다 (자리 주인이 한참 돌아오지 않을 때). 모든 기기가 똑같이 불러 두어야 한다.
  /// CPU의 수를 정하는 것은 방장 기기뿐이라, 지금 그 자리 차례이면 방장 기기에서 CPU가 바로 둔다.
  void coverSeat(int seat) {
    if (!online || seat == humanSeat || seat < 0 || seat >= players) return;
    if (!cpuSeats.add(seat)) return;
    _notify();
    _next();
  }

  /// [seat] 자리를 다시 사람에게 돌려준다 (돌아온 사람이 앉는다). 그 자리의 수를 두던 CPU는 다음 확인에서 저절로 멈춘다.
  void uncoverSeat(int seat) {
    if (!cpuSeats.remove(seat)) return;
    _notify();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 손님에게 보낸다). 씨앗과 둔 수만 있으면 판이 그대로 되살아난다.
  /// 연출을 기다리며 줄 서 있는 수도 이미 확인된 수라서 함께 담는다.
  Map<String, dynamic> wifiSnapshot() => {
        'players': players,
        'level': level.index,
        'seed': seed,
        'rotation': rotation,
        'moves': [
          for (final m in moves) [...m],
          for (final e in _incoming)
            if (e.move != null) [...e.move!],
        ],
        'cpu': [...cpuSeats],
      };

  /// [wifiSnapshot]으로 판을 되살린다. 나는 [humanSeat] 자리다. 맞지 않는 내용이면 null.
  static DavinciController? fromWifiSnapshot(Map<String, dynamic> j, {required int humanSeat, bool? animate}) {
    try {
      final players = j['players'] as int, levelIndex = j['level'] as int;
      if (players < 2 || players > 4 || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= DvLevel.values.length) return null;
      final cpu = [for (final s in j['cpu'] as List) if (s is int && s >= 0 && s < players && s != humanSeat) s];
      final c = DavinciController(
        mode: PlayMode.wifi,
        players: players,
        humanSeat: humanSeat,
        level: DvLevel.values[levelIndex],
        seed: j['seed'] as int,
        animate: animate,
        cpuSeats: cpu,
      );
      c.rotation = j['rotation'] as int;
      for (final raw in j['moves'] as List) {
        final move = [for (final v in raw as List) v as int];
        if (!c.state.isLegal(move)) return null;
        final actor = c.state.turn;
        c.moves.add(move);
        c.state.apply(move);
        if (move[0] == 0 || move[0] == 1) {
          final t = c.state.drawn;
          if (t != null) c.drawnBy[actor] = t;
        }
      }
      c.moveSerial = c.moves.length;
      return c;
    } catch (_) {
      return null;
    }
  }
}
