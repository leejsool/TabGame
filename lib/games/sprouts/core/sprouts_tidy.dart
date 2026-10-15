/// 콩나물: 지나치게 복잡하게 그려진 선을 위상은 그대로 두고 단순하게 정리한다 ("선 정리하기").
///
/// 콩나물은 "어느 점이 어느 점과, 어떤 순서로 이어졌나"(위상)만 중요하고 선의 모양은 상관없다. 그래서
/// 빙빙 돌거나 구불구불 그려진 선도, 다른 선·점을 건드리지 않고 줄을 팽팽히 당기듯 펴도 같은 판이다.
///
/// 방법: 곡선을 [점 → 새 점 → 점] 두 개의 변으로 나누고, 변마다 앞에서부터 "가장 멀리 있는 점으로 곧게 가는 지름길"을
/// 찾는다. 지름길은 아래를 모두 만족할 때만 쓴다.
///  1. 다른 점·다른 선·자기 자신의 먼 부분과 충분히 떨어져 있다.
///  2. 지름길과 원래 길로 둘러싸인 고리 안에 다른 점이나 다른 선이 들어 있지 않다 (고리를 가로질러 쓸어 버리면 위상이 바뀐다).
///  3. 변이 점에서 나가는 방향이 다른 선들을 뛰어넘지 않는다 (점 둘레의 선 순서가 그대로다).
/// 변 하나를 바꿀 때마다 판이 여전히 평면 그림이고, 점 둘레의 선 순서와 영역 구성이 그대로인지 정확히 다시 확인하고,
/// 하나라도 달라지면 그 변은 원래대로 둔다. 점의 자리와 새 점의 자리는 움직이지 않는다.
library;

import 'dart:math';

import 'sprouts_board.dart';
import 'sprouts_faces.dart';
import 'sprouts_geometry.dart';
import 'sprouts_relax.dart' show boardIsPlanar;

/// 곡선을 새 점에서 나눈 변 하나 (u에서 v로).
class _Edge {
  _Edge(this.curve, this.u, this.v, this.pts);

  final int curve;
  final int u, v;
  List<P> pts;
}

bool _cross(P a, P b, P c, P d) {
  double o(P p, P q, P r) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  final o1 = o(a, b, c), o2 = o(a, b, d), o3 = o(c, d, a), o4 = o(c, d, b);
  return ((o1 > 1e-9 && o2 < -1e-9) || (o1 < -1e-9 && o2 > 1e-9)) && ((o3 > 1e-9 && o4 < -1e-9) || (o3 < -1e-9 && o4 > 1e-9));
}

/// 선분 ab와 선분 cd 사이의 거리 (만나면 0).
double _segDist(P a, P b, P c, P d) {
  if (_cross(a, b, c, d)) return 0;
  return min(min(pointSegDist(a, c, d), pointSegDist(b, c, d)), min(pointSegDist(c, a, b), pointSegDist(d, a, b)));
}

bool _inside(P p, List<P> poly) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) c = !c;
  }
  return c;
}

/// 점 [o]에서 [pts]를 따라 [r] 이상 떨어진 첫 점의 방향.
double _dirAt(P o, List<P> pts, {double r = 6}) {
  P q = pts.last;
  for (final p in pts) {
    if (p.dist(o) >= r) {
      q = p;
      break;
    }
  }
  return atan2(q.y - o.y, q.x - o.x);
}

double _norm(double a) {
  while (a > pi) {
    a -= 2 * pi;
  }
  while (a <= -pi) {
    a += 2 * pi;
  }
  return a;
}

List<_Edge> _splitEdges(SproutsBoard b) {
  final edges = <_Edge>[];
  for (var ci = 0; ci < b.curves.length; ci++) {
    final c = b.curves[ci];
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
    edges.add(_Edge(ci, c.from, c.mid, c.pts.sublist(0, mi + 1)));
    edges.add(_Edge(ci, c.mid, c.to, c.pts.sublist(mi)));
  }
  return edges;
}

/// 꺾은선을 촘촘히 다시 찍되, 양 끝은 (점·새 점의 한가운데) 좌표 그대로 둔다.
List<P> _dense(List<P> pts) {
  final r = resample(pts);
  r[0] = pts.first;
  r[r.length - 1] = pts.last;
  return r;
}

