part of 'quoridor_controller.dart';

/// 같은 Wi‑Fi 판에서 사람이 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension QuoridorControllerRejoin on QuoridorController {
  /// [seat] 자리를 CPU가 대신 맡는다 (자리 주인이 한참 돌아오지 않을 때). 모든 기기가 똑같이 불러 두어야 한다.
  /// CPU의 수를 정하는 것은 방장 기기뿐이라, 지금 그 자리 차례이면 방장 기기에서 CPU가 바로 둔다.
  void coverSeat(int seat) {
    if (!online || seat == humanSeat || seat < 0 || seat >= players) return;
    if (!cpuSeats.add(seat)) return;
    _notify();
    _maybeCpu();
  }

  /// [seat] 자리를 다시 사람에게 돌려준다 (돌아온 사람이 앉는다). CPU가 그 자리의 수를 고르는 중이었으면 버린다.
  void uncoverSeat(int seat) {
    if (!cpuSeats.remove(seat)) return;
    if (turn == seat) _cpu.cancel();
    _notify();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 손님에게 보낸다). 수들만 있으면 판이 그대로 되살아난다.
  Map<String, dynamic> wifiSnapshot() => {
        'players': players,
        'level': level.index,
        'rotation': rotation,
        'moves': [...moves],
        'cpu': [...cpuSeats],
        'lastMover': lastMover,
      };

  /// [wifiSnapshot]으로 판을 되살린다. 나는 [humanSeat] 자리다. 맞지 않는 내용이면 null.
  static QuoridorController? fromWifiSnapshot(Map<String, dynamic> j, {required int humanSeat}) {
    try {
      final players = j['players'] as int;
      final levelIndex = j['level'] as int;
      if ((players != 2 && players != 4) || humanSeat < 0 || humanSeat >= players) return null;
      if (levelIndex < 0 || levelIndex >= QLevel.values.length) return null;
      final moves = [for (final m in j['moves'] as List) m as int];
      final cpu = [for (final s in j['cpu'] as List) if (s is int && s >= 0 && s < players && s != humanSeat) s];
      final c = QuoridorController(mode: PlayMode.wifi, players: players, humanSeat: humanSeat, level: QLevel.values[levelIndex], cpuSeats: cpu);
      c.rotation = j['rotation'] as int;
      c.moves.addAll(moves);
      c._rebuild();
      if (c.state.moveCount != moves.length) return null;
      c.lastMover = j['lastMover'] as int;
      return c;
    } catch (_) {
      return null;
    }
  }
}
