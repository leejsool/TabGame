import 'dart:math';

import 'snake_body.dart';
import 'snake_world.dart';

/// CPU 뱀의 솜씨.
///  - 멍청한: 앞을 짧게만 보고 가끔은 아예 안 보고 먹이만 쫓는다 (잘 부딪힌다).
///  - 보통: 앞을 넉넉히 보고 피하며 먹이를 모은다.
///  - 똑똑한: 멀리 보고, 사람 뱀 앞을 가로막거나 크면 빙 둘러싸서 가두려 한다.
///    다만 몇 초 둘러싼 뒤에는 꼭 실수(밖으로 틀어 틈을 연다)를 하고, 가끔 한눈을 팔기도 한다.
enum CpuSkill { dumb, normal, smart }

/// CPU 뱀의 성격 (솜씨와 따로 고루 섞는다).
///  - 공격형: 사냥을 자주 한다 (보통 솜씨도 가로막기를 하고, 자기보다 작은 CPU도 노린다). 부스터를 잘 쓰고 위험을 덜 따진다.
///  - 보통형: 똑똑한 솜씨일 때만 사람 뱀을 사냥한다.
///  - 신중형: 사냥을 안 한다. 더 멀리 보고, 다른 뱀 머리 쪽을 꺼리고, 막히면 부스터로 달아난다.
enum CpuMood { aggressive, balanced, cautious }

enum CpuPlan { roam, cut, coil, blunder }

/// 돌려 볼 방향들 (지금 머리 방향에서 얼마나 틀지).
const List<double> _offsets = [0, 0.25, -0.25, 0.5, -0.5, 0.8, -0.8, 1.2, -1.2, 1.7, -1.7, 2.3, -2.3, pi];

/// CPU 한 마리의 머리. [update]가 [WorldSnake.targetAngle]과 [WorldSnake.wantBoost]를 정한다.
class CpuBrain {
  CpuBrain(this.skill, this.rng, {this.hunts = true, this.mood = CpuMood.balanced}) {
    _nextLapse = _lapseGap();
    _cooldown = 3 + rng.nextDouble() * 6;
    _wander = rng.nextDouble() * 2 * pi;
  }

  /// 나간 사람 자리를 대신 모는 머리 (보통 솜씨, 사냥은 안 한다).
  CpuBrain.cover(Random rng) : this(CpuSkill.normal, rng, hunts: false);

  final CpuSkill skill;
  final CpuMood mood;
  final Random rng;
  final bool hunts;

  CpuPlan plan = CpuPlan.roam;

  /// 쫓는 사람 뱀 번호 (가로막기·둘러싸기 중일 때).
  int? targetId;

  double _think = 0, _lapse = 0, _nextLapse = 0, _cooldown = 0;
  double _planTime = 0, _planLimit = 0, _wander = 0, _wanderTime = 0;
  int _spin = 1;

  /// (시험용) 사냥 쉬는 시간을 끝내서 바로 표적을 찾게 한다.
  void debugReadyToHunt() => _cooldown = 0;

  bool get hunting => plan == CpuPlan.cut || plan == CpuPlan.coil;

  /// 지금 한눈을 파는 중인가 (그동안은 방향을 그대로 둔다).
  bool get lapsing => _lapse > 0;

  /// 지금 CPU 단계 ([SnakeWorld.cpuLevel]): 높을수록 빨리 판단하고 멀리 보고 실수가 드물다.
  /// (판단 빠르기·보는 거리는 [_sharpCap]단계까지만 오르고, 그 위로는 CPU 물갈이와 떼 사냥으로 어려워진다)
  int _level = 0;
  static const int _sharpCap = 7;
  int get _sharp => min(_level, _sharpCap);

  /// 이 단계부터 (사람 뱀 3000점) CPU가 떼로 사냥한다: 보통·똑똑한 CPU는 성격과 상관없이 사람 뱀을 노리고,
  /// 한 사람 뱀을 넷까지 함께 몰아붙이며, 더 멀리서도 달려온다. 둘러싼 뒤 실수(틈 열기)는 그대로 한다.
  static const int packLevel = 6;
  bool get _pack => _level >= packLevel;

  double _lapseGap() => switch (skill) {
        CpuSkill.dumb => 6 + rng.nextDouble() * 10,
        CpuSkill.normal => 12 + rng.nextDouble() * 18,
        CpuSkill.smart => 15 + rng.nextDouble() * 20,
      } *
      (1 + 0.15 * _sharp);

  double get _interval => switch (skill) {
        CpuSkill.dumb => 0.3 + rng.nextDouble() * 0.15,
        CpuSkill.normal => 0.17 + rng.nextDouble() * 0.06,
        CpuSkill.smart => 0.09 + rng.nextDouble() * 0.04,
      } *
      (1 - 0.07 * _sharp);

