import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 게임이 끝날 때마다 남기는 기록 목록을 기기에 저장하는 공통 틀. (최신 순, 개수 제한)
///
/// 기록 하나를 JSON으로 바꾸는 방법만 알려 주면 읽기·쓰기·깨진 데이터 처리·오래된 기록 정리를 해 준다.
/// 게임마다 `static` 함수 몇 개로 감싸서 쓴다 (예: `UtttHistory.load()` / `UtttHistory.add(record)`).
class JsonHistoryStore<T> {
  const JsonHistoryStore({
    required this.key,
    required this.fromJson,
    required this.toJson,
    this.maxEntries = 200,
  });

  /// SharedPreferences 키 (게임이름.history).
  final String key;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T record) toJson;

  /// 이만큼만 보관한다. 넘치면 가장 오래된 기록부터 지운다.
  final int maxEntries;

  /// 최신 순. 저장된 내용이 깨져 있으면 비우고 빈 목록을 준다.
  Future<List<T>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      await prefs.remove(key);
      return [];
    }
  }

  /// 기록을 맨 앞에 더한다.
  ///
  /// - [beforeInsert]: 더하기 전에 목록을 손볼 기회 (예: 같은 판의 옛 포기 기록 지우기).
  /// - [protect]: 개수가 넘쳐 오래된 기록을 지울 때 되도록 남길 기록 (예: 다시 도전할 수 있는 포기한 판).
  Future<void> add(
    T record, {
    void Function(List<T> list)? beforeInsert,
    bool Function(T record)? protect,
  }) async {
    final list = await load();
    beforeInsert?.call(list);
    list.insert(0, record);
    while (list.length > maxEntries) {
      var i = list.length - 1;
      if (protect != null) {
        final k = list.lastIndexWhere((e) => !protect(e));
        if (k >= 0) i = k;
      }
      list.removeAt(i);
    }
    await _write(list);
  }

  /// 목록을 읽어서 [edit]으로 고친 뒤 다시 저장한다 (개수 제한은 적용하지 않는다).
  Future<void> update(void Function(List<T> list) edit) async {
    final list = await load();
    edit(list);
    await _write(list);
  }

  Future<void> _write(List<T> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode([for (final e in list) toJson(e)]));
  }
}
