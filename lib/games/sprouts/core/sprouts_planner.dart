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

part 'sprouts_planner_loops.dart';
part 'sprouts_planner_guided.dart';

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
