import 'dart:math';

import 'pinball_table.dart';

/// 판에서 일어난 일 (점수·소리·진동을 정하려고 규칙 쪽이 읽어 간다).
enum HitKind {
  bumper,
  sling,
  target,

  /// 표적 묶음을 다 쓰러뜨림 (index = 묶음 번호).
  bank,
  post,
  wall,
  flipper,

  /// 롤오버 레인 하나가 켜짐 (index = 레인 번호).
  lane,

  /// 롤오버 레인 네 개가 다 켜짐.
  lanesDone,

  /// 궤도 레인을 끝까지 달려 올라감 (index = 0 왼쪽, 1 오른쪽).
  orbit,

  /// 스피너가 반 바퀴 돎.
  spin,

  /// 블랙홀에 공이 빨려 들어감.
  saucer,

  /// 불이 켜진 블랙홀에서 공이 여러 개 쏟아져 나옴.
  multiball,
  drain,
  saved,
  launch,
}

class HitEvent {
  const HitEvent(this.kind, this.x, this.y, {this.index = 0, this.strength = 0});

  final HitKind kind;
  final double x, y;

  /// 몇 번째 범퍼·표적인지, 또는 drain일 때 판에 남은 공 수.
  final int index;

  /// 부딪힌 세기 (속도).
  final double strength;
}

class Ball {
  Ball(this.x, this.y, {this.vx = 0, this.vy = 0});

  double x, y, vx, vy;

  /// 발사를 기다리는 공 (통로 바닥에 놓여 있다).
  bool waiting = true;
  double slow = 0; // 거의 멈춰 있던 시간
}

class FlipperState {
  FlipperState(this.spec) : angle = spec.restAngle;

  final FlipperSpec spec;
  double angle;
  double omega = 0;
  bool pressed = false;
}

class SpinnerState {
  double angle = 0;
  double omega = 0;
  int halves = 0;
}

class _Spawn {
  _Spawn(this.delay, this.x, this.y, this.vx, this.vy);

  double delay;
  final double x, y, vx, vy;
}

/// 판을 움직이는 물리. 규칙(점수·시간)은 모르고, 공의 움직임과 부딪힘만 계산한다.
/// 공이 얇은 벽을 뚫지 않도록 아주 잘게(1/720초) 나눠서 계산한다.
class PinballEngine {
  PinballEngine(this.table, {Random? rng}) : rng = rng ?? Random() {
    for (final f in table.flippers) {
      flippers.add(FlipperState(f));
    }
    targetDown = List<bool>.filled(table.targets.length, false);
    laneLit = List<bool>.filled(table.sensors.where((s) => s.kind == SensorKind.lane).length, false);
    spinners = [for (final _ in table.spinners) SpinnerState()];
    _sensorCool = List<double>.filled(table.sensors.length, 0);
    _bankReset = List<double>.filled(table.bankCount, -1);
  }

  static const double _dt = 1 / 720;
  static const double _maxSpeed = 3100;
  static const double _flipperSpeed = 22; // 라디안/초
  static const double _flipperThick = 9;

  final PinballTable table;
  final Random rng;
  final List<Ball> balls = [];
  final List<FlipperState> flippers = [];
  late List<bool> targetDown;
  late List<bool> laneLit;
  late List<SpinnerState> spinners;
  final List<HitEvent> events = [];

  /// 궤도 레인(0=왼쪽, 1=오른쪽)에 공이 들어와 있어서, 끝까지 가면 점수를 주는 상태.
  final List<double> orbitArmed = [0, 0];

  // 튜닝 (업그레이드가 바꾼다)
  double gravityMul = 1;
  double flipperLenMul = 1;
  double flipperPowerMul = 1;
  double ballScale = 1;

  /// 떨어지는 공을 튕겨 올려 줄 보호막 수.
  int shields = 0;

  /// 틸트(너무 흔듦) 동안은 플리퍼가 안 올라간다.
  bool locked = false;

  /// 블랙홀 불이 켜져 있으면 다음에 빨려 든 공이 멀티볼이 되어 나온다.
  bool saucerLit = false;

