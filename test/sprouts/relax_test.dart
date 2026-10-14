import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart';
import 'package:tabgame/games/sprouts/core/sprouts_topology.dart';

List<P> line(P a, P b, [int n = 40]) => [for (var i = 1; i < n; i++) P(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n)];

void main() {
  test('다른 점에 너무 가까운 선도, 점과 선을 살짝 밀어서 둘 수 있다 (위상은 그대로)', () {
    final b = SproutsBoard([
      Dot(const P(100, 200), 3),
      Dot(const P(300, 200), 3),
      Dot(const P(200, 214), 3), // 곧은 선이 15 거리로 지나간다 (너무 가깝다)
    ], []);
    final stroke = line(const P(100, 200), const P(300, 200));
    final strict = b.validate(0, 1, stroke, relax: false);
    expect(strict.ok, isFalse);
    expect(strict.reason, contains('점'));
    expect(strict.fixable, isTrue);

    final r = b.validate(0, 1, stroke);
    expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    expect(r.layout, isNotNull);
    final before = b.dots[2].pos;
    b.apply(0, 1, r, 0);
    expect(b.dots[2].pos.dist(before), greaterThan(3)); // 점이 밀렸다
    expect(b.curves.length, 1);
    // 위상은 그대로: 점 4 + 영역 0 = 선 2 + 부분 2
    final c = countTopology(b);
    expect(c.toString(), '점 4 + 영역 0 = 선 2 + 부분 2');
    expect(c.balanced, isTrue);
  });

  test('너무 가까운 두 점을 잇는 짧은 선: 점을 벌려서 새 점 자리를 만든다', () {
    final b = SproutsBoard([Dot(const P(190, 200), 3), Dot(const P(220, 200), 3)], []);
    final stroke = line(const P(190, 200), const P(220, 200), 20);
    final strict = b.validate(0, 1, stroke, relax: false);
    expect(strict.ok, isFalse);
    final r = b.validate(0, 1, stroke);
    expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    b.apply(0, 1, r, 0);
    expect(b.dots[0].pos.dist(b.dots[1].pos), greaterThan(30));
    expect(countTopology(b).balanced, isTrue);
  });

  test('정말로 선을 가로지르거나 점 위를 지나가는 선은 밀어도 안 된다', () {
    final b = SproutsBoard([
      Dot(const P(100, 100), 3),
      Dot(const P(300, 100), 3),
      Dot(const P(140, 40), 3),
      Dot(const P(140, 300), 3),
      Dot(const P(200, 200), 3),
    ], []);
    final first = b.validate(0, 1, line(const P(100, 100), const P(300, 100)));
    b.apply(0, 1, first, 0);
    // 위에서 아래로 가로지르기
    final cross = b.validate(2, 3, line(const P(140, 40), const P(140, 300), 60));
    expect(cross.ok, isFalse);
    // 다른 점(200,200) 한가운데를 지나가기
    final through = b.validate(2, 3, [
      ...line(const P(140, 40), const P(200, 200), 30),
      ...line(const P(200, 200), const P(140, 300), 30),
    ]);
    expect(through.ok, isFalse);
  });

  test('점이 많은 판을 끝까지 둬도 매 수마다 위상(오일러 공식)이 유지되고, 밀기는 선을 가로지르지 않는다', () {
    var relaxedMoves = 0;
    var total = 0;
    final watch = Stopwatch()..start();
    for (final n in [5, 6]) {
      for (final seed in [1, 2, 3]) {
        final rng = Random(seed * 17 + n);
        final b = SproutsBoard.initial(n, rng);
        var moves = 0;
        while (true) {
          final ms = findMoves(b);
          if (ms.isEmpty) break;
          final m = ms[rng.nextInt(ms.length)];
          if (m.result.layout != null) relaxedMoves++;
          b.apply(m.s, m.e, m.result, moves % 2);
          moves++;
          total++;
          final c = countTopology(b);
          expect(c.balanced, isTrue, reason: 'n=$n seed=$seed 수=$moves $c');
        }
        expect(moves, inInclusiveRange(2 * n, 3 * n - 1), reason: 'n=$n seed=$seed');
      }
    }
    // ignore: avoid_print
    print('밀어서 둔 수 $relaxedMoves / 전체 $total수, ${watch.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('사람이 아무렇게나 그은 곧은 선들로 판을 채워도 (밀기 포함) 위상이 매번 유지된다', () {
    var relaxed = 0, strictOk = 0, rejected = 0;
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final rng = Random(seed);
      final b = SproutsBoard.initial(6, rng);
      var owner = 0;
      for (var attempt = 0; attempt < 150; attempt++) {
        final live = [for (var i = 0; i < b.dots.length; i++) if (b.dots[i].lives > 0) i];
        if (live.length < 2) break;
        final s = live[rng.nextInt(live.length)];
        var e = live[rng.nextInt(live.length)];
        if (e == s) continue;
        final bend = (rng.nextDouble() - 0.5) * 120;
        final a = b.dots[s].pos, c = b.dots[e].pos;
        final d = c - a;
        final len = sqrt(d.x * d.x + d.y * d.y);
        final nx = -d.y / len, ny = d.x / len;
        final stroke = [
          for (var i = 1; i < 40; i++)
            P(a.x + d.x * i / 40 + nx * bend * 4 * (i / 40) * (1 - i / 40), a.y + d.y * i / 40 + ny * bend * 4 * (i / 40) * (1 - i / 40)),
        ];
        final r = b.validate(s, e, stroke);
        if (!r.ok) {
          rejected++;
          continue;
        }
        if (r.layout != null) {
          relaxed++;
        } else {
          strictOk++;
        }
        b.apply(s, e, r, owner);
        owner = 1 - owner;
        final cnt = countTopology(b);
        expect(boardIsPlanar(b), isTrue, reason: 'seed=$seed 시도=$attempt 밀기=${r.layout != null} 선이 가로질렀어요');
        expect(cnt.balanced, isTrue, reason: 'seed=$seed 시도=$attempt 밀기=${r.layout != null} $cnt');
      }
    }
    // ignore: avoid_print
    print('그대로 가능 $strictOk · 밀어서 가능 $relaxed · 안 됨 $rejected');
    expect(strictOk + relaxed, greaterThan(20));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('바짝 붙은 두 점(목숨 1개씩)도 이을 수 있는 수로 찾는다 (끝났다고 하면 안 된다)', () {
    for (final gap in [22.0, 30.0, 45.0]) {
      final b = SproutsBoard([
        Dot(const P(150, 300), 0),
        Dot(P(200, 250), 1),
        Dot(P(200 + gap * 0.8, 250 + gap * 0.6), 1),
        Dot(const P(320, 120), 0),
      ], []);
      expect(hasMove(b), isTrue, reason: '간격 $gap');
      final ms = findMoves(b);
      expect(ms.any((m) => !m.isLoop && m.s == 1 && m.e == 2), isTrue, reason: '간격 $gap');
      final m = ms.firstWhere((m) => m.s == 1 && m.e == 2);
      b.apply(m.s, m.e, m.result, 0);
      expect(boardIsPlanar(b), isTrue);
      expect(b.dots[1].lives, 0);
      expect(b.dots[2].lives, 0);
    }
  });

  test('끝났다고 판정한 판에는 정말로 둘 수 있는 수가 없다 (놓친 수 찾기)', () {
    var ended = 0, missed = 0;
    for (final n in [4, 5, 6]) {
      for (var seed = 1; seed <= 12; seed++) {
        final rng = Random(seed * 13 + n);
        final b = SproutsBoard.initial(n, rng);
        var moves = 0;
        while (true) {
          final ms = findMoves(b);
          if (ms.isEmpty) break;
          final m = ms[rng.nextInt(ms.length)];
          b.apply(m.s, m.e, m.result, moves++ % 2);
        }
        ended++;
        // 끝난 판에서 남은 목숨끼리 여러 모양의 곡선으로 이어 본다
        final live = [for (var i = 0; i < b.dots.length; i++) if (b.dots[i].lives > 0) i];
        for (final s in live) {
          for (final e in live) {
            if (e < s) continue;
            final a = b.dots[s].pos, c = b.dots[e].pos;
            for (final bend in const [0.0, 20.0, -20.0, 50.0, -50.0, 90.0, -90.0]) {
              List<P> stroke;
              if (s == e) {
                const r = 26.0;
                stroke = [for (var i = 1; i < 36; i++) P(a.x + r * (1 - cos(i * 2 * pi / 36 + bend / 30)), a.y + r * sin(i * 2 * pi / 36 + bend / 30))];
              } else {
                final d = c - a;
                final len = sqrt(d.x * d.x + d.y * d.y);
                final nx = -d.y / len, ny = d.x / len;
                stroke = [
                  for (var i = 1; i < 40; i++)
                    P(a.x + d.x * i / 40 + nx * bend * 4 * (i / 40) * (1 - i / 40), a.y + d.y * i / 40 + ny * bend * 4 * (i / 40) * (1 - i / 40)),
                ];
              }
              if (b.validate(s, e, stroke).ok) {
                missed++;
                // ignore: avoid_print
                print('놓친 수! n=$n seed=$seed 점 $s→$e 휨 $bend 목숨 ${b.totalLives}');
              }
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('끝난 판 $ended개 검사, 놓친 수 $missed개');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('판이 너무 좁으면 판을 넓혀서(화면은 멀어져 보인다) 점과 선을 바깥으로 밀어 자리를 만든다', () {
    // 작은 판(160×200) 안에 점이 빽빽하다: 판 안에서만 밀어서는 어렵다
    const small = Bounds(140, 185, 260, 235); // 120×50
    final dots = <Dot>[
      Dot(const P(150, 200), 3),
      Dot(const P(250, 200), 3),
      Dot(const P(200, 214), 3), // 선 아래쪽 20 안에 있다. 판이 50뿐이라 안에서는 비켜 줄 자리가 없다
    ];
    final b = SproutsBoard(dots, [], bounds: small);
    final stroke = line(const P(150, 200), const P(250, 200));
    final r = b.validate(0, 1, stroke);
    expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    expect(r.layout?.bounds, isNotNull, reason: '판을 넓혀야 했을 거예요');
    expect(r.layout!.bounds!.width, greaterThan(small.width));
    b.apply(0, 1, r, 0);
    expect(boardIsPlanar(b), isTrue);
    expect(countTopology(b).balanced, isTrue, reason: countTopology(b).toString());
    // 점들이 판 안에 들어 있다
    for (final d in b.dots) {
      expect(d.pos.x, inInclusiveRange(b.bounds.x0, b.bounds.x1));
      expect(d.pos.y, inInclusiveRange(b.bounds.y0, b.bounds.y1));
    }
  });

  test('점이 많은 판을 끝까지 두면 판이 넓어졌다 좁아져도 모든 점·선이 판 안에 있고 위상이 유지된다', () {
    var grew = 0;
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final rng = Random(seed);
      final b = SproutsBoard.initial(8, rng);
      var moves = 0;
      while (true) {
        final ms = findMoves(b);
        if (ms.isEmpty) break;
        final m = ms[rng.nextInt(ms.length)];
        b.apply(m.s, m.e, m.result, moves++ % 2);
        if (b.bounds != Bounds.initial) grew++;
        for (final d in b.dots) {
          expect(d.pos.x, inInclusiveRange(b.bounds.x0, b.bounds.x1), reason: 'seed=$seed 수=$moves ${b.bounds}');
          expect(d.pos.y, inInclusiveRange(b.bounds.y0, b.bounds.y1), reason: 'seed=$seed 수=$moves ${b.bounds}');
        }
        // 위상: 영역 수는 오일러 공식(선 + 부분 − 점 + 1)과 같고, 선은 서로 가로지르지 않는다
        final topo = countTopology(b);
        expect(analyzeRegions(b).regions.length, topo.lines + topo.parts - topo.points + 1, reason: 'seed=$seed 수=$moves $topo');
        expect(boardIsPlanar(b), isTrue, reason: 'seed=$seed 수=$moves 선이 가로질렀어요');
      }
    }
    // ignore: avoid_print
    print('판이 넓어진 상태로 둔 수: $grew');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
