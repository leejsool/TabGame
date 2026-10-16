/// 콩나물에서 "둘 수 있는 수"를 찾는다 (CPU·힌트·끝났는지 판정에 쓴다).
///
/// 판을 작은 격자로 나눠 "다른 선·점에 닿지 않는 칸"만 남기고, 점에서 점으로 가는 가장 짧은 길을
/// 너비 우선 탐색으로 찾는다. 찾은 길은 부드럽게 다듬은 뒤 규칙 판정([SproutsBoard.validate])을 다시 통과해야
/// 수로 인정한다. 한 점에서 자기 자신으로 돌아오는 고리는 동그라미 모양을 여러 방향으로 대 보고 같은 판정을 한다.
///
/// 격자는 처음엔 성기고 넉넉하게(빠르게) 보고, 그래도 둘 곳이 하나도 없으면 촘촘하고 빠듯하게 한 번 더 본다.
/// (사람이 손으로 빠듯한 틈을 잘 그릴 수 있는데 "끝났다"고 하는 일을 줄이려고.)
library;

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'sprouts_board.dart';
import 'sprouts_faces.dart';
import 'sprouts_geometry.dart';

/// 찾아낸 한 수: [s]에서 [e]로 가는 곡선 (판정을 통과한 것).
class SproutsMove {
  const SproutsMove(this.s, this.e, this.result);

  final int s, e;
  final StrokeResult result;

  List<P> get path => result.path!;

  bool get isLoop => s == e;
}

final double sqrt2 = sqrt(2);

/// 선분 ab와 cd가 한 점에서 가로지르는가 (끝점만 닿는 것은 아니다).
bool _cross(P a, P b, P c, P d) {
  double o(P p, P q, P r) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  final o1 = o(a, b, c), o2 = o(a, b, d), o3 = o(c, d, a), o4 = o(c, d, b);
  return ((o1 > 1e-9 && o2 < -1e-9) || (o1 < -1e-9 && o2 > 1e-9)) && ((o3 > 1e-9 && o4 < -1e-9) || (o3 < -1e-9 && o4 > 1e-9));
}

/// 점 [dot]의 한가운데에서 [to]로 곧게 가는 선분이 점 둘레의 선을 가로지르는가 (점 한가운데로 모이는 선들과 닿는 것은 빼고).
bool _crossesNear(SproutsBoard b, int dot, P to) {
  final o = b.dots[dot].pos;
  for (final c in b.curves) {
    final pts = c.pts;
    for (var j = 0; j + 1 < pts.length; j++) {
      if (pts[j].dist(o) > 40) continue;
      if (!_cross(o, to, pts[j], pts[j + 1])) continue;
      final m = P((pts[j].x + pts[j + 1].x) / 2, (pts[j].y + pts[j + 1].y) / 2);
      if (m.dist(o) < 4) continue;
      return true;
    }
  }
  return false;
}

