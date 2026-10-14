/// 콩나물(Sprouts) 기하 도구 (화면과 무관한 순수 계산).
///
/// 판은 [kBoardW]×[kBoardH] 크기의 가상 좌표계이고, 화면은 이것을 비율을 지켜 늘려 그린다.
library;

import 'dart:math';

/// 처음 판의 가로·세로 (가상 단위). 판이 빽빽해지면 이보다 커질 수 있다 ([Bounds]).
const double kBoardW = 400;
const double kBoardH = 460;

/// 판을 가장 크게 넓힐 수 있는 배율 (처음 크기의 몇 배까지).
const double kMaxBoardScale = 2.5;

/// 선과 점 둘레로 판이 가져야 하는 여백 (판을 줄일 때 쓴다).
const double kBoardPad = 70;

/// 점의 반지름.
const double kDotR = 8;

/// 점 근처로 보는 반지름: 이 안에서는 선끼리 모여 있어도 닿은 것으로 치지 않는다 (선은 점의 가운데로 모인다).
const double kInnerR = 12;

/// 점 밖에서 서로 다른 선(또는 자기 자신의 먼 부분) 사이에 필요한 최소 간격.
const double kClear = 8;

/// 선이 시작·끝 점이 아닌 다른 점에서 떨어져야 하는 거리.
const double kKeepOut = 20;

/// 판 가장자리에서 선이 떨어져야 하는 거리.
const double kMargin = 8;

/// 손가락이 점에서 이만큼 떨어진 곳에서 시작/끝나도 그 점으로 본다.
const double kSnap = 34;

/// 점 한 개에 이을 수 있는 선의 최대 수.
const int kMaxDegree = 3;

/// 곡선을 이 간격으로 촘촘히 나눠 저장한다.
const double kStep = 3;

/// 판의 범위 (가상 좌표). 화면은 이 범위를 꽉 채워 보여 준다.
/// 판이 빽빽해서 점과 선을 밀 자리가 없으면 범위가 넓어지고(화면은 멀어져 보임), 남는 자리가 생기면 다시 좁아진다(확대).
class Bounds {
  const Bounds(this.x0, this.y0, this.x1, this.y1);

  /// 처음 판.
  static const Bounds initial = Bounds(0, 0, kBoardW, kBoardH);

  final double x0, y0, x1, y1;

  double get width => x1 - x0;
  double get height => y1 - y0;
  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;

  /// 처음 크기의 몇 배인가.
  double get scale => width / kBoardW;

  /// 가운데는 그대로 두고 [f]배로 키운 범위 (처음 크기의 [kMaxBoardScale]배까지).
  Bounds grown(double f) {
    final s = min(scale * f, kMaxBoardScale);
    return Bounds(cx - kBoardW * s / 2, cy - kBoardH * s / 2, cx + kBoardW * s / 2, cy + kBoardH * s / 2);
  }

  static Bounds lerp(Bounds a, Bounds b, double t) => Bounds(
        a.x0 + (b.x0 - a.x0) * t,
        a.y0 + (b.y0 - a.y0) * t,
        a.x1 + (b.x1 - a.x1) * t,
        a.y1 + (b.y1 - a.y1) * t,
      );

  @override
  bool operator ==(Object other) => other is Bounds && other.x0 == x0 && other.y0 == y0 && other.x1 == x1 && other.y1 == y1;

  @override
  int get hashCode => Object.hash(x0, y0, x1, y1);

  @override
  String toString() => 'Bounds(${x0.round()},${y0.round()} ~ ${x1.round()},${y1.round()})';
}

class P {
  const P(this.x, this.y);

  final double x, y;

  double dist(P o) => sqrt(dist2(o));
  double dist2(P o) {
    final dx = x - o.x, dy = y - o.y;
    return dx * dx + dy * dy;
  }

  P operator +(P o) => P(x + o.x, y + o.y);
  P operator -(P o) => P(x - o.x, y - o.y);
  P operator *(double k) => P(x * k, y * k);

  @override
  bool operator ==(Object other) => other is P && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'P(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// 꺾은선의 길이.
double pathLength(List<P> pts) {
  var s = 0.0;
  for (var i = 1; i < pts.length; i++) {
    s += pts[i - 1].dist(pts[i]);
  }
  return s;
}

/// 꺾은선을 [step] 간격으로 고르게 다시 찍는다 (처음과 끝은 그대로).
List<P> resample(List<P> pts, [double step = kStep]) {
  if (pts.length < 2) return List<P>.of(pts);
  final out = <P>[pts.first];
  var carry = 0.0; // 마지막으로 찍은 점에서 현재 선분 시작까지 모자란 거리
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final seg = a.dist(b);
    if (seg == 0) continue;
    var at = step - carry;
    while (at <= seg) {
      final t = at / seg;
      out.add(P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
      at += step;
    }
    carry = seg - (at - step);
  }
  if (out.last.dist(pts.last) > 0.01) {
    // 끝에 너무 가까운 점은 지우고 정확한 끝점을 붙인다
    if (out.length > 1 && out.last.dist(pts.last) < step * 0.5) out.removeLast();
    out.add(pts.last);
  }
  return out;
}

/// 부호 있는 넓이 (신발끈 공식).
double polygonArea(List<P> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

/// 점 [p]에서 선분 ab까지의 거리.
double pointSegDist(P p, P a, P b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final l2 = dx * dx + dy * dy;
  if (l2 == 0) return p.dist(a);
  var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2;
  t = t.clamp(0.0, 1.0);
  return p.dist(P(a.x + dx * t, a.y + dy * t));
}

/// 꺾은선 위에서 시작점으로부터 [arc]만큼 간 점.
P pointAtArc(List<P> pts, double arc) {
  var left = arc;
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i - 1].dist(pts[i]);
    if (left <= seg || i == pts.length - 1) {
      final t = seg == 0 ? 0.0 : (left / seg).clamp(0.0, 1.0);
      return P(pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t, pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t);
    }
    left -= seg;
  }
  return pts.last;
}

/// 가까운 점들을 빠르게 찾기 위한 칸 나누기 (점 → 칸 번호).
class PointIndex {
  PointIndex(this.cell) : _cells = {};

  final double cell;
  final Map<int, List<P>> _cells;

  int _key(int cx, int cy) => cx * 100003 + cy;

  void add(P p) {
    final k = _key((p.x / cell).floor(), (p.y / cell).floor());
    (_cells[k] ??= <P>[]).add(p);
  }

  /// [p]에서 가장 가까운 점까지의 거리 (모두 [limit]보다 멀면 [limit]).
  double nearest(P p, double limit) {
    final cx = (p.x / cell).floor(), cy = (p.y / cell).floor();
    final r = (limit / cell).ceil();
    var best = limit * limit;
    for (var x = cx - r; x <= cx + r; x++) {
      for (var y = cy - r; y <= cy + r; y++) {
        final list = _cells[_key(x, y)];
        if (list == null) continue;
        for (final q in list) {
          final d = p.dist2(q);
          if (d < best) best = d;
        }
      }
    }
    return sqrt(best);
  }

  /// 모든 점을 하나씩 (칸 나누기와 상관없이).
  Iterable<P> get all sync* {
    for (final l in _cells.values) {
      yield* l;
    }
  }

  /// 반지름 [r] 안에 점이 있나.
  bool anyWithin(P p, double r) => nearest(p, r) < r;
}