  void update(SnakeWorld w, WorldSnake s, double dt) {
    _level = w.cpuLevel;
    _planTime += dt;
    _cooldown -= dt;
    if (_lapse > 0) {
      _lapse -= dt;
      return;
    }
    _nextLapse -= dt;
    if (_nextLapse <= 0) {
      _nextLapse = _lapseGap();
      _lapse = 0.4 + rng.nextDouble() * 0.7;
      s.wantBoost = false;
      return;
    }
    _think -= dt;
    if (_think > 0) return;
    _think = _interval;
    _decide(w, s);
  }

  /// 사냥(가로막기·둘러싸기)을 하는 머리인가.
  /// (단계 2부터는 보통형 보통 솜씨도 가로막기를 하고, 떼 사냥 단계부터는 신중형도 사람 뱀을 노린다)
  bool get _hunter =>
      hunts &&
      skill != CpuSkill.dumb &&
      (_pack ||
          (mood != CpuMood.cautious && (skill == CpuSkill.smart || mood == CpuMood.aggressive || _level >= 2)));

  void _decide(SnakeWorld w, WorldSnake s) {
    final r = s.radius;
    final look = switch (skill) {
          CpuSkill.dumb => 55 + r * 3,
          CpuSkill.normal => 120 + r * 3,
          CpuSkill.smart => 170 + r * 4,
        } *
        (mood == CpuMood.cautious ? 1.3 : 1) *
        (1 + 0.08 * _sharp);
    final dangerW = switch (mood) { CpuMood.aggressive => 4.5, CpuMood.balanced => 6.0, CpuMood.cautious => 8.0 };
    if (_hunter) _updatePlan(w, s);
    var goal = s.angle;
    var goalW = 1.0;
    var boost = false;
    final t = targetId == null ? null : w.byId[targetId];
    switch (plan) {
      case CpuPlan.cut when t != null:
        (goal, boost) = _cutGoal(s, t);
        goalW = 2.2;
      case CpuPlan.coil when t != null:
        (goal, boost) = _coilGoal(s, t);
        goalW = 2.5;
      case CpuPlan.blunder when t != null:
        // 실수: 둘러싸던 원 밖으로 틀어서 틈을 연다
        goal = atan2(s.y - t.y, s.x - t.x) + _spin * 0.5;
        goalW = 2;
      default:
        (goal, boost) = _foodGoal(w, s);
    }
    // 벽이 가까우면 가운데 쪽으로
    final edge = min(min(s.x, s.y), min(w.field - s.x, w.field - s.y));
    if (edge < 260 && plan == CpuPlan.roam) {
      final center = atan2(w.field / 2 - s.y, w.field / 2 - s.x);
      goal = edge < 150 ? center : goal + wrapAngle(center - goal) * 0.5;
    }
    // 멍청한 CPU는 가끔 앞을 안 본다
    final blind = skill == CpuSkill.dumb && rng.nextDouble() < max(0.05, 0.3 - 0.05 * _sharp);
    final wary = mood == CpuMood.cautious ? 1.5 : 1.0;
    final heads = switch (skill) {
      CpuSkill.dumb => const <HeadPath>[],
      CpuSkill.normal => HeadPath.near(w, s, look + 150, 0.35 * wary),
      CpuSkill.smart => HeadPath.near(w, s, look + 200, 0.6 * wary),
    };
    var best = s.angle, bestScore = -1e9, bestDanger = 1.0;
    for (final off in _offsets) {
      final a = s.angle + off;
      final clear = blind ? look : clearance(w, s, a, look, heads: heads);
      final danger = 1 - clear / look;
      var score = cos(wrapAngle(a - goal)) * goalW - danger * danger * dangerW - off.abs() * 0.08;
      if (clear < r * (mood == CpuMood.cautious ? 4 : 3) + 20) score -= 8;
      if (mood == CpuMood.cautious) {
        // 신중형: 가까운 다른 뱀 머리 쪽으로는 되도록 가지 않는다
        for (final h in heads) {
          final dx = h.x0 - s.x, dy = h.y0 - s.y;
          if (dx * dx + dy * dy > 260 * 260) continue;
          final toward = cos(wrapAngle(a - atan2(dy, dx)));
          if (toward > 0) score -= toward * 1.5;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = a;
        bestDanger = danger;
      }
    }
    s.targetAngle = wrapAngle(best);
    // 신중형은 앞이 막혀 오면 부스터로 빠져나간다
    final flee = mood == CpuMood.cautious && skill != CpuSkill.dumb && !blind && bestDanger > 0.55 && s.mass > 20;
    s.wantBoost = flee || (boost && bestDanger < (mood == CpuMood.aggressive ? 0.45 : 0.3));
  }

  /// 먹이 쪽 (없으면 어슬렁).
  (double, bool) _foodGoal(SnakeWorld w, WorldSnake s) {
    final range = switch (skill) { CpuSkill.dumb => 200.0, CpuSkill.normal => 320.0, CpuSkill.smart => 380.0 };
    Food? best;
    var bestScore = 0.0;
    w.foodGrid.query(s.x, s.y, range, (f) {
      final dx = f.x - s.x, dy = f.y - s.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > range) return;
      final ahead = cos(wrapAngle(atan2(dy, dx) - s.angle));
      final sc = f.value / (d + 30) * (1.3 + ahead * 0.7);
      if (sc > bestScore) {
        bestScore = sc;
        best = f;
      }
    });
    final f = best;
    if (f == null) {
      _wanderTime -= 1;
      if (_wanderTime <= 0) {
        _wanderTime = 8 + rng.nextDouble() * 10;
        _wander = s.angle + (rng.nextDouble() - 0.5) * 2;
      }
      return (_wander, false);
    }
    final dx = f.x - s.x, dy = f.y - s.y;
    final near = dx * dx + dy * dy < 220 * 220;
    final greedy = mood == CpuMood.aggressive
        ? f.value >= 2 && near && s.mass > 22 && rng.nextDouble() < 0.6
        : skill != CpuSkill.dumb && mood == CpuMood.balanced && f.value >= 3 && near && s.mass > 30 && rng.nextDouble() < 0.35;
    return (atan2(dy, dx), greedy);
  }