class _Grid {
  /// [g]: 격자 한 칸의 크기, [reach]: 선에서 이만큼 안쪽 칸은 막는다.
  _Grid(SproutsBoard b, this.g, this.reach, [this.zoneR = kKeepOut])
      : ox = b.bounds.x0,
        oy = b.bounds.y0,
        cols = (b.bounds.width / g).ceil(),
        rows = (b.bounds.height / g).ceil() {
    final n = cols * rows;
    blocked = Uint8List(n);
    zone = Int16List(n)..fillRange(0, n, -1);
    zoneDist = Float32List(n);
    final span = (reach / g).ceil() + 1;
    // 판 가장자리
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = center(c, r);
        if (p.x < b.bounds.x0 + kMargin + 3 ||
            p.y < b.bounds.y0 + kMargin + 3 ||
            p.x > b.bounds.x1 - kMargin - 3 ||
            p.y > b.bounds.y1 - kMargin - 3) {
          blocked[r * cols + c] = 1;
        }
      }
    }
    // 이미 그려진 선 (점 가까운 부분은 빼고)
    for (final q in b.obstacles.all) {
      final cx = ((q.x - ox) / g).floor(), cy = ((q.y - oy) / g).floor();
      for (var r = max(0, cy - span); r <= min(rows - 1, cy + span); r++) {
        for (var c = max(0, cx - span); c <= min(cols - 1, cx + span); c++) {
          if (center(c, r).dist(q) < reach) blocked[r * cols + c] = 1;
        }
      }
    }
    // 점 가까이를 지나가는 선(위에서 빠진 부분)도 얇게 막는다: 안 그러면 길이 점 바로 옆에서 그 점에 이어진 선을 가로질러 버린다
    final barrier = max(3.5, 0.8 * sqrt2 * g);
    final bspan = (barrier / g).ceil() + 1;
    for (final c in b.curves) {
      for (final q in c.pts) {
        if (b.dots.every((d) => d.pos.dist(q) > kNearDot)) continue;
        final cx = ((q.x - ox) / g).floor(), cy = ((q.y - oy) / g).floor();
        for (var r = max(0, cy - bspan); r <= min(rows - 1, cy + bspan); r++) {
          for (var c2 = max(0, cx - bspan); c2 <= min(cols - 1, cx + bspan); c2++) {
            if (center(c2, r).dist(q) < barrier) blocked[r * cols + c2] = 1;
          }
        }
      }
    }
    // 점: 한가운데는 막고, 둘레(kKeepOut)는 그 점의 구역으로 표시
    final rr = (zoneR / g).ceil() + 1;
    for (var i = 0; i < b.dots.length; i++) {
      final d = b.dots[i].pos;
      final cx = ((d.x - ox) / g).floor(), cy = ((d.y - oy) / g).floor();
      for (var r = max(0, cy - rr); r <= min(rows - 1, cy + rr); r++) {
        for (var c = max(0, cx - rr); c <= min(cols - 1, cx + rr); c++) {
          final dist = center(c, r).dist(d);
          final k = r * cols + c;
          if (dist < kDotR + 0.6 * g) {
            blocked[k] = 1;
          } else if (dist < zoneR && (zone[k] < 0 || dist < zoneDist[k])) {
            zone[k] = i;
            zoneDist[k] = dist;
          }
        }
      }
    }
  }

  final double g, reach, zoneR;

  /// 판 범위의 왼쪽 위 (칸 번호는 이 점에서부터 센다).
  final double ox, oy;
  final int cols, rows;
  late final Uint8List blocked;
  late final Int16List zone;
  late final Float32List zoneDist;

  P center(int c, int r) => P(ox + (c + 0.5) * g, oy + (r + 0.5) * g);
}

/// 둘 수 있는 수들을 찾는다.
///
/// [firstOnly]면 하나만 찾고 멈춘다. [deadline]이 있으면 그 시간이 지나면 지금까지 찾은 것만 돌려준다.
/// 점마다 한 점에서 갈 수 있는 모든 점까지 한 번의 탐색으로 길을 찾는다.
///
/// 자리가 넉넉한 수가 하나도 없을 때만([allowRelax]) 좁은 틈으로라도 갈 수 있는 길을 찾고, 그 길을 둘 수 있도록
/// 기존 점과 선을 밀어 보는 수까지 찾는다 (콩나물은 위상만 중요하니, 틈만 있으면 둘 수 있는 수다).
/// 밀어서 둔 수는 [StrokeResult.layout]에 밀린 배치가 담겨 있다.
///
/// 위상적으로는 둘 수 있는데 이 판에서 자리를 못 찾으면, 판 전체를 조금씩 늘려서(점과 선의 위치만 늘리고 이어진 구조는 그대로)
/// 자리를 만들어 본다. 그렇게 찾은 수도 [StrokeResult.layout]에 늘어난 배치가 담겨 있다. 그래서 위상적으로 둘 수 있는 수가
/// 남아 있는 한 이 함수는 (시간이 허락하는 한) 수를 찾아낸다.
List<SproutsMove> findMoves(SproutsBoard b, {bool firstOnly = false, Stopwatch? clock, Duration? deadline, bool allowRelax = true}) =>
    _findCore(b, firstOnly, clock, deadline, allowRelax, allowRelax);