/// 변들로 판을 다시 만든다 (점은 그대로, 곡선은 두 변을 이어 촘촘히 다시 찍는다).
SproutsBoard _rebuild(SproutsBoard b, List<_Edge> edges) {
  final curves = <Curve>[];
  for (var ci = 0; ci < b.curves.length; ci++) {
    final c = b.curves[ci];
    final a = edges[2 * ci].pts, d = edges[2 * ci + 1].pts;
    // 새 점은 두 변이 만나는 자리라서, 변마다 따로 촘촘히 찍어야 새 점이 곡선 위에 그대로 남는다
    curves.add(Curve(from: c.from, to: c.to, mid: c.mid, owner: c.owner, pts: [..._dense(a), ..._dense(d).skip(1)]));
  }
  final nb = SproutsBoard([for (final d in b.dots) Dot(d.pos, d.lives)], curves, bounds: b.bounds);
  nb.bounds = nb.fittedBounds();
  return nb;
}

/// 점마다 변들이 나가는 순서 (시계 방향 각도 순, 돌려도 같게 맨 앞을 정규화).
List<List<int>> _rotation(List<_Edge> edges, int nd) {
  final per = List.generate(nd, (_) => <(double, int)>[]);
  for (var k = 0; k < edges.length; k++) {
    final e = edges[k];
    per[e.u].add((_dirAt(e.pts.first, e.pts), 2 * k));
    per[e.v].add((_dirAt(e.pts.last, e.pts.reversed.toList()), 2 * k + 1));
  }
  final out = <List<int>>[];
  for (final l in per) {
    l.sort((a, b) => a.$1.compareTo(b.$1));
    final ids = [for (final x in l) x.$2];
    if (ids.isEmpty) {
      out.add(ids);
      continue;
    }
    final s = ids.indexOf(ids.reduce(min));
    out.add([...ids.sublist(s), ...ids.sublist(0, s)]);
  }
  return out;
}

String _regionSig(SproutsBoard b) {
  final rs = [for (final r in analyzeRegions(b).regions) (r.toList()..sort()).join(',')]..sort();
  return rs.join('|');
}

bool _sameRotation(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}

/// 판 [b]를 단순하게 정리한 새 판. 정리할 것이 없으면(이미 단순하면) null.
SproutsBoard? tidyBoard(SproutsBoard b) {
  if (b.curves.isEmpty) return null;
  final edges = _splitEdges(b);
  final nd = b.dots.length;
  final rotation = _rotation(edges, nd);
  final regions = _regionSig(b);

  // 긴 변부터: 길게 돌아간 선을 먼저 펴야 짧은 변이 쓸 자리가 생긴다
  final order = List<int>.generate(edges.length, (i) => i)
    ..sort((x, y) => pathLength(edges[y].pts).compareTo(pathLength(edges[x].pts)));
  var changed = false;
  // 한 번에 다 펴지지 않는다 (앞의 변이 펴져야 뒤의 변이 쓸 자리가 생긴다): 더 줄지 않을 때까지 몇 번 되풀이한다
  for (var pass = 0; pass < 6; pass++) {
    var passChanged = false;
    for (final k in order) {
      final old = edges[k].pts;
      final shorter = _shorten(b, edges, k);
      if (shorter == null) continue;
      edges[k].pts = shorter;
      // 정확한 확인: 여전히 평면 그림이고, 점 둘레의 선 순서와 영역 구성이 그대로여야 한다
      final nb = _rebuild(b, edges);
      final ok = boardIsPlanar(nb) && _sameRotation(_rotation(edges, nd), rotation) && _regionSig(nb) == regions;
      if (ok) {
        passChanged = true;
      } else {
        edges[k].pts = old;
      }
    }
    if (!passChanged) break;
    changed = true;
  }
  if (!changed) return null;
  return _rebuild(b, edges);
}