  Ball? held; // 블랙홀에 잡혀 있는 공
  double _heldFor = 0;
  double _saucerCool = 0;

  double _acc = 0;
  late List<double> _bankReset;
  double _lanesReset = -1;
  late List<double> _sensorCool;
  final List<_Spawn> _spawns = [];

  /// 발사 힘(0~1)에 따른 공의 처음 속도. 0.35쯤부터 통로 꼭대기까지 올라간다.
  static double launchSpeed(double power) => 1000 + 2100 * power.clamp(0.0, 1.0);

  double get ballR => kBallR * ballScale;
  bool get hasWaitingBall => balls.any((b) => b.waiting);

  /// 아직 판에 남은 공 (움직이는 공 + 잡힌 공 + 곧 나올 공).
  int get ballsInPlay => balls.length + (held == null ? 0 : 1) + _spawns.length;

  /// 플리퍼 끝 위치.
  (double, double) flipperTip(FlipperState f) {
    final l = f.spec.length * flipperLenMul;
    return (f.spec.px + l * cos(f.angle), f.spec.py + l * sin(f.angle));
  }

  void setFlipper(bool left, bool pressed) {
    for (final f in flippers) {
      if (f.spec.left == left) f.pressed = pressed;
    }
  }

  /// 발사 통로에 새 공을 놓는다.
  void spawnWaitingBall() {
    if (hasWaitingBall) return;
    balls.add(Ball(kLaneX, kLaneFloorY - ballR - 2));
  }

  /// 통로의 공을 쏜다. [power]는 0~1.
  void launch(double power) {
    final p = power.clamp(0.0, 1.0);
    final speed = launchSpeed(p);
    for (final b in balls) {
      if (b.waiting) {
        b.waiting = false;
        b.vy = -speed;
        events.add(HitEvent(HitKind.launch, b.x, b.y, strength: speed));
      }
    }
  }

  /// 같은 힘으로 공을 더 쏜다 (쌍둥이 공): [delay]초 뒤에 통로에서 나온다.
  void launchExtra(double delay, double speed) => _spawns.add(_Spawn(delay, kLaneX, kLaneFloorY - ballR - 2, 0, -speed));

  /// 판을 흔든다: 공들이 옆으로 튄다.
  void nudge() {
    for (final b in balls) {
      if (b.waiting) continue;
      b.vx += (rng.nextBool() ? 1 : -1) * (250 + rng.nextDouble() * 220);
      b.vy -= 170;
    }
  }

  void resetAll() {
    balls.clear();
    _spawns.clear();
    held = null;
    for (final f in flippers) {
      f.angle = f.spec.restAngle;
      f.omega = 0;
      f.pressed = false;
    }
    resetTargets();
    for (var i = 0; i < laneLit.length; i++) {
      laneLit[i] = false;
    }
    events.clear();
  }

  void resetTargets() {
    for (var i = 0; i < targetDown.length; i++) {
      targetDown[i] = false;
    }
    for (var i = 0; i < _bankReset.length; i++) {
      _bankReset[i] = -1;
    }
  }

  /// [dt]초만큼 진행한다. 일어난 일은 [events]에 쌓인다 (읽은 쪽이 비운다).
  void advance(double dt) {
    _acc += min(dt, 0.05);
    while (_acc >= _dt) {
      _acc -= _dt;
      _step();
    }
  }

  void _step() {
    _stepFlippers();
    _stepTimers();
    _stepSaucer();
    _stepSpinners();
    for (var i = balls.length - 1; i >= 0; i--) {
      final b = balls[i];
      b.vy += 1560 * gravityMul * _dt;
      final sp = sqrt(b.vx * b.vx + b.vy * b.vy);
      if (sp > _maxSpeed) {
        b.vx *= _maxSpeed / sp;
        b.vy *= _maxSpeed / sp;
      }
      b.x += b.vx * _dt;
      b.y += b.vy * _dt;
      _collide(b);
      _unstick(b);
      if (!b.waiting) {
        _sensors(b);
        if (_trySaucer(b)) {
          balls.removeAt(i);
          continue;
        }
      }
      if (b.y > 1290 && b.vy > 0 && shields > 0 && b.x < 556 && b.x > 60) {
        shields--;
        b.vy = -2100;
        b.vx = (rng.nextDouble() - 0.5) * 700;
        events.add(HitEvent(HitKind.saved, b.x, b.y));
      }
      if (b.y > kDrainY && b.x < kLaneInnerX) {
        balls.removeAt(i);
        events.add(HitEvent(HitKind.drain, b.x, b.y, index: ballsInPlay));
      }
    }
  }

