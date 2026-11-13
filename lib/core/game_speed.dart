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

  /// 설정의 "야추 빠른 진행": CPU 차례 · 주사위 굴림이 짧아지고, 끝날 때 점수 세기를 눌러 건너뛸 수 있다. 기본은 꺼짐.
  static bool yachtQuick = false;

  /// 설정의 "바둑돌 옮기기 자동 진행": 빈칸이 모두 0이 되어 승부가 정해지면 남은 수를 자동으로 둔다. 기본은 켜짐.
  static bool stonesAuto = true;
}
