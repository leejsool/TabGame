import 'package:shared_preferences/shared_preferences.dart';

/// 튜토리얼 진행 기록 (기기에 저장).
///
/// - "봤어요": 게임을 처음 열 때 안내를 이미 보여줬는지 (게임 id 단위)
/// - "마쳤어요": 스도쿠 연습 같은 개별 레슨을 끝냈는지 (레슨 id 단위)
class TutorialProgress {
  TutorialProgress._();

  static const _kSeen = 'tutorialSeen';
  static const _kDone = 'tutorialDone';

  static Future<Set<String>> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const <String>[]).toSet();
  }

  static Future<void> _add(String key, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(key) ?? const <String>[]).toSet();
    if (set.add(id)) await prefs.setStringList(key, set.toList()..sort());
  }

  /// 이 게임의 처음 안내를 이미 보여줬는가.
  static Future<bool> isSeen(String gameId) async =>
      (await _read(_kSeen)).contains(gameId);

  static Future<void> markSeen(String gameId) => _add(_kSeen, gameId);

  /// "처음 안내"를 모든 게임에서 다시 보이게 한다. (레슨을 마친 기록은 그대로)
  static Future<void> resetSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSeen);
  }

  /// 마친 레슨들의 id.
  static Future<Set<String>> doneLessons() => _read(_kDone);

  static Future<void> markLessonDone(String lessonId) => _add(_kDone, lessonId);
}