/// 꺾은선의 꼭짓점은 그대로 두고, 점 사이가 [kStep]보다 벌어진 곳에만 일직선 위에 점을 더 찍는다 (모양이 정확히 같다).
List<P> _densify(List<P> pts) {
  final out = <P>[pts.first];
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final n = (a.dist(b) / kStep).ceil();
    for (var k = 1; k < n; k++) {
      out.add(P(a.x + (b.x - a.x) * k / n, a.y + (b.y - a.y) * k / n));
    }
    out.add(b);
  }
  return out;
}

/// 점 [s]와 [e](같으면 고리)를 잇는 수를 찾는다. 위상적으로 이을 수 있는 쌍이면 (시간이 허락하는 한) 점과 선을 밀거나 판을 늘려서라도
/// 찾아낸다. 이을 수 없는 쌍이거나 못 찾으면 null.
SproutsMove? connectPair(SproutsBoard b, int s, int e, {Stopwatch? clock, Duration? deadline}) {
  if (s < 0 || e < 0 || s >= b.dots.length || e >= b.dots.length) return null;
  final pair = s <= e ? (s, e) : (e, s);
  if (!analyzeRegions(b).allPairs(b).contains(pair)) return null;
  final moves = _findCore(b, true, clock, deadline, true, true, only: pair);
  if (moves.isEmpty) return null;
  final m = moves.first;
  return m;
}

/// 판을 [f]배로 늘린 판: 점과 선의 위치만 늘려서(곡선은 점 사이가 벌어진 곳에 점만 더 찍는다) 이어진 구조와 점 둘레 선의 순서, 영역은 그대로다.
/// 늘린 판이 가장 큰 판의 범위를 넘으면 null.
SproutsBoard? stretchedBoard(SproutsBoard b, double f) {
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
  if (minX == double.infinity) return null;
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  P grow(P p) => P(cx + (p.x - cx) * f, cy + (p.y - cy) * f);
  final dots = [for (final d in b.dots) Dot(grow(d.pos), d.lives)];
  final curves = [
    for (final c in b.curves) Curve(from: c.from, to: c.to, mid: c.mid, owner: c.owner, pts: _densify([for (final p in c.pts) grow(p)])),
  ];
  final nb = SproutsBoard(dots, curves);
  nb.bounds = nb.fittedBounds();
  // 가장 큰 판에도 다 못 담으면 쓸 수 없다
  bool inside(P p) => p.x >= nb.bounds.x0 + kMargin && p.y >= nb.bounds.y0 + kMargin && p.x <= nb.bounds.x1 - kMargin && p.y <= nb.bounds.y1 - kMargin;
  if (!dots.every((d) => inside(d.pos)) || !curves.every((c) => c.pts.every(inside))) return null;
  return nb;
}

/// [b]의 배치 그대로를 담은 배치 (밀려 있다면 밀린 배치).
SproutsLayout _layoutOf(SproutsBoard b, StrokeResult r) {
  final l = r.layout;
  if (l != null) return SproutsLayout(l.dots, l.curves, bounds: l.bounds ?? b.bounds);
  return SproutsLayout([for (final d in b.dots) d.pos], [for (final c in b.curves) c.pts], bounds: b.bounds);
}

/// (isolate용) 판 데이터를 받아, 위상적으로는 둘 수 있는데 자리가 없을 때 점과 선을 옮겨 늘린 판 데이터를 돌려준다. 필요 없으면 빈 목록.
List<double> sproutsRoomTask(List<double> data) {
  final room = makeRoom(SproutsBoard.fromData(data), clock: Stopwatch()..start(), deadline: const Duration(seconds: 6));
  return room == null ? const <double>[] : room.toData();
}

const List<double> _stretchFactors = [1.25, 1.6, 2.0, 2.5, 3.2];

/// 지금 판에서는 자리가 모자라 못 찾는 수를, 판을 늘려서 찾는다. 찾은 수의 배치는 늘어난 판의 것이다.
List<SproutsMove> _stretchFind(SproutsBoard b, bool firstOnly, Stopwatch? clock, Duration? deadline, (int, int)? only) {
  for (final f in _stretchFactors) {
    if (clock != null && deadline != null && clock.elapsed > deadline) break;
    final sb = stretchedBoard(b, f);
    if (sb == null) break; // 더 늘려도 안 담긴다
    final moves = _findCore(sb, firstOnly, clock, deadline, true, false, only: only);
    if (moves.isEmpty) continue;
    return [for (final m in moves) SproutsMove(m.s, m.e, StrokeResult.ok(m.path, m.result.midIndex, layout: _layoutOf(sb, m.result)))];
  }
  return const [];
}

