import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../records/favorites.dart';
import '../core/freecell_difficulty.dart';
import '../game/freecell_controller.dart';

/// 한 판의 기록: 완성했거나, 포기한 판.
class FreecellRecord {
  const FreecellRecord({
    required this.at,
    required this.deal,
    required this.seconds,
    required this.moves,
    this.gaveUp = false,
  });

  final int at;
  final int deal;
  final int seconds;
  final int moves;

  /// 포기한 판인가 (그러면 [deal] 번호로 다시 도전할 수 있고, [seconds]·[moves]는 포기하기까지의 값).
  final bool gaveUp;

  Map<String, dynamic> toJson() => {
        'at': at,
        'deal': deal,
        'sec': seconds,
        'mv': moves,
        if (gaveUp) 'gu': 1,
      };

  static FreecellRecord fromJson(Map<String, dynamic> j) => FreecellRecord(
        at: j['at'] as int,
        deal: j['deal'] as int,
        seconds: j['sec'] as int,
        moves: j['mv'] as int,
        gaveUp: j['gu'] == 1,
      );
}

class FreecellStats {
  const FreecellStats({
    this.starts = 0,
    this.wins = 0,
    this.bestSeconds,
    this.bestMoves,
  });

  /// 시작한 판 수 / 완성한 판 수.
  final int starts;
  final int wins;
  final int? bestSeconds;
  final int? bestMoves;

  double get winRate => starts == 0 ? 0 : (wins / starts).clamp(0.0, 1.0);
}

/// 진행 중인 판과 기록을 기기에 저장한다.
class FreecellStorage {
  FreecellStorage._();

  static const _saveKey = 'freecell.save';
  static const _historyKey = 'freecell.history';
  static const maxHistory = 100;

  /// 즐겨찾기한 판 (같은 번호 = 같은 판).
  static final favorites = FavoriteStore<FreecellRecord>(
    key: 'freecell.favorites',
    fromJson: FreecellRecord.fromJson,
    toJson: (r) => r.toJson(),
    boardKey: (r) => '${r.deal}',
  );

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static FreecellController? _active;

  static void setActive(FreecellController c) => _active = c;

  static Future<void> save(FreecellController c) async {
    if (!identical(c, _active) || c.completed || c.gaveUp || c.untouched) return;
    final json = jsonEncode(c.toJson()); // 화면이 정리되기 전에 지금 상태를 굳혀 둔다
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, json);
  }

  static Future<Map<String, dynamic>?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(_saveKey);
      return null;
    }
  }

  static Future<void> clearSave(FreecellController c) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  /// 마지막으로 고른 난이도 (null = 무작위).
  static Future<FcLevel?> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('freecell.level');
    if (name == null) return null;
    for (final l in FcLevel.values) {
      if (l.name == name) return l;
    }
    return null;
  }

  static Future<void> saveLevel(FcLevel? level) async {
    final prefs = await SharedPreferences.getInstance();
    if (level == null) {
      await prefs.remove('freecell.level');
    } else {
      await prefs.setString('freecell.level', level.name);
    }
  }

  /// 새 판을 시작할 때 (이어하기는 제외) 도전 횟수를 센다.
  static Future<void> recordStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('freecell.starts', (prefs.getInt('freecell.starts') ?? 0) + 1);
  }

  static Future<FreecellStats> stats() async {
    final prefs = await SharedPreferences.getInstance();
    return FreecellStats(
      starts: prefs.getInt('freecell.starts') ?? 0,
      wins: prefs.getInt('freecell.wins') ?? 0,
      bestSeconds: prefs.getInt('freecell.bestTime'),
      bestMoves: prefs.getInt('freecell.bestMoves'),
    );
  }

  /// 완성 기록. 시간이나 이동 수가 최고 기록이면 true.
  static Future<bool> recordWin(FreecellRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('freecell.wins', (prefs.getInt('freecell.wins') ?? 0) + 1);
    var best = false;
    final bt = prefs.getInt('freecell.bestTime');
    if (bt == null || r.seconds < bt) {
      await prefs.setInt('freecell.bestTime', r.seconds);
      best = true;
    }
    final bm = prefs.getInt('freecell.bestMoves');
    if (bm == null || r.moves < bm) {
      await prefs.setInt('freecell.bestMoves', r.moves);
      best = true;
    }
    await _addToHistory(prefs, r);
    return best;
  }

  /// 포기한 판을 기록에 남긴다 (같은 번호를 또 포기하면 가장 최근 것만 남는다).
  static Future<void> recordGiveUp(FreecellRecord r) async {
    assert(r.gaveUp);
    await _addToHistory(await SharedPreferences.getInstance(), r);
  }

  /// 같은 번호의 포기 기록은 지우고(포기했던 판을 완성했거나 또 포기한 경우) 맨 앞에 더한다.
  /// 넘치면 오래된 완성 기록부터 지운다 (다시 도전할 수 있는 포기한 판은 되도록 남긴다).
  static Future<void> _addToHistory(SharedPreferences prefs, FreecellRecord r) async {
    final list = await loadHistory();
    list.removeWhere((e) => e.gaveUp && e.deal == r.deal);
    list.insert(0, r);
    while (list.length > maxHistory) {
      final i = list.lastIndexWhere((e) => !e.gaveUp);
      list.removeAt(i < 0 ? list.length - 1 : i);
    }
    await prefs.setString(_historyKey, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 최신 순.
  static Future<List<FreecellRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) FreecellRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_historyKey);
      return [];
    }
  }
}
