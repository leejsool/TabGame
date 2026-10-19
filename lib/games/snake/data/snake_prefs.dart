import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지렁이의 모험 설정: 부스터를 누르는 쪽 (기본은 오른쪽 = 왼손으로 방향, 오른손으로 부스터).
class SnakePrefs {
  SnakePrefs._();

  static const String _key = 'snake.boostLeft';

  /// 참이면 왼쪽을 누르면 부스터, 오른쪽을 끌면 방향 (왼손잡이용).
  static final ValueNotifier<bool> boostLeft = ValueNotifier(false);

  /// 순위표를 접어 두었나 (접으면 1등과 나만 보인다).
  static final ValueNotifier<bool> boardFolded = ValueNotifier(false);
  static const String _foldKey = 'snake.boardFolded';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      boostLeft.value = p.getBool(_key) ?? false;
      boardFolded.value = p.getBool(_foldKey) ?? false;
    } catch (_) {}
  }

  static Future<void> setBoardFolded(bool on) async {
    boardFolded.value = on;
    try {
      await (await SharedPreferences.getInstance()).setBool(_foldKey, on);
    } catch (_) {}
  }

  static Future<void> setBoostLeft(bool on) async {
    boostLeft.value = on;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, on);
    } catch (_) {}
  }
}
