import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart';
import 'package:tabgame/games/sprouts/core/sprouts_topology.dart';

/// 사람이 그은 것처럼 만든 궤적: 성기게 찍고, 끝을 지나치거나 시작을 점 뒤쪽에서 하거나 손이 떨린다.
List<P> human(List<P> path, Random rng, {double overshoot = 0, double jitter = 0, double startBehind = 0}) {
  final pts = <P>[for (var i = 0; i < path.length; i += 2) path[i]];
  if (jitter > 0) {
    final ph = rng.nextDouble() * 6.28;
    final fr = 0.05 + rng.nextDouble() * 0.05;
    for (var i = 1; i + 1 < pts.length; i++) {
      final d = pts[i + 1] - pts[i - 1];
      final l = max(1e-6, sqrt(d.x * d.x + d.y * d.y));
      final off = sin(ph + i * fr * 6) * jitter;
      pts[i] = P(pts[i].x - d.y / l * off, pts[i].y + d.x / l * off);
    }
  }
  if (overshoot > 0) {
    final a = pts[pts.length - 2], b = pts.last;
    final d = b - a;
    final l = max(1e-6, sqrt(d.x * d.x + d.y * d.y));
    for (var k = 3.0; k <= overshoot; k += 3) {
      pts.add(P(b.x + d.x / l * k, b.y + d.y / l * k));
    }
  }
  if (startBehind > 0) {
    final d = pts.first - pts[1];
    final l = max(1e-6, sqrt(d.x * d.x + d.y * d.y));
    pts.insertAll(0, [for (var k = startBehind; k > 0; k -= 3) P(pts.first.x + d.x / l * k, pts.first.y + d.y / l * k)]);
  }
  return pts;
}

/// 기존 선(과 다른 점)에 [gap]까지 바싹 붙도록 궤적을 옮긴다 (가로지르지는 않는다).
List<P> hug(SproutsBoard b, List<P> path, double gap) {
  final out = <P>[];
  for (var i = 0; i < path.length; i += 2) {
    final p = path[i];
    P? near;
    var bd = 1e9;
    for (final c in b.curves) {
      for (final q in c.pts) {
        if (b.dots.any((d) => d.pos.dist(q) < 14)) continue;
        final d = p.dist(q);
        if (d < bd) {
          bd = d;
          near = q;
        }
      }
    }
    if (near != null && bd > gap && bd < 22 && p.dist(b.dots[0].pos) > 20) {
      final k = (bd - gap) / bd;
      out.add(P(p.x + (near.x - p.x) * k, p.y + (near.y - p.y) * k));
    } else {
      out.add(p);
    }
  }
  return out;
}

List<P> line(P a, P b, [double step = 4]) {
  final n = (a.dist(b) / step).ceil();
  return [for (var i = 0; i <= n; i++) P(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n)];
}

