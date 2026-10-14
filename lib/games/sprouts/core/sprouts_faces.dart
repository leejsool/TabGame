/// 콩나물의 "위상적" 판단: 어떤 점이 어느 영역(빈 공간) 둘레에 있는지로 둘 수 있는 수를 정확히 안다.
///
/// 콩나물에서 한 수는 "같은 영역 둘레에 있는 두 점(점마다 목숨이 남아 있어야 함), 또는 목숨이 2개 이상인 한 점"을
/// 곡선으로 잇는 것이다. 선의 모양이나 자리는 상관없다. 그래서 점과 선의 이어진 구조(평면 지도)에서 영역을 구하면
/// 둘 수 있는 수가 있는지 정확히 알 수 있다.
///
/// 방법: 곡선을 [점 → 새 점 → 점] 두 개의 변으로 나눈 평면 그래프에서, 각 점에서 변들을 각도 순으로 늘어놓고
/// 변을 따라 한 바퀴 도는 길(= 면)을 모두 찾는다. 서로 이어지지 않은 덩어리는 한 덩어리가 다른 덩어리의 면 안에
/// 들어 있는지를 보고 같은 영역으로 묶는다.
library;

import 'dart:math';

import 'sprouts_board.dart';
import 'sprouts_geometry.dart';

/// 판의 영역들. 각 영역에 닿아 있는 점들의 목록.
class SproutsRegions {
  SproutsRegions(this.regions);

  /// 영역마다, 그 영역의 둘레에 닿아 있는 점 번호들.
  final List<Set<int>> regions;

  /// 영역 [r]에서 둘 수 있는 점 쌍들 (한 점으로 돌아오는 고리는 (d, d)).
  Iterable<(int, int)> pairsIn(SproutsBoard b, int r) sync* {
    final dots = regions[r].where((d) => b.dots[d].lives > 0).toList()..sort();
    for (var i = 0; i < dots.length; i++) {
      if (b.dots[dots[i]].lives >= 2) yield (dots[i], dots[i]);
      for (var j = i + 1; j < dots.length; j++) {
        yield (dots[i], dots[j]);
      }
    }
  }

  /// 둘 수 있는 수 (점 쌍)가 하나라도 있나.
  bool hasMove(SproutsBoard b) {
    for (var r = 0; r < regions.length; r++) {
      if (pairsIn(b, r).isNotEmpty) return true;
    }
    return false;
  }

  /// 위상적으로 가능한 모든 점 쌍 (중복 없이).
  List<(int, int)> allPairs(SproutsBoard b) {
    final seen = <(int, int)>{};
    for (var r = 0; r < regions.length; r++) {
      seen.addAll(pairsIn(b, r));
    }
    return seen.toList()..sort((a, c) => a.$1 != c.$1 ? a.$1.compareTo(c.$1) : a.$2.compareTo(c.$2));
  }
}

class _Edge {
  _Edge(this.u, this.v, this.pts);

  final int u, v;
  final List<P> pts; // u에서 v로
}