/// 위상적으로는 둘 수 있는데 자리가 없어서 못 두는 판이면, 둘 수 있을 만큼 점과 선을 옮겨 늘린 판을 돌려준다. 이미 자리가
/// 있거나(null이 아니라 [b] 그대로는 돌려주지 않는다) 위상적으로 끝난 판이면 null.
SproutsBoard? makeRoom(SproutsBoard b, {Stopwatch? clock, Duration? deadline}) {
  if (b.totalLives <= 0 || !analyzeRegions(b).hasMove(b)) return null;
  if (_findCore(b, true, clock, deadline, false, false).isNotEmpty) return null;
  for (final relax in const [false, true]) {
    for (final f in _stretchFactors) {
      final sb = stretchedBoard(b, f);
      if (sb == null) break;
      if (_findCore(sb, true, clock, deadline, relax, false).isNotEmpty) return sb;
    }
  }
  return null;
}

List<SproutsMove> _findCore(SproutsBoard b, bool firstOnly, Stopwatch? clock, Duration? deadline, bool allowRelax, bool allowStretch, {(int, int)? only}) {
  if (b.totalLives <= 0) return const [];
  // 위상적으로 둘 수 있는 수가 없으면 곧바로 끝 (정확하고 빠르다)
  if (!analyzeRegions(b).hasMove(b)) return const [];
  bool timeUp() => clock != null && deadline != null && clock.elapsed > deadline;
  final quick = _find(b, _Grid(b, 5, kClear + 3), firstOnly, clock, deadline, false, only);
  if (quick.isNotEmpty) return quick;
  // 성긴 격자로는 못 찾았다: 촘촘하게 한 번 더
  if (timeUp()) return quick;
  final fine = _find(b, _Grid(b, 2.5, kClear + 1), firstOnly, clock, deadline, false, only);
  if (fine.isNotEmpty || timeUp()) return fine;
  // 그래도 없다: 가장 촘촘한 격자로 규칙이 허락하는 가장 좁은 틈까지 본다
  final finest = _find(b, _Grid(b, 1.5, kClear + 0.3), firstOnly, clock, deadline, false, only);
  if (finest.isNotEmpty || !allowRelax || timeUp()) return finest;
  // 그래도 없다: 좁은 틈으로 가는 길을 찾아, 점과 선을 밀어서 둘 수 있는지 본다
  final tight = _find(b, _Grid(b, 3, 2.5, kDotR + 3), firstOnly, clock, deadline, true, only);
  if (tight.isNotEmpty || timeUp()) return tight;
  // 그래도 못 찾았지만 위상적으로는 둘 수 있는 점 쌍이 있다면, 바로 그 쌍만 골라 이어 본다 (위상이 정확한 안내)
  final targeted = _targeted(b, firstOnly, clock, deadline, only);
  if (targeted.isNotEmpty || !allowStretch || timeUp()) return targeted;
  // 마지막: 판 전체를 늘려서 자리를 만든다
  return _stretchFind(b, firstOnly, clock, deadline, only);
}

/// 위상적으로 둘 수 있는 점 쌍([analyzeRegions])을 하나씩 정해서, 여러 모양의 곡선으로 이어 보며 점과 선을 밀어 본다.
List<SproutsMove> _targeted(SproutsBoard b, bool firstOnly, Stopwatch? clock, Duration? deadline, (int, int)? only) {
  final out = <SproutsMove>[];
  final pairs = [for (final p in analyzeRegions(b).allPairs(b)) if (only == null || p == only) p];
  final watch = Stopwatch()..start();
  for (final (s, e) in pairs) {
    if (watch.elapsedMilliseconds > 2500) break;
    if (clock != null && deadline != null && clock.elapsed > deadline) break;
    if (s == e) continue; // 고리는 위에서 이미 여러 모양으로 해 봤다
    final move = _direct(b, s, e, true, const [0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 40.0, -40.0, 50.0, -50.0, 65.0, -65.0, 80.0, -80.0, 100.0, -100.0]);
    if (move != null) {
      out.add(move);
      if (firstOnly) return out;
    }
  }
  return out;
}

