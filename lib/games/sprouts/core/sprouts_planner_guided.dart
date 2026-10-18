part of 'sprouts_planner.dart';

// 그은 선 안내 경로와 CPU 수 부호화 (파일을 역할별로 나눈 것)

/// 그은 선 [stroke]이 이미 그려진 선을 (출발·도착 점 바로 곁이 아닌 곳에서) 가로지르는가.
/// 가로질렀다면 어느 쪽으로 지나가려던 것인지 알 수 없다 (그저 두 점을 잇고 싶었던 것).
bool strokeCrossesLines(SproutsBoard b, int s, int e, List<P> stroke) {
  final sp = b.dots[s].pos, ep = b.dots[e].pos;
  for (var i = 0; i + 1 < stroke.length; i++) {
    final a = stroke[i], c = stroke[i + 1];
    if (a.dist(sp) < 2 * kNearDot || a.dist(ep) < 2 * kNearDot) continue;
    for (final cv in b.curves) {
      final pts = cv.pts;
      for (var j = 0; j + 1 < pts.length; j++) {
        if (_segTouch(a, c, pts[j], pts[j + 1])) return true;
      }
    }
  }
  return false;
}

/// 손으로 그은 선 [stroke]과 고쳐 그린 길 [route](둘 다 [s]에서 [e]로 가는 길)가 위상적으로 같은 길인가.
///
/// 두 길로 만든 닫힌 고리 안에 다른 점(점 위에 찍힌 새 점 포함)이 하나라도 들어 있으면, 두 길은 그 점의 서로 다른 쪽을
/// 지나는 것이다. 점은 선들과 이어져 있으니 점 하나는 그 점이 속한 덩어리 전체를 대표한다.
/// (그은 선이 점 바로 위를 지나가서 어느 쪽인지 알 수 없는 점은 따지지 않는다. 그은 선이 다른 선을 가로질렀다면
/// 어느 쪽으로 가려던 것인지 알 수 없으니 언제나 같은 길로 본다.)
bool sameRoute(SproutsBoard b, int s, int e, List<P> stroke, List<P> route) {
  if (stroke.length < 2 || route.length < 2) return true;
  if (strokeCrossesLines(b, s, e, stroke)) return true;
  final sp = b.dots[s].pos, ep = b.dots[e].pos;
  final drawn = <P>[sp, ...resample(stroke, 6), ep];
  final poly = <P>[...drawn, ...route.reversed];
  for (var d = 0; d < b.dots.length; d++) {
    if (d == s || d == e) continue;
    final p = b.dots[d].pos;
    var near = double.infinity;
    for (var i = 0; i + 1 < drawn.length; i++) {
      near = min(near, pointSegDist(p, drawn[i], drawn[i + 1]));
    }
    if (near < 6) continue;
    if (_pointInPolygon(p, poly)) return false;
  }
  return true;
}

bool _pointInPolygon(P p, List<P> poly) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], bb = poly[j];
    if ((a.y > p.y) != (bb.y > p.y) && p.x < (bb.x - a.x) * (p.y - a.y) / (bb.y - a.y) + a.x) c = !c;
  }
  return c;
}

/// 판에 있는 모든 점과 선을 감싸는 상자의 가운데 ([stretchedBoard]가 판을 늘리는 중심).
P _stretchCenter(SproutsBoard b) {
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  void see(P p) {
    if (p.x < minX) minX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.x > maxX) maxX = p.x;
    if (p.y > maxY) maxY = p.y;
  }

  for (final d in b.dots) {
    see(d.pos);
  }
  for (final c in b.curves) {
    for (final p in c.pts) {
      see(p);
    }
  }
  return P((minX + maxX) / 2, (minY + maxY) / 2);
}

/// 그은 선이 지나는 틈이 너무 좁아 그대로는 못 두는 수를, 판 전체를 조금씩 늘려서(점과 선의 자리만 늘리고 이어진 구조는 그대로)
/// 그은 선을 같은 비율로 늘린 선을 따라가며 고쳐 그린다. 그은 선과 같은 길로만 고친다.
/// 찾은 수의 배치([StrokeResult.layout])는 늘어난 판의 것이다. 못 찾으면 null.
SproutsMove? stretchedGuidedMove(SproutsBoard b, int s, int e, List<P> stroke) {
  final c = _stretchCenter(b);
  for (final f in _stretchFactors) {
    final sb = stretchedBoard(b, f);
    if (sb == null) break;
    final scaled = [for (final p in stroke) P(c.x + (p.x - c.x) * f, c.y + (p.y - c.y) * f)];
    final fix = guidedFix(sb, s, e, scaled, maxDeviation: 45 * f);
    if (fix == null) continue;
    final r = fix.move.result;
    return SproutsMove(s, e, StrokeResult.ok(r.path!, r.midIndex, layout: _layoutOf(sb, r)));
  }
  return null;
}

