import 'dart:collection';
import 'dart:math';

import 'snake_ai.dart';
import 'snake_body.dart';
import 'snake_grid.dart';

/// 뱀 색 가짓수 (그리는 쪽의 `snakeColors`와 같은 수).
const int snakeColorCount = 14;

/// 방장 기기에서 움직이는 진짜 뱀.
class WorldSnake extends SnakeBody {
  WorldSnake({required super.id, required super.name, required super.color, super.seat, this.brain});

  /// CPU의 머리 (사람 자리라도 나갔거나 손이 멈춘 동안 대신 움직인다).
  CpuBrain? brain;

  /// 가고 싶은 방향과 부스터 (사람은 조종기로, CPU는 머리가 정한다).
  double targetAngle = 0;
  bool wantBoost = false;

  /// 사람이 마지막으로 조종한 시각 (손님의 연결이 잠깐 멈추면 CPU가 잠시 대신 몬다).
  double lastInput = 0;
  bool autopilot = false;
  double bornAt = 0;
  double _dropTimer = 0;

  bool get cpuDriven => !human || covered || autopilot;
}

/// 뱀 한 마리가 죽은 일.
class SnakeDeath {
  const SnakeDeath({required this.id, required this.seat, required this.killer, required this.killerName, required this.score});

  final int id, seat;

  /// 부딪힌 상대 뱀 번호 (벽이면 -1).
  final int killer;
  final String killerName;
  final int score;
}

/// 방장 기기가 돌리는 필드 전체: 뱀들, 먹이, 벽, 부딪힘, CPU가 다시 태어나는 일.
///
/// 사람 자리(seat)는 0 = 방장, 1… = 손님. 사람은 죽으면 "다시 하기"를 눌러야 다시 태어난다.
/// CPU는 죽고 2~4초 뒤 다시 태어나는데, 필드의 인원(살아 있는 뱀 + 다시 하기를 기다리는 사람)이
/// [population] 이상이면 태어나지 않는다. 그래서 사람이 들어오면 CPU가 하나씩 줄어 인원이 지켜진다.
class SnakeWorld {
  SnakeWorld({Random? rng, this.field = SnakeRules.field, this.population = SnakeRules.population, this.foodTarget = SnakeRules.foodTarget})
      : rng = rng ?? Random(),
        grid = BodyGrid(field),
        foodGrid = FoodGrid<Food>(field);

  final Random rng;
  final double field;
  final int population, foodTarget;
  final BodyGrid grid;
  final FoodGrid<Food> foodGrid;

  /// 살아 있는 뱀들.
  final List<WorldSnake> snakes = [];
  final Map<int, WorldSnake> byId = {};
  final Map<int, Food> food = {};
  int _natural = 0;

  /// 놓인 차례대로의 먹이 (오래된 먹이를 치우려고).
  final Queue<Food> _naturalByAge = Queue<Food>(), _dropByAge = Queue<Food>();

  /// 아무도 안 먹은 먹이를 치우는 나이 (저절로 깔린 먹이 / 죽은 뱀·부스터가 남긴 먹이).
  /// CPU가 벽을 피하다 보니 벽 근처 먹이만 남아 쌓이고 가운데가 비는 것을 막는다: 치운 만큼 먹이가 드문 곳에 새로 깔린다.
  static const double naturalLife = 45, dropLife = 60;
  double time = 0;
  int _nextId = 1, _nextFood = 1;

  /// 사람 자리의 이름 (자리가 있는 동안). 나가서 CPU가 대신하는 자리는 [awaySeats]에도 든다.
  final Map<int, String> seatNames = {};
  final Set<int> awaySeats = {};
  final List<double> _cpuDue = [];
  double _deficitCheck = 0;

  /// CPU 단계 (0~[maxCpuLevel]). 사람 뱀이 1등인 채로 [levelStep]점을 넘을 때마다 하나씩 올라가고,
  /// CPU가 1등이면 15초마다 하나씩 내려간다. 단계가 높을수록 CPU가 더 빨리 판단하고 멀리 보고 실수가 줄어든다.
  int cpuLevel = 0;
  static const int maxCpuLevel = 5;
  static const int levelStep = 500;
  double _levelTimer = 0, _levelDecay = 0;

