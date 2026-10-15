import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart';
import 'package:tabgame/games/sprouts/core/sprouts_tidy.dart';
import 'package:tabgame/games/sprouts/core/sprouts_topology.dart';

/// 곡선 하나를 가진 판: 점들 [dots] 중 0 → 새 점 → 1을 [path]로 잇는다 (새 점은 path 위의 [midIndex]번째 자리).
SproutsBoard oneCurve(List<P> dots, List<P> path, int midIndex) {
  final ds = [for (final p in dots) Dot(p, 3)];
  ds[0].lives = 2;
  ds[1].lives = 2;
  final pts = resample(path);
  pts[0] = dots[0];
  pts[pts.length - 1] = dots[1];
  // resample 뒤에도 새 점이 곡선 위에 오도록, 곡선에서 가장 가까운 점으로 놓는다
  var best = 0;
  for (var i = 0; i < pts.length; i++) {
    if (pts[i].dist(path[midIndex]) < pts[best].dist(path[midIndex])) best = i;
  }
  ds.add(Dot(pts[best], 1));
  return SproutsBoard(ds, [Curve(from: 0, to: 1, mid: ds.length - 1, pts: pts, owner: 0)]);
}

double totalLength(SproutsBoard b) => b.curves.fold(0.0, (s, c) => s + pathLength(c.pts));

String regionSig(SproutsBoard b) =>
    ([for (final r in analyzeRegions(b).regions) (r.toList()..sort()).join(',')]..sort()).join('|');

/// 위상이 그대로인지 확인한다.
void expectSameTopology(SproutsBoard before, SproutsBoard after, {String reason = ''}) {
  expect(boardIsPlanar(after), isTrue, reason: '$reason 선이 서로 가로지름');
  expect(regionSig(after), regionSig(before), reason: '$reason 영역 구성이 바뀜');
  expect(countTopology(after).toString(), countTopology(before).toString(), reason: reason);
  expect(after.dots.length, before.dots.length);
  expect(after.curves.length, before.curves.length);
  for (var i = 0; i < before.dots.length; i++) {
    expect(after.dots[i].pos, before.dots[i].pos, reason: '$reason 점은 움직이지 않는다');
    expect(after.dots[i].lives, before.dots[i].lives);
  }
  for (var i = 0; i < before.curves.length; i++) {
    final a = before.curves[i], c = after.curves[i];
    expect((c.from, c.to, c.mid, c.owner), (a.from, a.to, a.mid, a.owner));
    expect(c.pts.first, before.dots[a.from].pos);
    expect(c.pts.last, before.dots[a.to].pos);
    // 새 점은 여전히 곡선 위에 있다
    final m = before.dots[a.mid].pos;
    expect(c.pts.any((p) => p.dist(m) < 0.01), isTrue, reason: '$reason 새 점이 곡선에서 벗어남');
  }
}