/// [b]의 영역들을 구한다.
SproutsRegions analyzeRegions(SproutsBoard b) {
  final nd = b.dots.length;

  // ── 변: 곡선을 새 점에서 둘로 나눈다 ──
  final edges = <_Edge>[];
  for (final c in b.curves) {
    var mi = 0;
    var best = double.infinity;
    for (var i = 0; i < c.pts.length; i++) {
      final d = c.pts[i].dist(b.dots[c.mid].pos);
      if (d < best) {
        best = d;
        mi = i;
      }
    }
    mi = mi.clamp(1, c.pts.length - 2);
    edges.add(_Edge(c.from, c.mid, c.pts.sublist(0, mi + 1)));
    edges.add(_Edge(c.mid, c.to, c.pts.sublist(mi)));
  }

  // 반변: 2k = u→v, 2k+1 = v→u
  final nh = edges.length * 2;
  List<P> polyOf(int h) => h.isEven ? edges[h ~/ 2].pts : edges[h ~/ 2].pts.reversed.toList();
  int originOf(int h) => h.isEven ? edges[h ~/ 2].u : edges[h ~/ 2].v;
  int targetOf(int h) => h.isEven ? edges[h ~/ 2].v : edges[h ~/ 2].u;

  // 점마다 나가는 반변을 각도 순으로
  final out = List.generate(nd, (_) => <int>[]);
  for (var h = 0; h < nh; h++) {
    out[originOf(h)].add(h);
  }
  double angleOf(int h) {
    final poly = polyOf(h);
    final o = poly.first;
    P q = poly.last;
    for (final p in poly) {
      if (p.dist(o) >= 6) {
        q = p;
        break;
      }
    }
    return atan2(q.y - o.y, q.x - o.x);
  }

  final ang = [for (var h = 0; h < nh; h++) angleOf(h)];
  for (var d = 0; d < nd; d++) {
    out[d].sort((a, c) => ang[a].compareTo(ang[c]));
  }
  final slot = List<int>.filled(nh, 0); // 반변이 자기 점의 목록에서 몇 번째인가
  for (var d = 0; d < nd; d++) {
    for (var i = 0; i < out[d].length; i++) {
      slot[out[d][i]] = i;
    }
  }

  // 다음 반변: h(u→v)의 끝 v에서, 되돌아가는 반변(v→u)의 바로 이전(각도 순) 반변
  int next(int h) {
    final v = targetOf(h);
    final twin = h ^ 1;
    final list = out[v];
    final i = slot[twin];
    return list[(i - 1 + list.length) % list.length];
  }

  // ── 면: 반변을 따라 한 바퀴 ──
  final cycleOf = List<int>.filled(nh, -1);
  final cycleDots = <Set<int>>[];
  final cycleArea = <double>[];
  final cyclePoly = <List<P>>[];
  final cycleComp = <int>[]; // 어느 덩어리의 면인가 (아래에서 채움)
  final cycleStart = <int>[];
  for (var h0 = 0; h0 < nh; h0++) {
    if (cycleOf[h0] >= 0) continue;
    final id = cycleDots.length;
    final dots = <int>{};
    final poly = <P>[];
    var h = h0;
    do {
      cycleOf[h] = id;
      dots.add(originOf(h));
      poly.addAll(polyOf(h));
      h = next(h);
    } while (h != h0);
    cycleDots.add(dots);
    cyclePoly.add(poly);
    cycleArea.add(polygonArea(poly));
    cycleStart.add(h0);
    cycleComp.add(-1);
  }

  // ── 이어진 덩어리 ──
  final parent = List<int>.generate(nd, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (final e in edges) {
    parent[find(e.u)] = find(e.v);
  }
  final compIds = <int, int>{};
  final dotComp = List<int>.filled(nd, 0);
  for (var d = 0; d < nd; d++) {
    dotComp[d] = compIds.putIfAbsent(find(d), () => compIds.length);
  }
  final nComp = compIds.length;
  for (var c = 0; c < cycleDots.length; c++) {
    cycleComp[c] = dotComp[cycleDots[c].first];
  }

  // 덩어리마다 바깥 면은 정확히 하나다. 면을 이렇게 돌면 안쪽 면은 넓이가 양수, 바깥 면은 음수(나무 모양은 0)이므로
  // 덩어리의 면 가운데 넓이가 가장 작은 것이 바깥 면이다.
  final outerOf = List<int>.filled(nComp, -1); // 덩어리 → 바깥 면 번호 (점만 있는 덩어리는 -1)
  final byComp = List.generate(nComp, (_) => <int>[]);
  for (var c = 0; c < cycleDots.length; c++) {
    byComp[cycleComp[c]].add(c);
  }
  for (var k = 0; k < nComp; k++) {
    final cs = byComp[k];
    if (cs.isEmpty) continue;
    var pick = cs.first;
    for (final c in cs) {
      if (cycleArea[c] < cycleArea[pick]) pick = c;
    }
    outerOf[k] = pick;
  }

  // ── 영역 묶기 ──
  // 노드: 면(cycle)들 + 모양 없는 점(덩어리)마다 하나 + 무한 바깥 하나
  final nCycles = cycleDots.length;
  final isoBase = nCycles;
  final infinity = nCycles + nComp;
  final uf = List<int>.generate(nCycles + nComp + 1, (i) => i);
  int ufFind(int x) {
    while (uf[x] != x) {
      uf[x] = uf[uf[x]];
      x = uf[x];
    }
    return x;
  }

  void ufUnion(int a, int c) => uf[ufFind(a)] = ufFind(c);

  bool inside(P p, List<P> poly) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], bb = poly[j];
      if ((a.y > p.y) != (bb.y > p.y) && p.x < (bb.x - a.x) * (p.y - a.y) / (bb.y - a.y) + a.x) c = !c;
    }
    return c;
  }

  // 덩어리 k의 바깥(표시) 노드와, 그것을 품은 가장 좁은 안쪽 면
  for (var k = 0; k < nComp; k++) {
    final node = outerOf[k] >= 0 ? outerOf[k] : isoBase + k;
    // 대표 점: 덩어리에 속한 점 하나
    var rep = -1;
    for (var d = 0; d < nd; d++) {
      if (dotComp[d] == k) {
        rep = d;
        break;
      }
    }
    final p = b.dots[rep].pos;
    var bestCycle = -1;
    var bestArea = double.infinity;
    for (var c = 0; c < nCycles; c++) {
      if (cycleComp[c] == k) continue;
      if (outerOf[cycleComp[c]] == c) continue; // 남의 바깥 면은 건너뛴다
      final a = cycleArea[c].abs();
      if (a >= bestArea) continue;
      if (inside(p, cyclePoly[c])) {
        bestArea = a;
        bestCycle = c;
      }
    }
    ufUnion(node, bestCycle >= 0 ? bestCycle : infinity);
  }

  // ── 영역별 점 모으기 ──
  final regionOf = <int, Set<int>>{};
  void add(int node, int dot) => (regionOf[ufFind(node)] ??= <int>{}).add(dot);
  for (var c = 0; c < nCycles; c++) {
    for (final d in cycleDots[c]) {
      add(c, d);
    }
  }
  for (var d = 0; d < nd; d++) {
    if (out[d].isEmpty) add(isoBase + dotComp[d], d);
  }
  return SproutsRegions(regionOf.values.toList());
}
