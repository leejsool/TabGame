import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_topology.dart';

void main() {
  test('처음 판: 영역 하나에 모든 점, 점 쌍마다 둘 수 있다', () {
    final b = SproutsBoard.initial(3, Random(1));
    final r = analyzeRegions(b);
    expect(r.regions.length, 1);
    expect(r.regions.single, {0, 1, 2});
    expect(r.hasMove(b), isTrue);
    expect(r.allPairs(b).where((p) => p.$1 != p.$2).length, 3);
    expect(r.allPairs(b).where((p) => p.$1 == p.$2).length, 3); // 점마다 고리도 가능
  });

  test('고리 안에 갇힌 점은 바깥의 점과 이을 수 없다 (위상)', () {
    // 점 0에서 나와 점 0으로 돌아오는 고리 안에 점 1을 가둔다
    final b = SproutsBoard([Dot(const P(200, 200), 3), Dot(const P(200, 150), 3), Dot(const P(330, 330), 3)], []);
    final loop = [for (var i = 1; i < 60; i++) P(200 + 70 * sin(i * 2 * pi / 60) * 1.0, 200 - 70 * (1 - cos(i * 2 * pi / 60)) / 1.0 * 0.0 - 50 * (1 - cos(i * 2 * pi / 60)))];
    // 위 곡선은 점 0에서 위로 올라가 한 바퀴 도는 고리 (점 1을 둘러싼다)
    final r = b.validate(0, 0, [for (var i = 1; i < 60; i++) P(200 + 60 * sin(i * 2 * pi / 60), 200 - 55 * (1 - cos(i * 2 * pi / 60)))]);
    expect(r.ok, isTrue, reason: r.reason);
    b.apply(0, 0, r, 0);
    expect(loop.isNotEmpty, isTrue);
    final regions = analyzeRegions(b);
    final countTopo = countTopology(b);
    // 안쪽 영역과 바깥 영역: 영역 수 = 오일러 계산의 영역 + 1(바깥)
    expect(regions.regions.length, countTopo.regions + 1);
    // 점 1은 안쪽 영역에만, 점 2는 바깥 영역에만 있다
    final regionWith1 = regions.regions.firstWhere((s) => s.contains(1));
    expect(regionWith1.contains(2), isFalse);
    expect(regions.allPairs(b).any((p) => p == (1, 2)), isFalse);
    expect(regions.allPairs(b).any((p) => p == (0, 2)), isTrue);
  });

  test('무작위로 끝까지 두며 영역 수가 칠하기 방식과 늘 같고, 위상적으로 끝난 판은 기하로도 끝났다', () {
    var checked = 0;
    for (final n in [2, 3, 4, 5, 6]) {
      for (var seed = 1; seed <= 8; seed++) {
        final rng = Random(seed * 7 + n);
        final b = SproutsBoard.initial(n, rng);
        var moves = 0;
        while (true) {
          final reg = analyzeRegions(b);
          final topo = countTopology(b);
          // 오일러 공식: 영역(바깥 제외) = 선 + 부분 − 점. 칠하기 방식은 아주 좁은 틈에서 한 칸 어긋날 수 있어 이 식과 비교한다.
          expect(reg.regions.length, topo.lines + topo.parts - topo.points + 1, reason: 'n=$n seed=$seed 수=$moves $topo');
          checked++;
          final ms = findMoves(b);
          if (!reg.hasMove(b)) {
            expect(ms, isEmpty, reason: 'n=$n seed=$seed: 위상적으로 끝났는데 기하로는 수가 있다고 나왔어요');
            break;
          }
          if (ms.isEmpty) break; // (위상으로는 있지만 기하로 못 찾는 경우)
          // 기하로 찾은 수는 모두 위상적으로도 둘 수 있는 점 쌍이어야 한다 (영역 계산이 틀리지 않았다는 확인)
          final pairs = reg.allPairs(b).toSet();
          for (final m in ms) {
            final key = (min(m.s, m.e), max(m.s, m.e));
            expect(pairs.contains(key), isTrue, reason: 'n=$n seed=$seed 수=$moves: 점 ${m.s}→${m.e}은 위상적으로 안 되는 쌍이라고 나왔어요');
          }
          final m = ms[rng.nextInt(ms.length)];
          b.apply(m.s, m.e, m.result, moves++ % 2);
        }
      }
    }
    expect(checked, greaterThan(100));
  }, timeout: const Timeout(Duration(minutes: 5)), tags: 'slow');
}
