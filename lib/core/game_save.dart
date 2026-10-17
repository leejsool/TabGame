import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 대결 게임(CPU와 / 둘이서)에서 "이어하던 판" 하나를 게임마다 따로 보관하는 곳.
///
/// 판이 끝나거나 저장하지 않고 나가면 지우고, 저장하고 나가면(또는 앱을 잠시 내려 두면) 지금 모습을 덮어쓴다.
/// 모습을 어떻게 JSON으로 바꾸고 되살리는지는 게임마다 다르다 (이곳은 보관만 한다).
class GameSave {
  GameSave._();

  /// 저장이 바뀔 때마다 올라가는 값 (설정 화면이 "이어하기" 카드를 다시 그리려고 듣는다).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String _key(String gameId) => 'save.$gameId';

  static Future<Map<String, dynamic>?> load(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(gameId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(_key(gameId)); // 깨진 저장은 버린다
      return null;
    }
  }

  static Future<void> write(String gameId, Map<String, dynamic> json) async {
    final text = jsonEncode(json); // 화면이 정리되기 전에 지금 모습을 굳혀 둔다
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(gameId), text);
    changes.value++;
  }

  static Future<void> clear(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_key(gameId))) return; // (지울 것이 없다)
    await prefs.remove(_key(gameId));
    changes.value++;
  }
}