  // ── 같은 Wi‑Fi로 보낼 일들 (보낼 때 비운다) ──
  final List<WorldSnake> born = [];
  final List<SnakeDeath> deaths = [];
  final List<Food> foodAdded = [];

  /// 먹힌 먹이 (먹이 번호, 먹은 뱀 번호).
  final List<(int, int)> foodEaten = [];

  /// 뱀이 죽을 때마다 (이 기기의 화면이 "내가 죽었다 / 잡았다"를 알려고 듣는다).
  void Function(SnakeDeath death)? onDeath;

  /// 처음 판을 차린다: 먹이를 깔고 사람 자리를 뺀 만큼 CPU를 넣는다.
  void setUp() {
    while (_natural < foodTarget) {
      _addNaturalFood(); // (처음 깐 먹이가 한꺼번에 치워지지 않게 나이를 흩어 둔다)
    }
    final aged = _naturalByAge.toList()..sort((a, b) => a.bornAt.compareTo(b.bornAt));
    _naturalByAge
      ..clear()
      ..addAll(aged);
    _buildGrid();
    final cpus = population - headcount;
    for (var i = 0; i < cpus; i++) {
      _spawnCpu();
    }
  }

  // ── 사람 자리 ──

  WorldSnake? snakeOfSeat(int seat) {
    for (final s in snakes) {
      if (s.seat == seat) return s;
    }
    return null;
  }

  /// 사람 자리를 만들고 그 뱀을 낳는다.
  WorldSnake addSeat(int seat, String name) {
    seatNames[seat] = name;
    awaySeats.remove(seat);
    return respawnSeat(seat)!;
  }

  /// 죽은 사람 자리의 뱀을 새로 낳는다 ("다시 하기"). 이미 살아 있으면 그 뱀.
  WorldSnake? respawnSeat(int seat) {
    final name = seatNames[seat];
    if (name == null) return null;
    final alive = snakeOfSeat(seat);
    if (alive != null) return alive;
    final s = _spawn(name: name, color: (seat * 5 + 3) % snakeColorCount, seat: seat);
    s.covered = awaySeats.contains(seat);
    if (s.covered) s.brain = CpuBrain.cover(rng);
    return s;
  }

  /// 사람이 아주 나갔다: 그 뱀은 먹이로 흩어지고 자리는 없어진다.
  void removeSeat(int seat) {
    final s = snakeOfSeat(seat);
    if (s != null) {
      _kill(s, null);
      _removeDead();
    }
    seatNames.remove(seat);
    awaySeats.remove(seat);
  }

  /// 나간 사람의 자리를 CPU가 대신 몬다 (돌아오면 [uncoverSeat]).
  void coverSeat(int seat) {
    if (!seatNames.containsKey(seat)) return;
    awaySeats.add(seat);
    final s = snakeOfSeat(seat);
    if (s == null) return;
    s.covered = true;
    s.brain ??= CpuBrain.cover(rng);
  }

  void uncoverSeat(int seat) {
    awaySeats.remove(seat);
    final s = snakeOfSeat(seat);
    if (s == null) return;
    s.covered = false;
    s.autopilot = false;
    s.lastInput = time;
    s.targetAngle = s.angle;
    s.wantBoost = false;
  }

  /// 사람의 조종 (가고 싶은 방향, 부스터).
  void steer(int seat, double angle, bool boost) {
    final s = snakeOfSeat(seat);
    if (s == null || s.covered) return;
    s.targetAngle = angle;
    s.wantBoost = boost;
    s.lastInput = time;
    s.autopilot = false;
  }

  /// 필드의 인원: 살아 있는 뱀 + 죽어서 "다시 하기"를 기다리는 사람 (나간 사람 자리는 빼고).
  int get headcount {
    var n = snakes.length;
    for (final seat in seatNames.keys) {
      if (!awaySeats.contains(seat) && snakeOfSeat(seat) == null) n++;
    }
    return n;
  }

  // ── 한 걸음 ──