  /// 가로막기: 상대 머리가 갈 자리보다 조금 앞을 노린다.
  (double, bool) _cutGoal(WorldSnake s, WorldSnake t) {
    final dx = t.x - s.x, dy = t.y - s.y;
    final d = sqrt(dx * dx + dy * dy);
    final lead = (d / SnakeRules.speed).clamp(0.35, 1.1);
    final ts = t.boost ? SnakeRules.boostSpeed : SnakeRules.speed;
    final ahead = ts * lead + t.radius * 4;
    final ax = t.x + cos(t.angle) * ahead, ay = t.y + sin(t.angle) * ahead;
    final boost = d < 380 && s.mass > 20 && _planTime < 2.5 && rng.nextDouble() < 0.8;
    return (atan2(ay - s.y, ax - s.x), boost);
  }

  /// 둘러싸기: 상대 머리 둘레를 돌면서 원을 점점 좁힌다.
  (double, bool) _coilGoal(WorldSnake s, WorldSnake t) {
    final vx = s.x - t.x, vy = s.y - t.y;
    final d = sqrt(vx * vx + vy * vy);
    final theta = atan2(vy, vx);
    final r0 = t.radius * 3 + s.radius * 2 + 40;
    final rStart = max(r0, s.length / (2 * pi) * 0.9);
    final ring = rStart + (r0 - rStart) * (_planTime / 2.5).clamp(0.0, 1.0);
    final err = ((d - ring) / ring).clamp(-1.0, 1.0);
    final goal = theta + _spin * pi / 2 + _spin * err * 0.9;
    return (goal, d > ring * 1.8 && s.mass > 25);
  }

  void _updatePlan(SnakeWorld w, WorldSnake s) {
    final t = targetId == null ? null : w.byId[targetId];
    if (hunting) {
      if (t == null || !_huntable(s, t) || _dist(s, t) > (_pack ? 1200 : 900)) {
        _endPlan(3, 6);
      } else if (_planTime > _planLimit) {
        if (plan == CpuPlan.coil) {
          plan = CpuPlan.blunder;
          _planTime = 0;
          _planLimit = 1 + rng.nextDouble();
        } else {
          _endPlan(5, 9);
        }
      }
      return;
    }
    if (plan == CpuPlan.blunder) {
      if (_planTime > _planLimit || t == null) _endPlan(6, 12);
      return;
    }
    if (_cooldown > 0 || s.mass < 18) return;
    WorldSnake? pick;
    var pickD = _pack ? 950.0 : 650.0;
    for (final o in w.snakes) {
      if (!_huntable(s, o) || o.id == s.id) continue;
      // 사람 뱀을 먼저 노린다 (CPU는 조금 더 가까워야 고른다)
      final d = _dist(s, o) * (o.human ? 1 : 1.5);
      if (d >= pickD) continue;
      var hunters = 0;
      for (final h in w.snakes) {
        final b = h.brain;
        if (b != null && b.hunting && b.targetId == o.id && !h.human) hunters++;
      }
      // 한 뱀을 셋 이상(단계 3부터는 넷, 떼 사냥 때 사람 뱀은 다섯 이상)이 몰아붙이지는 않는다
      if (hunters >= (_pack && o.human ? 4 : (_level >= 3 ? 3 : 2))) continue;
      pick = o;
      pickD = d;
    }
    if (pick == null) {
      _cooldown = 1.5;
      return;
    }
    final need = 2 * pi * (pick.radius * 3 + s.radius * 2 + 40) * 1.25;
    plan = skill == CpuSkill.smart && s.length >= need && pickD < 420 ? CpuPlan.coil : CpuPlan.cut;
    targetId = pick.id;
    _planTime = 0;
    // 단계가 높으면 조금 더 오래 둘러싸지만, 끝에는 꼭 실수(틈 열기)를 한다
    _planLimit = plan == CpuPlan.coil ? 3.5 + 0.3 * _level + rng.nextDouble() * 3 : 3 + rng.nextDouble() * 3;
    // 지금 도는 쪽으로 감는다
    final vx = s.x - pick.x, vy = s.y - pick.y;
    final cross = vx * sin(s.angle) - vy * cos(s.angle);
    _spin = cross >= 0 ? 1 : -1;
  }