/// isolate에서 쓰는 형태: [판 데이터, 시작 점, 끝 점, 손으로 그은 선(x, y, x, y, …)] → 바로잡은 수 ([encodeMove] 형태, 점과 선을 민 배치 포함).
/// 손으로 그은 선을 최대한 따라가는 길을 먼저 찾고, 안 되면 두 점을 잇는 어떤 길이든 (점과 선을 밀거나 판을 늘려서라도) 찾는다.
/// 위상적으로 이을 수 없는 쌍이거나 끝내 못 찾으면 빈 목록.
List<double> sproutsGuideTask(List<Object> args) {
  final board = SproutsBoard.fromData(List<double>.from(args[0] as List));
  final flat = List<double>.from(args[3] as List);
  final stroke = <P>[for (var i = 0; i + 1 < flat.length; i += 2) P(flat[i], flat[i + 1])];
  final s = args[1] as int, e = args[2] as int;
  final fix = guidedFix(board, s, e, stroke);
  if (fix != null) return encodeMove(fix.move);
  // 그은 선이 지나는 틈이 좁아서 못 고쳤다: 판을 늘려서라도 그은 선과 같은 길로 고친다
  final stretched = stretchedGuidedMove(board, s, e, stroke);
  if (stretched != null) return encodeMove(stretched);
  // 마지막으로, 두 점을 잇는 다른 길이라도 찾아본다. 단 그은 선과 위상적으로 같은 길일 때만 쓴다
  // (다른 영역이나 점의 반대쪽으로 돌아가면 그은 뜻과 다른 판이 되니, 차라리 고치지 않는다)
  final any = connectPair(board, s, e, clock: Stopwatch()..start(), deadline: const Duration(seconds: 6));
  if (any == null) return const [];
  // (선을 가로지르며 그은 선은 어느 쪽으로 가려던 것인지 알 수 없으니 어떤 길이든 된다)
  if (!strokeCrossesLines(board, s, e, stroke) && (any.result.layout != null || !sameRoute(board, s, e, stroke, any.path))) return const [];
  return encodeMove(any);
}

/// 손으로 그은 선 [stroke]이 고쳐진 [path]에서 가장 멀리 벗어난 거리 (점 둘레의 군더더기는 뺀다).
double _deviation(SproutsBoard b, int s, int e, List<P> stroke, List<P> path) {
  final idx = PointIndex(12);
  for (final p in path) {
    idx.add(p);
  }
  var worst = 0.0;
  for (final p in stroke) {
    if (p.dist(b.dots[s].pos) < 30 || p.dist(b.dots[e].pos) < 30) continue;
    worst = max(worst, idx.nearest(p, 300));
  }
  return worst;
}