  void step(double dt) {
    time += dt;
    for (final s in snakes) {
      _control(s, dt);
    }
    for (final s in snakes) {
      _move(s, dt);
    }
    _buildGrid();
    _collide();
    _removeDead();
    _eat();
    _expireFood();
    for (var k = 0; k < 30 && _natural < foodTarget; k++) {
      _addNaturalFood();
    }
    _respawnCpus(dt);
    _updateCpuLevel(dt);
  }

  void _updateCpuLevel(double dt) {
    _levelTimer += dt;
    if (_levelTimer < 0.5) return;
    _levelTimer = 0;
    WorldSnake? top;
    for (final s in snakes) {
      if (top == null || s.mass > top.mass) top = s;
    }
    if (top != null && top.human && !top.covered) {
      _levelDecay = 0;
      final want = min(maxCpuLevel, top.score ~/ levelStep);
      if (want > cpuLevel) cpuLevel = want;
    } else if (cpuLevel > 0) {
      _levelDecay += 0.5;
      if (_levelDecay >= 15) {
        _levelDecay = 0;
        cpuLevel--;
      }
    }
  }

  void _control(WorldSnake s, double dt) {
    if (s.human && !s.covered && s.seat != 0) s.autopilot = time - s.lastInput > 1.5;
    if (s.cpuDriven) {
      final brain = s.brain ??= CpuBrain.cover(rng);
      brain.update(this, s, dt);
    }
    final diff = wrapAngle(s.targetAngle - s.angle);
    final maxTurn = SnakeRules.turnRateOf(s.radius) * dt;
    s.angle = wrapAngle(s.angle + diff.clamp(-maxTurn, maxTurn));
    s.boost = s.wantBoost && s.mass > SnakeRules.minBoostMass;
  }

  void _move(WorldSnake s, double dt) {
    if (s.boost) {
      s.mass = max(SnakeRules.minBoostMass - 0.5, s.mass - SnakeRules.boostCost * dt);
      s._dropTimer += dt;
      if (s._dropTimer >= 0.25 && !s.trail.isEmpty) {
        s._dropTimer = 0;
        addFood(s.trail.xAt(0), s.trail.yAt(0), SnakeRules.boostCost * 0.25 * 0.7, s.color, natural: false);
      }
    }
    final v = s.boost ? SnakeRules.boostSpeed : SnakeRules.speed;
    s.x += cos(s.angle) * v * dt;
    s.y += sin(s.angle) * v * dt;
    s.layTrail();
  }

  void _buildGrid() {
    grid.begin();
    for (final s in snakes) {
      final r = s.radius;
      grid.add(s.x, s.y, r, s.id);
      final t = s.trail;
      for (var i = 0; i < t.length; i++) {
        grid.add(t.xAt(i), t.yAt(i), r, s.id);
      }
    }
    grid.build();
  }

  final Set<WorldSnake> _dead = {};

  void _collide() {
    for (final s in snakes) {
      final r = s.radius;
      if (s.x < r || s.y < r || s.x > field - r || s.y > field - r) {
        _kill(s, null);
        continue;
      }
      int? hit;
      grid.query(s.x, s.y, r + 30, (i) {
        if (grid.owner[i] == s.id) return false;
        final dx = grid.px[i] - s.x, dy = grid.py[i] - s.y;
        final lim = (r + grid.pr[i]) * 0.78;
        if (dx * dx + dy * dy < lim * lim) {
          hit = grid.owner[i];
          return true;
        }
        return false;
      });
      if (hit != null) _kill(s, byId[hit]);
    }
  }

  void _kill(WorldSnake s, WorldSnake? killer) {
    if (!_dead.add(s)) return;
    if (killer != null) killer.kills++;
    final death = SnakeDeath(id: s.id, seat: s.seat, killer: killer?.id ?? -1, killerName: killer?.name ?? '', score: s.score);
    deaths.add(death);
    _scatter(s);
    if (!s.human) _cpuDue.add(time + 2 + rng.nextDouble() * 2);
    onDeath?.call(death);
  }

  void _removeDead() {
    if (_dead.isEmpty) return;
    snakes.removeWhere(_dead.contains);
    for (final s in _dead) {
      byId.remove(s.id);
    }
    _dead.clear();
  }