  void _stepFlippers() {
    for (final f in flippers) {
      final goal = (f.pressed && !locked) ? f.spec.upAngle : f.spec.restAngle;
      final speed = _flipperSpeed * flipperPowerMul;
      final diff = goal - f.angle;
      final move = diff.abs() <= speed * _dt ? diff : speed * _dt * diff.sign;
      f.angle += move;
      f.omega = move / _dt;
    }
  }

  void _stepTimers() {
    for (var i = 0; i < _bankReset.length; i++) {
      if (_bankReset[i] >= 0) {
        _bankReset[i] -= _dt;
        if (_bankReset[i] < 0) {
          for (var k = 0; k < targetDown.length; k++) {
            if (table.targets[k].bank == i) targetDown[k] = false;
          }
        }
      }
    }
    if (_lanesReset >= 0) {
      _lanesReset -= _dt;
      if (_lanesReset < 0) {
        for (var i = 0; i < laneLit.length; i++) {
          laneLit[i] = false;
        }
      }
    }
    for (var i = 0; i < _sensorCool.length; i++) {
      if (_sensorCool[i] > 0) _sensorCool[i] -= _dt;
    }
    for (var i = 0; i < orbitArmed.length; i++) {
      if (orbitArmed[i] > 0) orbitArmed[i] -= _dt;
    }
    for (var i = _spawns.length - 1; i >= 0; i--) {
      final s = _spawns[i];
      s.delay -= _dt;
      if (s.delay <= 0) {
        _spawns.removeAt(i);
        balls.add(Ball(s.x, s.y, vx: s.vx, vy: s.vy)..waiting = false);
      }
    }
  }

  void _stepSpinners() {
    for (final s in spinners) {
      if (s.omega < 0.05) {
        s.omega = 0;
        continue;
      }
      s.angle += s.omega * _dt;
      s.omega *= 1 - 1.6 * _dt;
      final halves = (s.angle / pi).floor();
      if (halves > s.halves) {
        final spec = table.spinners[spinners.indexOf(s)];
        for (var k = s.halves; k < halves; k++) {
          events.add(HitEvent(HitKind.spin, spec.x, spec.y));
        }
        s.halves = halves;
      }
    }
  }

  void _stepSaucer() {
    if (_saucerCool > 0) _saucerCool -= _dt;
    final h = held;
    if (h == null) return;
    _heldFor -= _dt;
    if (_heldFor > 0) return;
    held = null;
    _saucerCool = 0.9;
    final c = table.saucer;
    void eject(double delay, double vx, double vy) {
      _spawns.add(_Spawn(delay, c.x, c.y - 4, vx, vy));
    }

    eject(0, (rng.nextDouble() - 0.5) * 700, -(1300 + rng.nextDouble() * 400));
    if (saucerLit) {
      saucerLit = false;
      eject(0.45, -360 - rng.nextDouble() * 280, -(1300 + rng.nextDouble() * 300));
      eject(0.9, 360 + rng.nextDouble() * 280, -(1300 + rng.nextDouble() * 300));
      events.add(HitEvent(HitKind.multiball, c.x, c.y));
    }
  }

  bool _trySaucer(Ball b) {
    final c = table.saucer;
    if (held != null || _saucerCool > 0) return false;
    final dx = b.x - c.x, dy = b.y - c.y;
    if (dx * dx + dy * dy > c.r * c.r) return false;
    if (b.vx * b.vx + b.vy * b.vy > 1550 * 1550) return false;
    held = b;
    _heldFor = saucerLit ? 0.5 : 0.9;
    events.add(HitEvent(HitKind.saucer, c.x, c.y));
    return true;
  }

