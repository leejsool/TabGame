import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/rhythm/data/rhythm_storage.dart';

void main() {
  test('보정한 적이 없으면 기본값은 0ms', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await RhythmStorage.loadOffsetMs(), 0);
  });

  test('예전 기본값(70ms)이 저장돼 있으면 한 번만 0으로 돌린다', () async {
    SharedPreferences.setMockInitialValues({'rhythm.offsetMs': 70});
    expect(await RhythmStorage.loadOffsetMs(), 0);
    // 그 뒤에 사람이 직접 70ms로 정하면 그대로 둔다
    await RhythmStorage.saveOffsetMs(70);
    expect(await RhythmStorage.loadOffsetMs(), 70);
  });

  test('직접 잰 다른 값은 그대로 둔다', () async {
    SharedPreferences.setMockInitialValues({'rhythm.offsetMs': 95});
    expect(await RhythmStorage.loadOffsetMs(), 95);
    SharedPreferences.setMockInitialValues({'rhythm.offsetMs': -20});
    expect(await RhythmStorage.loadOffsetMs(), -20);
  });
}
