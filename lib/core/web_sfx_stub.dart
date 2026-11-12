/// 앱(웹이 아닌 곳)에서는 쓰지 않는다: 소리는 audioplayers로 낸다.
class WebSfx {
  static const bool supported = false;

  static Future<void> load(String asset) async {}

  static void play(String asset, {double volume = 1.0}) {}
}
