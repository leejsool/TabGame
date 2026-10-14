/// 콩나물: 자리가 좁아서 안 되는 수를, 이미 그려진 점과 선을 부드럽게 밀어서 가능하게 만든다.
///
/// 콩나물은 "어느 점이 어느 점과 이어졌나"(위상)만 중요하고 선의 모양은 상관없다. 그래서 새 곡선이
/// 위상적으로는 문제가 없는데(어떤 선도 가로지르지 않고, 다른 점 위를 지나지 않는데) 너무 좁아서 안 될 때는,
/// 점과 선을 고무줄처럼 조금씩 밀어 간격을 벌려도 같은 판이다.
///
/// 방법: 새 곡선도 판의 일부로 보고, 서로 너무 가까운 점들을 아주 조금씩(한 번에 0.6 이하) 밀어내는 일을
/// 간격이 다 벌어질 때까지 되풀이한다. 한 번에 조금씩만 움직이고 가까운 곳에서는 서로 밀어내기만 하니 선이 서로를
/// 뛰어넘지 못한다. 끝난 뒤에는 어떤 선도 만나지 않았는지 정확히 다시 확인하고, 아니면 포기한다.
library;

import 'dart:math';

import 'sprouts_board.dart';
import 'sprouts_geometry.dart';

/// (진단용) 마지막으로 밀기에 실패한 이유.
String? lastRelaxFailure;

/// 두 선분이 한 점에서 가로지르는가 (끝점만 닿는 것은 아니다).
bool _segCross(P a, P b, P c, P d) {
  double o(P p, P q, P r) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  final o1 = o(a, b, c), o2 = o(a, b, d), o3 = o(c, d, a), o4 = o(c, d, b);
  return ((o1 > 1e-9 && o2 < -1e-9) || (o1 < -1e-9 && o2 > 1e-9)) && ((o3 > 1e-9 && o4 < -1e-9) || (o3 < -1e-9 && o4 > 1e-9));
}

/// 새 곡선 [path](양 끝은 점 [s], [e]의 한가운데)가 위상적으로 둘 수 있는가:
/// 기존 선을 가로지르지 않고, 자기 자신을 가로지르지 않고, 다른 점 위를 지나가지 않는다.
bool strokeTopologyOk(SproutsBoard b, int s, int e, List<P> path) {
  final sp = b.dots[s].pos, ep = b.dots[e].pos;
  // 다른 점 위를 지나가지 않는다
  for (var d = 0; d < b.dots.length; d++) {
    if (d == s || d == e) continue;
    for (final p in path) {
      if (p.dist(b.dots[d].pos) < kDotR) return false;
    }
  }
  // 자기 자신
  for (var i = 0; i + 1 < path.length; i++) {
    for (var j = i + 2; j + 1 < path.length; j++) {
      if (i == 0 && j + 2 == path.length && s == e) continue; // 고리의 처음과 끝은 같은 점에서 만난다
      if (_segCross(path[i], path[i + 1], path[j], path[j + 1])) return false;
    }
  }
  // 기존 선
  for (final c in b.curves) {
    final pts = c.pts;
    for (var j = 0; j + 1 < pts.length; j++) {
      final c0 = pts[j], c1 = pts[j + 1];
      final minX = min(c0.x, c1.x) - 1, maxX = max(c0.x, c1.x) + 1, minY = min(c0.y, c1.y) - 1, maxY = max(c0.y, c1.y) + 1;
      for (var i = 0; i + 1 < path.length; i++) {
        final a = path[i], bb = path[i + 1];
        if (max(a.x, bb.x) < minX || min(a.x, bb.x) > maxX || max(a.y, bb.y) < minY || min(a.y, bb.y) > maxY) continue;
        if (!_segCross(a, bb, c0, c1)) continue;
        // 점의 한가운데에서 모이는 선들은 서로 닿는 것이 아니다
        final m = P((c0.x + c1.x) / 2, (c0.y + c1.y) / 2);
        if (m.dist(sp) < 4 || m.dist(ep) < 4) continue;
        return false;
      }
    }
  }
  return true;
}