void main() {
  group('손가락이 점을 살짝 지나치거나 점 뒤에서 시작해도 된다', () {
    SproutsBoard two() => SproutsBoard([Dot(const P(100, 200), 3), Dot(const P(300, 200), 3)], []);

    test('b점을 지나쳐 25만큼 더 가서 뗐다', () {
      final b = two();
      final stroke = line(const P(100, 200), const P(325, 203));
      final e = b.endDotFor(stroke, 0);
      expect(e, 1);
      final r = b.validate(0, e, stroke);
      expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    });

    test('a점 뒤쪽 20에서 시작해서 a를 지나 b로 간다', () {
      final b = two();
      final stroke = line(const P(80, 200), const P(300, 200));
      final r = b.validate(0, 1, stroke);
      expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    });

    test('점을 지나쳐 다른 점 곁에서 떼어도, 지나간 점이 끝점이다', () {
      final b = SproutsBoard([Dot(const P(100, 200), 3), Dot(const P(250, 200), 3), Dot(const P(300, 150), 3)], []);
      // b(250,200)를 지난 뒤 c(300,150) 쪽으로 방향을 틀어 c에서 27쯤 떨어진 곳에서 뗀다
      final stroke = [...line(const P(100, 200), const P(250, 200)), ...line(const P(250, 200), const P(278, 172))];
      expect(b.nearestDot(stroke.last), 2); // 끝만 보면 c가 가장 가깝다
      expect(b.endDotFor(stroke, 0), 1); // 하지만 b 위를 지나갔다
    });

    test('짧은 선에서 출발점이 끝점으로 오인되지 않는다', () {
      final b = SproutsBoard([Dot(const P(100, 200), 3), Dot(const P(160, 200), 3)], []);
      final stroke = line(const P(100, 200), const P(150, 200));
      expect(b.endDotFor(stroke, 0), 1);
    });

    test('두 점이 가까워도 곧은 선으로 이어진다 (끝을 지나친 궤적)', () {
      final b = SproutsBoard([Dot(const P(160, 200), 3), Dot(const P(210, 200), 3)], []);
      final r = b.validate(0, 1, line(const P(160, 200), const P(235, 200)));
      expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
    });
  });


  group('안 되는 선을 알아서 바로잡기 (guidedMove)', () {
    SproutsBoard withWall(P c, P d) {
      final b = SproutsBoard([
        Dot(const P(100, 200), 3),
        Dot(const P(300, 200), 3),
        Dot(c, 3),
        Dot(d, 3),
      ], []);
      final r = b.validate(2, 3, line(c, d));
      expect(r.ok, isTrue, reason: '${r.reason} / $lastRelaxFailure');
      b.apply(2, 3, r, 0);
      return b;
    }

    test('선 끝을 살짝 스치며 가로지른 선은, 끝을 돌아 지나가도록 바로잡힌다', () {
      final b = withWall(const P(200, 110), const P(200, 208));
      final stroke = line(const P(100, 200), const P(300, 200));
      expect(b.validate(0, 1, stroke).ok, isFalse); // 손으로 그은 그대로는 안 된다
      final fix = guidedMove(b, 0, 1, stroke);
      expect(fix, isNotNull);
      final copy = b.copy()..apply(0, 1, fix!.result, 1);
      expect(boardIsPlanar(copy), isTrue);
      expect(countTopology(copy).balanced, isTrue, reason: '${countTopology(copy)}');
      // 바로잡은 선은 손으로 그은 선에서 크게 벗어나지 않았다
      final mid = fix.path[fix.path.length ~/ 2];
      expect((mid.y - 200).abs(), lessThan(60));
    });

    test('컨트롤러: 안 된다는 안내가 먼저 나오고, 곧 알아서 바로잡은 선이 그려진다', () async {
      final b = withWall(const P(200, 110), const P(200, 208));
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, board: b);
      expect(c.tryStroke(line(const P(100, 200), const P(300, 200))), isFalse);
      expect(c.message, isNotNull);
      for (var i = 0; i < 100 && c.moveCount == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(c.moveCount, 1);
      expect(c.message, isNull);
      expect(c.notice, contains('알아서'));
      expect(boardIsPlanar(c.board), isTrue);
      c.dispose();
    });

    test('컨트롤러: 새로 긋기 시작하면(cancelRepair) 앞선 선은 바로잡지 않는다', () async {
      final b = withWall(const P(200, 110), const P(200, 208));
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 4, board: b);
      expect(c.tryStroke(line(const P(100, 200), const P(300, 200))), isFalse);
      c.cancelRepair();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(c.moveCount, 0);
      c.dispose();
    });

    test('판을 가로지르는 긴 벽은 알아서 돌아가지 않는다 (규칙을 어긴 것)', () {
      final b = withWall(const P(200, 30), const P(200, 430));
      final stroke = line(const P(100, 200), const P(300, 200));
      expect(guidedMove(b, 0, 1, stroke), isNull);
    });

    test('바로잡힌 수는 언제나 선을 가로지르지 않고 오일러 공식이 맞는다', () {
      var fixed = 0, tried = 0;
      for (var seed = 0; seed < 3; seed++) {
        final rng = Random(seed * 13 + 5);
        final b = SproutsBoard.initial(4 + seed % 3, rng);
        for (var step = 0; step < 6; step++) {
          final moves = findMoves(b, allowRelax: false);
          if (moves.isEmpty) break;
          // 곧은 선으로 아무 두 점이나 이어 보기 (대부분 안 되는 선이다)
          for (var s = 0; s < b.dots.length; s++) {
            for (var e = s + 1; e < b.dots.length; e++) {
              if (b.dots[s].lives < 1 || b.dots[e].lives < 1) continue;
              final stroke = line(b.dots[s].pos, b.dots[e].pos);
              if (b.validate(s, e, stroke).ok) continue;
              tried++;
              final fix = guidedMove(b, s, e, stroke);
              if (fix == null) continue;
              fixed++;
              final copy = b.copy()..apply(s, e, fix.result, 0);
              expect(boardIsPlanar(copy), isTrue, reason: '점 $s→$e');
              expect(countTopology(copy).balanced, isTrue, reason: '${countTopology(copy)}');
            }
          }
          final m = moves[rng.nextInt(moves.length)];
          final r = b.validate(m.s, m.e, m.path);
          if (!r.ok) break;
          b.apply(m.s, m.e, r, step % 2);
        }
      }
      expect(tried, greaterThan(10));
      // ignore: avoid_print
      print('안 되는 곧은 선 $tried개 중 $fixed개를 바로잡았어요');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  test('플래너의 수를 사람처럼 그리면(지나침·점 뒤 시작·손떨림) 거의 다 받아들여진다', () {
    final tried = <String, int>{};
    final rejected = <String, int>{};
    final reasons = <String, int>{};
    final seeds = int.tryParse(Platform.environment['SPROUTS_FUZZ_SEEDS'] ?? '') ?? 6;
    for (var seed = 0; seed < seeds; seed++) {
      final rng = Random(seed * 31 + 7);
      final n = 3 + seed % 4;
      final b = SproutsBoard.initial(n, rng);
      for (var step = 0; step < 3 * n; step++) {
        final moves = findMoves(b, allowRelax: false);
        if (moves.isEmpty) break;
        for (final m in moves.take(6)) {
          for (final variant in ['plain', 'over12', 'over28', 'jit3', 'behind15', 'hug4']) {
            final stroke = switch (variant) {
              'over12' => human(m.path, rng, overshoot: 12),
              'over28' => human(m.path, rng, overshoot: 28),
              'jit3' => human(m.path, rng, jitter: 3),
              'behind15' => human(m.path, rng, startBehind: 15),
              'hug4' => hug(b, m.path, 4),
              _ => human(m.path, rng),
            };
            final s = b.nearestDot(stroke.first);
            final e = b.endDotFor(stroke, s);
            // 다른 점 위에서 뗀 것처럼 보이는 궤적은 사람의 의도가 모호하니 세지 않는다
            if (s != m.s || e != m.e) continue;
            tried[variant] = (tried[variant] ?? 0) + 1;
            final res = b.validate(s, e, stroke);
            if (!res.ok) {
              // 바싹 붙인 궤적이 정말로 선을 가로질렀다면 거절이 맞다: 위상적으로 문제없는 것만 센다
              if (variant == 'hug4' && !strokeTopologyOk(b, s, e, b.pathFor(s, e, stroke))) {
                tried[variant] = tried[variant]! - 1;
                continue;
              }
              final key = '$variant: ${res.reason} / ${(lastRelaxFailure ?? '').split('(').first}';
              reasons[key] = (reasons[key] ?? 0) + 1;
              rejected[variant] = (rejected[variant] ?? 0) + 1;
            } else {
              // 받아들인 수는 정말로 아무 선도 가로지르지 않고, 오일러 공식이 맞아야 한다
              final copy = b.copy()..apply(s, e, res, 0);
              expect(boardIsPlanar(copy), isTrue, reason: '$variant 점 $s→$e 선이 가로질렀어요');
              expect(countTopology(copy).balanced, isTrue, reason: '$variant: ${countTopology(copy)}');
            }
          }
        }
        final m = moves[rng.nextInt(moves.length)];
        final r = b.validate(m.s, m.e, m.path);
        if (!r.ok) break;
        b.apply(m.s, m.e, r, step % 2);
      }
    }
    if (Platform.environment['SPROUTS_FUZZ_SEEDS'] != null) {
      for (final e in reasons.entries) {
        // ignore: avoid_print
        print('${e.value}  ${e.key}');
      }
    }
    for (final v in tried.keys) {
      final bad = rejected[v] ?? 0;
      // ignore: avoid_print
      if (Platform.environment['SPROUTS_FUZZ_SEEDS'] != null) print('$v: $bad / ${tried[v]} 거절');
      expect(bad / tried[v]!, lessThan(0.015), reason: '$v: $bad / ${tried[v]} 거절');
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
