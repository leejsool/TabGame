import 'package:flutter/foundation.dart';

import 'update/update_service.dart' show kDevBuild;

/// 정식 앱에서 아직 닫아 둔 게임([GameInfo.devOnly])을 몰래 여는 문.
/// 허브 카드를 [tapsNeeded]번 연달아(사이가 [maxGap]보다 짧게) 누르면 앱을 끌 때까지 열린다.
/// 개발용 앱에서는 처음부터 열려 있다.
class DevUnlock {
  DevUnlock._();

  static const int tapsNeeded = 10;
  static const Duration maxGap = Duration(milliseconds: 1500);

  /// 이번에 앱을 켠 뒤 열어 둔 게임 id들. 허브 카드가 이걸 보고 다시 그린다.
  static final ValueNotifier<Set<String>> opened = ValueNotifier(<String>{});

  static final Map<String, ({int count, DateTime at})> _taps = {};

  static bool isOpen(String id) => kDevBuild || opened.value.contains(id);

  /// 닫힌 카드를 한 번 눌렀다. 이번 누름으로 열렸으면 true.
  static bool tap(String id, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final prev = _taps[id];
    final count = prev != null && t.difference(prev.at) <= maxGap ? prev.count + 1 : 1;
    if (count < tapsNeeded) {
      _taps[id] = (count: count, at: t);
      return false;
    }
    _taps.remove(id);
    opened.value = {...opened.value, id};
    return true;
  }

  @visibleForTesting
  static void reset() {
    _taps.clear();
    opened.value = <String>{};
  }
}