void main() {
  group('선 정리하기', () {
    test('구불구불한 선은 곧게 펴진다 (빈 판)', () {
      const a = P(60, 200), c = P(340, 200);
      final path = <P>[
        for (var x = 60.0; x <= 340; x += 2) P(x, 200 + 55 * sin((x - 60) / 14)),
      ];
      final b = oneCurve([a, c, const P(200, 400)], path, path.length ~/ 2);
      final before = totalLength(b);
      final t = tidyBoard(b);
      expect(t, isNotNull);
      expect(totalLength(t!), lessThan(before * 0.6));
      expect(totalLength(t), closeTo(280, 20)); // 거의 곧은 선
      expectSameTopology(b, t);
    });

    test('올가미처럼 크게 돌아가는 선도 펴진다', () {
      const a = P(80, 230), c = P(320, 230);
      final path = <P>[
        for (var x = 80.0; x <= 150; x += 3) P(x, 230),
        // 위로 한 바퀴 크게 돈다 (아무것도 안 감싼다)
        for (var t = 0.0; t <= 2 * pi; t += 0.1) P(150 + 35 * sin(t), 195 + 35 * cos(t)),
        for (var x = 153.0; x <= 320; x += 3) P(x, 230),
      ];
      final b = oneCurve([a, c, const P(200, 420)], path, 3);
      final t = tidyBoard(b);
      expect(t, isNotNull);
      expect(totalLength(t!), lessThan(totalLength(b) * 0.9));
      expectSameTopology(b, t);
    });

    test('점을 감싸고 돌아가는 선은 그 점을 가로질러 펴지지 않는다', () {
      const a = P(60, 200), c = P(60, 400), pole = P(200, 300);
      final path = <P>[
        for (var i = 0; i <= 40; i++) P(60 + 240 * i / 40, 200),
        for (var i = 1; i <= 20; i++) P(300 + 40 * sin(pi * i / 20), 200 + 200 * i / 20),
        for (var i = 1; i <= 40; i++) P(300 - 240 * i / 40, 400),
      ];
      final b = oneCurve([a, c, pole], path, path.length ~/ 2);
      final t = tidyBoard(b) ?? b;
      expectSameTopology(b, t);
      // 감싼 점에서 왼쪽으로 쏜 반직선을 선이 가로지르면 점이 고리 밖으로 쓸려 나간 것이다
      for (final cv in t.curves) {
        for (var i = 0; i + 1 < cv.pts.length; i++) {
          final p = cv.pts[i], q = cv.pts[i + 1];
          final crosses = (p.y - 300) * (q.y - 300) < 0 && (p.x + (q.x - p.x) * (300 - p.y) / (q.y - p.y)) < 200;
          expect(crosses, isFalse, reason: '선이 점을 가로질러 펴졌어요');
        }
        for (final p in cv.pts) {
          if (p.dist(a) < 12 || p.dist(c) < 12) continue;
          expect(p.dist(pole), greaterThan(17));
        }
      }
    });

    test('이미 곧은 선은 정리할 게 없다 (null)', () {
      const a = P(60, 200), c = P(340, 200);
      final path = [for (var x = 60.0; x <= 340; x += 3) P(x, 200)];
      final b = oneCurve([a, c, const P(200, 400)], path, path.length ~/ 2);
      expect(tidyBoard(b), isNull);
      expect(tidyBoard(SproutsBoard.initial(3, Random(1))), isNull); // 곡선이 없는 판
    });

    test('손으로 구불구불 그은 선들로 판을 채워도 위상이 늘 그대로다 (무작위 판)', () {
      var tidied = 0, shortened = 0.0, total = 0.0;
      for (final n in [2, 3, 4, 5]) {
        for (var seed = 1; seed <= 6; seed++) {
          final rng = Random(seed * 31 + n);
          final b = SproutsBoard.initial(n, rng);
          var moves = 0;
          while (moves < 3 * n) {
            final ms = findMoves(b);
            if (ms.isEmpty) break;
            final m = ms[rng.nextInt(ms.length)];
            // 사람처럼 흔들어서 긋는다: 가운데가 크게 출렁이는 선
            final amp = 10 + rng.nextDouble() * 22, freq = 10 + rng.nextDouble() * 10;
            final base = m.path;
            final wiggly = <P>[];
            var arc = 0.0;
            for (var i = 0; i < base.length; i++) {
              if (i > 0) arc += base[i].dist(base[i - 1]);
              final prev = base[max(0, i - 1)], next = base[min(base.length - 1, i + 1)];
              final dx = next.x - prev.x, dy = next.y - prev.y;
              final l = max(1e-6, sqrt(dx * dx + dy * dy));
              final f = sin(pi * i / (base.length - 1)); // 양 끝은 점에 붙인다
              final off = amp * f * sin(arc / freq);
              wiggly.add(P(base[i].x - dy / l * off, base[i].y + dx / l * off));
            }
            final r = b.validate(m.s, m.e, wiggly);
            b.apply(m.s, m.e, r.ok ? r : m.result, moves % 2);
            moves++;

            final t = tidyBoard(b);
            if (t != null) {
              tidied++;
              total += totalLength(b);
              shortened += totalLength(b) - totalLength(t);
              expectSameTopology(b, t, reason: 'n=$n seed=$seed 수=$moves');
              expect(totalLength(t), lessThan(totalLength(b)));
              // 정리한 판에서도 위상적으로 둘 수 있는 수(점 쌍)가 같다
              expect(analyzeRegions(t).allPairs(t), analyzeRegions(b).allPairs(b), reason: 'n=$n seed=$seed 수=$moves');
              // 정리한 판 위에서 게임을 이어 간다
              for (var i = 0; i < t.curves.length; i++) {
                b.curves[i] = t.curves[i];
              }
              b.bounds = t.bounds;
            }
          }
        }
      }
      expect(tidied, greaterThan(10));
      // ignore: avoid_print
      print('선 정리하기: $tidied번 정리, 선 길이 ${(100 * shortened / total).toStringAsFixed(0)}% 줄어듦');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
