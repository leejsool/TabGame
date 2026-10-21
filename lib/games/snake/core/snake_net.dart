import 'dart:math';

import 'snake_body.dart';
import 'snake_world.dart';

/// 같은 Wi‑Fi로 주고받는 판의 모습.
///
/// 방장 기기만 판을 계산하고, 1초에 15번 바뀐 것(`t: 'w'`)을 손님들에게 보낸다: 모든 뱀의 머리 위치·방향·크기,
/// 새로 태어난 뱀, 죽은 뱀, 놓인 먹이와 먹힌 먹이. 손님 기기는 머리가 지나간 자리를 이어 몸을 그린다 ([SnakeMirror]).
/// 처음 들어올 때와 무언가 놓쳤을 때는 판 전체(`snap`)를 받는다. 위치는 10배 한 정수로 보낸다.

int _q(double v) => (v * 10).round();
double _dq(Object? v) => (v as num) / 10;

/// 방장 → 손님: 지난번 이후 바뀐 것 (보내고 나면 [SnakeWorld]의 일 목록을 비운다).
Map<String, dynamic> encodeDelta(SnakeWorld w, int seq) {
  final s = <int>[];
  for (final x in w.snakes) {
    s.addAll([x.id, _q(x.x), _q(x.y), (x.angle * 1000).round(), _q(x.mass), x.boost ? 1 : 0, x.kills, x.covered ? 1 : 0]);
  }
  final m = <String, dynamic>{'t': 'w', 'k': seq, 's': s, 'lv': w.cpuLevel};
  final born = [for (final b in w.born) if (w.byId.containsKey(b.id)) _bornJson(b)];
  if (born.isNotEmpty) m['n'] = born;
  if (w.deaths.isNotEmpty) m['d'] = [for (final d in w.deaths) d.id, for (final d in w.deaths) d.killer];
  if (w.foodAdded.isNotEmpty) m['fa'] = _foodFlat(w.foodAdded.where((f) => w.food.containsKey(f.id)));
  if (w.foodEaten.isNotEmpty) m['fe'] = [for (final (f, by) in w.foodEaten) ...[f, by]];
  w.born.clear();
  w.deaths.clear();
  w.foodAdded.clear();
  w.foodEaten.clear();
  return m;
}

List<Object> _bornJson(SnakeBody b) => [b.id, b.seat, b.name, b.color, _q(b.x), _q(b.y), (b.angle * 1000).round(), _q(b.mass)];

List<int> _foodFlat(Iterable<Food> foods) => [
      for (final f in foods) ...[f.id, _q(f.x), _q(f.y), _q(f.value), f.color, f.natural ? 1 : 0],
    ];

/// 판 전체 (처음 들어오는 손님·다시 들어오는 손님·놓친 손님에게).
Map<String, dynamic> encodeFull(SnakeWorld w, int seq) => {
      'k': seq,
      'field': w.field,
      'lv': w.cpuLevel,
      // 사람 명단 (방장이 사라졌을 때 누가 이어받을지 손님들이 같은 답을 내려고): [자리, 이름, CPU가 대신하는 중이면 1]
      'hs': w.hostSeat,
      'seats': [
        for (final e in w.seatNames.entries) [e.key, e.value, w.awaySeats.contains(e.key) ? 1 : 0],
      ],
      'sn': [
        for (final s in w.snakes)
          [
            ..._bornJson(s),
            s.boost ? 1 : 0,
            s.kills,
            s.covered ? 1 : 0,
            [for (var i = 0; i < s.trail.length; i += 2) ...[s.trail.xAt(i).round(), s.trail.yAt(i).round()]],
          ],
      ],
      'f': _foodFlat(w.food.values),
    };

/// 손님 기기가 따라 그리는 뱀: 받은 머리 위치 사이를 부드럽게 이어 간다.
class MirrorSnake extends SnakeBody {
  MirrorSnake({required super.id, required super.name, required super.color, super.seat});

