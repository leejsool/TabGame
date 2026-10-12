import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 코스 한 번의 결과.
class RhythmResult {
  const RhythmResult({required this.stars, required this.accuracy, required this.score, required this.maxCombo});

  final int stars;
  final double accuracy;
  final int score;
  final int maxCombo;
}

/// 입력 보정값과 코스별 최고 기록을 기기에 저장한다.
class RhythmStorage {
  RhythmStorage._();

  static const _kOffset = 'rhythm.offsetMs';

  /// 코스 0(훈련소 입소)은 예전 키를 그대로 쓰고, 그 뒤 코스는 'rhythm.c1.' 처럼 구분한다.
  static String _p(int course) => course == 0 ? 'rhythm.' : 'rhythm.c$course.';

  /// 보정을 한 적이 없을 때의 기본값: 안드로이드는 소리·터치 지연이 평균적으로 있어서 조금 빼 준다.
  static int get defaultOffsetMs => defaultTargetPlatform == TargetPlatform.android ? 70 : 0;

  /// 탭 보정(밀리초). 양수 = 기기가 늦게 반응해서 그만큼 빼 준다.
  static Future<int> loadOffsetMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kOffset) ?? defaultOffsetMs;
  }

  static Future<void> saveOffsetMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOffset, ms.clamp(-300, 300));
  }

  static Future<RhythmResult?> loadBest([int course = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    final p = _p(course);
    final score = prefs.getInt('${p}best.score');
    if (score == null) return null;
    return RhythmResult(
      stars: prefs.getInt('${p}best.stars') ?? 0,
      accuracy: prefs.getDouble('${p}best.acc') ?? 0,
      score: score,
      maxCombo: 0,
    );
  }

  /// 이 코스의 최고 별 개수 (한 번도 안 했으면 0).
  static Future<int> bestStars([int course = 0]) async => (await loadBest(course))?.stars ?? 0;

  static Future<int> clears([int course = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_p(course)}clears') ?? 0;
  }

  /// 결과를 남기고, 최고 기록이면 true. 별이 더 적더라도 점수가 높으면 최고 기록이 되지만,
  /// 별 개수는 지금까지의 최고를 유지한다 (한 번 통과한 코스가 다시 잠기지 않도록).
  static Future<bool> record(RhythmResult r, [int course = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    final p = _p(course);
    await prefs.setInt('${p}clears', (prefs.getInt('${p}clears') ?? 0) + 1);
    final bestScore = prefs.getInt('${p}best.score');
    final bestStars = prefs.getInt('${p}best.stars') ?? 0;
    final isBest = bestScore == null || r.score > bestScore;
    if (isBest) {
      await prefs.setInt('${p}best.score', r.score);
      await prefs.setDouble('${p}best.acc', r.accuracy);
    }
    if (r.stars > bestStars || bestScore == null) {
      await prefs.setInt('${p}best.stars', r.stars);
    }
    return isBest;
  }
}
