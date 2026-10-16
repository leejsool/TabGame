import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart';

List<P> poly(List<P> pts, {int per = 12}) {
  final out = <P>[];
  for (var i = 0; i + 1 < pts.length; i++) {
    for (var k = 0; k < per; k++) {
      out.add(P(pts[i].x + (pts[i + 1].x - pts[i].x) * k / per, pts[i].y + (pts[i + 1].y - pts[i].y) * k / per));
    }
  }
  out.add(pts.last);
  return out;
}

/// 위 점 0과 아래 점 1을 왼쪽·오른쪽 두 곡선으로 이어 만든 렌즈 모양 판.
/// 렌즈 한가운데에 외딴 점 2(섬)가 있고, 렌즈 바깥에 외딴 점 3이 있다. 점 0, 1은 목숨이 하나씩 남았다.
SproutsBoard lens(double w) {
  final b = SproutsBoard([
    Dot(const P(200, 100), 3),
    Dot(const P(200, 360), 3),
    Dot(const P(200, 230), 3),
    Dot(const P(60, 230), 3),
  ], []);
  for (final side in [-1.0, 1.0]) {
    final path = poly([const P(200, 100), P(200 + side * w, 160), P(200 + side * w, 300), const P(200, 360)]);
    final r = b.validate(0, 1, path.sublist(1, path.length - 1));
    expect(r.ok, isTrue, reason: r.reason);
    b.apply(0, 1, r, 0);
  }
  return b;
}

/// 길 [path] 가 [y]높이에서 지나는 x.
double xAt(List<P> path, double y) => path.reduce((a, c) => (a.y - y).abs() < (c.y - y).abs() ? a : c).x;

void main() {
  group('그은 선과 같은 길로만 고친다', () {
    test('같은 길 판정: 섬의 왼쪽으로 그은 선은, 왼쪽으로 돌아간 길만 같은 길이다', () {
      final b = lens(60);
      final stroke = poly([const P(200, 100), const P(160, 160), const P(160, 300), const P(200, 360)], per: 8);
      expect(strokeCrossesLines(b, 0, 1, stroke), isFalse);
      final left = poly([const P(200, 100), const P(165, 160), const P(165, 300), const P(200, 360)]);
      final right = poly([const P(200, 100), const P(235, 160), const P(235, 300), const P(200, 360)]);
      final outside = poly([const P(200, 100), const P(330, 140), const P(330, 320), const P(200, 360)]);
      expect(sameRoute(b, 0, 1, stroke, left), isTrue);
      expect(sameRoute(b, 0, 1, stroke, right), isFalse, reason: '섬의 반대쪽으로 지나가면 위상이 다르다');
      expect(sameRoute(b, 0, 1, stroke, outside), isFalse, reason: '렌즈 바깥으로 돌아가면 위상이 다르다 (다른 영역)');
    });

    test('선을 가로지른 선은 어느 쪽으로 가려던 것인지 알 수 없어서 어떤 길도 같은 길로 본다', () {
      final b = lens(60);
      final across = poly([const P(120, 230), const P(280, 230)]);
      // 0에서 1로 가는 선이 아니라 가로지르는 선: 출발·도착 점 곁이 아닌 곳에서 곡선을 가로지른다
      expect(strokeCrossesLines(b, 0, 1, across), isTrue);
      final outside = poly([const P(200, 100), const P(330, 140), const P(330, 320), const P(200, 360)]);
      expect(sameRoute(b, 0, 1, across, outside), isTrue);
    });

    for (final w in [60.0, 44.0, 36.0, 30.0, 26.0]) {
      test('렌즈 폭 $w: 섬의 왼쪽 틈으로 그은 선은 (좁아서 판을 늘려야 해도) 섬의 왼쪽으로 고쳐지고, 바깥으로 돌아가지 않는다', () {
        final b = lens(w);
        final stroke = poly([const P(200, 100), P(200 - w * 0.5, 160), P(200 - w * 0.5, 300), const P(200, 360)], per: 8);
        final out = sproutsGuideTask([b.toData(), 0, 1, [for (final p in stroke) ...[p.x, p.y]]]);
        expect(out, isNotEmpty);
        final m = decodeCpuMove(out)!;
        final nb = b.copy()..apply(m.s, m.e, m.result, 0);
        expect(boardIsPlanar(nb), isTrue);
        // 섬(점 2)을 사이에 두고 길이 왼쪽에 있다: 판이 밀리거나 늘어났다면 그 배치의 섬을 본다
        final island = nb.dots[2].pos;
        final newCurve = nb.curves.last;
        expect(xAt(newCurve.pts, island.y), lessThan(island.x), reason: '섬의 왼쪽으로 지나가야 해요');
        // 렌즈 바깥(왼쪽 곡선보다 더 왼쪽, 또는 오른쪽 곡선보다 더 오른쪽)으로 돌아가지 않았다
        final leftWall = nb.curves[0].pts.reduce((a, c) => (a.y - island.y).abs() < (c.y - island.y).abs() ? a : c).x;
        expect(xAt(newCurve.pts, island.y), greaterThan(leftWall), reason: '렌즈 안쪽이어야 해요');
      });
    }

    test('판을 늘려서 그은 선을 따라가는 고치기도 같은 길을 지난다', () {
      final b = lens(26);
      final stroke = poly([const P(200, 100), const P(187, 160), const P(187, 300), const P(200, 360)], per: 8);
      final m = stretchedGuidedMove(b, 0, 1, stroke);
      expect(m, isNotNull);
      final layout = m!.result.layout!;
      final island = layout.dots[2];
      expect(xAt(m.path, island.y), lessThan(island.x));
      expect(m.result.layout!.bounds, isNotNull);
    });
  });
}
