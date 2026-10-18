/// 게임 진행 속도. 설정의 "빠른 진행"을 켜면 CPU가 생각하는 시간과 상대 수를 보여 주는 움직임이 짧아진다.
///
/// 시간을 쓰는 곳은 직접 `Duration`을 쓰지 말고 `GameSpeed.scale(...)`을 거친다 (한 곳에서 바꿀 수 있게).
class GameSpeed {
  GameSpeed._();

  /// 빠른 진행일 때 곱하는 값.
  static const double fastFactor = 0.55;

  /// 지금 곱하는 값 (1이면 보통). 설정이 바뀔 때 [Settings]가 정한다.
  static double factor = 1;

  static Duration scale(Duration d) => d * factor;
}