  void _sensors(Ball b) {
    for (var i = 0; i < table.sensors.length; i++) {
      final s = table.sensors[i];
      if (_sensorCool[i] > 0) continue;
      final dx = b.x - s.x, dy = b.y - s.y;
      if (dx * dx + dy * dy > s.r * s.r) continue;
      _sensorCool[i] = 0.4;
      switch (s.kind) {
        case SensorKind.lane:
          if (laneLit[s.index]) break;
          laneLit[s.index] = true;
          events.add(HitEvent(HitKind.lane, s.x, s.y, index: s.index));
          if (laneLit.every((e) => e)) {
            events.add(HitEvent(HitKind.lanesDone, s.x, s.y));
            _lanesReset = 0.9;
          }
        case SensorKind.orbitIn:
          if (b.vy < 0) orbitArmed[s.index] = 4;
        case SensorKind.orbitOut:
          if (orbitArmed[s.index] > 0 && b.vy < 0) {
            orbitArmed[s.index] = 0;
            events.add(HitEvent(HitKind.orbit, s.x, s.y, index: s.index));
          }
      }
    }
    for (var i = 0; i < spinners.length; i++) {
      final sp = table.spinners[i];
      if ((b.x - sp.x).abs() < sp.w / 2 && (b.y - sp.y).abs() < 9) {
        final speed = sqrt(b.vx * b.vx + b.vy * b.vy);
        spinners[i].omega = max(spinners[i].omega, min(34.0, 4 + speed * 0.03));
      }
    }
  }

  /// 거의 멈춘 공이 판 위에 끼어 있으면 살짝 흔들어 준다.
  void _unstick(Ball b) {
    // 약하게 쏴서 통로 바닥으로 되돌아온 공은 다시 쏠 수 있게 기다리는 공으로 돌려놓는다.
    if (!b.waiting && b.x > kLaneInnerX && b.y > kLaneFloorY - ballR - 6 && b.vx * b.vx + b.vy * b.vy < 12800) {
      b.slow += _dt;
      if (b.slow > 0.25) {
        b.slow = 0;
        b.waiting = true;
        b.vx = 0;
      }
      return;
    }
    if (b.waiting || b.x > kLaneInnerX || b.y > 1200) return;
    if (b.vx * b.vx + b.vy * b.vy < 800) {
      b.slow += _dt;
      if (b.slow > 1.2) {
        b.slow = 0;
        b.vx += rng.nextBool() ? 300 : -300;
        b.vy -= 360;
      }
    } else {
      b.slow = 0;
    }
  }

  void _collide(Ball b) {
    final r = ballR;
    for (final w in table.walls) {
      _hitSegment(b, w.ax, w.ay, w.bx, w.by, 0, r, w.bounce, w.kick, w.sling >= 0 ? HitKind.sling : HitKind.wall, w.sling, gate: w.gate, kn: w.kick > 0 ? (w.nx, w.ny) : null);
    }
    for (var i = 0; i < table.bumpers.length; i++) {
      _hitDisc(b, table.bumpers[i].x, table.bumpers[i].y, table.bumpers[i].r, r, 0.9, 1000, HitKind.bumper, i);
    }
    for (var i = 0; i < table.targets.length; i++) {
      if (targetDown[i]) continue;
      final t = table.targets[i];
      if (_hitDisc(b, t.x, t.y, t.r, r, 0.55, 0, HitKind.target, i)) {
        targetDown[i] = true;
        final done = [for (var k = 0; k < targetDown.length; k++) if (table.targets[k].bank == t.bank) targetDown[k]].every((e) => e);
        if (done) {
          events.add(HitEvent(HitKind.bank, t.x, t.y, index: t.bank));
          _bankReset[t.bank] = 1.1;
        }
      }
    }
    for (final d in table.posts) {
      _hitDisc(b, d.x, d.y, d.r, r, 0.7, 0, HitKind.post, 0);
    }
    for (final f in flippers) {
      final l = f.spec.length * flipperLenMul;
      final tx = f.spec.px + l * cos(f.angle);
      final ty = f.spec.py + l * sin(f.angle);
      _hitSegment(b, f.spec.px, f.spec.py, tx, ty, _flipperThick, r, 0.38, 0, HitKind.flipper, 0, omega: f.omega, pivot: (f.spec.px, f.spec.py));
    }
  }

