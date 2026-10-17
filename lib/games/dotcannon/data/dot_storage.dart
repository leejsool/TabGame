import 'package:shared_preferences/shared_preferences.dart';

import '../core/dot_levels.dart';

/// 한 단계의 기록.
class DotStageStats {
  const DotStageStats({this.wins = 0, this.bestSeconds, this.bestDeploys});

  final int wins;
  final int? bestSeconds;

  /// 가장 적게 올린 대포 수.
  final int? bestDeploys;

  bool get cleared => wins > 0;
}

/// 새 기록이 어떤 최고 기록을 깼는지.
class DotBest {
  const DotBest({this.time = false, this.deploys = false});

  final bool time;
  final bool deploys;

  bool get any => time || deploys;
}

/// 단계별 기록을 기기에 저장한다. (이어하던 판은 `GameSave`가 보관한다)
class DotStorage {
  DotStorage._();

  static String _k(String what, String level) => 'dotcannon.$what.$level';

  static Future<DotStageStats> stats(String level) async {
    final prefs = await SharedPreferences.getInstance();
    return DotStageStats(
      wins: prefs.getInt(_k('wins', level)) ?? 0,
      bestSeconds: prefs.getInt(_k('best', level)),
      bestDeploys: prefs.getInt(_k('bestDeploys', level)),
    );
  }

  /// 단계 이름표 → 기록.
  static Future<Map<String, DotStageStats>> statsFor(Iterable<DotLevel> levels) async => {
        for (final l in levels) l.id: await stats(l.id),
      };

  /// 클리어를 기록하고, 어떤 최고 기록을 깼는지 돌려준다.
  static Future<DotBest> recordWin(String level, {required int seconds, required int deploys}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_k('wins', level), (prefs.getInt(_k('wins', level)) ?? 0) + 1);
    var time = false, dep = false;
    final bt = prefs.getInt(_k('best', level));
    if (bt == null || seconds < bt) {
      await prefs.setInt(_k('best', level), seconds);
      time = true;
    }
    final bd = prefs.getInt(_k('bestDeploys', level));
    if (bd == null || deploys < bd) {
      await prefs.setInt(_k('bestDeploys', level), deploys);
      dep = true;
    }
    return DotBest(time: time, deploys: dep);
  }
}
