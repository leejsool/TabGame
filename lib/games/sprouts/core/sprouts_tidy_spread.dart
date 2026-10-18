part of 'sprouts_tidy.dart';

// 퍼뜨리기 계산 (파일을 역할별로 나눈 것)

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