/// 모든 곡선(과 새 곡선)이 서로 가로지르지 않는가.
bool _planar(List<List<P>> curves) {
  const cell = 16.0;
  final grid = <int, List<(int, int)>>{};
  int key(int cx, int cy) => cx * 100003 + cy;
  for (var c = 0; c < curves.length; c++) {
    final pts = curves[c];
    for (var i = 0; i + 1 < pts.length; i++) {
      final x0 = (min(pts[i].x, pts[i + 1].x) / cell).floor(), x1 = (max(pts[i].x, pts[i + 1].x) / cell).floor();
      final y0 = (min(pts[i].y, pts[i + 1].y) / cell).floor(), y1 = (max(pts[i].y, pts[i + 1].y) / cell).floor();
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          (grid[key(x, y)] ??= []).add((c, i));
        }
      }
    }
  }
  for (final list in grid.values) {
    for (var a = 0; a < list.length; a++) {
      for (var b = a + 1; b < list.length; b++) {
        final (c1, i1) = list[a];
        final (c2, i2) = list[b];
        if (c1 == c2 && (i1 - i2).abs() < 2) continue;
        if (_segCross(curves[c1][i1], curves[c1][i1 + 1], curves[c2][i2], curves[c2][i2 + 1])) return false;
      }
    }
  }
  return true;
}

/// 판의 모든 곡선이 서로 가로지르지 않는가 (정확한 확인).
bool boardIsPlanar(SproutsBoard b) => _planar([for (final c in b.curves) c.pts]);

class _Curve {
  _Curve(this.from, this.to, this.mid, this.midIdx, this.x, this.y);

  final int from, to, mid, midIdx;
  final List<double> x, y;
}

/// 새 곡선 [path]를 두기 위해 점과 선을 밀어 본다. 성공하면 밀린 판 위의 수(곡선·새 점 자리·밀린 배치)를 돌려준다.
///
/// 판 안에서 밀어도 자리가 안 나면, 판을 조금씩 넓혀 가며(화면에서는 멀어져 보인다) 점과 선이 바깥쪽 빈 곳으로 밀려 나가게 한다.
StrokeResult? relaxForStroke(SproutsBoard b, int s, int e, List<P> path, {int maxIter = 240}) {
  if (!strokeTopologyOk(b, s, e, path)) {
    lastRelaxFailure = '위상 문제 (선을 가로지르거나 점 위를 지나감)';
    return null;
  }
  StrokeResult? last;
  for (final f in const [1.0, 1.4, 1.9, 2.6]) {
    final grown = f == 1.0 ? b.bounds : b.bounds.grown(f);
    if (f > 1.0 && grown.scale <= b.bounds.scale + 1e-9) break; // 더는 못 넓힌다
    final r = _relaxOnce(b, grown, s, e, path, maxIter);
    if (r != null) return r;
    last = r;
  }
  return last;
}

