part of 'sprouts_planner.dart';

// 고리·직접 잇기 계산 (파일을 역할별로 나눈 것)

/// 점 [s]에서 나가 자기 자신으로 돌아오는 길쭉한 타원 고리 (좁은 틈에도 들어간다). 되는 모양이 없으면 null.
SproutsMove? _ovalLoop(SproutsBoard b, int s, bool relax) {
  final o = b.dots[s].pos;
  for (final (a, w) in const [(26.0, 9.0), (36.0, 9.0), (20.0, 7.0), (46.0, 11.0)]) {
    for (var k = 0; k < 36; k++) {
      final theta = k * 10 * pi / 180;
      final ux = cos(theta), uy = sin(theta);
      final cen = P(o.x + a * ux, o.y + a * uy);
      final pts = <P>[
        for (var i = 1; i < 48; i++)
          P(
            cen.x - a * cos(i * 2 * pi / 48) * ux - w * sin(i * 2 * pi / 48) * uy,
            cen.y - a * cos(i * 2 * pi / 48) * uy + w * sin(i * 2 * pi / 48) * ux,
          ),
      ];
      final r = b.validate(s, s, pts, relax: relax);
      if (r.ok) return SproutsMove(s, s, r);
    }
  }
  return null;
}

/// [s]의 둘레에서 출발해, [targets] 각 점의 둘레까지 가는 칸 길. 점 번호 → 칸 번호 목록(출발→도착).
Map<int, List<int>> _bfs(_Grid g, SproutsBoard b, int s, Set<int> targets) {
  final cols = g.cols, rows = g.rows;
  final n = cols * rows;
  final parent = Int32List(n)..fillRange(0, n, -2); // -2 = 아직 안 감, -1 = 출발
  final queue = Queue<int>();
  final sp = b.dots[s].pos;
  const ring = kDotR + 7;
  final span = (ring / g.g).ceil() + 1;
  final scx = ((sp.x - g.ox) / g.g).floor(), scy = ((sp.y - g.oy) / g.g).floor();
  for (var r = max(0, scy - span); r <= min(rows - 1, scy + span); r++) {
    for (var c = max(0, scx - span); c <= min(cols - 1, scx + span); c++) {
      final k = r * cols + c;
      if (g.blocked[k] != 0) continue;
      final cp = g.center(c, r);
      final d = cp.dist(sp);
      if (d >= kDotR && d <= ring && !_crossesNear(b, s, cp)) {
        parent[k] = -1;
        queue.add(k);
      }
    }
  }
  final result = <int, List<int>>{};
  const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)];
  while (queue.isNotEmpty && result.length < targets.length) {
    final k = queue.removeFirst();
    final c = k % cols, r = k ~/ cols;
    final zk = g.zone[k];
    // 목표 점의 둘레에 닿았다
    if (zk >= 0 && zk != s && targets.contains(zk) && g.zoneDist[k] <= ring && !result.containsKey(zk) && !_crossesNear(b, zk, g.center(c, r))) {
      final path = <int>[];
      for (var q = k; q >= 0; q = parent[q]) {
        path.add(q);
        if (parent[q] == -1) break;
      }
      result[zk] = path.reversed.toList();
      continue; // 그 점 안으로는 더 들어가지 않는다
    }
    for (final (dc, dr) in dirs) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      final nk = nr * cols + nc;
      if (parent[nk] != -2 || g.blocked[nk] != 0) continue;
      if (dc != 0 && dr != 0 && (g.blocked[r * cols + nc] != 0 || g.blocked[nr * cols + c] != 0)) continue; // 모서리 가로지르기 금지
      final nz = g.zone[nk];
      if (nz >= 0 && nz != s) {
        if (!targets.contains(nz)) continue; // 다른 점의 둘레는 지나갈 수 없다
        // 목표 점 둘레에서는 가운데 쪽으로만 다가간다
        if (zk == nz && g.zoneDist[nk] >= g.zoneDist[k]) continue;
      } else if (zk >= 0 && zk != s && targets.contains(zk)) {
        continue; // 목표 점 둘레에 들어갔으면 거기서 나오지 않는다
      }
      parent[nk] = k;
      queue.add(nk);
    }
  }
  return result;
}

/// 가까운 두 점을 곧은 선과 살짝 휘어진 선 두 가지로 이어 본다.
SproutsMove? _direct(SproutsBoard b, int s, int e, bool relax, [List<double> bends = const [0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 45.0, -45.0]]) {
  final a = b.dots[s].pos, c = b.dots[e].pos;
  final d = c - a;
  final len = sqrt(d.x * d.x + d.y * d.y);
  if (len < 1) return null;
  final nx = -d.y / len, ny = d.x / len;
  for (final bend in bends) {
    final stroke = [
      for (var i = 1; i < 40; i++)
        P(
          a.x + d.x * i / 40 + nx * bend * 4 * (i / 40) * (1 - i / 40),
          a.y + d.y * i / 40 + ny * bend * 4 * (i / 40) * (1 - i / 40),
        ),
    ];
    final r = b.validate(s, e, stroke, relax: relax);
    if (r.ok) return SproutsMove(s, e, r);
  }
  return null;
}

