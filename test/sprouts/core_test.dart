import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart' show boardIsPlanar;
import 'package:tabgame/games/sprouts/core/sprouts_topology.dart';

SproutsBoard twoDots() => SproutsBoard([Dot(const P(100, 200), 3), Dot(const P(300, 200), 3)], []);

List<P> line(P a, P b, [int n = 12]) => [for (var i = 1; i < n; i++) P(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n)];

void main() {
  group('기하 도구', () {
    test('resample은 처음·끝을 지키고 간격이 고르다', () {
      final r = resample([const P(0, 0), const P(30, 0), const P(30, 40)], 3);
      expect(r.first, const P(0, 0));
      expect(r.last, const P(30, 40));
      for (var i = 1; i < r.length - 1; i++) {
        expect(r[i].dist(r[i - 1]), closeTo(3, 0.6));
      }
      expect(pathLength(r), closeTo(70, 0.5));
    });

    test('pointSegDist / pointAtArc', () {
      expect(pointSegDist(const P(5, 5), const P(0, 0), const P(10, 0)), closeTo(5, 1e-9));
      expect(pointSegDist(const P(-3, 4), const P(0, 0), const P(10, 0)), closeTo(5, 1e-9));
      final mid = pointAtArc([const P(0, 0), const P(10, 0), const P(10, 10)], 15);
      expect(mid.x, closeTo(10, 1e-9));
      expect(mid.y, closeTo(5, 1e-9));
    });
  });

  group('수 판정', () {
    test('두 점을 곡선으로 이으면 목숨이 줄고 가운데에 새 점이 생긴다', () {
      final b = twoDots();
      final r = b.validate(0, 1, line(const P(100, 200), const P(300, 200)));
      expect(r.ok, isTrue, reason: r.reason);
      final mid = b.apply(0, 1, r, 0);
      expect(mid, 2);
      expect(b.dots[0].lives, 2);
      expect(b.dots[1].lives, 2);
      expect(b.dots[2].lives, 1);
      expect(b.dots[2].pos.x, closeTo(200, 25));
      expect(b.totalLives, 5); // 6 → 5: 한 수마다 1씩 줄어든다
    });

    test('고리: 한 점에서 나와 자기 자신에게 돌아오면 목숨 2개를 쓰고, 목숨이 모자라면 안 된다', () {
      final b = twoDots();
      final loop = [for (var i = 1; i < 36; i++) P(100 + 30 * (1 - cos(i * 2 * pi / 36)) * 1.0, 200 - 30 * sin(i * 2 * pi / 36))];
      final r = b.validate(0, 0, loop);
      expect(r.ok, isTrue, reason: r.reason);
      b.apply(0, 0, r, 0);
      expect(b.dots[0].lives, 1);
      // 목숨이 1개뿐인 점에서는 더 못 그린다
      final again = b.validate(0, 0, loop);
      expect(again.ok, isFalse);
    });

    test('다른 선과 만나는 선은 안 된다 (가로지르기)', () {
      final b = SproutsBoard([
        Dot(const P(100, 100), 3),
        Dot(const P(300, 100), 3),
        Dot(const P(140, 40), 3),
        Dot(const P(140, 300), 3),
      ], []);
      final first = b.validate(0, 1, line(const P(100, 100), const P(300, 100)));
      expect(first.ok, isTrue, reason: first.reason);
      b.apply(0, 1, first, 0);
      // 위의 점 2 → 아래의 점 3 : 방금 그린 가로선을 가로지른다
      final cross = b.validate(2, 3, line(const P(140, 40), const P(140, 300), 40));
      expect(cross.ok, isFalse);
      expect(cross.reason, contains('선'));
      // 돌아서 가는 길은 된다
      final around = b.validate(2, 3, [
        for (var i = 1; i < 30; i++) P(140 - 120 * sin(i * pi / 30), 40 + 260 * i / 30),
      ]);
      expect(around.ok, isTrue, reason: around.reason);
    });

    test('다른 점을 지나가거나, 목숨 없는 점에는 이을 수 없다', () {
      final b = SproutsBoard([
        Dot(const P(60, 200), 3),
        Dot(const P(340, 200), 3),
        Dot(const P(200, 200), 3),
        Dot(const P(200, 100), 0),
      ], []);
      final through = b.validate(0, 1, line(const P(60, 200), const P(340, 200), 40));
      expect(through.ok, isFalse);
      expect(through.reason, contains('점'));
      final dead = b.validate(0, 3, line(const P(60, 200), const P(200, 100)));
      expect(dead.ok, isFalse);
    });

    test('자기 자신과 닿거나 판 밖으로 나가는 선은 안 된다', () {
      final b = twoDots();
      // 8자 모양으로 스스로 가로지른다
      final figure8 = <P>[
        const P(150, 120), const P(250, 280), const P(250, 120), const P(150, 280), const P(200, 250),
      ];
      expect(b.validate(0, 1, figure8).ok, isFalse);
      final out = b.validate(0, 1, [const P(100, 100), const P(200, -50), const P(300, 100)]);
      expect(out.ok, isFalse);
    });
  });

  group('수 찾기', () {
    test('처음 판에서는 점 쌍과 고리가 모두 둘 수 있는 수다', () {
      final b = SproutsBoard.initial(3, Random(1));
      final moves = findMoves(b);
      expect(moves.where((m) => !m.isLoop).length, 3); // 점 3개 → 쌍 3개
      expect(moves.any((m) => m.isLoop), isTrue);
      for (final m in moves) {
        expect(m.result.ok, isTrue);
        expect(b.dots[m.s].lives, greaterThanOrEqualTo(m.isLoop ? 2 : 1));
      }
    });

    test('판 데이터를 숫자로 바꿨다가 되돌려도 같다', () {
      final b = SproutsBoard.initial(3, Random(2));
      final m = findMoves(b).firstWhere((m) => !m.isLoop);
      b.apply(m.s, m.e, m.result, 1);
      final c = SproutsBoard.fromData(b.toData());
      expect(c.dots.length, b.dots.length);
      expect(c.curves.length, 1);
      expect(c.curves.first.owner, 1);
      expect(c.curves.first.pts.length, b.curves.first.pts.length);
      expect(c.totalLives, b.totalLives);
    });

    test('무작위로 끝까지 두면 항상 합법이고, 점 n개 판은 2n ~ 3n−1수 안에 끝난다', () {
      for (final n in [2, 3, 4, 5]) {
        for (final seed in [1, 2, 3, 4, 5, 6]) {
          final rng = Random(seed * 10 + n);
          final b = SproutsBoard.initial(n, rng);
          var moves = 0;
          while (true) {
            final ms = findMoves(b);
            if (ms.isEmpty) break;
            final m = ms[rng.nextInt(ms.length)];
            final before = b.totalLives;
            b.apply(m.s, m.e, m.result, moves % 2);
            expect(b.totalLives, before - 1);
            moves++;
            expect(moves, lessThanOrEqualTo(SproutsBoard.maxMoves(n)), reason: 'n=$n seed=$seed');
          }
          expect(moves, greaterThanOrEqualTo(2 * n), reason: 'n=$n seed=$seed 너무 일찍 끝났어요 (수 찾기가 놓친 수가 있을 수 있어요)');
        }
      }
    });
  });

  group('끝난 판', () {
    test('점 3개 판을 끝까지 두면 위상적으로도 둘 수 있는 수가 없다 (자리가 좁아 수를 못 찾아 일찍 끝나는 일이 없다)', () {
      // 이 시드들은 예전에 "고리를 그릴 수 있는데 끝났다"처럼 일찍 끝나던 판이다
      for (final seed in [1, 3, 36, 38, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]) {
        final rng = Random(seed);
        final b = SproutsBoard.initial(3, rng);
        var moves = 0;
        while (true) {
          final ms = findMoves(b);
          if (ms.isEmpty) break;
          final m = ms[rng.nextInt(ms.length)];
          b.apply(m.s, m.e, m.result, moves % 2);
          moves++;
        }
        expect(analyzeRegions(b).hasMove(b), isFalse, reason: 'seed=$seed $moves수 만에 끝났는데 위상적으로는 둘 수 있는 수가 남았어요');
      }
    });
  });

  group('자리가 모자랄 때 점과 선을 옮겨 늘리기', () {
    // 예전에는 "이을 수 있는데 끝났다"고 하던 판들 (점 수, 시드)
    const old = [(4, 3), (4, 5), (4, 75), (4, 82), (4, 105), (5, 2), (5, 5), (5, 19), (5, 47), (5, 48), (5, 51), (5, 55), (5, 57), (5, 106), (5, 113), (5, 120)];

    test('점 4~5개 판도 끝까지 두면 위상적으로 더 둘 수 없을 때만 끝나고, 선은 서로 가로지르지 않는다', () {
      for (final (n, seed) in old) {
        final rng = Random(seed * 31 + n);
        final b = SproutsBoard.initial(n, rng);
        var moves = 0;
        while (true) {
          final ms = findMoves(b);
          if (ms.isEmpty) break;
          final m = ms[rng.nextInt(ms.length)];
          b.apply(m.s, m.e, m.result, moves % 2);
          moves++;
          expect(boardIsPlanar(b), isTrue, reason: 'n=$n seed=$seed $moves번째 수에서 선이 가로질렀어요');
        }
        expect(analyzeRegions(b).hasMove(b), isFalse, reason: 'n=$n seed=$seed $moves수 만에 끝났는데 위상적으로는 둘 수 있는 수가 남았어요');
      }
    });

    test('판을 늘려도 이어진 구조(영역별 점)와 목숨은 그대로이고 선은 가로지르지 않는다', () {
      final rng = Random(9);
      final b = SproutsBoard.initial(4, rng);
      for (var i = 0; i < 6; i++) {
        final ms = findMoves(b, allowRelax: false);
        if (ms.isEmpty) break;
        final m = ms[rng.nextInt(ms.length)];
        b.apply(m.s, m.e, m.result, i % 2);
      }
      final before = analyzeRegions(b);
      for (final f in [1.25, 2.0]) {
        final sb = stretchedBoard(b, f);
        expect(sb, isNotNull, reason: 'f=$f');
        expect(boardIsPlanar(sb!), isTrue);
        expect([for (final d in sb.dots) d.lives], [for (final d in b.dots) d.lives]);
        final after = analyzeRegions(sb);
        Set<String> sig(SproutsRegions r) => {for (final reg in r.regions) (reg.toList()..sort()).join(',')};
        expect(sig(after), sig(before), reason: 'f=$f 영역이 달라졌어요');
      }
    });

    test('자리가 있는 판과 끝난 판에서는 자리를 만들지 않는다', () {
      expect(makeRoom(SproutsBoard.initial(3, Random(1))), isNull);
      final rng = Random(4);
      final b = SproutsBoard.initial(2, rng);
      while (true) {
        final ms = findMoves(b);
        if (ms.isEmpty) break;
        final m = ms[rng.nextInt(ms.length)];
        b.apply(m.s, m.e, m.result, 0);
      }
      expect(makeRoom(b), isNull);
    });

    test('CPU가 고른 수는 점과 선을 밀거나 늘린 배치까지 숫자로 담았다가 그대로 되살린다', () {
      final rng = Random(2);
      final b = SproutsBoard.initial(3, rng);
      final sb = stretchedBoard(b, 1.5)!;
      final base = findMoves(sb, firstOnly: true).first;
      final layout = SproutsLayout([for (final d in sb.dots) d.pos], [for (final c in sb.curves) c.pts], bounds: sb.bounds);
      final move = SproutsMove(base.s, base.e, StrokeResult.ok(base.path, base.result.midIndex, layout: layout));
      final back = decodeCpuMove(encodeMove(move))!;
      expect(back.s, move.s);
      expect(back.e, move.e);
      expect(back.result.midIndex, move.result.midIndex);
      expect(back.path.length, move.path.length);
      expect(back.result.layout, isNotNull);
      expect(back.result.layout!.dots.length, layout.dots.length);
      expect(back.result.layout!.bounds, layout.bounds);
      // 배치가 없는 수도 그대로
      final plain = decodeCpuMove(encodeMove(base))!;
      expect(plain.result.layout, isNull);
      expect(plain.path.length, base.path.length);
    });
  });

  group('위상수학: 점 + 영역 = 선 + 부분', () {
    test('처음 판은 점 n개, 선 0, 영역 0, 부분 n', () {
      final c = countTopology(SproutsBoard.initial(3, Random(1)));
      expect((c.points, c.lines, c.regions, c.parts), (3, 0, 0, 3));
      expect(c.balanced, isTrue);
    });

    test('한 수 두면 점·선이 늘고, 고리를 그리면 영역이 생긴다', () {
      final b = SproutsBoard.initial(2, Random(2));
      final m = findMoves(b).firstWhere((m) => !m.isLoop);
      b.apply(m.s, m.e, m.result, 0);
      var c = countTopology(b);
      expect((c.points, c.lines, c.regions, c.parts), (3, 2, 0, 1));
      final loop = findMoves(b).firstWhere((m) => m.isLoop);
      b.apply(loop.s, loop.e, loop.result, 1);
      c = countTopology(b);
      expect(c.regions, 1);
      expect(c.balanced, isTrue, reason: c.toString());
    });

    test('아무렇게나 끝까지 둬도 매 수마다 오일러 공식이 맞는다 (선이 만났다면 어긋난다)', () {
      for (final n in [2, 3, 4, 5]) {
        for (final seed in [1, 2, 3, 4]) {
          final rng = Random(seed * 31 + n);
          final b = SproutsBoard.initial(n, rng);
          var moves = 0;
          while (true) {
            final c = countTopology(b);
            expect(c.balanced, isTrue, reason: 'n=$n seed=$seed 수=$moves: $c');
            final ms = findMoves(b);
            if (ms.isEmpty) break;
            final m = ms[rng.nextInt(ms.length)];
            b.apply(m.s, m.e, m.result, moves % 2);
            moves++;
          }
        }
      }
    });
  });
}
