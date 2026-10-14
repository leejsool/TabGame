/// 콩나물(Sprouts) 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 규칙
/// - 판에 점이 몇 개 있다. 차례마다 점 두 개(또는 한 점을 시작과 끝으로)를 곡선으로 잇고,
///   방금 그린 선 위 어딘가에 새 점을 하나 찍는다. 이것이 한 수다.
/// - 선은 다른 선이나 자기 자신과 만나면 안 되고, 점 하나에 이어진 선은 최대 3개다.
/// - 더 이상 움직일 수 없을 때, 마지막으로 수를 둔 사람이 이긴다.
///
/// 점마다 "남은 목숨"(= 3 − 이어진 선 수)이 있다. 새 점은 선 위에 찍혀 선이 2개 이어진 셈이라 목숨이 1이다.
library;

import 'dart:math';

import 'sprouts_geometry.dart';
import 'sprouts_relax.dart';

class Dot {
  Dot(this.pos, this.lives);

  final P pos;

  /// 남은 목숨 (더 이을 수 있는 선의 수).
  int lives;
}

/// 그려진 곡선 하나. [mid]는 그 위에 찍힌 새 점의 번호.
class Curve {
  const Curve({required this.from, required this.to, required this.mid, required this.pts, required this.owner});

  final int from, to, mid;

  /// [kStep] 간격으로 촘촘히 찍은 점들 (처음과 끝은 점의 한가운데).
  final List<P> pts;

  /// 그린 사람 (0 / 1).
  final int owner;
}

/// 점과 선을 밀어서 간격을 벌린 뒤의 배치 (점의 위치들과 곡선별 점들).
class SproutsLayout {
  const SproutsLayout(this.dots, this.curves, {this.bounds});

  final List<P> dots;
  final List<List<P>> curves;

  /// 자리를 만들려고 판을 넓혔다면 넓어진 범위.
  final Bounds? bounds;
}

/// 한 수의 판정 결과.
class StrokeResult {
  const StrokeResult.ok(this.path, this.midIndex, {this.layout})
      : ok = true,
        reason = '',
        fixable = false;
  const StrokeResult.fail(this.reason, {this.fixable = false})
      : ok = false,
        path = null,
        midIndex = -1,
        layout = null;

  final bool ok;

  /// 안 되는 이유 (사람에게 보여 준다).
  final String reason;

  /// 위상적으로는 문제가 없고 자리가 좁아서 안 되는 것 (점과 선을 밀어 주면 될 수도 있다).
  final bool fixable;

  /// 판정을 통과한 곡선 (촘촘히 다시 찍은 것).
  final List<P>? path;

  /// [path] 안에서 새 점이 찍힐 자리.
  final int midIndex;

  /// 자리를 만들려고 기존 점과 선을 밀었다면 그 배치 ([path]는 밀린 뒤의 좌표다).
  final SproutsLayout? layout;
}

class SproutsBoard {
  SproutsBoard(this.dots, this.curves, {this.bounds = Bounds.initial});

  /// 처음 판: 점 [n]개를 서로 떨어뜨려 무작위로 놓는다.
  factory SproutsBoard.initial(int n, Random rng) {
    final pts = <P>[];
    const minGap = 90.0;
    var tries = 0;
    while (pts.length < n) {
      final p = P(60 + rng.nextDouble() * (kBoardW - 120), 60 + rng.nextDouble() * (kBoardH - 120));
      final gap = tries > 400 ? minGap * 0.6 : minGap;
      if (pts.every((q) => q.dist(p) >= gap)) pts.add(p);
      tries++;
    }
    return SproutsBoard([for (final p in pts) Dot(p, kMaxDegree)], []);
  }

  final List<Dot> dots;
  final List<Curve> curves;

  /// 지금 판의 범위. 빽빽하면 넓어지고, 남으면 좁아진다.
  Bounds bounds;

  PointIndex? _obstacles;

  SproutsBoard copy() => SproutsBoard([for (final d in dots) Dot(d.pos, d.lives)], List<Curve>.of(curves), bounds: bounds);

  /// 남은 목숨의 합. 한 수마다 정확히 1씩 줄어든다 (선 두 끝에서 2, 새 점에서 +1).
  int get totalLives => dots.fold(0, (s, d) => s + d.lives);

  /// 점 [n]개로 시작한 판은 아무리 길어도 3n−1수에서 끝난다.
  static int maxMoves(int n) => 3 * n - 1;