  /// 죽은 뱀은 몸을 따라 먹이로 흩어진다 (크기의 60%쯤).
  void _scatter(WorldSnake s) {
    final r = s.radius, t = s.trail;
    final gap = max(r * 1.4, 12.0);
    final spots = <(double, double)>[(s.x, s.y)];
    var acc = 0.0;
    for (var i = t.length - 1; i > 0; i--) {
      final dx = t.xAt(i) - t.xAt(i - 1), dy = t.yAt(i) - t.yAt(i - 1);
      acc += sqrt(dx * dx + dy * dy);
      if (acc >= gap) {
        acc = 0;
        spots.add((t.xAt(i - 1), t.yAt(i - 1)));
      }
    }
    final each = max(1.0, s.mass * 0.6 / spots.length);
    for (final (x, y) in spots) {
      addFood(x + (rng.nextDouble() - 0.5) * r, y + (rng.nextDouble() - 0.5) * r, each, s.color, natural: false);
    }
  }

  void _eat() {
    final eaten = <Food>[];
    for (final s in snakes) {
      final reach = SnakeRules.eatRangeOf(s.radius);
      eaten.clear();
      foodGrid.query(s.x, s.y, reach + 12, (f) {
        final dx = f.x - s.x, dy = f.y - s.y, lim = reach + f.radius;
        if (dx * dx + dy * dy < lim * lim) eaten.add(f);
      });
      for (final f in eaten) {
        _removeFood(f);
        s.mass += f.value;
        foodEaten.add((f.id, s.id));
      }
    }
  }

  // ── 먹이 ──

  /// 먹이를 놓는다 (필드 밖이면 안쪽으로 당긴다). 너무 많으면 저절로 깔리는 먹이 말고는 놓지 않는다.
  Food? addFood(double x, double y, double value, int color, {bool natural = true, double? bornAt}) {
    if (!natural && food.length >= SnakeRules.foodCap) return null;
    final f = Food(_nextFood++, x.clamp(12, field - 12), y.clamp(12, field - 12), value, color, natural: natural, bornAt: bornAt ?? time);
    food[f.id] = f;
    (natural ? _naturalByAge : _dropByAge).add(f);
    foodGrid.add(f, f.x, f.y);
    if (natural) _natural++;
    foodAdded.add(f);
    return f;
  }

  void _removeFood(Food f) {
    if (food.remove(f.id) == null) return;
    foodGrid.remove(f, f.x, f.y);
    if (f.natural) _natural--;
  }

  /// 저절로 깔리는 먹이: 아무 데나 네 곳을 골라 보고 그중 먹이가 가장 드문 곳에 놓는다.
  void _addNaturalFood() {
    final v = rng.nextDouble() < 0.15 ? 2.0 : 1.0;
    var bx = 0.0, by = 0.0, best = 1 << 30;
    for (var k = 0; k < 4; k++) {
      final x = 30 + rng.nextDouble() * (field - 60), y = 30 + rng.nextDouble() * (field - 60);
      var n = 0;
      foodGrid.query(x, y, 100, (_) => n++);
      if (n < best) {
        best = n;
        bx = x;
        by = y;
      }
    }
    addFood(bx, by, v, rng.nextInt(snakeColorCount), bornAt: time == 0 ? -rng.nextDouble() * naturalLife : null);
  }

  /// 오래 아무도 안 먹은 먹이를 치운다 (손님 기기에는 "먹힌 먹이"로 알린다, 먹은 뱀 -1).
  void _expireFood() {
    _expire(_naturalByAge, naturalLife);
    _expire(_dropByAge, dropLife);
  }

  void _expire(Queue<Food> q, double life) {
    for (var k = 0; k < 8 && q.isNotEmpty; k++) {
      final f = q.first;
      if (food[f.id] != f) {
        q.removeFirst(); // (이미 먹혔다)
        continue;
      }
      if (time - f.bornAt < life) break;
      q.removeFirst();
      _removeFood(f);
      foodEaten.add((f.id, -1));
    }
  }

  // ── 태어나기 ──