SproutsMove? _toMove(_Grid g, SproutsBoard b, int s, int e, List<int> cells, bool relax, {void Function(List<P> source)? onSource}) {
  if (cells.isEmpty) return null;
  final raw = <P>[for (final k in cells) g.center(k % g.cols, k ~/ g.cols)];

  bool free(P p) {
    final c = ((p.x - g.ox) / g.g).floor(), r = ((p.y - g.oy) / g.g).floor();
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rows) return false;
    final k = r * g.cols + c;
    if (g.blocked[k] != 0) return false;
    final z = g.zone[k];
    return z < 0 || z == s || z == e;
  }

  bool lineOfSight(P a, P c) {
    final len = a.dist(c);
    final steps = max(1, (len / 2.5).ceil());
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      if (!free(P(a.x + (c.x - a.x) * t, a.y + (c.y - a.y) * t))) return false;
    }
    return true;
  }

  // 곧게 다듬기: 보이는 가장 먼 점으로 바로 이어 간다
  final pulled = <P>[raw.first];
  var i = 0;
  while (i < raw.length - 1) {
    var j = raw.length - 1;
    while (j > i + 1 && !lineOfSight(raw[i], raw[j])) {
      j--;
    }
    pulled.add(raw[j]);
    i = j;
  }

  List<P> smooth(List<P> pts, int rounds) {
    var cur = pts;
    for (var k = 0; k < rounds; k++) {
      final next = <P>[cur.first];
      for (var q = 0; q < cur.length - 1; q++) {
        next
          ..add(cur[q] * 0.75 + cur[q + 1] * 0.25)
          ..add(cur[q] * 0.25 + cur[q + 1] * 0.75);
      }
      next.add(cur.last);
      cur = next;
    }
    return cur;
  }

  for (final candidate in [smooth(pulled, 2), pulled, raw]) {
    final source = resample(candidate);
    final r = b.validate(s, e, source, relax: relax, trim: false);
    if (r.ok) {
      onSource?.call(source);
      return SproutsMove(s, e, r);
    }
  }
  return null;
}

/// 둘 수 있는 수가 하나라도 있나.
bool hasMove(SproutsBoard b, {bool allowRelax = true}) => findMoves(b, firstOnly: true, allowRelax: allowRelax).isNotEmpty;

/// 사람이 그은 곡선 [stroke]은 규칙에 안 맞지만 [s]에서 [e]로 이을 수는 있을 때, 그 곡선을 최대한 따라가면서
/// 규칙에 맞는 길을 알아서 찾아 준다 (살짝 선을 스치거나 좁은 틈을 빠듯하게 지나간 선을 바로잡는다).
///
/// 격자 위에서 "손으로 그은 선에서 멀수록 비싼" 길찾기를 하고, 찾은 길은 [_toMove]가 다듬어 규칙 판정까지 한다.
/// 바로잡은 선이 손으로 그은 선에서 [maxDeviation] 넘게 벗어나면 (선을 가로질러 크게 돌아가야 하면) 고치지 않고 null을 돌려준다.
SproutsMove? guidedMove(SproutsBoard b, int s, int e, List<P> stroke, {double maxDeviation = 45}) =>
    guidedFix(b, s, e, stroke, maxDeviation: maxDeviation)?.move;

/// [guidedMove]와 같되, 판정을 통과한 곡선의 원래 모양([source], 판을 밀기 전의 좌표)도 함께 돌려준다.
/// ([source]를 다시 [SproutsBoard.validate]에 넣으면 같은 수가 나온다: 다른 isolate에서 찾아 온 뒤 여기서 확정할 때 쓴다.)
({SproutsMove move, List<P> source})? guidedFix(SproutsBoard b, int s, int e, List<P> stroke, {double maxDeviation = 45}) {
  if (s == e || s < 0 || e < 0 || stroke.length < 2) return null;
  if (b.dots[s].lives < 1 || b.dots[e].lives < 1) return null;
  final guide = PointIndex(12);
  for (final p in resample(stroke, 4)) {
    guide.add(p);
  }
  const plans = <(double, double, double, bool)>[
    (5.0, kClear + 3, kKeepOut, false),
    (2.5, kClear + 1, kKeepOut, false),
    (3.0, 2.5, kDotR + 3, true),
  ];
  for (final (g, reach, zoneR, relax) in plans) {
    final grid = _Grid(b, g, reach, zoneR);
    final cells = _guidedRoute(grid, b, s, e, guide);
    if (cells == null) continue;
    List<P>? source;
    final move = _toMove(grid, b, s, e, cells, relax, onSource: (p) => source = p);
    if (move == null || source == null) continue;
    if (_deviation(b, s, e, stroke, move.path) > maxDeviation) continue;
    // 그은 선과 같은 길(같은 영역, 점·덩어리의 같은 쪽)을 지나야 한다: 다른 쪽으로 돌아가면 위상이 달라진다
    if (!sameRoute(b, s, e, stroke, source!)) continue;
    return (move: move, source: source!);
  }
  return null;
}

/// 선분 ab와 cd가 가로지르거나 맞닿는가 (한 점이 상대 선분 위에 정확히 얹힌 경우까지).
bool _segTouch(P a, P b, P c, P d) =>
    _cross(a, b, c, d) ||
    min(min(pointSegDist(a, c, d), pointSegDist(b, c, d)), min(pointSegDist(c, a, b), pointSegDist(d, a, b))) < 0.75;

/// 그은 선 [stroke]이 이미 그려진 선을 (출발·도착 점 바로 곁이 아닌 곳에서) 가로지르는가.
/// 가로질렀다면 어느 쪽으로 지나가려던 것인지 알 수 없다 (그저 두 점을 잇고 싶었던 것).