  /// [p]에 가장 가까운 점 (반지름 [within] 안). 없으면 -1. [needLive]면 목숨이 남은 점만.
  int nearestDot(P p, {double? within, bool needLive = false}) {
    var best = -1;
    // 판이 넓어져 화면에서 작아 보이면 손가락이 닿는 범위도 그만큼 넓힌다
    var bd = within ?? kSnap * pow(max(1.0, bounds.scale), 0.8);
    for (var i = 0; i < dots.length; i++) {
      if (needLive && dots[i].lives <= 0) continue;
      final d = dots[i].pos.dist(p);
      if (d <= bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  /// 이미 그려진 선들의 점 (점 가까운 부분은 빼고) — 새 선이 이 점들에서 [kClear] 이상 떨어져야 한다.
  PointIndex get obstacles {
    var idx = _obstacles;
    if (idx != null) return idx;
    idx = PointIndex(kClear);
    for (final c in curves) {
      for (final p in c.pts) {
        if (dots.every((d) => d.pos.dist(p) > kNearDot)) idx.add(p);
      }
    }
    return _obstacles = idx;
  }

  /// 궤적 [stroke]이 끝나는 점. 손가락이 점을 살짝 지나쳐서 멀어진 곳에서 떼었다면, 끝에서부터 거슬러 올라가
  /// 점 위를 지나간 자리를 찾아 그 점으로 본다. ([startDot]은 출발한 점이라 건너뛴다: 짧은 궤적에서 시작점이 끝점으로 오인되지 않게)
  int endDotFor(List<P> stroke, int startDot) {
    final last = stroke.last;
    final cand = nearestDot(last);
    if (cand >= 0 && dots[cand].pos.dist(last) <= kDotR * 1.6) return cand; // 점 위에서 뗐다
    // 고리(출발한 점으로 돌아오기)는 충분히 길게 그렸을 때만 인정한다
    final loopOk = pathLength(stroke) >= 90;
    var walked = 0.0;
    for (var i = stroke.length - 1; i > 0 && walked <= 70; i--) {
      walked += stroke[i].dist(stroke[i - 1]);
      final d = nearestDot(stroke[i - 1], within: kDotR * 1.6);
      if (d >= 0 && d != cand && (d != startDot || loopOk)) return d;
    }
    return cand;
  }

  /// 손가락 궤적 [stroke]에 양 끝(점의 한가운데)을 붙여 촘촘히 다시 찍은 곡선.
  List<P> pathFor(int s, int e, List<P> stroke) {
    final sp = dots[s].pos, ep = dots[e].pos;
    // 점 안쪽에서 찍힌 궤적 점은 버리고, 양 끝은 점의 한가운데로 맞춘다
    final inner = <P>[
      for (final p in trimWobble(stroke, sp, ep, kSnap * pow(max(1.0, bounds.scale), 0.8)))
        if (p.dist(sp) > kDotR * 0.8 && p.dist(ep) > kDotR * 0.8) p,
    ];
    return resample([sp, ...inner, ep]);
  }

  /// 손가락이 점을 살짝 지나치거나(끝) 점 뒤쪽에서 출발해 점을 거치는(처음) 궤적의 군더더기를 잘라 낸다.
  ///
  /// 점 [sp]·[ep] 둘레 [zone] 안에서만 맴도는 처음/끝 부분은, 점 가까이([kKeepOut] 안)로 처음 들어온
  /// (끝) / 마지막으로 나간(처음) 자리에서 끊는다. 그러면 곡선은 점에 닿는 순간 끝나고, 점을 지나쳐 돌아오는
  /// 부분 때문에 "점에 너무 가까워요"라고 하지 않는다.
  static List<P> trimWobble(List<P> stroke, P sp, P ep, double zone) {
    final n = stroke.length;
    if (n < 3) return stroke;
    final near = kKeepOut * 0.95;
    final loop = sp == ep;

    // 처음: 시작 점 둘레 안에서 맴도는 구간
    var run = 0;
    while (run < n && stroke[run].dist(sp) <= zone) {
      run++;
    }
    var headLimit = run;
    if (run == n) {
      // 궤적 전체가 점 둘레 안이다 (가까운 두 점 사이, 또는 작은 고리)
      if (loop) return stroke;
      headLimit = _closest(stroke, ep); // 도착 점에 가장 가까워지기 전까지만 본다
    }
    var headCut = -1;
    for (var i = 0; i < headLimit; i++) {
      if (stroke[i].dist(sp) < near) headCut = i;
    }

    // 끝: 도착 점 둘레 안에서 끝나는 구간
    var tailStart = n;
    while (tailStart > 0 && stroke[tailStart - 1].dist(ep) <= zone) {
      tailStart--;
    }
    var from = tailStart;
    if (tailStart == 0) from = _closest(stroke, sp); // 시작 점에서 가장 멀어진 뒤부터만 본다
    from = max(from, headCut + 1);
    var tailCut = n;
    for (var i = from; i < n; i++) {
      if (stroke[i].dist(ep) < near) {
        tailCut = i;
        break;
      }
    }
    if (headCut + 1 >= tailCut) return const <P>[]; // 두 점이 가까워서 사이에 남는 게 없다: 곧은 선으로 잇는다
    return stroke.sublist(headCut + 1, tailCut);
  }

  static int _closest(List<P> pts, P q) {
    var best = 0;
    var bd = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = pts[i].dist(q);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  /// [s]에서 [e]로 가는 곡선 [stroke](손가락 궤적, 양 끝점은 없어도 된다)가 규칙에 맞는지 본다.
  ///
  /// 자리가 좁아서만 안 되는 수는 [relax]가 true일 때 기존 점과 선을 살살 밀어서 자리를 만들어 보고,
  /// 되면 그 배치를 [StrokeResult.layout]에 담아 돌려준다 (콩나물은 위상만 중요하니 같은 판이다).
  StrokeResult validate(int s, int e, List<P> stroke, {bool relax = true}) {
    final strict = _validateStrict(s, e, stroke);
    if (strict.ok || !relax || !strict.fixable) return strict;
    return relaxForStroke(this, s, e, pathFor(s, e, stroke)) ?? strict;
  }

  StrokeResult _validateStrict(int s, int e, List<P> stroke) {
    if (s < 0 || e < 0 || s >= dots.length || e >= dots.length) {
      return const StrokeResult.fail('점에서 시작해서 점에서 끝나야 해요');
    }
    final loop = s == e;
    if (dots[s].lives < (loop ? 2 : 1)) {
      return StrokeResult.fail(loop ? '이 점에는 고리를 그릴 만큼 선을 더 이을 수 없어요 (2개 필요)' : '시작한 점에는 더 이을 수 없어요');
    }
    if (dots[e].lives < 1) return const StrokeResult.fail('끝난 점에는 더 이을 수 없어요 (선이 이미 3개예요)');

    final sp = dots[s].pos, ep = dots[e].pos;
    final path = pathFor(s, e, stroke);
    if (path.length < 4) return const StrokeResult.fail('선이 너무 짧아요');

    final total = pathLength(path);
    if (loop) {
      if (total < 60 || polygonArea(path).abs() < 250) return const StrokeResult.fail('고리가 너무 작아요. 더 크게 그려 보세요');
    }

    // 지금까지의 거리(arc)
    final arc = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      arc[i] = arc[i - 1] + path[i - 1].dist(path[i]);
    }

    final obs = obstacles;
    bool nearEnd(P p) => p.dist(sp) <= kNearDot || p.dist(ep) <= kNearDot;
    for (var i = 0; i < path.length; i++) {
      final p = path[i];
      if (p.x < bounds.x0 + kMargin || p.y < bounds.y0 + kMargin || p.x > bounds.x1 - kMargin || p.y > bounds.y1 - kMargin) {
        return const StrokeResult.fail('판 밖으로 나갔어요');
      }
      // 다른 점에서 멀리
      for (var d = 0; d < dots.length; d++) {
        if (d == s || d == e) continue;
        if (dots[d].pos.dist(p) < kKeepOut) return const StrokeResult.fail('다른 점에 너무 가까워요', fixable: true);
      }
      // 시작/끝 점은 처음과 마지막 부분 말고는 가까이 가면 안 된다
      // (고리는 같은 점에서 나와 같은 점으로 돌아오니, 처음과 마지막 부분을 모두 빼고 본다)
      final farFromStart = arc[i] >= 3 * kInnerR, farFromEnd = total - arc[i] >= 3 * kInnerR;
      if (farFromStart && (!loop || farFromEnd) && p.dist(sp) < kKeepOut) return const StrokeResult.fail('시작한 점에 너무 가까워요', fixable: true);
      if (farFromEnd && (!loop || farFromStart) && p.dist(ep) < kKeepOut) return const StrokeResult.fail('끝나는 점에 너무 가까워요', fixable: true);
      // 다른 선과의 간격
      if (!nearEnd(p) && obs.nearest(p, kClear) < kClear) return const StrokeResult.fail('다른 선과 만났어요', fixable: true);
    }
    // 자기 자신과 만나면 안 된다
    for (var i = 0; i < path.length; i++) {
      if (nearEnd(path[i])) continue;
      for (var j = i + 1; j < path.length; j++) {
        if (arc[j] - arc[i] < 3 * kInnerR) continue;
        if (nearEnd(path[j])) continue;
        if (path[i].dist2(path[j]) < kClear * kClear) return const StrokeResult.fail('선이 자기 자신과 만났어요', fixable: true);
      }
    }

    // 새 점의 자리: 선의 가운데 근처에서 주변과 가장 멀리 떨어진 곳
    var best = -1;
    var bestScore = -1.0;
    for (var i = 0; i < path.length; i++) {
      final f = arc[i] / total;
      if (f < 0.25 || f > 0.75) continue;
      final p = path[i];
      var score = min(p.dist(sp), p.dist(ep));
      if (score < kKeepOut * 0.9) continue; // 시작·끝 점과 겹치면 안 된다
      score = min(score, obs.nearest(p, 3 * kDotR));
      for (var d = 0; d < dots.length; d++) {
        if (d == s || d == e) continue;
        score = min(score, dots[d].pos.dist(p));
      }
      // 가운데에 가까울수록 조금 유리하게
      score -= (f - 0.5).abs() * 12;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best < 0) return const StrokeResult.fail('선이 너무 짧아서 새 점을 찍을 자리가 없어요', fixable: true);
    return StrokeResult.ok(path, best);
  }

  /// 판정을 통과한 곡선으로 한 수를 둔다. 새 점의 번호를 돌려준다.
  int apply(int s, int e, StrokeResult r, int owner) {
    assert(r.ok);
    final path = r.path!;
    final layout = r.layout;
    if (layout != null) {
      // 자리를 만들려고 기존 점과 선을 밀었다
      for (var i = 0; i < layout.dots.length; i++) {
        dots[i] = Dot(layout.dots[i], dots[i].lives);
      }
      for (var i = 0; i < layout.curves.length; i++) {
        final c = curves[i];
        curves[i] = Curve(from: c.from, to: c.to, mid: c.mid, pts: layout.curves[i], owner: c.owner);
      }
    }
    if (layout?.bounds != null) bounds = layout!.bounds!;
    final mid = dots.length;
    dots[s].lives -= 1;
    dots[e].lives -= 1;
    dots.add(Dot(path[r.midIndex], 1));
    curves.add(Curve(from: s, to: e, mid: mid, pts: path, owner: owner));
    _obstacles = null;
    bounds = fittedBounds();
    return mid;
  }

  /// 점과 선을 모두 담는 데 필요한 만큼만의 범위: 남는 자리는 잘라 내고(확대), 모자라면 넓힌다(축소).
  /// 처음 크기보다 작게는 줄이지 않는다.
  Bounds fittedBounds() {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    void see(P p) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }

    for (final d in dots) {
      see(d.pos);
    }
    for (final c in curves) {
      for (final p in c.pts) {
        see(p);
      }
    }
    if (minX == double.infinity) return Bounds.initial;
    const pad = kBoardPad;
    if (minX - pad >= Bounds.initial.x0 && minY - pad >= Bounds.initial.y0 && maxX + pad <= Bounds.initial.x1 && maxY + pad <= Bounds.initial.y1) {
      return Bounds.initial; // 처음 판 안에 여유 있게 들어간다
    }
    final s = [1.0, (maxX - minX + 2 * pad) / kBoardW, (maxY - minY + 2 * pad) / kBoardH].reduce(max).clamp(1.0, kMaxBoardScale);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    return Bounds(cx - kBoardW * s / 2, cy - kBoardH * s / 2, cx + kBoardW * s / 2, cy + kBoardH * s / 2);
  }

  // ── 저장/전달 (isolate로 넘기려고 숫자 목록으로) ──

  /// [x0, y0, x1, y1, dotCount, (x, y, lives)×n, curveCount, (from, to, mid, owner, pointCount, (x, y)×k)×m]
  List<double> toData() {
    final out = <double>[bounds.x0, bounds.y0, bounds.x1, bounds.y1, dots.length.toDouble()];
    for (final d in dots) {
      out..add(d.pos.x)..add(d.pos.y)..add(d.lives.toDouble());
    }
    out.add(curves.length.toDouble());
    for (final c in curves) {
      out..add(c.from.toDouble())..add(c.to.toDouble())..add(c.mid.toDouble())..add(c.owner.toDouble())..add(c.pts.length.toDouble());
      for (final p in c.pts) {
        out..add(p.x)..add(p.y);
      }
    }
    return out;
  }

  static SproutsBoard fromData(List<double> d) {
    var i = 0;
    final bounds = Bounds(d[i++], d[i++], d[i++], d[i++]);
    final n = d[i++].toInt();
    final dots = <Dot>[];
    for (var k = 0; k < n; k++) {
      final x = d[i++], y = d[i++], l = d[i++].toInt();
      dots.add(Dot(P(x, y), l));
    }
    final m = d[i++].toInt();
    final curves = <Curve>[];
    for (var k = 0; k < m; k++) {
      final from = d[i++].toInt(), to = d[i++].toInt(), mid = d[i++].toInt(), owner = d[i++].toInt(), cnt = d[i++].toInt();
      final pts = <P>[for (var q = 0; q < cnt; q++) P(d[i++], d[i++])];
      curves.add(Curve(from: from, to: to, mid: mid, pts: pts, owner: owner));
    }
    return SproutsBoard(dots, curves, bounds: bounds);
  }
}
