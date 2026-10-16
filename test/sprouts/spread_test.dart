import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart';
import 'package:tabgame/games/sprouts/core/sprouts_tidy.dart';

String regionSig(SproutsBoard b) => ([for (final r in analyzeRegions(b).regions) (r.toList()..sort()).join(',')]..sort()).join('|');

double _dir(P o, List<P> pts) {
  P q = pts.last;
  for (final p in pts) {
    if (p.dist(o) >= 6) {
      q = p;
      break;
    }
  }
  return atan2(q.y - o.y, q.x - o.x);
}

/// 점마다 이어진 선들의 순서 (점에서 나가는 방향을 각도 순으로 정렬한 곡선 번호들).
List<List<int>> fanOrder(SproutsBoard b) {
  final out = <List<int>>[];
  for (var d = 0; d < b.dots.length; d++) {
    final o = b.dots[d].pos;
    final items = <(double, int)>[];
    for (var ci = 0; ci < b.curves.length; ci++) {
      final c = b.curves[ci];
      if (c.from == d) items.add((_dir(o, c.pts), ci * 2));
      if (c.to == d) items.add((_dir(o, c.pts.reversed.toList()), ci * 2 + 1));
      if (c.mid == d) {
        var mi = 0;
        for (var i = 0; i < c.pts.length; i++) {
          if (c.pts[i].dist(o) < c.pts[mi].dist(o)) mi = i;
        }
        items.add((_dir(o, c.pts.sublist(mi)), ci * 2));
        items.add((_dir(o, c.pts.sublist(0, mi + 1).reversed.toList()), ci * 2 + 1));
      }
    }
    items.sort((a, c) => a.$1.compareTo(c.$1));
    final ids = [for (final x in items) x.$2];
    if (ids.isEmpty) {
      out.add(ids);
      continue;
    }
    final s = ids.indexOf(ids.reduce(min));
    out.add([...ids.sublist(s), ...ids.sublist(0, s)]);
  }
  return out;
}

/// 서로 다른 선 사이(점 곁은 뺀다)와, 점과 그 점에 안 이어진 선 사이의 가장 좁은 간격.
({double line, double dot}) tightest(SproutsBoard b) {
  var line = double.infinity, dot = double.infinity;
  for (var a = 0; a < b.curves.length; a++) {
    for (var c = a + 1; c < b.curves.length; c++) {
      for (final p in b.curves[a].pts) {
        if (b.dots.any((d) => d.pos.dist(p) <= kNearDot)) continue;
        for (final q in b.curves[c].pts) {
          if (b.dots.any((d) => d.pos.dist(q) <= kNearDot)) continue;
          // 같은 점에서 나온 두 선이 그 점 가까이에서 모여 있는 것은 따지지 않는다 (부챗살)
          final shared = {b.curves[a].from, b.curves[a].to, b.curves[a].mid}.intersection({b.curves[c].from, b.curves[c].to, b.curves[c].mid});
          if (shared.any((d) => b.dots[d].pos.dist(p) < 40 && b.dots[d].pos.dist(q) < 40)) continue;
          line = min(line, p.dist(q));
        }
      }
    }
  }
  for (var d = 0; d < b.dots.length; d++) {
    for (final c in b.curves) {
      if (c.from == d || c.to == d || c.mid == d) continue;
      for (final p in c.pts) {
        dot = min(dot, p.dist(b.dots[d].pos));
      }
    }
  }
  return (line: line, dot: dot);
}

void expectSameTopology(SproutsBoard before, SproutsBoard after, {String reason = ''}) {
  expect(boardIsPlanar(after), isTrue, reason: '$reason 선이 서로 가로지름');
  expect(regionSig(after), regionSig(before), reason: '$reason 영역 구성이 바뀜');
  expect(fanOrder(after), fanOrder(before), reason: '$reason 점 둘레의 선 순서가 바뀜');
  expect(after.dots.length, before.dots.length);
  for (var i = 0; i < before.dots.length; i++) {
    expect(after.dots[i].lives, before.dots[i].lives);
  }
  for (var i = 0; i < before.curves.length; i++) {
    final a = before.curves[i], c = after.curves[i];
    expect((c.from, c.to, c.mid, c.owner), (a.from, a.to, a.mid, a.owner));
    expect(c.pts.first.dist(after.dots[a.from].pos), lessThan(0.01));
    expect(c.pts.last.dist(after.dots[a.to].pos), lessThan(0.01));
    expect(c.pts.any((p) => p.dist(after.dots[a.mid].pos) < 0.01), isTrue, reason: '$reason 새 점이 곡선에서 벗어남');
  }
}

