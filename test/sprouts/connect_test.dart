import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart' show boardIsPlanar;
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';

/// 판을 몇 수 둔 뒤 위상적으로 이을 수 있는 점 쌍 하나를 고른다.
(SproutsBoard, int, int)? midGame(int seed, int n, int moves) {
  final rng = Random(seed);
  final b = SproutsBoard.initial(n, rng);
  for (var i = 0; i < moves; i++) {
    final ms = findMoves(b, allowRelax: false);
    if (ms.isEmpty) break;
    final m = ms[rng.nextInt(ms.length)];
    b.apply(m.s, m.e, m.result, i % 2);
  }
  final pairs = [for (final p in analyzeRegions(b).allPairs(b)) if (p.$1 != p.$2) p];
  if (pairs.isEmpty) return null;
  final p = pairs[rng.nextInt(pairs.length)];
  return (b, p.$1, p.$2);
}

void main() {
  group('두 점을 이으려는 손길 바로잡기', () {
    test('아무렇게나 그은 선(다른 선을 가로지름)이어도, 위상적으로 이을 수 있는 두 점이면 이어 주는 길을 언제나 찾는다', () {
      var tried = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final g = midGame(seed, 4 + seed % 2, 5 + seed % 6);
        if (g == null) continue;
        final (b, s, e) = g;
        final a = b.dots[s].pos, c = b.dots[e].pos;
        // 두 점 사이를 곧장 가로지르는 선 (다른 선을 건드리거나 가로지를 수 있다)
        final stroke = [for (var i = 0; i <= 20; i++) P(a.x + (c.x - a.x) * i / 20, a.y + (c.y - a.y) * i / 20)];
        final out = sproutsGuideTask([b.toData(), s, e, [for (final p in stroke) ...[p.x, p.y]]]);
        expect(out, isNotEmpty, reason: 'seed=$seed ($s,$e) 이을 수 있는 점인데 길을 못 찾았어요');
        final m = decodeCpuMove(out)!;
        expect((m.s, m.e), (s, e));
        final nb = b.copy()..apply(m.s, m.e, m.result, 0);
        expect(boardIsPlanar(nb), isTrue, reason: 'seed=$seed 선이 가로질렀어요');
        tried++;
      }
      expect(tried, greaterThan(30));
    }, tags: 'slow');

    test('위상적으로 이을 수 없는 쌍은 이어 주지 않는다', () {
      // 점 두 개를 이은 판에서 한 점을 고리로 막아, 다른 영역의 점과는 이을 수 없게 만든다
      final rng = Random(3);
      final b = SproutsBoard.initial(3, rng);
      var found = false;
      for (var i = 0; i < 6 && !found; i++) {
        final ms = findMoves(b, allowRelax: false);
        if (ms.isEmpty) break;
        final m = ms[rng.nextInt(ms.length)];
        b.apply(m.s, m.e, m.result, i % 2);
        final live = [for (var k = 0; k < b.dots.length; k++) if (b.dots[k].lives > 0) k];
        final pairs = analyzeRegions(b).allPairs(b).toSet();
        for (final x in live) {
          for (final y in live) {
            if (x < y && !pairs.contains((x, y))) {
              expect(connectPair(b, x, y), isNull);
              found = true;
            }
          }
        }
      }
    });

    test('손가락이 점에서 조금 벗어나 끝나도 이을 수 있는 가까운 점으로 본다', () {
      final c = SproutsController(mode: PlayMode.local2p, dotCount: 2, rng: Random(8));
      final a = c.board.dots[0].pos, b = c.board.dots[1].pos;
      // 끝점을 도착 점에서 40쯤 떨어진 곳(붙잡는 거리 밖)에서 뗀다
      final d = P(b.x - a.x, b.y - a.y);
      final len = sqrt(d.x * d.x + d.y * d.y);
      final end = P(b.x - d.x / len * 45, b.y - d.y / len * 45);
      final stroke = [for (var i = 0; i <= 30; i++) P(a.x + (end.x - a.x) * i / 30, a.y + (end.y - a.y) * i / 30)];
      expect(c.tryStroke(stroke), isTrue, reason: c.message);
      expect(c.moveCount, 1);
      expect(c.board.curves.single.to, 1);
    });
  });
}
