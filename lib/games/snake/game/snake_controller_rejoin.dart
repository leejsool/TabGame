part of 'snake_controller.dart';

/// 같은 Wi‑Fi 판에서 사람이 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension SnakeControllerRejoin on SnakeController {
  /// [seat] 자리의 뱀을 CPU가 대신 몬다 (자리 주인이 한참 응답이 없을 때, 방장 기기).
  void coverSeat(int seat) {
    final w = world;
    if (w == null || seat == mySeat) return;
    w.coverSeat(seat);
    onToast?.call('${w.seatNames[seat] ?? '친구'}님의 연결이 끊겨 CPU가 대신 움직여요');
  }

  /// [seat] 자리를 다시 사람에게 돌려준다 (돌아온 사람이 앉는다).
  void uncoverSeat(int seat) {
    final w = world;
    if (w == null) return;
    w.uncoverSeat(seat);
    onToast?.call('${w.seatNames[seat] ?? '친구'}님이 돌아왔어요');
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 손님에게 보낸다).
  Map<String, dynamic> wifiSnapshot() => encodeFull(world!, hostNet?.seq ?? 0);

  /// 방장이 보낸 `resume`(`seat` + `snap`)이나 `start` 메시지로 손님의 판을 만든다. 맞지 않는 내용이면 null.
  static SnakeController? fromWifiSnapshot(Map<String, dynamic> m, LanConnection conn) {
    try {
      final seat = m['seat'];
      final snap = m['snap'];
      if (seat is! int || seat < 1 || snap is! Map<String, dynamic>) return null;
      return SnakeController.guest(conn: conn, seat: seat, snap: snap);
    } catch (_) {
      return null;
    }
  }
}