  double _fx = 0, _fy = 0, _tx = 0, _ty = 0, _fa = 0, _ta = 0;

  void _aim(double x2, double y2, double a2) {
    _fx = x;
    _fy = y;
    _fa = angle;
    _tx = x2;
    _ty = y2;
    _ta = a2;
  }

  void _place(double x2, double y2, double a2) {
    x = _fx = _tx = x2;
    y = _fy = _ty = y2;
    angle = _fa = _ta = a2;
  }
}

/// 손님 기기의 판: 방장이 보낸 것만으로 뱀과 먹이를 그린다 (부딪힘·먹기는 방장이 정한다).
class SnakeMirror {
  SnakeMirror(Map<String, dynamic> snap) {
    load(snap);
  }

  double field = SnakeRules.field;

  /// 마지막으로 받은 변화의 번호.
  int seq = 0;
  final Map<int, MirrorSnake> snakes = {};
  final Map<int, Food> food = {};

  /// CPU 단계 (방장이 정한다).
  int cpuLevel = 0;

  /// 변화를 놓쳐서 판 전체를 다시 받아야 한다.
  bool needSync = false;

  /// 사람 명단 (자리 → 이름), 그중 CPU가 대신하는 자리, 지금 방장의 자리.
  /// 방장이 사라지면 이 명단으로 다음 방장을 정한다 ([successor]).
  final Map<int, String> seats = {};
  final Set<int> away = {};
  int hostSeat = 0;

  void addSeat(int seat, String name) {
    seats[seat] = name;
    away.remove(seat);
  }

  void removeSeat(int seat) {
    seats.remove(seat);
    away.remove(seat);
  }

  void setAway(int seat, bool on) {
    if (!seats.containsKey(seat)) return;
    on ? away.add(seat) : away.remove(seat);
  }

  /// 방장이 사라졌을 때 판을 이어받을 자리: 방장이 아니고 CPU가 대신하지 않는 사람 중 가장 앞 자리 (없으면 null).
  /// 모든 손님이 같은 명단을 가지고 있으므로 각자 계산해도 같은 사람이 나온다.
  int? successor() {
    int? best;
    for (final s in seats.keys) {
      if (s == hostSeat || away.contains(s)) continue;
      if (best == null || s < best) best = s;
    }
    return best;
  }

  /// 뱀이 죽을 때 (죽은 뱀, 부딪힌 상대 뱀 — 벽이면 null).
  void Function(MirrorSnake dead, SnakeBody? killer)? onDeath;

  double _lastAt = -1, _interval = 1 / 15, _now = 0;

  /// 판 전체로 바꾼다.
  void load(Map<String, dynamic> snap) {
    seq = snap['k'] as int;
    field = (snap['field'] as num).toDouble();
    cpuLevel = snap['lv'] is int ? snap['lv'] as int : 0;
    hostSeat = snap['hs'] is int ? snap['hs'] as int : 0;
    seats.clear();
    away.clear();
    for (final raw in (snap['seats'] as List?) ?? const []) {
      final j = raw as List;
      seats[j[0] as int] = '${j[1]}';
      if (j[2] == 1) away.add(j[0] as int);
    }
    snakes.clear();
    for (final raw in snap['sn'] as List) {
      final j = raw as List;
      final s = _born(j);
      s.boost = j[8] == 1;
      s.kills = j[9] as int;
      s.covered = j[10] == 1;
      final pts = j[11] as List;
      s.trail.clear();
      for (var i = 0; i + 1 < pts.length; i += 2) {
        s.trail.add((pts[i] as num).toDouble(), (pts[i + 1] as num).toDouble());
      }
      s.trail.add(s.x, s.y);
    }
    food.clear();
    _addFood(snap['f'] as List);
    needSync = false;
    _lastAt = -1;
  }