  bool _hitDisc(Ball b, double cx, double cy, double cr, double r, double bounce, double kick, HitKind kind, int index) {
    var dx = b.x - cx, dy = b.y - cy;
    final dist = sqrt(dx * dx + dy * dy);
    final reach = r + cr;
    if (dist >= reach) return false;
    if (dist < 1e-6) {
      dx = 0;
      dy = -1;
    } else {
      dx /= dist;
      dy /= dist;
    }
    b.x = cx + dx * reach;
    b.y = cy + dy * reach;
    final vn = b.vx * dx + b.vy * dy;
    if (vn >= 0) return false;
    b.vx -= (1 + bounce) * vn * dx;
    b.vy -= (1 + bounce) * vn * dy;
    if (kick > 0) {
      final after = b.vx * dx + b.vy * dy;
      if (after < kick) {
        b.vx += (kick - after) * dx;
        b.vy += (kick - after) * dy;
      }
    }
    if (-vn > 55 || kind == HitKind.bumper) events.add(HitEvent(kind, cx, cy, index: index, strength: -vn));
    return true;
  }

  void _hitSegment(
    Ball b,
    double ax,
    double ay,
    double bx,
    double by,
    double thick,
    double r,
    double bounce,
    double kick,
    HitKind kind,
    int index, {
    double omega = 0,
    (double, double)? pivot,
    bool gate = false,
    (double, double)? kn,
  }) {
    if (gate && (b.vx <= 0 || b.x > ax)) return;
    final ex = bx - ax, ey = by - ay;
    final len2 = ex * ex + ey * ey;
    var t = len2 == 0 ? 0.0 : ((b.x - ax) * ex + (b.y - ay) * ey) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + ex * t, cy = ay + ey * t;
    var dx = b.x - cx, dy = b.y - cy;
    final dist = sqrt(dx * dx + dy * dy);
    final reach = r + thick;
    if (dist >= reach) return;
    if (dist < 1e-6) {
      // 선분 한가운데에 겹쳤을 때: 선분에 수직인 쪽 (위쪽 우선)
      final len = sqrt(len2);
      dx = len == 0 ? 0 : ey / len;
      dy = len == 0 ? -1 : -ex / len;
      if (dy > 0) {
        dx = -dx;
        dy = -dy;
      }
    } else {
      dx /= dist;
      dy /= dist;
    }
    b.x = cx + dx * reach;
    b.y = cy + dy * reach;
    // 부딪힌 자리가 움직이는 속도 (플리퍼가 올라가는 중이면 공을 치고 올라간다)
    var sx = 0.0, sy = 0.0;
    if (pivot != null && omega != 0) {
      final rx = cx - pivot.$1, ry = cy - pivot.$2;
      sx = -omega * ry;
      sy = omega * rx;
    }
    final vn = (b.vx - sx) * dx + (b.vy - sy) * dy;
    if (vn >= 0) return;
    final e = bounce;
    b.vx -= (1 + e) * vn * dx;
    b.vy -= (1 + e) * vn * dy;
    // 슬링샷은 판 안쪽에서 맞았을 때만 튕겨 낸다
    final kicks = kick > 0 && (kn == null || dx * kn.$1 + dy * kn.$2 > 0);
    if (kicks) {
      final after = b.vx * dx + b.vy * dy;
      if (after < kick) {
        b.vx += (kick - after) * dx;
        b.vy += (kick - after) * dy;
      }
    }
    if (-vn > 150 || kicks) events.add(HitEvent(kicks ? kind : HitKind.wall, cx, cy, index: index, strength: -vn));
  }
}