List<P> seg(P a, P c) {
  final r = resample([a, c]);
  r[0] = a;
  r[r.length - 1] = c;
  return r;
}

/// 가로로 나란히 바짝 붙은(13 간격) 곧은 선 두 개.
SproutsBoard twoParallel() {
  final dots = <Dot>[
    Dot(const P(60, 200), 2),
    Dot(const P(340, 200), 2),
    Dot(const P(60, 213), 2),
    Dot(const P(340, 213), 2),
  ];
  final p1 = seg(dots[0].pos, dots[1].pos), p2 = seg(dots[2].pos, dots[3].pos);
  dots
    ..add(Dot(p1[p1.length ~/ 2], 1))
    ..add(Dot(p2[p2.length ~/ 2], 1));
  return SproutsBoard(dots, [
    Curve(from: 0, to: 1, mid: 4, pts: p1, owner: 0),
    Curve(from: 2, to: 3, mid: 5, pts: p2, owner: 1),
  ]);
}

void main() {
  group('선 정리하기: 간격 벌리기', () {
    test('나란히 바짝 붙은 두 선은 간격이 벌어지고 위상은 그대로다', () {
      final b = twoParallel();
      final before = tightest(b);
      expect(before.line, lessThan(14));
      final sp = spreadBoard(b);
      expect(sp, isNotNull);
      expectSameTopology(b, sp!);
      final after = tightest(sp);
      expect(after.line, greaterThan(before.line + 6), reason: '${before.line} → ${after.line}');
      expect(after.line, greaterThan(17));
    });

    test('이미 넉넉한 판과 곡선이 없는 판은 벌릴 것이 없다 (null)', () {
      expect(spreadBoard(SproutsBoard.initial(3, Random(1))), isNull);
      final a = const P(60, 200), c = const P(340, 200);
      final pts = seg(a, c);
      final b = SproutsBoard([Dot(a, 2), Dot(c, 2), Dot(pts[pts.length ~/ 2], 1)], [Curve(from: 0, to: 1, mid: 2, pts: pts, owner: 0)]);
      expect(spreadBoard(b), isNull);
    });

    test('손으로 구불구불 그은 선들로 판을 채워도 (정리한 뒤) 벌리면 위상은 그대로고 가장 좁은 간격은 넓어진다 (무작위 판)', () {
      var spreadCount = 0, tightBefore = 0.0, tightAfter = 0.0;
      for (final n in [3, 4, 5]) {
        for (var seed = 1; seed <= 6; seed++) {
          final rng = Random(seed * 17 + n);
          final b = SproutsBoard.initial(n, rng);
          var moves = 0;
          while (moves < 3 * n) {
            final ms = findMoves(b);
            if (ms.isEmpty) break;
            final m = ms[rng.nextInt(ms.length)];
            b.apply(m.s, m.e, m.result, moves % 2);
            moves++;
            if (moves < 3 || moves % 2 == 1) continue;
            final t = tidyBoard(b) ?? b;
            final sp = spreadBoard(t);
            if (sp == null) continue;
            spreadCount++;
            expectSameTopology(t, sp, reason: 'n=$n seed=$seed 수=$moves');
            expect(analyzeRegions(sp).allPairs(sp), analyzeRegions(t).allPairs(t), reason: 'n=$n seed=$seed 수=$moves');
            final before = tightest(t), after = tightest(sp);
            final bl = min(before.line, 22.0), al = min(after.line, 22.0); // 목표 간격(22)을 넘으면 더 넓은 것은 따지지 않는다
            expect(al, greaterThanOrEqualTo(bl - 1), reason: 'n=$n seed=$seed 수=$moves: 선 간격이 좁아졌어요 $bl → $al');
            tightBefore += bl;
            tightAfter += al;
          }
        }
      }
      expect(spreadCount, greaterThan(3));
      expect(tightAfter, greaterThan(tightBefore));
      // ignore: avoid_print
      print('간격 벌리기: $spreadCount번, 가장 좁은 선 간격 평균 ${(tightBefore / spreadCount).toStringAsFixed(1)} → ${(tightAfter / spreadCount).toStringAsFixed(1)}');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('선 정리하기 작업(isolate)은 정리하고 벌린 판 데이터를 돌려준다', () {
      final b = twoParallel();
      final r = sproutsTidyAndRoomTask(b.toData());
      expect(r[0], isNotEmpty);
      final nb = SproutsBoard.fromData(r[0]);
      expectSameTopology(b, nb);
      expect(tightest(nb).line, greaterThan(tightest(b).line + 6));
    });
  });
}
