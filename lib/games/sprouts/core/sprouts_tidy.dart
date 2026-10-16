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
import 'sprouts_planner.dart' show makeRoom;
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

// ── 간격 벌리기 ──
//
// 정리한 선은 팽팽하게 당겨져서 다른 선·점에 바짝 붙기 쉽다. 그러면 다음 선을 그을 틈이 없으니, 위상은 그대로 두고
// 선과 점을 서로 밀어내서 간격을 고르게 벌린다. (점과 선을 한꺼번에 조금씩 밀어내는 일을 되풀이한다. 한 번에 아주 조금씩만
// 움직이고 가까운 곳에서는 서로 밀어내기만 하니 선이 서로를 뛰어넘지 못한다. 끝난 뒤에는 선이 가로지르지 않는지, 점 둘레의
// 선 순서와 영역 구성이 그대로인지 정확히 다시 확인하고, 하나라도 달라지면 벌리지 않는다.)

/// 서로 다른 선 사이에 두고 싶은 간격.
const double _gapLine = 22;

/// 점과 그 점에 이어지지 않은 선 사이에 두고 싶은 간격.
const double _gapDot = 30;

/// 점과 점 사이에 두고 싶은 간격.
const double _gapDots = 64;

/// 판 가장자리에서 두고 싶은 간격.
const double _gapEdge = 16;

class _SpCurve {
  _SpCurve(this.from, this.to, this.mid, this.midIdx, this.offset, this.length);

  final int from, to, mid, midIdx, offset, length;
}

