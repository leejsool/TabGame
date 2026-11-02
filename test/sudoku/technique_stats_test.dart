import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/sudoku/data/technique_stats.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('연습 횟수는 모두, 평균 시간은 스스로 찾은 것만 센다', () async {
    await TechniqueStats.record('xWing', seconds: 30, found: true);
    await TechniqueStats.record('xWing', seconds: 90, found: true);
    await TechniqueStats.record('xWing', seconds: 500, found: false);
    final s = (await TechniqueStats.load())['xWing']!;
    expect(s.count, 3);
    expect(s.averageSeconds, 60);
    expect((await TechniqueStats.load())['claiming'], isNull);
  });

  test('읽기 쉬운 시간', () {
    expect(spokenTime(42), '42초');
    expect(spokenTime(60), '1분');
    expect(spokenTime(65), '1분 5초');
  });
}
