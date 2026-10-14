import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/getcolor/core/getcolor_rules.dart';
import 'package:tabgame/games/getcolor/core/getcolor_solver.dart';

WaterState s(List<List<int>> b) => WaterState([for (final x in b) List<int>.of(x)]);

/// 솔버와 따로 만든 단순 탐색 (가지치기 없이 모든 상태를 본다): 풀 수 있으면 true.
bool bruteSolvable(WaterState start, {int limit = 300000}) {
  final seen = <String>{start.key};
  final stack = [start.copy()];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    if (cur.isSolved) return true;
    for (final m in cur.legalMoves()) {
      final n = cur.copy()..pour(m.from, m.to);
      if (seen.add(n.key)) {
        if (seen.length > limit) throw StateError('too big');
        stack.add(n);
      }
    }
  }
  return false;
}

void main() {
  group('붓기 규칙', () {
    test('같은 색 위나 빈 병에만 부을 수 있고, 가득 찬 병에는 못 붓는다', () {
      final w = s([
        [0, 1, 2],
        [3, 2],
        [2, 2, 1, 0],
        [],
      ]);
      expect(w.canPour(0, 1), isTrue); // 2 → 2
      expect(w.canPour(0, 3), isTrue); // 빈 병
      expect(w.canPour(0, 2), isFalse); // 가득 참
      expect(w.canPour(1, 0), isTrue);
      expect(w.canPour(0, 0), isFalse);
      expect(w.canPour(3, 0), isFalse); // 빈 병에서는 못 붓는다
      expect(w.canPour(2, 1), isFalse); // 위 색이 다르다(0 vs 2)
    });

    test('맨 위 같은 색 덩어리는 통째로만 붓고, 다 들어갈 자리가 없으면 일부만 붓지 않는다', () {
      final w = s([
        [1, 0, 0, 0],
        [0, 0],
        [],
      ]);
      expect(w.topRun(0), 3);
      expect(w.canPour(0, 1), isFalse); // 빈 자리가 2칸뿐이라 3칸 덩어리는 못 들어간다
      expect(w.pourAmount(0, 1), 0);
      expect(w.pour(0, 1), 0);
      expect(w.bottles[0], [1, 0, 0, 0]);
      expect(w.bottles[1], [0, 0]);
      expect(w.pourAmount(0, 2), 3);
      expect(w.pour(0, 2), 3);
      expect(w.bottles[0], [1]);
      expect(w.bottles[2], [0, 0, 0]);
      // 이제 한 칸 남은 병 [0,0,0]에 0 한 칸은 들어간다
      final v = s([
        [1, 0],
        [0, 0, 0],
      ]);
      expect(v.canPour(0, 1), isTrue);
      expect(v.pour(0, 1), 1);
      expect(v.isDone(1), isTrue);
    });

    test('남은 자리가 모자라면 같은 색이어도 못 붓는다 (a-a-d-e 를 자리 1칸짜리 a-b-c 위에)', () {
      // 병은 아래→위: 받는 병 [c, b, a] (자리 1칸), 보내는 병 [e, d, a, a]
      final w = s([
        [2, 1, 0],
        [4, 3, 0, 0],
      ]);
      expect(w.canPour(1, 0), isFalse);
      expect(w.legalMoves().contains(const GcMove(1, 0)), isFalse);
      // 받는 병이 비어 있으면(자리 4칸) 같은 덩어리가 들어간다
      final v = s([
        [2, 1, 0],
        [4, 3, 0, 0],
        [],
      ]);
      expect(v.canPour(1, 2), isTrue);
      expect(v.pourAmount(1, 2), 2);
    });

    test('풀린 판: 병마다 비었거나 한 가지 색으로 가득', () {
      expect(s([[0, 0, 0, 0], [1, 1, 1, 1], []]).isSolved, isTrue);
      expect(s([[0, 0, 0], [1, 1, 1, 1], [0]]).isSolved, isFalse);
      expect(s([[0, 0, 0, 1], [1, 1, 1, 0]]).isSolved, isFalse);
    });

    test('복사본을 부어도 원본은 그대로', () {
      final a = s([[0, 1], [1], []]);
      final b = a.copy()..pour(0, 1);
      expect(a.bottles[0], [0, 1]);
      expect(b.bottles[0], [0]);
    });

    test('상태 문자열은 병 순서가 달라도 같다', () {
      expect(s([[0, 1], [2], []]).key, s([[2], [], [0, 1]]).key);
      expect(s([[0, 1], [2], []]).key == s([[1, 0], [2], []]).key, isFalse);
    });
  });

  group('새 판', () {
    test('난이도마다 색·병 수가 맞고, 색마다 정확히 4칸이며 처음부터 끝난 병이 없다', () {
      final rng = Random(5);
      for (final level in GcLevel.values) {
        for (var i = 0; i < 20; i++) {
          final w = WaterState.shuffled(level, rng);
          expect(w.count, level.bottles);
          final tally = <int, int>{};
          for (final b in w.bottles) {
            for (final c in b) {
              tally[c] = (tally[c] ?? 0) + 1;
            }
          }
          expect(tally.length, level.colors);
          expect(tally.values.every((n) => n == kBottleCapacity), isTrue);
          expect(w.bottles.where((b) => b.isEmpty).length, level.empties);
          expect([for (var k = 0; k < w.count; k++) w.isDone(k)].any((d) => d), isFalse);
          expect(w.isSolved, isFalse);
        }
      }
    });

    test('같은 시드면 같은 판', () {
      final a = WaterState.shuffled(GcLevel.hard, Random(9));
      final b = WaterState.shuffled(GcLevel.hard, Random(9));
      expect(a.key, b.key);
      expect(a.bottles, b.bottles);
    });
  });

  group('매우 어려움', () {
    test('13가지 색 + 빈 병 2개 = 병 15개, 맨 마지막 난이도(저장된 기록의 번호가 밀리지 않는다)', () {
      const lv = GcLevel.veryHard;
      expect(lv.colors, 13);
      expect(lv.empties, 2);
      expect(lv.bottles, 15);
      expect(GcLevel.values.last, lv);
      expect(GcLevel.values.indexOf(GcLevel.master), 3);
      expect(lv.candidates, greaterThan(1));
      expect([for (final l in GcLevel.values) if (l != lv) l.candidates].every((c) => c == 1), isTrue);
    });

    test('후보 중 풀이기가 가장 애를 먹은 판을 낸다 (첫 후보보다 어렵거나 같다) + 풀 수 있다', () async {
      for (final seed in [3, 8, 14]) {
        final first = WaterState.shuffled(GcLevel.veryHard, Random(seed));
        final picked = await generateWaterPuzzle(GcLevel.veryHard, Random(seed));
        final r = await solveWater(picked, maxNodes: 200000);
        expect(r.verdict, GcVerdict.winnable, reason: 'seed $seed');
        expect(picked.count, 15);
        expect([for (var k = 0; k < picked.count; k++) picked.isDone(k)].any((d) => d), isFalse);
        final rf = await solveWater(first, maxNodes: 60000);
        if (rf.verdict == GcVerdict.winnable) {
          expect(r.nodes, greaterThanOrEqualTo(rf.nodes), reason: 'seed $seed');
        }
      }
    });

    test('평균적으로 달인보다 풀이기가 훨씬 더 많이 헤맨다', () async {
      Future<double> avgNodes(GcLevel level) async {
        final rng = Random(77);
        var sum = 0;
        const n = 6;
        for (var i = 0; i < n; i++) {
          final r = await solveWater(await generateWaterPuzzle(level, rng), maxNodes: 200000);
          sum += r.nodes;
        }
        return sum / n;
      }

      final master = await avgNodes(GcLevel.master);
      final very = await avgNodes(GcLevel.veryHard);
      expect(very, greaterThan(master * 3), reason: '달인 $master / 매우 어려움 $very');
    });
  });

  group('풀이기', () {
    test('막힌 판은 막혔다고 판정한다', () async {
      final dead = s([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ]);
      expect(dead.legalMoves(), isEmpty);
      final r = await solveWater(dead);
      expect(r.verdict, GcVerdict.lost);
    });

    test('빈 병이 하나 더 있으면 같은 판도 풀린다', () async {
      final w = s([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [],
      ]);
      final r = await solveWater(w);
      expect(r.verdict, GcVerdict.winnable);
      expect(r.path, isNotEmpty);
    });

    test('이미 풀린 판은 수순이 필요 없다', () async {
      final r = await solveWater(s([[0, 0, 0, 0], [1, 1, 1, 1], []]));
      expect(r.verdict, GcVerdict.winnable);
      expect(r.path, isEmpty);
    });

    test('만든 판은 모두 풀 수 있고, 찾은 수순대로 두면 실제로 풀린다', () async {
      final rng = Random(21);
      for (final level in GcLevel.values) {
        for (var i = 0; i < 6; i++) {
          final puzzle = await generateWaterPuzzle(level, rng);
          final r = await solveWater(puzzle);
          expect(r.verdict, GcVerdict.winnable, reason: '${level.label} #$i');
          final play = puzzle.copy();
          for (final m in r.path) {
            expect(play.canPour(m.from, m.to), isTrue, reason: '${level.label} #$i $m');
            play.pour(m.from, m.to);
          }
          expect(play.isSolved, isTrue, reason: '${level.label} #$i');
          expect(puzzle.isSolved, isFalse, reason: '원본은 그대로');
        }
      }
    });

    test('한도가 너무 작으면 모른다고 답하고, 취소해도 멈춘다', () async {
      final puzzle = WaterState.shuffled(GcLevel.master, Random(3));
      expect((await solveWater(puzzle, maxNodes: 2)).verdict, GcVerdict.unknown);
      final c = await solveWater(puzzle, maxNodes: 1000000, cancelled: () => true);
      expect(c.verdict == GcVerdict.unknown || c.verdict == GcVerdict.winnable, isTrue);
    });

    test('"막혔다/풀 수 있다" 판정은 가지치기 없는 단순 탐색과 같다', () async {
      final rng = Random(33);
      var lost = 0, won = 0;
      for (var i = 0; i < 60; i++) {
        // 작은 판(3~4색)을 빈 병 0~1개로 섞어서 막힌 판도 자주 나오게 한다
        final colors = 3 + rng.nextInt(2);
        final empties = rng.nextInt(2);
        final units = [for (var c = 0; c < colors; c++) ...List.filled(kBottleCapacity, c)]..shuffle(rng);
        final w = WaterState([
          for (var b = 0; b < colors; b++) units.sublist(b * kBottleCapacity, (b + 1) * kBottleCapacity),
          for (var e = 0; e < empties; e++) <int>[],
        ]);
        final r = await solveWater(w, maxNodes: 200000);
        expect(r.verdict, isNot(GcVerdict.unknown), reason: 'i=$i');
        final brute = bruteSolvable(w);
        expect(r.verdict == GcVerdict.winnable, brute, reason: 'i=$i ${w.bottles}');
        if (brute) {
          won++;
        } else {
          lost++;
        }
      }
      expect(lost, greaterThan(0));
      expect(won, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
