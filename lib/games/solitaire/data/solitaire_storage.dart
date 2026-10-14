import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/solitaire_controller.dart';

/// 한 판의 기록: 완성했거나, 포기한 판.
class SolitaireRecord {
  const SolitaireRecord({
    required this.at,
    required this.deal,
    required this.draw,
    required this.seconds,
    required this.moves,
    this.gaveUp = false,
  });

  final int at;
  final int deal;

  /// 한 번에 뽑은 장수 (1 또는 3).
  final int draw;
  final int seconds;
  final int moves;

  /// 포기한 판인가 (그러면 [deal]·[draw]로 다시 도전할 수 있고, [seconds]·[moves]는 포기하기까지의 값).
  final bool gaveUp;

  Map<String, dynamic> toJson() => {
        'at': at,
        'deal': deal,
        'draw': draw,
        'sec': seconds,
        'mv': moves,
        if (gaveUp) 'gu': 1,
      };

  static SolitaireRecord fromJson(Map<String, dynamic> j) => SolitaireRecord(
        at: j['at'] as int,
        deal: j['deal'] as int,
        draw: j['draw'] as int,
        seconds: j['sec'] as int,
        moves: j['mv'] as int,
        gaveUp: j['gu'] == 1,
      );
}

/// 뽑기 장수별 통계.
class SolitaireStats {
  const SolitaireStats({this.starts = 0, this.wins = 0, this.bestSeconds, this.bestMoves});

  final int starts;
  final int wins;
  final int? bestSeconds;
  final int? bestMoves;

  double get winRate => starts == 0 ? 0 : (wins / starts).clamp(0.0, 1.0);
}

/// 진행 중인 판과 기록을 기기에 저장한다.
class SolitaireStorage {
  SolitaireStorage._();

  static const _saveKey = 'solitaire.save';
  static const _historyKey = 'solitaire.history';
  static const maxHistory = 100;

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static SolitaireController? _active;

  static void setActive(SolitaireController c) => _active = c;

  static Future<void> save(SolitaireController c) async {
    if (!identical(c, _active) || c.completed || c.gaveUp || c.untouched) return;
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

  static Future<void> clearSave(SolitaireController c) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  /// 마지막으로 고른 뽑기 장수.
  static Future<int> loadDraw() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('solitaire.draw') == 3 ? 3 : 1;
  }

  static Future<void> saveDraw(int draw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('solitaire.draw', draw);
  }

  /// 새 판을 시작할 때 (이어하기는 제외) 도전 횟수를 센다.
  static Future<void> recordStart(int draw) async {
    final prefs = await SharedPreferences.getInstance();
    final k = 'solitaire.starts$draw';
    await prefs.setInt(k, (prefs.getInt(k) ?? 0) + 1);
  }

  static Future<SolitaireStats> stats(int draw) async {
    final prefs = await SharedPreferences.getInstance();
    return SolitaireStats(
      starts: prefs.getInt('solitaire.starts$draw') ?? 0,
      wins: prefs.getInt('solitaire.wins$draw') ?? 0,
      bestSeconds: prefs.getInt('solitaire.bestTime$draw'),
      bestMoves: prefs.getInt('solitaire.bestMoves$draw'),
    );
  }

  /// 완성 기록. 시간이나 이동 수가 (같은 뽑기 장수 중) 최고 기록이면 true.
  static Future<bool> recordWin(SolitaireRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final d = r.draw;
    await prefs.setInt('solitaire.wins$d', (prefs.getInt('solitaire.wins$d') ?? 0) + 1);
    var best = false;
    final bt = prefs.getInt('solitaire.bestTime$d');
    if (bt == null || r.seconds < bt) {
      await prefs.setInt('solitaire.bestTime$d', r.seconds);
      best = true;
    }
    final bm = prefs.getInt('solitaire.bestMoves$d');
    if (bm == null || r.moves < bm) {
      await prefs.setInt('solitaire.bestMoves$d', r.moves);
      best = true;
    }
    await _addToHistory(prefs, r);
    return best;
  }

  /// 포기한 판을 기록에 남긴다 (같은 판을 또 포기하면 가장 최근 것만 남는다).
  static Future<void> recordGiveUp(SolitaireRecord r) async {
    assert(r.gaveUp);
    await _addToHistory(await SharedPreferences.getInstance(), r);
  }

  /// 같은 판(번호 + 뽑기 장수)의 포기 기록은 지우고(포기했던 판을 완성했거나 또 포기한 경우) 맨 앞에 더한다.
  /// 넘치면 오래된 완성 기록부터 지운다 (다시 도전할 수 있는 포기한 판은 되도록 남긴다).
  static Future<void> _addToHistory(SharedPreferences prefs, SolitaireRecord r) async {
    final list = await loadHistory();
    list.removeWhere((e) => e.gaveUp && e.deal == r.deal && e.draw == r.draw);
    list.insert(0, r);
    while (list.length > maxHistory) {
      final i = list.lastIndexWhere((e) => !e.gaveUp);
      list.removeAt(i < 0 ? list.length - 1 : i);
    }
    await prefs.setString(_historyKey, jsonEncode([for (final e in list) e.toJson()]));
  }

  /// 최신 순.
  static Future<List<SolitaireRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) SolitaireRecord.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_historyKey);
      return [];
    }
  }
}
