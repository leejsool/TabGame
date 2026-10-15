import 'package:flutter/material.dart';

import '../core/json_history.dart';

/// 기록 화면의 "즐겨찾기": 마음에 든 판(같은 문제·같은 번호·같은 그림)을 따로 모아 두고 바로 다시 한다.
///
/// 즐겨찾기는 기록 목록과 따로 저장한다. 그래서 기록이 많이 쌓여 오래된 판이 지워져도 남고,
/// 같은 판을 다시 해서 새 기록이 생겨도 별이 그대로다. (한 판 = [boardKey]가 같은 기록)
class FavoriteStore<T> {
  const FavoriteStore({required this.key, required this.fromJson, required this.toJson, required this.boardKey});

  /// SharedPreferences 키 (게임이름.favorites).
  final String key;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T record) toJson;

  /// 같은 판인지 알아보는 열쇠.
  final String Function(T record) boardKey;

  JsonHistoryStore<T> get _store => JsonHistoryStore<T>(key: key, fromJson: fromJson, toJson: toJson, maxEntries: 1 << 20);

  /// 별 단 순서의 반대로 (가장 나중에 단 것이 맨 앞).
  Future<List<T>> load() => _store.load();

  /// [record]의 판을 즐겨찾기에 더한다. 이미 있으면 맨 앞으로 옮기며 기록을 새것으로 바꾼다.
  Future<void> add(T record) => _store.update((list) {
        final k = boardKey(record);
        list.removeWhere((e) => boardKey(e) == k);
        list.insert(0, record);
      });

  Future<void> remove(T record) => _store.update((list) {
        final k = boardKey(record);
        list.removeWhere((e) => boardKey(e) == k);
      });
}

/// 기록 보드 한 개가 들고 있는 즐겨찾기 목록 (화면 상태에서 쓴다).
class FavoriteSet<T> {
  FavoriteSet(this.store);

  final FavoriteStore<T> store;

  /// 즐겨찾기한 판의 기록 (가장 나중에 단 것이 맨 앞).
  List<T> items = [];

  Future<void> load() async => items = await store.load();

  bool has(T record) {
    final k = store.boardKey(record);
    return items.any((e) => store.boardKey(e) == k);
  }

  Future<void> toggle(T record) async {
    if (has(record)) {
      await store.remove(record);
    } else {
      await store.add(record);
    }
    await load();
  }

  /// 즐겨찾기한 판들을 화면에 보일 기록으로 바꾼다: 같은 판의 기록 가운데 가장 빠른 것
  /// ([seconds]가 작은 것, 별 달 때 남긴 기록 포함). 같은 판을 다시 해서 기록을 깼으면 그 기록이 보인다.
  List<T> shown(Iterable<T> history, int Function(T record) seconds) {
    return [
      for (final fav in items)
        history.fold<T>(fav, (best, r) => store.boardKey(r) == store.boardKey(fav) && seconds(r) < seconds(best) ? r : best),
    ];
  }
}

/// 기록 한 줄 끝의 즐겨찾기 별 단추.
class FavoriteStar extends StatelessWidget {
  const FavoriteStar({super.key, required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: on ? '즐겨찾기 해제' : '즐겨찾기에 담기',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 44),
      onPressed: onTap,
      icon: Icon(on ? Icons.star_rounded : Icons.star_border_rounded, color: on ? const Color(0xFFF2A900) : null),
    );
  }
}
