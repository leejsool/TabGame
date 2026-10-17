import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/dot_levels.dart';

/// 갤러리 사진으로 만든 도트 그림(단계)을 기기에 보관하는 곳.
class DotCustomStore {
  DotCustomStore._();

  static const _key = 'dotcannon.custom';
  static const maxCount = 40;

  /// 새로 만든 것이 앞에 오는 순서.
  static Future<List<DotLevel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) DotLevel.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> _write(List<DotLevel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final l in list) l.toJson()]));
  }

  /// 새 그림을 맨 앞에 넣는다. 가득 차면 가장 오래된 것부터 밀려난다. 같은 이름표가 있으면 바꾼다.
  static Future<void> save(DotLevel level) async {
    final list = await loadAll();
    list.removeWhere((l) => l.id == level.id);
    list.insert(0, level);
    while (list.length > maxCount) {
      list.removeLast();
    }
    await _write(list);
  }

  static Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((l) => l.id == id);
    await _write(list);
  }

  /// 새 이름표 (만든 시각).
  static String newId() => 'c:${DateTime.now().millisecondsSinceEpoch}';
}