  MirrorSnake _born(List j) {
    final s = MirrorSnake(id: j[0] as int, seat: j[1] as int, name: '${j[2]}', color: (j[3] as int) % snakeColorCount);
    s.mass = _dq(j[7]);
    final x = _dq(j[4]), y = _dq(j[5]), a = (j[6] as num) / 1000;
    s.layStraight(x, y, a);
    s._place(x, y, a);
    snakes[s.id] = s;
    return s;
  }

  void _addFood(List flat) {
    for (var i = 0; i + 5 < flat.length; i += 6) {
      final f = Food(flat[i] as int, _dq(flat[i + 1]), _dq(flat[i + 2]), _dq(flat[i + 3]), (flat[i + 4] as int) % snakeColorCount, natural: flat[i + 5] == 1);
      food[f.id] = f;
    }
  }

  /// 방장이 보낸 변화 하나를 반영한다 ([now]는 초 단위 시계). 번호가 건너뛰었으면 [needSync]를 켠다.
  void apply(Map<String, dynamic> m, double now) {
    if (needSync) return;
    final k = m['k'];
    if (k is! int || k <= seq) return;
    if (k != seq + 1) {
      needSync = true;
      return;
    }
    seq = k;
    if (m['lv'] is int) cpuLevel = m['lv'] as int;
    if (_lastAt >= 0) _interval = (_interval * 0.8 + (now - _lastAt).clamp(0.03, 0.2) * 0.2);
    _lastAt = now;
    for (final j in (m['n'] as List?) ?? const []) {
      if (!snakes.containsKey((j as List)[0])) _born(j);
    }
    final d = (m['d'] as List?) ?? const [];
    final half = d.length ~/ 2;
    final killers = [for (var i = 0; i < half; i++) snakes[d[half + i]]];
    for (var i = 0; i < half; i++) {
      final dead = snakes.remove(d[i]);
      if (dead != null) onDeath?.call(dead, killers[i]);
    }
    final s = (m['s'] as List?) ?? const [];
    for (var i = 0; i + 7 < s.length; i += 8) {
      final b = snakes[s[i]];
      if (b == null) continue;
      b._aim(_dq(s[i + 1]), _dq(s[i + 2]), (s[i + 3] as num) / 1000);
      b.mass = _dq(s[i + 4]);
      b.boost = s[i + 5] == 1;
      b.kills = s[i + 6] as int;
      b.covered = s[i + 7] == 1;
    }
    _addFood((m['fa'] as List?) ?? const []);
    final fe = (m['fe'] as List?) ?? const [];
    for (var i = 0; i + 1 < fe.length; i += 2) {
      food.remove(fe[i]);
    }
    _now = now;
  }

  /// 화면 한 장마다: 머리를 받은 위치 사이에서 옮기고 지나간 자리에 몸을 잇는다.
  void frame(double now) {
    _now = now;
    final t = _lastAt < 0 ? 1.0 : ((_now - _lastAt) / _interval).clamp(0.0, 1.0);
    for (final s in snakes.values) {
      s.x = s._fx + (s._tx - s._fx) * t;
      s.y = s._fy + (s._ty - s._fy) * t;
      s.angle = s._fa + wrapAngle(s._ta - s._fa) * t;
      s.layTrail();
    }
  }

  SnakeBody? ofSeat(int seat) {
    for (final s in snakes.values) {
      if (s.seat == seat) return s;
    }
    return null;
  }
}

/// 손님 → 방장: 조종 (방향은 1000배 한 정수).
Map<String, dynamic> encodeInput(double angle, bool boost) => {'t': 'in', 'a': (angle * 1000).round(), 'b': boost ? 1 : 0};

/// 크기 순서 (1등부터).
List<T> rankSnakes<T extends SnakeBody>(Iterable<T> all) => [...all]..sort((a, b) => b.mass.compareTo(a.mass));

/// 두 점 사이 거리.
double snakeDist(double ax, double ay, double bx, double by) => sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));
