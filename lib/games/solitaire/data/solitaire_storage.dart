import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/solitaire_controller.dart';

/// 완성한 판의 기록.
class SolitaireRecord {
  const SolitaireRecord({
    required this.at,
    required this.deal,
    required this.draw,
    required this.seconds,
    required this.moves,
  });

  final int at;
  final int deal;

  /// 한 번에 뽑은 장수 (1 또는 3).
  final int draw;
  final int seconds;
  final int moves;

  Map<String, dynamic> toJson() => {'at': at, 'deal': deal, 'draw': draw, 'sec': seconds, 'mv': moves};

  static SolitaireRecord fromJson(Map<String, dynamic> j) => SolitaireRecord(
        at: j['at'] as int,
        deal: j['deal'] as int,
        draw: j['draw'] as int,
        seconds: j['sec'] as int,
        moves: j['mv'] as int,
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
    final list = await loadHistory();
    list.insert(0, r);
    if (list.length > maxHistory) list.removeRange(maxHistory, list.length);
    await prefs.setString(_historyKey, jsonEncode([for (final e in list) e.toJson()]));
    return best;
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