/// 간격을 벌리는 계산 한 판 (점과 곡선 위의 점들을 배열로 들고 있다).
class _Spread {
  _Spread(SproutsBoard b, this.bounds) {
    ox = bounds.x0;
    oy = bounds.y0;
    bw = bounds.width;
    bh = bounds.height;
    nd = b.dots.length;
    dx = [for (final d in b.dots) d.pos.x - ox];
    dy = [for (final d in b.dots) d.pos.y - oy];
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
      curves.add(_SpCurve(c.from, c.to, c.mid, mi, px.length, c.pts.length));
      for (var i = 0; i < c.pts.length; i++) {
        px.add(c.pts[i].x - ox);
        py.add(c.pts[i].y - oy);
        owner.add(curves.length - 1);
        pos.add(i);
      }
    }
    np = px.length;
    bound = List<int>.filled(np, -1);
    for (final c in curves) {
      bound[c.offset] = c.from;
      bound[c.offset + c.length - 1] = c.to;
      bound[c.offset + c.midIdx] = c.mid;
    }
    gcols = (bw / _cell).ceil() + 3;
    grows = (bh / _cell).ceil() + 3;
    head = List<int>.filled(gcols * grows, -1);
    nextIn = List<int>.filled(np, -1);
    fx = List<double>.filled(np, 0);
    fy = List<double>.filled(np, 0);
    gx = List<double>.filled(nd, 0);
    gy = List<double>.filled(nd, 0);
    nearDot = List<bool>.filled(np, false);
  }

  static const double _cell = 22;

  final Bounds bounds;
  late final double ox, oy, bw, bh;
  late final int nd, np, gcols, grows;
  late final List<double> dx, dy;
  final List<double> px = [], py = [];
  final List<int> owner = [], pos = [];
  final List<_SpCurve> curves = [];
  late final List<int> bound;
  late final List<int> head, nextIn;
  late final List<double> fx, fy, gx, gy;
  late final List<bool> nearDot;

  int _cellOf(double x, double y) {
    final cx = (x / _cell).floor().clamp(0, gcols - 1), cy = (y / _cell).floor().clamp(0, grows - 1);
    return cy * gcols + cx;
  }

  bool _onCurve(int curve, int dot) {
    final c = curves[curve];
    return c.from == dot || c.to == dot || c.mid == dot;
  }

  /// 두 곡선 위의 점 [ka], [kb]가 가져야 할 간격. 같은 점에서 나온 두 곡선은 그 점 가까이에서는 부챗살처럼 모여 있으니
  /// 점에서 멀어진 만큼만 벌어지게 한다 (점 둘레에서 선들이 고르게 퍼지도록).
  double _gapFor(int ca, int cb, int ka, int kb) {
    final a = curves[ca], b = curves[cb];
    var gap = _gapLine;
    for (final d in {a.from, a.to, a.mid}) {
      if (d != b.from && d != b.to && d != b.mid) continue;
      final ra = sqrt((px[ka] - dx[d]) * (px[ka] - dx[d]) + (py[ka] - dy[d]) * (py[ka] - dy[d]));
      final rb = sqrt((px[kb] - dx[d]) * (px[kb] - dx[d]) + (py[kb] - dy[d]) * (py[kb] - dy[d]));
      if (ra < 40 && rb < 40) gap = min(gap, 0.9 * (ra + rb) / 2);
    }
    return gap;
  }

  /// 힘을 계산해 [fx]·[fy]·[gx]·[gy]에 모으고, 아직 모자란 간격의 정도(에너지)를 돌려준다.
  double evaluate() {
    for (var k = 0; k < np; k++) {
      fx[k] = 0;
      fy[k] = 0;
    }
    for (var d = 0; d < nd; d++) {
      gx[d] = 0;
      gy[d] = 0;
    }
    var energy = 0.0;
    head.fillRange(0, head.length, -1);
    for (var k = 0; k < np; k++) {
      final c = _cellOf(px[k], py[k]);
      nextIn[k] = head[c];
      head[c] = k;
    }
    for (var k = 0; k < np; k++) {
      nearDot[k] = false;
    }
    for (var d = 0; d < nd; d++) {
      final cx = (dx[d] / _cell).floor(), cy = (dy[d] / _cell).floor();
      for (var ay = max(0, cy - 1); ay <= min(grows - 1, cy + 1); ay++) {
        for (var ax = max(0, cx - 1); ax <= min(gcols - 1, cx + 1); ax++) {
          for (var k = head[ay * gcols + ax]; k >= 0; k = nextIn[k]) {
            final ddx = px[k] - dx[d], ddy = py[k] - dy[d];
            if (ddx * ddx + ddy * ddy <= kNearDot * kNearDot) nearDot[k] = true;
          }
        }
      }
    }

    // 선과 선
    for (var k = 0; k < np; k++) {
      if (nearDot[k]) continue;
      final cx = (px[k] / _cell).floor(), cy = (py[k] / _cell).floor();
      for (var ay = max(0, cy - 1); ay <= min(grows - 1, cy + 1); ay++) {
        for (var ax = max(0, cx - 1); ax <= min(gcols - 1, cx + 1); ax++) {
          for (var j = head[ay * gcols + ax]; j >= 0; j = nextIn[j]) {
            if (j <= k || nearDot[j]) continue;
            if (owner[j] == owner[k] && (pos[j] - pos[k]).abs() < 14) continue;
            final vx = px[k] - px[j], vy = py[k] - py[j];
            final d2 = vx * vx + vy * vy;
            if (d2 >= _gapLine * _gapLine) continue;
            final target = owner[j] != owner[k] ? _gapFor(owner[k], owner[j], k, j) : _gapLine;
            if (d2 >= target * target) continue;
            final dist = sqrt(d2);
            double ux, uy;
            if (dist < 1e-6) {
              final a = (k * 2.399) % (2 * pi);
              ux = cos(a);
              uy = sin(a);
            } else {
              ux = vx / dist;
              uy = vy / dist;
            }
            final gap = target - dist;
            energy += gap * gap;
            final push = gap * 0.5 + 0.1;
            fx[k] += ux * push;
            fy[k] += uy * push;
            fx[j] -= ux * push;
            fy[j] -= uy * push;
          }
        }
      }
    }

    // 점과 (그 점에 이어지지 않은) 선
    final r = (_gapDot / _cell).ceil();
    for (var d = 0; d < nd; d++) {
      final cx = (dx[d] / _cell).floor(), cy = (dy[d] / _cell).floor();
      for (var ay = max(0, cy - r); ay <= min(grows - 1, cy + r); ay++) {
        for (var ax = max(0, cx - r); ax <= min(gcols - 1, cx + r); ax++) {
          for (var k = head[ay * gcols + ax]; k >= 0; k = nextIn[k]) {
            if (_onCurve(owner[k], d)) continue;
            final vx = px[k] - dx[d], vy = py[k] - dy[d];
            final d2 = vx * vx + vy * vy;
            if (d2 >= _gapDot * _gapDot) continue;
            final dist = max(sqrt(d2), 1e-6);
            final gap = _gapDot - dist;
            energy += gap * gap;
            final push = gap * 0.45 + 0.1;
            fx[k] += vx / dist * push * 0.65;
            fy[k] += vy / dist * push * 0.65;
            gx[d] -= vx / dist * push * 0.35;
            gy[d] -= vy / dist * push * 0.35;
          }
        }
      }
    }

    // 점과 점
    for (var a = 0; a < nd; a++) {
      for (var c = a + 1; c < nd; c++) {
        final vx = dx[a] - dx[c], vy = dy[a] - dy[c];
        final d2 = vx * vx + vy * vy;
        if (d2 >= _gapDots * _gapDots) continue;
        final dist = max(sqrt(d2), 1e-6);
        final gap = _gapDots - dist;
        energy += gap * gap * 0.25;
        final push = gap * 0.25 + 0.1;
        gx[a] += vx / dist * push;
        gy[a] += vy / dist * push;
        gx[c] -= vx / dist * push;
        gy[c] -= vy / dist * push;
      }
    }

    // 판 가장자리
    for (var k = 0; k < np; k++) {
      if (px[k] < _gapEdge) fx[k] += (_gapEdge - px[k]) * 0.4;
      if (py[k] < _gapEdge) fy[k] += (_gapEdge - py[k]) * 0.4;
      if (px[k] > bw - _gapEdge) fx[k] -= (px[k] - (bw - _gapEdge)) * 0.4;
      if (py[k] > bh - _gapEdge) fy[k] -= (py[k] - (bh - _gapEdge)) * 0.4;
    }
    const m = _gapEdge + kDotR;
    for (var d = 0; d < nd; d++) {
      if (dx[d] < m) gx[d] += (m - dx[d]) * 0.4;
      if (dy[d] < m) gy[d] += (m - dy[d]) * 0.4;
      if (dx[d] > bw - m) gx[d] -= (dx[d] - (bw - m)) * 0.4;
      if (dy[d] > bh - m) gy[d] -= (dy[d] - (bh - m)) * 0.4;
    }
    return energy;
  }

  /// [evaluate]로 모은 힘대로 한 걸음 (선은 매끄럽게 펴면서).
  void move(double step) {
    for (final c in curves) {
      for (var i = 1; i < c.length - 1; i++) {
        final k = c.offset + i;
        if (bound[k] >= 0) continue;
        fx[k] += 0.3 * ((px[k - 1] + px[k + 1]) / 2 - px[k]);
        fy[k] += 0.3 * ((py[k - 1] + py[k + 1]) / 2 - py[k]);
      }
    }
    double clamp(double v) => v > step ? step : (v < -step ? -step : v);
    for (var d = 0; d < nd; d++) {
      dx[d] += clamp(gx[d]);
      dy[d] += clamp(gy[d]);
    }
    for (var k = 0; k < np; k++) {
      if (bound[k] >= 0) continue;
      px[k] += clamp(fx[k]);
      py[k] += clamp(fy[k]);
    }
    for (var k = 0; k < np; k++) {
      final d = bound[k];
      if (d >= 0) {
        px[k] = dx[d];
        py[k] = dy[d];
      }
    }
  }

  /// 지금 배치의 판. 곡선은 새 점에서 나눠 촘촘히 다시 찍는다.
  SproutsBoard toBoard(SproutsBoard b) {
    List<P> dense(List<P> pts) {
      final r = resample(pts);
      r[0] = pts.first;
      r[r.length - 1] = pts.last;
      return r;
    }

    final out = <Curve>[];
    for (var ci = 0; ci < curves.length; ci++) {
      final c = curves[ci];
      final all = [for (var i = 0; i < c.length; i++) P(px[c.offset + i] + ox, py[c.offset + i] + oy)];
      out.add(Curve(
        from: c.from,
        to: c.to,
        mid: c.mid,
        owner: b.curves[ci].owner,
        pts: [...dense(all.sublist(0, c.midIdx + 1)), ...dense(all.sublist(c.midIdx)).skip(1)],
      ));
    }
    final nb = SproutsBoard([for (var d = 0; d < nd; d++) Dot(P(dx[d] + ox, dy[d] + oy), b.dots[d].lives)], out, bounds: bounds);
    nb.bounds = nb.fittedBounds();
    return nb;
  }
}