  /// 노릴 수 있는 뱀: 직접 조종 중인 사람 뱀. 공격형은 자기보다 작은 CPU도.
  bool _huntable(WorldSnake me, WorldSnake o) {
    if (o.human) return !o.covered && !o.autopilot;
    if (_pack) return false; // 떼 사냥 때는 사람 뱀만 노린다
    return mood == CpuMood.aggressive && o.mass < me.mass * 0.8;
  }

  void _endPlan(double lo, double hi) {
    plan = CpuPlan.roam;
    targetId = null;
    final k = mood == CpuMood.aggressive ? 0.6 : 1.0; // 공격형은 금방 다시 사냥한다
    _cooldown = (lo + rng.nextDouble() * (hi - lo)) * k * (1 - 0.1 * _sharp) * (_pack ? 0.6 : 1);
  }

  static double _dist(SnakeBody a, SnakeBody b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// [a] 방향으로 [look]만큼 가는 동안 막힘 없이 갈 수 있는 거리 (벽이나 다른 뱀 몸까지).
  /// [heads]: 가까운 다른 뱀 머리가 곧 지나갈 길 (거기도 막힌 것으로 본다).
  static double clearance(SnakeWorld w, WorldSnake s, double a, double look, {List<HeadPath> heads = const []}) {
    final r = s.radius;
    final step = max(9.0, r * 0.9);
    final ca = cos(a), sa = sin(a);
    final g = w.grid;
    for (var d = step; d <= look; d += step) {
      final px = s.x + ca * d, py = s.y + sa * d;
      final m = r * 1.6;
      if (px < m || py < m || px > w.field - m || py > w.field - m) return d;
      final hit = g.query(px, py, r + 26, (i) {
        if (g.owner[i] == s.id) return false;
        final dx = g.px[i] - px, dy = g.py[i] - py, lim = r + g.pr[i] + 4;
        return dx * dx + dy * dy < lim * lim;
      });
      if (hit) return d;
      for (final h in heads) {
        if (h.blocks(px, py, r)) return d;
      }
    }
    return look;
  }
}

/// 다른 뱀 머리가 앞으로 잠깐 동안 곧게 간다고 볼 때 지나갈 길 (선분).
class HeadPath {
  HeadPath(this.x0, this.y0, this.x1, this.y1, this.r);

  final double x0, y0, x1, y1, r;

  /// [s] 둘레 [range] 안의 다른 뱀 머리들이 [seconds] 동안 갈 길.
  static List<HeadPath> near(SnakeWorld w, WorldSnake s, double range, double seconds) {
    final out = <HeadPath>[];
    for (final o in w.snakes) {
      if (o.id == s.id) continue;
      final dx = o.x - s.x, dy = o.y - s.y;
      if (dx * dx + dy * dy > range * range) continue;
      final v = (o.boost ? SnakeRules.boostSpeed : SnakeRules.speed) * seconds;
      out.add(HeadPath(o.x, o.y, o.x + cos(o.angle) * v, o.y + sin(o.angle) * v, o.radius));
    }
    return out;
  }

  bool blocks(double px, double py, double myR) {
    final vx = x1 - x0, vy = y1 - y0;
    final len2 = vx * vx + vy * vy;
    var t = len2 == 0 ? 0.0 : ((px - x0) * vx + (py - y0) * vy) / len2;
    t = t.clamp(0.0, 1.0);
    final dx = x0 + vx * t - px, dy = y0 + vy * t - py;
    final lim = myR + r + 14;
    return dx * dx + dy * dy < lim * lim;
  }
}
