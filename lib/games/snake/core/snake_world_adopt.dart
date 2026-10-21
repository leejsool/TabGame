part of 'snake_world.dart';

/// 방장이 나갔을 때: 손님 기기가 따라 그리던 판([SnakeMirror])을 이어받아 진짜 판으로 만든다.
extension SnakeWorldAdopt on SnakeWorld {
  /// [m]의 뱀·먹이·사람 명단·CPU 단계를 그대로 이어받는다. 이 판([hostSeat])의 주인 말고 다른 사람 자리는
  /// 모두 CPU가 대신 몰다가, 그 손님이 새 방에 다시 들어오면 돌려준다. 나간 방장([oldHostSeat])의 뱀은 먹이로 흩어진다.
  /// CPU 뱀은 머리(성격·솜씨)를 새로 받는다 (하던 사냥 계획은 이어지지 않는다).
  void adoptMirror(SnakeMirror m, {required int oldHostSeat}) {
    cpuLevel = m.cpuLevel;
    seatNames
      ..clear()
      ..addAll(m.seats);
    var maxId = 0;
    for (final ms in m.snakes.values) {
      maxId = max(maxId, ms.id);
      final s = WorldSnake(id: ms.id, name: ms.name, color: ms.color, seat: ms.seat);
      s.x = ms.x;
      s.y = ms.y;
      s.angle = s.targetAngle = ms.angle;
      s.mass = ms.mass;
      s.boost = ms.boost;
      s.kills = ms.kills;
      for (var i = 0; i < ms.trail.length; i++) {
        s.trail.add(ms.trail.xAt(i), ms.trail.yAt(i));
      }
      if (!s.human) s.brain = _newBrain();
      snakes.add(s);
      byId[s.id] = s;
    }
    _nextId = maxId + 1;
    // (먹이는 나이를 흩어 두어 한꺼번에 치워지지 않게 한다)
    for (final f in m.food.values) {
      addFood(f.x, f.y, f.value, f.color, natural: f.natural, bornAt: -rng.nextDouble() * (f.natural ? SnakeWorld.naturalLife : SnakeWorld.dropLife));
    }
    for (final q in [_naturalByAge, _dropByAge]) {
      final aged = q.toList()..sort((a, b) => a.bornAt.compareTo(b.bornAt));
      q
        ..clear()
        ..addAll(aged);
    }
    for (final seat in seatNames.keys.toList()) {
      if (seat != hostSeat && seat != oldHostSeat) coverSeat(seat);
    }
    if (oldHostSeat != hostSeat) removeSeat(oldHostSeat);
    _buildGrid();
    // 이어받기 전에 있던 일은 새 손님들에게 알릴 필요가 없다 (들어올 때 판 전체를 받는다)
    born.clear();
    deaths.clear();
    foodAdded.clear();
    foodEaten.clear();
  }
}