/// 선과 점 사이를 고르게 벌린 새 판 (위상은 그대로). 이미 넉넉하거나 더 벌릴 수 없으면 null.
///
/// 판 안에서 벌려도 모자라면 판을 조금씩 넓혀 가며(화면에서는 멀어져 보인다) 바깥쪽 빈 곳으로 밀려 나가게 한다.
SproutsBoard? spreadBoard(SproutsBoard b, {Duration limit = const Duration(seconds: 5)}) {
  if (b.curves.isEmpty) return null;
  final nd = b.dots.length;
  final rotation = _rotation(_splitEdges(b), nd);
  final regions = _regionSig(b);
  final clock = Stopwatch()..start();

  SproutsBoard? best;
  var bestEnergy = double.infinity;
  var startEnergy = -1.0;
  for (final f in const [1.0, 1.4, 1.9]) {
    final bounds = f == 1.0 ? b.bounds : b.bounds.grown(f);
    if (f > 1.0 && bounds.scale <= b.bounds.scale + 1e-9) break; // 더는 못 넓힌다
    final sp = _Spread(b, bounds);
    final e0 = sp.evaluate();
    if (startEnergy < 0) startEnergy = e0;
    if (e0 < 40) return null; // 이미 넉넉하다
    var e = e0, still = 0, bestIter = e0;
    for (var iter = 0; iter < 420 && clock.elapsed < limit; iter++) {
      sp.move(0.8);
      e = sp.evaluate();
      if (e < 1) break;
      if (e < bestIter - 0.5) {
        bestIter = e;
        still = 0;
      } else if (++still > 60) {
        break;
      }
    }
    final nb = sp.toBoard(b);
    final ok = boardIsPlanar(nb) && _sameRotation(_rotation(_splitEdges(nb), nd), rotation) && _regionSig(nb) == regions;
    if (ok && e < bestEnergy) {
      best = nb;
      bestEnergy = e;
    }
    if (e < 40 || clock.elapsed >= limit) break;
  }
  // 눈에 띄게 나아졌을 때만 쓴다
  if (best == null || bestEnergy > startEnergy * 0.8) return null;
  return best;
}

/// (isolate용) 판 데이터를 받아 정리한 판 데이터를 돌려준다. 정리할 게 없으면 빈 목록.
List<double> sproutsTidyTask(List<double> data) {
  final b = SproutsBoard.fromData(data);
  final t = tidyBoard(b);
  return t == null ? const <double>[] : t.toData();
}

/// (isolate용) "선 정리하기": 선을 단순하게 펴고(위상은 그대로) 선과 점 사이 간격을 고르게 벌인 판 데이터와,
/// 그래도 위상적으로 이을 자리가 없으면 점과 선을 옮겨 늘린 판 데이터. 각각 필요 없으면 빈 목록.
/// (늘린 판은 정리하고 벌린 판을 바탕으로 한다)
List<List<double>> sproutsTidyAndRoomTask(List<double> data) {
  final b = SproutsBoard.fromData(data);
  final t = tidyBoard(b);
  final spread = spreadBoard(t ?? b);
  final tidy = spread ?? t;
  final room = makeRoom(tidy ?? b, clock: Stopwatch()..start(), deadline: const Duration(seconds: 6));
  return [tidy == null ? const <double>[] : tidy.toData(), room == null ? const <double>[] : room.toData()];
}
