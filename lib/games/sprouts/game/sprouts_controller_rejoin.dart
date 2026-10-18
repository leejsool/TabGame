part of 'sprouts_controller.dart';

/// 같은 Wi‑Fi 판에서 상대가 나갔다 돌아올 때 쓰는 조각 (자리를 CPU에게 맡기기 · 되찾기 · 판의 모습 보내고 받기).
extension ScRejoin on SproutsController {
  /// 나간 상대 자리를 CPU가 대신 맡는다. 지금이 상대 차례이면 CPU가 바로 둔다.
  void coverOpponent() {
    if (!online || cpuCover) return;
    cpuCover = true;
    _notify();
    _maybeCpu();
  }

  /// 돌아온 상대에게 자리를 돌려준다. CPU가 수를 고르는 중이었으면 버린다.
  void uncoverOpponent() {
    if (!cpuCover) return;
    cpuCover = false;
    _cpu.cancel();
    _notify();
  }

  /// 같은 Wi‑Fi 판의 지금 모습 (다시 들어오는 상대에게 보낸다). 판과 차례, 되돌리기에 쓰는 최근 판들을 담는다.
  Map<String, dynamic> wifiSnapshot() => {...toJson(), 'humanSide': cpuSide}; // 돌아오는 상대가 맡은 쪽

  /// [wifiSnapshot]으로 판을 되살린다 (돌아온 상대 쪽 기기). 맞지 않는 내용이면 null.
  static SproutsController? fromWifiSnapshot(Map<String, dynamic> j) => SproutsController._restore(j, wifi: true);
}