List<SproutsMove> _find(SproutsBoard b, _Grid grid, bool firstOnly, Stopwatch? clock, Duration? deadline, bool relax, (int, int)? only) {
  final out = <SproutsMove>[];
  final relaxClock = Stopwatch()..start();
  bool timeUp() => clock != null && deadline != null && clock.elapsed > deadline;

  for (var s = 0; s < b.dots.length; s++) {
    if (b.dots[s].lives <= 0) continue;
    if (only != null && s != only.$1) continue;
    if (timeUp()) break;

    // ── 고리 ──
    if (b.dots[s].lives >= 2 && (only == null || only.$1 == only.$2)) {
      for (final radius in relax ? const [28.0] : const [20.0, 28.0, 38.0]) {
        for (var k = 0; k < 24; k++) {
          final theta = (k * 15 + (radius.toInt() % 3) * 5) * pi / 180;
          final cen = P(b.dots[s].pos.x + radius * cos(theta), b.dots[s].pos.y + radius * sin(theta));
          final pts = <P>[
            for (var i = 1; i < 36; i++)
              P(cen.x + radius * cos(theta + pi + i * 2 * pi / 36), cen.y + radius * sin(theta + pi + i * 2 * pi / 36)),
          ];
          final r = b.validate(s, s, pts, relax: relax);
          if (r.ok) {
            out.add(SproutsMove(s, s, r));
            if (firstOnly) return out;
            break; // 반지름마다 한 방향이면 충분하다
          }
        }
      }
      // 동그라미가 들어갈 자리가 없는 좁은 틈(두 선 사이, 선과 점 사이)을 위해 길쭉한 타원 고리도 대 본다
      if (!out.any((m) => m.s == s && m.e == s)) {
        final loop = _ovalLoop(b, s, relax);
        if (loop != null) {
          out.add(loop);
          if (firstOnly) return out;
        }
      }
    }

    // ── 다른 점으로 ──
    final targets = <int>{
      for (var e = s + 1; e < b.dots.length; e++)
        if (b.dots[e].lives > 0 && (only == null || e == only.$2)) e,
    };
    if (targets.isEmpty) continue;
    final reached = _bfs(grid, b, s, targets);
    // 바짝 붙은 점들은 서로의 둘레가 겹쳐서 길찾기가 제대로 길을 못 만든다: 곧바로 이어 본다
    final direct = <int>{};
    for (final e in targets) {
      if (b.dots[s].pos.dist(b.dots[e].pos) > 90) continue;
      final move = _direct(b, s, e, relax);
      if (move != null) {
        direct.add(e);
        out.add(move);
        if (firstOnly) return out;
      }
    }
    // 밀어서라도 둘 수 있는 수를 찾는 마지막 단계: 멀리 있는 점도 곧은 선으로 이어 본다 (길찾기가 놓친 수를 위해)
    if (relax) {
      for (final e in targets) {
        if (direct.contains(e) || b.dots[s].pos.dist(b.dots[e].pos) <= 90) continue;
        if (relaxClock.elapsedMilliseconds > 2500) break;
        final move = _direct(b, s, e, true, const [0.0, 25.0, -25.0, 55.0, -55.0]);
        if (move != null) {
          direct.add(e);
          out.add(move);
          if (firstOnly) return out;
        }
      }
    }
    var entries = [for (final en in reached.entries) if (!direct.contains(en.key)) en];
    if (relax) {
      // 밀어 보는 것은 비싸니, 가장 짧은 길 몇 개만 시도한다
      entries.sort((a, c) => a.value.length.compareTo(c.value.length));
      entries = entries.take(3).toList();
    }
    for (final entry in entries) {
      if (timeUp()) break;
      final move = _toMove(grid, b, s, entry.key, entry.value, relax);
      if (move != null) {
        out.add(move);
        if (firstOnly) return out;
      }
    }
  }
  return out;
}

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