/// [s]의 둘레에서 [e]의 둘레까지, 손으로 그은 선([guide])에서 멀수록 비용이 큰 칸 길 (없으면 null).
List<int>? _guidedRoute(_Grid g, SproutsBoard b, int s, int e, PointIndex guide) {
  final cols = g.cols, rows = g.rows;
  final n = cols * rows;
  final cost = Float64List(n)..fillRange(0, n, double.infinity);
  final parent = Int32List(n)..fillRange(0, n, -2);
  final done = Uint8List(n);
  // 이진 힙 (비용, 칸)
  final hk = <double>[], hv = <int>[];
  void push(double c, int v) {
    hk.add(c);
    hv.add(v);
    var i = hk.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (hk[p] <= hk[i]) break;
      final tk = hk[p], tv = hv[p];
      hk[p] = hk[i];
      hv[p] = hv[i];
      hk[i] = tk;
      hv[i] = tv;
      i = p;
    }
  }

  int pop() {
    final top = hv.first;
    final lk = hk.removeLast(), lv = hv.removeLast();
    if (hk.isNotEmpty) {
      hk[0] = lk;
      hv[0] = lv;
      var i = 0;
      for (;;) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < hk.length && hk[l] < hk[m]) m = l;
        if (r < hk.length && hk[r] < hk[m]) m = r;
        if (m == i) break;
        final tk = hk[m], tv = hv[m];
        hk[m] = hk[i];
        hv[m] = hv[i];
        hk[i] = tk;
        hv[i] = tv;
        i = m;
      }
    }
    return top;
  }

  double stepCost(int k, double len) {
    final d = guide.nearest(g.center(k % cols, k ~/ cols), 80);
    return len * (1 + d / 8);
  }

  final sp = b.dots[s].pos;
  const ring = kDotR + 7;
  final span = (ring / g.g).ceil() + 1;
  final scx = ((sp.x - g.ox) / g.g).floor(), scy = ((sp.y - g.oy) / g.g).floor();
  for (var r = max(0, scy - span); r <= min(rows - 1, scy + span); r++) {
    for (var c = max(0, scx - span); c <= min(cols - 1, scx + span); c++) {
      final k = r * cols + c;
      if (g.blocked[k] != 0) continue;
      final z = g.zone[k];
      if (z >= 0 && z != s) continue;
      final cp = g.center(c, r);
      final d = cp.dist(sp);
      if (d >= kDotR && d <= ring && !_crossesNear(b, s, cp)) {
        parent[k] = -1;
        cost[k] = stepCost(k, g.g);
        push(cost[k], k);
      }
    }
  }
  const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)];
  while (hk.isNotEmpty) {
    final k = pop();
    if (done[k] != 0) continue;
    done[k] = 1;
    final c = k % cols, r = k ~/ cols;
    final zk = g.zone[k];
    if (zk == e && g.zoneDist[k] <= ring && !_crossesNear(b, e, g.center(c, r))) {
      final path = <int>[];
      for (var q = k; q >= 0; q = parent[q]) {
        path.add(q);
        if (parent[q] == -1) break;
      }
      return path.reversed.toList();
    }
    for (final (dc, dr) in dirs) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      final nk = nr * cols + nc;
      if (done[nk] != 0 || g.blocked[nk] != 0) continue;
      if (dc != 0 && dr != 0 && (g.blocked[r * cols + nc] != 0 || g.blocked[nr * cols + c] != 0)) continue;
      final nz = g.zone[nk];
      if (nz >= 0 && nz != s) {
        if (nz != e) continue; // 다른 점의 둘레는 지나갈 수 없다
        if (zk == nz && g.zoneDist[nk] >= g.zoneDist[k]) continue; // 도착 점 둘레에서는 가운데 쪽으로만
      } else if (zk == e) {
        continue; // 도착 점 둘레에 들어갔으면 거기서 나오지 않는다
      }
      final nc2 = cost[k] + stepCost(nk, (dc != 0 && dr != 0 ? 1.4142 : 1.0) * g.g);
      if (nc2 < cost[nk]) {
        cost[nk] = nc2;
        parent[nk] = k;
        push(nc2, nk);
      }
    }
  }
  return null;
}

/// 수 하나를 숫자 목록으로: [s, e, 새 점 자리, 점 수, x0, y0, …, 배치 있음(0/1),
/// (있으면) 범위 있음(0/1), (있으면) x0, y0, x1, y1, 점 수, (x, y)×점, 곡선 수, (점 수, (x, y)×k)×곡선].
/// 점과 선을 밀거나 판을 늘려서 둔 수는 그 배치도 함께 담는다.
List<double> encodeMove(SproutsMove m) {
  final out = <double>[m.s.toDouble(), m.e.toDouble(), m.result.midIndex.toDouble(), m.path.length.toDouble()];
  for (final p in m.path) {
    out..add(p.x)..add(p.y);
  }
  final l = m.result.layout;
  out.add(l == null ? 0 : 1);
  if (l != null) {
    final b = l.bounds;
    out.add(b == null ? 0 : 1);
    if (b != null) out..add(b.x0)..add(b.y0)..add(b.x1)..add(b.y1);
    out.add(l.dots.length.toDouble());
    for (final p in l.dots) {
      out..add(p.x)..add(p.y);
    }
    out.add(l.curves.length.toDouble());
    for (final c in l.curves) {
      out.add(c.length.toDouble());
      for (final p in c) {
        out..add(p.x)..add(p.y);
      }
    }
  }
  return out;
}

/// [encodeMove]의 결과를 다시 수로 만든다.
SproutsMove? decodeCpuMove(List<double> data) {
  if (data.isEmpty) return null;
  var i = 0;
  final s = data[i++].toInt(), e = data[i++].toInt(), mid = data[i++].toInt();
  final n = data[i++].toInt();
  final path = <P>[for (var k = 0; k < n; k++) P(data[i++], data[i++])];
  SproutsLayout? layout;
  if (data[i++] != 0) {
    Bounds? bounds;
    if (data[i++] != 0) {
      bounds = Bounds(data[i++], data[i++], data[i++], data[i++]);
    }
    final nd = data[i++].toInt();
    final dots = <P>[for (var k = 0; k < nd; k++) P(data[i++], data[i++])];
    final nc = data[i++].toInt();
    final curves = <List<P>>[];
    for (var c = 0; c < nc; c++) {
      final np = data[i++].toInt();
      curves.add([for (var k = 0; k < np; k++) P(data[i++], data[i++])]);
    }
    layout = SproutsLayout(dots, curves, bounds: bounds);
  }
  return SproutsMove(s, e, StrokeResult.ok(path, mid, layout: layout));
}
