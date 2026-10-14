import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/mines_rules.dart';
import '../game/mines_controller.dart';

/// 한 판의 기록: 클리어했거나, 포기한 판.
class MinesRecord {
  const MinesRecord({
    required this.at,
    required this.level,
    required this.seconds,
    this.gaveUp = false,
    this.mines,
    this.opened = 0,
  });

  final int at;
  final MinesLevel level;
  final int seconds;

  /// 포기한 판인가 (그러면 [mines]로 같은 지뢰 배치에 다시 도전할 수 있다).
  final bool gaveUp;

  /// 포기한 판의 지뢰 위치 (칸 번호). 클리어 기록에는 없다.
  final List<int>? mines;

  /// 포기할 때까지 연 칸 수.
  final int opened;

  /// 같은 지뢰 배치인지 알아보는 열쇠.
  String? get boardKey => mines == null ? null : '${level.index}:${(List<int>.of(mines!)..sort()).join(',')}';

  Map<String, dynamic> toJson() => {
        'at': at,
        'lv': level.index,
        'sec': seconds,
        if (gaveUp) 'gu': 1,
        if (gaveUp && mines != null) 'mines': mines,
        if (gaveUp) 'open': opened,
      };

  static MinesRecord fromJson(Map<String, dynamic> j) => MinesRecord(
        at: j['at'] as int,
        level: MinesLevel.values[j['lv'] as int],
        seconds: j['sec'] as int,
        gaveUp: j['gu'] == 1,
        mines: j['mines'] == null ? null : List<int>.from(j['mines'] as List),
        opened: (j['open'] as int?) ?? 0,
      );
}

class MinesStats {
  const MinesStats({this.starts = 0, this.wins = 0, this.bestSeconds});

  final int starts;
  final int wins;
  final int? bestSeconds;

  double get winRate => starts == 0 ? 0 : (wins / starts).clamp(0.0, 1.0);
}

/// 진행 중인 판과 기록을 기기에 저장한다.
class MinesStorage {
  MinesStorage._();

  static const _saveKey = 'mines.save';
  static const _historyKey = 'mines.history';
  static const maxHistory = 100;

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static MinesController? _active;

  static void setActive(MinesController c) => _active = c;

  static Future<void> save(MinesController c) async {
    if (!identical(c, _active) || !c.saveable) return;
    final json = jsonEncode(c.toJson());
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

  static Future<void> clearSave(MinesController c) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  /// 마지막으로 고른 난이도.
  static Future<MinesLevel> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt('mines.level') ?? 0;
    return MinesLevel.values[i.clamp(0, MinesLevel.values.length - 1)];
  }

  static Future<void> saveLevel(MinesLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mines.level', level.index);
  }

  /// 첫 칸을 연 판을 센다 (이어하기는 제외).
  static Future<void> recordStart(MinesLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    final k = 'mines.starts${level.index}';
    await prefs.setInt(k, (prefs.getInt(k) ?? 0) + 1);
  }

  static Future<MinesStats> stats(MinesLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    return MinesStats(
      starts: prefs.getInt('mines.starts${level.index}') ?? 0,
      wins: prefs.getInt('mines.wins${level.index}') ?? 0,
      bestSeconds: prefs.getInt('mines.best${level.index}'),
    );
  }

  /// 클리어 기록. 그 난이도의 최고 기록이면 true.
  static Future<bool> recordWin(MinesRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final i = r.level.index;
    await prefs.setInt('mines.wins$i', (prefs.getInt('mines.wins$i') ?? 0) + 1);
    var best = false;
    final b = prefs.getInt('mines.best$i');
    if (b == null || r.seconds < b) {
      await prefs.setInt('mines.best$i', r.seconds);
      best = true;
    }
    await _addToHistory(prefs, r);
    return best;
  }

  /// 포기한 판을 기록에 남긴다 (같은 배치를 또 포기하면 가장 최근 것만 남는다).
  static Future<void> recordGiveUp(MinesRecord r) async {
    assert(r.gaveUp && r.mines != null);
    await _addToHistory(await SharedPreferences.getInstance(), r);
  }

  /// 같은 배치의 포기 기록은 지우고(포기했던 판을 클리어했거나 또 포기한 경우) 맨 앞에 더한다.
  /// 넘치면 오래된 클리어 기록부터 지운다 (다시 도전할 수 있는 포기한 판은 되도록 남긴다).
  static Future<void> _addToHistory(SharedPreferences prefs, MinesRecord r) async {
    final list = await loadHistory();
    final key = r.boardKey;
    if (key != null) list.removeWhere((e) => e.gaveUp && e.boardKey == key);
    list.insert(0, r);
    while (list.length > maxHistory) {
      final i = list.lastIndexWhere((e) => !e.gaveUp);
      list.removeAt(i < 0 ? list.length - 1 : i);
    }
    await prefs.setString(_historyKey, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 최신 순.
  static Future<List<MinesRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) MinesRecord.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      await prefs.remove(_historyKey);
      return [];
    }
  }
}
