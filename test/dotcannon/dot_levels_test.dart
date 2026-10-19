import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/dotcannon/core/dot_levels.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';
import 'package:tabgame/games/dotcannon/core/dot_stages.dart';

void main() {
  test('모든 단계의 그림은 줄 길이가 같고 모든 색이 그림에 쓰인다', () {
    for (final l in dotLevels) {
      expect(l.pixels.length, l.width * l.height, reason: l.name);
      final used = l.pixels.toSet();
      for (var i = 0; i < l.colorCount; i++) {
        expect(used.contains(i), isTrue, reason: '${l.name}: $i번 색이 그림에 없어요');
      }
      expect(used.every((c) => c == kDotEmpty || (c >= 0 && c < l.colorCount)), isTrue, reason: l.name);
    }
  });

  test('단계 이름과 이름표는 겹치지 않는다', () {
    expect({for (final l in dotLevels) l.id}.length, dotLevels.length);
  });

  test('대포의 탄 합계는 색별 도트 수와 같다', () {
    for (final l in dotLevels) {
      final g = l.newGame();
      final ammo = List<int>.filled(l.colorCount, 0);
      for (final q in g.queue) {
        for (final c in q) {
          ammo[c.color] += c.ammo;
        }
      }
      expect(ammo, g.remainingByColor(l.colorCount), reason: l.name);
    }
  });

  test('모든 단계는 풀 수 있다 (간단한 규칙으로 끝까지 돌려 본다)', () {
    for (final l in dotLevels) {
      expect(botSolves(l.newGame()), isTrue, reason: '${l.name}: 풀리지 않는 배치예요 (seed ${l.seed})');
    }
  });

  test('단계를 JSON으로 바꿨다가 되살려도 같은 판이 된다', () {
    for (final l in dotLevels) {
      final back = DotLevel.fromJson(l.toJson());
      expect(back.newGame().toJson(), l.newGame().toJson(), reason: l.name);
    }
  });

  test('그림 칸을 길이 부호화했다가 풀어도 같다', () {
    final px = [kDotEmpty, kDotEmpty, 0, 0, 0, 1, kDotEmpty, 25, 25, 12];
    expect(encodeDotRuns(px), '.2a3b1.1z2m1');
    expect(decodeDotRuns(encodeDotRuns(px)), px);
    for (final l in dotLevels) {
      expect(decodeDotRuns(encodeDotRuns(l.pixels)), l.pixels, reason: l.name);
    }
  });

  test('기본 단계는 손으로 만든 4개 이상이다', () {
    expect(dotLevels.length, greaterThanOrEqualTo(4));
  });
}