StrokeResult? _relaxOnce(SproutsBoard b, Bounds bounds, int s, int e, List<P> path, int maxIter) {
  final ox = bounds.x0, oy = bounds.y0;
  final bw = bounds.width, bh = bounds.height;

  final nOld = b.dots.length;
  final nd = nOld + 1; // 새 점 하나가 더 생긴다
  final dx = List<double>.filled(nd, 0), dy = List<double>.filled(nd, 0);
  for (var i = 0; i < nOld; i++) {
    dx[i] = b.dots[i].pos.x - ox;
    dy[i] = b.dots[i].pos.y - oy;
  }
  // 새 점 자리: 곡선의 한가운데
  final total = pathLength(path);
  var midIdx = 1;
  var acc = 0.0;
  for (var i = 1; i < path.length - 1; i++) {
    acc += path[i - 1].dist(path[i]);
    if (acc >= total / 2) {
      midIdx = i;
      break;
    }
  }
  dx[nOld] = path[midIdx].x - ox;
  dy[nOld] = path[midIdx].y - oy;

  final curves = <_Curve>[];
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
    curves.add(_Curve(c.from, c.to, c.mid, mi, [for (final p in c.pts) p.x - ox], [for (final p in c.pts) p.y - oy]));
  }
  curves.add(_Curve(s, e, nOld, midIdx, [for (final p in path) p.x - ox], [for (final p in path) p.y - oy]));

  // 점들을 한 줄로
  final owner = <int>[], pos = <int>[];
  for (var c = 0; c < curves.length; c++) {
    for (var i = 0; i < curves[c].x.length; i++) {
      owner.add(c);
      pos.add(i);
    }
  }
  final np = owner.length;
  final px = List<double>.filled(np, 0), py = List<double>.filled(np, 0);
  final offset = List<int>.filled(curves.length, 0);
  {
    var k = 0;
    for (var c = 0; c < curves.length; c++) {
      offset[c] = k;
      for (var i = 0; i < curves[c].x.length; i++) {
        px[k] = curves[c].x[i];
        py[k] = curves[c].y[i];
        k++;
      }
    }
  }
  // 점에 묶인 점(양 끝과 새 점 자리)
  final bound = List<int>.filled(np, -1); // 묶인 점의 번호, 아니면 -1
  for (var c = 0; c < curves.length; c++) {
    final cv = curves[c];
    bound[offset[c]] = cv.from;
    bound[offset[c] + cv.x.length - 1] = cv.to;
    bound[offset[c] + cv.midIdx] = cv.mid;
  }

  const tPair = kClear + 3.0; // 서로 다른 선 사이 간격 (판정의 kClear보다 넉넉히)
  const tDot = kKeepOut + 3.0; // 점과 다른 선 사이
  const tDots = 2 * kKeepOut - 4;
  const edge = 12.0; // 판 가장자리에서
  const cell = 14.0;
  const step = 0.6;
  final gcols = (bw / cell).ceil() + 3, grows = (bh / cell).ceil() + 3;
  final head = List<int>.filled(gcols * grows, -1);
  final nextIn = List<int>.filled(np, -1);
  int cellOf(double x, double y) {
    final cx = (x / cell).floor().clamp(0, gcols - 1), cy = (y / cell).floor().clamp(0, grows - 1);
    return cy * gcols + cx;
  }

  final fx = List<double>.filled(np, 0), fy = List<double>.filled(np, 0);
  final gx = List<double>.filled(nd, 0), gy = List<double>.filled(nd, 0);
  final nearDot = List<bool>.filled(np, false);

  bool converged = false;
  var bestViolations = 1 << 30, stagnant = 0;
  var lastPair = 0, lastDot = 0, lastDots = 0;
  for (var iter = 0; iter < maxIter; iter++) {
    for (var k = 0; k < np; k++) {
      fx[k] = 0;
      fy[k] = 0;
    }
    for (var d = 0; d < nd; d++) {
      gx[d] = 0;
      gy[d] = 0;
    }
    var violations = 0;
    var vPair = 0, vDot = 0, vDots = 0;

    // 칸 나누기 (연결 목록)
    head.fillRange(0, head.length, -1);
    for (var k = 0; k < np; k++) {
      final c = cellOf(px[k], py[k]);
      nextIn[k] = head[c];
      head[c] = k;
    }

    // 점 가까이에 있는 점들은 서로 모여 있어도 된다
    for (var k = 0; k < np; k++) {
      nearDot[k] = false;
    }
    for (var d = 0; d < nd; d++) {
      final cx = (dx[d] / cell).floor(), cy = (dy[d] / cell).floor();
      for (var ay = max(0, cy - 1); ay <= min(grows - 1, cy + 1); ay++) {
        for (var ax = max(0, cx - 1); ax <= min(gcols - 1, cx + 1); ax++) {
          for (var k = head[ay * gcols + ax]; k >= 0; k = nextIn[k]) {
            final ddx = px[k] - dx[d], ddy = py[k] - dy[d];
            if (ddx * ddx + ddy * ddy <= kNearDot * kNearDot) nearDot[k] = true;
          }
        }
      }
    }

    // 선과 선 사이
    for (var k = 0; k < np; k++) {
      if (nearDot[k]) continue;
      final cx = (px[k] / cell).floor(), cy = (py[k] / cell).floor();
      for (var ay = max(0, cy - 1); ay <= min(grows - 1, cy + 1); ay++) {
        for (var ax = max(0, cx - 1); ax <= min(gcols - 1, cx + 1); ax++) {
          for (var j = head[ay * gcols + ax]; j >= 0; j = nextIn[j]) {
            if (j <= k || nearDot[j]) continue;
            if (owner[j] == owner[k] && (pos[j] - pos[k]).abs() < 14) continue;
            final vx = px[k] - px[j], vy = py[k] - py[j];
            final d2 = vx * vx + vy * vy;
            if (d2 >= tPair * tPair) continue;
            violations++;
            vPair++;
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
            final push = (tPair - dist) * 0.45 + 0.1;
            fx[k] += ux * push;
            fy[k] += uy * push;
            fx[j] -= ux * push;
            fy[j] -= uy * push;
          }
        }
      }
    }

    // 점과 (그 점에 이어지지 않은) 선 사이
    for (var d = 0; d < nd; d++) {
      final cx = (dx[d] / cell).floor(), cy = (dy[d] / cell).floor();
      const r = 2;
      for (var ay = max(0, cy - r); ay <= min(grows - 1, cy + r); ay++) {
        for (var ax = max(0, cx - r); ax <= min(gcols - 1, cx + r); ax++) {
          for (var k = head[ay * gcols + ax]; k >= 0; k = nextIn[k]) {
            final cv = curves[owner[k]];
            if (cv.from == d || cv.to == d || cv.mid == d) continue;
            final vx = px[k] - dx[d], vy = py[k] - dy[d];
            final d2 = vx * vx + vy * vy;
            if (d2 >= tDot * tDot) continue;
            violations++;
            vDot++;
            final dist = max(sqrt(d2), 1e-6);
            final ux = vx / dist, uy = vy / dist;
            final push = (tDot - dist) * 0.4 + 0.1;
            fx[k] += ux * push * 0.65;
            fy[k] += uy * push * 0.65;
            gx[d] -= ux * push * 0.35;
            gy[d] -= uy * push * 0.35;
          }
        }
      }
    }

    // 점과 점 사이
    for (var a = 0; a < nd; a++) {
      for (var c2 = a + 1; c2 < nd; c2++) {
        final vx = dx[a] - dx[c2], vy = dy[a] - dy[c2];
        final d2 = vx * vx + vy * vy;
        if (d2 >= tDots * tDots) continue;
        violations++;
        vDots++;
        final dist = max(sqrt(d2), 1e-6);
        final push = (tDots - dist) * 0.3 + 0.15;
        gx[a] += vx / dist * push;
        gy[a] += vy / dist * push;
        gx[c2] -= vx / dist * push;
        gy[c2] -= vy / dist * push;
      }
    }

    // 판 가장자리
    for (var k = 0; k < np; k++) {
      if (px[k] < edge) fx[k] += (edge - px[k]) * 0.4;
      if (py[k] < edge) fy[k] += (edge - py[k]) * 0.4;
      if (px[k] > bw - edge) fx[k] -= (px[k] - (bw - edge)) * 0.4;
      if (py[k] > bh - edge) fy[k] -= (py[k] - (bh - edge)) * 0.4;
    }
    for (var d = 0; d < nd; d++) {
      final m = edge + kDotR;
      if (dx[d] < m) gx[d] += (m - dx[d]) * 0.4;
      if (dy[d] < m) gy[d] += (m - dy[d]) * 0.4;
      if (dx[d] > bw - m) gx[d] -= (dx[d] - (bw - m)) * 0.4;
      if (dy[d] > bh - m) gy[d] -= (dy[d] - (bh - m)) * 0.4;
    }

    lastPair = vPair;
    lastDot = vDot;
    lastDots = vDots;
    if (violations == 0) {
      converged = true;
      break;
    }
    // 오래 줄어들지 않으면 포기한다 (좁은 곳이 풀리지 않는 경우)
    if (violations < bestViolations) {
      bestViolations = violations;
      stagnant = 0;
    } else if (++stagnant > 40) {
      break;
    }

    // 곡선은 매끄럽게 (이웃 점의 가운데로 조금씩)
    for (var c = 0; c < curves.length; c++) {
      final len = curves[c].x.length;
      for (var i = 1; i < len - 1; i++) {
        final k = offset[c] + i;
        if (bound[k] >= 0) continue;
        fx[k] += 0.3 * ((px[k - 1] + px[k + 1]) / 2 - px[k]);
        fy[k] += 0.3 * ((py[k - 1] + py[k + 1]) / 2 - py[k]);
      }
    }

    // 움직이기 (한 번에 조금씩만)
    double clampStep(double v) => v > step ? step : (v < -step ? -step : v);
    for (var d = 0; d < nd; d++) {
      dx[d] += clampStep(gx[d]);
      dy[d] += clampStep(gy[d]);
    }
    for (var k = 0; k < np; k++) {
      if (bound[k] >= 0) continue;
      px[k] += clampStep(fx[k]);
      py[k] += clampStep(fy[k]);
    }
    for (var k = 0; k < np; k++) {
      final d = bound[k];
      if (d >= 0) {
        px[k] = dx[d];
        py[k] = dy[d];
      }
    }
  }
  // 넉넉한 목표 간격(판정보다 조금 더 큼)까지는 못 벌렸어도, 실제 규칙 판정만 통과하면 된다:
  // 아래에서 정확히 다시 확인한다. (좁은 틈을 빠듯하게 지나가는 선도 둘 수 있게)
  final note = converged ? '' : '목표 간격까지는 안 벌어졌어요 (선-선 $lastPair, 점-선 $lastDot, 점-점 $lastDots) ';

  // 결과를 모으고, 정말 아무 선도 만나지 않았는지 정확히 확인한다
  final newCurves = <List<P>>[];
  for (var c = 0; c < curves.length; c++) {
    newCurves.add([for (var i = 0; i < curves[c].x.length; i++) P(px[offset[c] + i] + ox, py[offset[c] + i] + oy)]);
  }
  if (!_planar(newCurves)) {
    lastRelaxFailure = '$note밀다가 선이 서로 가로질렀어요';
    return null;
  }

  final dots2 = [for (var i = 0; i < nOld; i++) Dot(P(dx[i] + ox, dy[i] + oy), b.dots[i].lives)];
  final old2 = [
    for (var c = 0; c < b.curves.length; c++)
      Curve(from: b.curves[c].from, to: b.curves[c].to, mid: b.curves[c].mid, pts: newCurves[c], owner: b.curves[c].owner),
  ];
  final relaxed = SproutsBoard(dots2, old2, bounds: bounds);
  final newPath = newCurves.last;
  final r = relaxed.validate(s, e, newPath.sublist(1, newPath.length - 1), relax: false);
  if (!r.ok) {
    final diag = StringBuffer();
    {
      final sp = relaxed.dots[s].pos, ep = relaxed.dots[e].pos;
      final chk = relaxed.pathFor(s, e, newPath.sublist(1, newPath.length - 1));
      for (var i = 0; i < chk.length; i++) {
        final p = chk[i];
        if (p.dist(sp) <= kNearDot || p.dist(ep) <= kNearDot) continue;
        final dn = relaxed.obstacles.nearest(p, kClear);
        if (dn < kClear) {
          var dd = 1e9;
          for (final d in relaxed.dots) {
            dd = min(dd, d.pos.dist(p));
          }
          diag.write(' [점$i/${chk.length} 선간격 ${dn.toStringAsFixed(1)} 시작거리 ${p.dist(sp).toStringAsFixed(0)} 끝거리 ${p.dist(ep).toStringAsFixed(0)} 가까운점 ${dd.toStringAsFixed(0)}]');
          break;
        }
      }
    }
    lastRelaxFailure = '$note밀린 뒤에도 규칙에 안 맞아요: ${r.reason}$diag';
    return null;
  }
  return StrokeResult.ok(
    r.path!,
    r.midIndex,
    layout: SproutsLayout([for (final d in dots2) d.pos], [for (final c in old2) c.pts], bounds: bounds == b.bounds ? null : bounds),
  );
}