  void _respawnCpus(double dt) {
    _deficitCheck -= dt;
    if (_deficitCheck <= 0) {
      _deficitCheck = 1;
      // 사람이 아주 나가서 자리가 비면 CPU가 채운다
      final missing = population - headcount - _cpuDue.length;
      for (var i = 0; i < missing; i++) {
        _cpuDue.add(time + 1 + rng.nextDouble() * 2);
      }
    }
    _cpuDue.sort();
    while (_cpuDue.isNotEmpty && _cpuDue.first <= time) {
      _cpuDue.removeAt(0);
      if (headcount < population) _spawnCpu();
    }
  }

  void _spawnCpu() {
    final counts = {for (final k in CpuSkill.values) k: 0};
    for (final s in snakes) {
      final b = s.brain;
      if (!s.human && b != null) counts[b.skill] = counts[b.skill]! + 1;
    }
    // 멍청한·보통·똑똑한 CPU를 고루 섞는다 (가장 적은 쪽부터)
    final skill = CpuSkill.values.reduce((a, b) => counts[a]! <= counts[b]! ? a : b);
    // 성격(공격형·보통형·신중형)도 같은 솜씨 안에서 고루 섞는다
    final moods = {for (final k in CpuMood.values) k: 0};
    for (final x in snakes) {
      final b = x.brain;
      if (!x.human && b != null && b.skill == skill) moods[b.mood] = moods[b.mood]! + 1;
    }
    final fewest = moods.values.reduce(min);
    final pickable = [for (final k in CpuMood.values) if (moods[k] == fewest) k];
    final mood = pickable[rng.nextInt(pickable.length)];
    final used = {for (final s in snakes) s.name};
    final free = [for (final n in cpuNames) if (!used.contains(n)) n];
    final name = free.isEmpty ? 'CPU $_nextId' : free[rng.nextInt(free.length)];
    _spawn(name: name, color: rng.nextInt(snakeColorCount), brain: CpuBrain(skill, rng, mood: mood));
  }

  WorldSnake _spawn({required String name, required int color, int seat = -1, CpuBrain? brain}) {
    final s = WorldSnake(id: _nextId++, name: name, color: color, seat: seat, brain: brain);
    final (x, y) = _openSpot();
    final toCenter = atan2(field / 2 - y, field / 2 - x);
    final heading = toCenter + (rng.nextDouble() - 0.5) * 2.4;
    s.layStraight(x, y, heading);
    s.targetAngle = heading;
    s.bornAt = time;
    s.lastInput = time;
    snakes.add(s);
    byId[s.id] = s;
    born.add(s);
    return s;
  }

  /// 다른 뱀과 떨어진 빈 자리 (못 찾으면 가장 덜 붐비는 곳).
  (double, double) _openSpot() {
    const margin = 450.0;
    (double, double)? best;
    var bestGap = -1.0;
    for (var k = 0; k < 40; k++) {
      final x = margin + rng.nextDouble() * (field - margin * 2);
      final y = margin + rng.nextDouble() * (field - margin * 2);
      var gap = 1e9;
      for (final s in snakes) {
        final dx = s.x - x, dy = s.y - y;
        gap = min(gap, sqrt(dx * dx + dy * dy));
      }
      if (grid.query(x, y, 260, (_) => true)) gap = min(gap, 100);
      if (gap > 500) return (x, y);
      if (gap > bestGap) {
        bestGap = gap;
        best = (x, y);
      }
    }
    return best!;
  }

  /// 크기 순서 (1등부터).
  List<WorldSnake> ranking() => [...snakes]..sort((a, b) => b.mass.compareTo(a.mass));
}

/// CPU 뱀 이름들.
const List<String> cpuNames = [
  '꿈틀이', '냠냠이', '번개', '초코', '구름', '말랑이', '후추', '콩떡', '보리', '자두', '호떡', '꼬물이',
  '스르륵', '쏜살', '누룽지', '찹쌀', '감자', '고구마', '두부', '단호박', '깨비', '먹보', '느림보', '왕눈이',
  '뭉치', '솜사탕', '꽈배기', '젤리', '레몬', '망고', '키위', '토리', '도토리', '참깨', '모찌', '라떼',
];
