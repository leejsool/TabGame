import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/getcolor_rules.dart';
import '../game/getcolor_controller.dart';

/// 한 판의 기록: 클리어했거나, 포기한 판.
class GetColorRecord {
  const GetColorRecord({
    required this.at,
    required this.level,
    required this.seconds,
    required this.moves,
    this.gaveUp = false,
    this.initial,
  });

  final int at;
  final GcLevel level;
  final int seconds;

  /// 붓기 횟수.
  final int moves;

  /// 포기한 판인가 (그러면 [initial]로 같은 판에 다시 도전할 수 있다).
  final bool gaveUp;

  /// 처음 병 상태. 포기한 판에만 저장한다 (클리어 기록에서는 같은 판의 포기 기록을 지우는 데만 쓴다).
  final List<List<int>>? initial;

  /// 같은 판인지 알아보는 열쇠 (병 순서가 달라도 같은 판이면 같다).
  String? get boardKey => initial == null ? null : WaterState([for (final b in initial!) b]).key;

  Map<String, dynamic> toJson() => {
        'at': at,
        'lv': level.index,
        'sec': seconds,
        'mv': moves,
        if (gaveUp) 'gu': 1,
        if (gaveUp && initial != null) 'init': initial,
      };

  static GetColorRecord fromJson(Map<String, dynamic> j) => GetColorRecord(
        at: j['at'] as int,
        level: GcLevel.values[(j['lv'] as int).clamp(0, GcLevel.values.length - 1)],
        seconds: j['sec'] as int,
        moves: j['mv'] as int,
        gaveUp: j['gu'] == 1,
        initial: j['init'] == null ? null : [for (final b in j['init'] as List) List<int>.from(b as List)],
      );
}

class GetColorStats {
  const GetColorStats({this.wins = 0, this.bestSeconds, this.bestMoves, this.gaveUps = 0});

  final int wins;
  final int? bestSeconds;
  final int? bestMoves;

  /// 포기한 횟수.
  final int gaveUps;
}

/// 새 기록이 어떤 최고 기록을 깼는지.
class GetColorBest {
  const GetColorBest({this.time = false, this.moves = false});

  final bool time;
  final bool moves;

  bool get any => time || moves;
}

/// 진행 중인 판과 기록을 기기에 저장한다.
class GetColorStorage {
  GetColorStorage._();

  static const _saveKey = 'getcolor.save';
  static const _historyKey = 'getcolor.history';
  static const maxHistory = 100;

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static GetColorController? _active;

  static void setActive(GetColorController c) => _active = c;

  static Future<void> save(GetColorController c) async {
    if (!identical(c, _active) || c.completed || c.untouched) return;
    final json = jsonEncode(c.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, json);
  }

  static Future<Map<String, dynamic>?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      // 읽어 보고 깨져 있으면 버린다
      GetColorController.fromJson(j).dispose();
      return j;
    } catch (_) {
      await prefs.remove(_saveKey);
      return null;
    }
  }

  static Future<void> clearSave(GetColorController c) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  /// 마지막으로 고른 난이도.
  static Future<GcLevel> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt('getcolor.level') ?? 0;
    return GcLevel.values[i.clamp(0, GcLevel.values.length - 1)];
  }

  static Future<void> saveLevel(GcLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('getcolor.level', level.index);
  }

  static Future<GetColorStats> stats(GcLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    final i = level.index;
    return GetColorStats(
      wins: prefs.getInt('getcolor.wins$i') ?? 0,
      bestSeconds: prefs.getInt('getcolor.best$i'),
      bestMoves: prefs.getInt('getcolor.bestMoves$i'),
      gaveUps: prefs.getInt('getcolor.giveups$i') ?? 0,
    );
  }

  /// 클리어 기록. 그 난이도의 최고 기록(시간/붓기 횟수)을 깼는지 돌려준다.
  static Future<GetColorBest> recordWin(GetColorRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final i = r.level.index;
    await prefs.setInt('getcolor.wins$i', (prefs.getInt('getcolor.wins$i') ?? 0) + 1);
    var bestTime = false, bestMoves = false;
    final bt = prefs.getInt('getcolor.best$i');
    if (bt == null || r.seconds < bt) {
      await prefs.setInt('getcolor.best$i', r.seconds);
      bestTime = true;
    }
    final bm = prefs.getInt('getcolor.bestMoves$i');
    if (bm == null || r.moves < bm) {
      await prefs.setInt('getcolor.bestMoves$i', r.moves);
      bestMoves = true;
    }
    final list = await loadHistory();
    // 포기했던 판을 이번에 클리어했으면 "포기한 판"에서 뺀다
    final key = r.boardKey;
    if (key != null) list.removeWhere((e) => e.gaveUp && e.boardKey == key);
    list.insert(0, r);
    await _saveHistory(prefs, list);
    return GetColorBest(time: bestTime, moves: bestMoves);
  }

  /// 포기한 판을 기록에 남긴다 (같은 판을 또 포기하면 가장 최근 것만 남는다).
  static Future<void> recordGiveUp(GetColorRecord r) async {
    assert(r.gaveUp && r.initial != null);
    final prefs = await SharedPreferences.getInstance();
    final i = r.level.index;
    await prefs.setInt('getcolor.giveups$i', (prefs.getInt('getcolor.giveups$i') ?? 0) + 1);
    final list = await loadHistory();
    final key = r.boardKey;
    list.removeWhere((e) => e.gaveUp && e.boardKey == key);
    list.insert(0, r);
    await _saveHistory(prefs, list);
  }

  /// 오래된 것부터 줄이되, 아직 다시 도전할 수 있는 포기한 판은 되도록 남긴다.
  static Future<void> _saveHistory(SharedPreferences prefs, List<GetColorRecord> list) async {
    while (list.length > maxHistory) {
      final at = list.lastIndexWhere((e) => !e.gaveUp);
      list.removeAt(at < 0 ? list.length - 1 : at);
    }
    await prefs.setString(_historyKey, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 최신 순.
  static Future<List<GetColorRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) GetColorRecord.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      await prefs.remove(_historyKey);
      return [];
    }
  }
}