/// 변 [k]의 더 짧은 길 (지름길로 바꾼 꺾은선). 줄일 수 없으면 null.
List<P>? _shorten(SproutsBoard b, List<_Edge> edges, int k) {
  final e = edges[k];
  final path = e.pts;
  final n = path.length;
  if (n < 4) return null;

  // 다른 변들의 점 (점 곁은 뺀다: 선들이 점의 한가운데로 모이니까)
  final dotPos = [for (final d in b.dots) d.pos];
  final others = PointIndex(kClear);
  var anyOther = false;
  for (var m = 0; m < edges.length; m++) {
    if (m == k) continue;
    for (final p in edges[m].pts) {
      if (dotPos.every((d) => d.dist(p) > kNearDot)) {
        others.add(p);
        anyOther = true;
      }
    }
  }

  // 고리 안에 들어 있는지 볼 것들: 점들 + 다른 변의 가운데 점 (한 점에서 나와 돌아오는 고리 변까지 잡는다)
  final probes = <(P, int)>[
    for (var d = 0; d < dotPos.length; d++) (dotPos[d], d),
    for (var m = 0; m < edges.length; m++)
      if (m != k) (edges[m].pts[edges[m].pts.length ~/ 2], -1),
  ];

  // 길이(arc)
  final arc = List<double>.filled(n, 0);
  for (var i = 1; i < n; i++) {
    arc[i] = arc[i - 1] + path[i - 1].dist(path[i]);
  }

  // 점 둘레 순서 확인용: 이 변이 나가는 점에서 다른 선들이 나가는 방향들
  List<double> otherDirs(int dot) {
    final out = <double>[];
    for (var m = 0; m < edges.length; m++) {
      if (m == k) continue;
      final f = edges[m];
      if (f.u == dot) out.add(_dirAt(f.pts.first, f.pts));
      if (f.v == dot) out.add(_dirAt(f.pts.last, f.pts.reversed.toList()));
    }
    return out;
  }

  final startDirs = otherDirs(e.u), endDirs = otherDirs(e.v);
  final oldStart = _dirAt(path.first, path);
  final oldEnd = _dirAt(path.last, path.reversed.toList());

  bool sweepFree(double from, double to, List<double> dirs) {
    final d = _norm(to - from);
    if (d.abs() > pi * 0.85) return false;
    for (final phi in dirs) {
      final t = _norm(phi - from);
      if (d > 0 ? (t > 1e-6 && t < d + 1e-6) : (t < -1e-6 && t > d - 1e-6)) return false;
    }
    return true;
  }

  const window = 12; // 3 * kInnerR / kStep: 가까운 이웃은 자기 자신과 만난 것으로 치지 않는다
  final out = <P>[path[0]];
  var i = 0;
  var improved = false;

  bool chordOk(int a, int c) {
    final A = path[a], B = path[c];
    final len = A.dist(B);
    if (arc[c] - arc[a] - len < 4) return false; // 거의 곧은 길: 바꿀 이유가 없다

    // 1) 다른 점에서 멀리
    for (var d = 0; d < dotPos.length; d++) {
      if (d == e.u && a == 0) continue;
      if (d == e.v && c == n - 1) continue;
      if (pointSegDist(dotPos[d], A, B) < kKeepOut * 0.9) return false;
    }
    // 2) 다른 변과의 간격: 지름길을 따라 촘촘히 재 본다
    if (anyOther) {
      final steps = max(1, (len / kStep).ceil());
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final q = P(A.x + (B.x - A.x) * t, A.y + (B.y - A.y) * t);
        if (others.nearest(q, kClear) < kClear) return false;
      }
    }
    // 3) 자기 자신: 이미 정리한 앞부분과 아직 안 본 뒷부분
    var back = 0.0;
    for (var s = out.length - 1; s > 0; s--) {
      back += out[s].dist(out[s - 1]);
      if (back < 3 * kInnerR) continue;
      if (_segDist(A, B, out[s - 1], out[s]) < kClear) return false;
    }
    for (var q = c + window; q < n; q++) {
      if (pointSegDist(path[q], A, B) < kClear) return false;
    }
    // 4) 점에서 나가는 방향이 다른 선을 뛰어넘지 않는다
    if (a == 0 && !sweepFree(oldStart, atan2(B.y - A.y, B.x - A.x), startDirs)) return false;
    if (c == n - 1) {
      final newEnd = atan2(A.y - B.y, A.x - B.x); // 끝 점에서 지름길을 거슬러 가는 방향
      if (!sweepFree(oldEnd, newEnd, endDirs)) return false;
    }
    // 5) 지름길과 원래 길의 고리 안에 점이나 선이 들어 있지 않다
    final poly = <P>[for (var q = a; q <= c; q += 3) path[q], B];
    for (final (p, id) in probes) {
      if (id == e.u && a == 0) continue;
      if (id == e.v && c == n - 1) continue;
      if (_inside(p, poly)) return false;
    }
    return true;
  }

  while (i < n - 1) {
    var next = i + 1;
    for (var j = n - 1; j > i + 1; j--) {
      if (chordOk(i, j)) {
        next = j;
        improved = true;
        break;
      }
    }
    out.add(path[next]);
    i = next;
  }
  if (!improved) return null;
  final res = _dense(out);
  if (pathLength(res) > pathLength(path) - 2) return null;
  return res;
}

/// (isolate용) 판 데이터를 받아 정리한 판 데이터를 돌려준다. 정리할 게 없으면 빈 목록.
List<double> sproutsTidyTask(List<double> data) {
  final b = SproutsBoard.fromData(data);
  final t = tidyBoard(b);
  return t == null ? const <double>[] : t.toData();
}
