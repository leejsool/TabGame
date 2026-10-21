import 'dart:math';
import 'dart:typed_data';

/// 뱀 게임의 숫자들 (필드 크기, 빠르기, 굵기·길이가 자라는 정도).
class SnakeRules {
  SnakeRules._();

  /// 네모난 필드의 한 변 (벽 안쪽). 30마리가 자주 마주치되 숨 쉴 틈은 있는 넓이.
  static const double field = 5000;

  /// 필드에 있어야 할 뱀 수 (사람 + CPU). 사람이 늘면 죽은 CPU가 다시 태어나지 않아 이 수가 지켜진다.
  static const int population = 30;

  /// 한 방에 들어올 수 있는 사람 수 (방장 포함).
  static const int maxHumans = 8;

  /// 몸의 자취 점 사이 간격.
  static const double spacing = 6;

  /// 몸이 커브 안쪽으로 파고드는 정도 (0 = 머리가 지난 길 그대로). 자취 점이 하나 찍힐 때마다 몸의 점들이
  /// 이웃한 두 점의 가운데 쪽으로 이만큼씩 당겨진다. 그래서 오래된 꼬리 쪽일수록 많이 당겨져서,
  /// 같은 자리를 빙빙 돌면 몸이 서서히 안쪽으로 조여든다 (곧게 가는 몸은 그대로).
  static const double tighten = 0.2;

  static const double speed = 165, boostSpeed = 330;
  static const double startMass = 10;

  /// 부스터를 쓸 수 있는 가장 작은 크기 (이보다 작으면 부스터가 안 켜진다).
  static const double minBoostMass = 14;

  /// 부스터를 쓰는 동안 1초에 줄어드는 크기 (줄어든 만큼 꼬리 뒤에 먹이로 떨어진다).
  static const double boostCost = 3;

  /// 저절로 깔리는 먹이 수와 (죽은 뱀이 남긴 것까지 합친) 최대 먹이 수.
  static const int foodTarget = 1100, foodCap = 2600;

  /// 굵기(반지름): 아주 서서히 굵어진다 (10 → 9.6, 100 → 13, 500 → 18.7, 1000 → 22).
  static double radiusOf(double mass) => 9 + 5 * log(1 + mass / 80);

  /// 몸 길이: 먹을수록 길어진다 (10 → 110, 100 → 380, 1000 → 2070).
  static double lengthOf(double mass) => 60 + 8 * pow(mass, 0.8).toDouble();

  /// 1초에 돌 수 있는 각도 (굵을수록 조금 느리게 돈다).
  static double turnRateOf(double radius) => 4.6 * 14 / (radius + 5);

  /// 먹이를 먹는 거리 (머리 중심에서).
  static double eatRangeOf(double radius) => radius + 10;
}

/// 뱀 몸이 지나온 자취: 머리가 [SnakeRules.spacing]만큼 갈 때마다 찍은 점들 (0 = 가장 오래된 점).
/// 점을 하나 찍을 때마다 [smooth]로 몸이 안쪽으로 조금씩 파고든다. 수백 점을 자주 고치므로
/// 숫자 하나하나가 새 객체가 되는 List 대신 배열을 쓴다.
class SnakeTrail {
  Float64List _xs = Float64List(256), _ys = Float64List(256);
  int _start = 0, _end = 0;

  int get length => _end - _start;
  bool get isEmpty => length == 0;
  double xAt(int i) => _xs[_start + i];
  double yAt(int i) => _ys[_start + i];
  double get lastX => _xs[_end - 1];
  double get lastY => _ys[_end - 1];

  void add(double x, double y) {
    if (_end == _xs.length) {
      if (_start > _xs.length ~/ 2) {
        _compact();
      } else {
        _xs = Float64List(_xs.length * 2)..setRange(0, _end, _xs);
        _ys = Float64List(_ys.length * 2)..setRange(0, _end, _ys);
      }
    }
    _xs[_end] = x;
    _ys[_end] = y;
    _end++;
  }

  void _compact() {
    final n = length;
    _xs.setRange(0, n, _xs, _start);
    _ys.setRange(0, n, _ys, _start);
    _start = 0;
    _end = n;
  }

  void clear() => _start = _end = 0;

  /// 머리 ([hx], [hy])에서부터 [keep]만큼의 몸을 덮는 점만 남긴다.
  void trim(double hx, double hy, double keep) {
    if (isEmpty) return;
    var i = length - 1;
    var acc = _dist(hx, hy, xAt(i), yAt(i));
    while (i > 0 && acc < keep) {
      acc += _dist(xAt(i), yAt(i), xAt(i - 1), yAt(i - 1));
      i--;
    }
    _start += i;
    if (_start > 512) _compact();
  }

  /// 몸의 점들을 이웃한 두 점의 가운데 쪽으로 [k]만큼 당긴다 (맨 끝 점과 머리 가까운 두 점은 그대로).
  /// 곧은 몸은 그대로고 굽은 몸은 안쪽으로 조금 파고든다.
  void smooth(double k) {
    final last = _end - 3;
    var px = _xs[_start], py = _ys[_start];
    for (var i = _start + 1; i <= last; i++) {
      final cx = _xs[i], cy = _ys[i];
      _xs[i] = cx + k * ((px + _xs[i + 1]) * 0.5 - cx);
      _ys[i] = cy + k * ((py + _ys[i + 1]) * 0.5 - cy);
      px = cx;
      py = cy;
    }
  }

  static double _dist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return sqrt(dx * dx + dy * dy);
  }
}

/// 화면에 그리고 순위를 매기는 데 필요한 뱀 한 마리 (방장 기기의 진짜 뱀과 손님 기기의 따라 그리는 뱀이 함께 쓴다).
class SnakeBody {
  SnakeBody({required this.id, required this.name, required this.color, this.seat = -1});

  final int id;
  final String name;

  /// 색 번호 ([snakeColors]의 칸).
  final int color;

  /// 사람 자리 번호 (0 = 방장, 1… = 손님). CPU면 -1.
  final int seat;

  double x = 0, y = 0, angle = 0, mass = SnakeRules.startMass;
  bool boost = false;
  int kills = 0;

  /// 사람 자리지만 지금은 CPU가 대신 움직이는 중 (나간 사람).
  bool covered = false;

  final SnakeTrail trail = SnakeTrail();

  double get radius => SnakeRules.radiusOf(mass);
  double get length => SnakeRules.lengthOf(mass);
  int get score => mass.floor();
  bool get human => seat >= 0;

  /// 머리를 ([hx], [hy])에 두고 [heading] 반대쪽으로 곧게 뻗은 몸을 깐다 (막 태어난 뱀).
  void layStraight(double hx, double hy, double heading) {
    x = hx;
    y = hy;
    angle = heading;
    trail.clear();
    final n = (length / SnakeRules.spacing).ceil() + 1;
    for (var i = n; i >= 1; i--) {
      trail.add(hx - cos(heading) * SnakeRules.spacing * i, hy - sin(heading) * SnakeRules.spacing * i);
    }
  }

  /// 머리가 지나간 자리에 자취 점을 찍고 길이에 맞게 꼬리를 줄인다.
  void layTrail() {
    if (trail.isEmpty) {
      trail.add(x, y);
      return;
    }
    var lx = trail.lastX, ly = trail.lastY;
    var d = SnakeTrail._dist(x, y, lx, ly);
    while (d >= SnakeRules.spacing) {
      final t = SnakeRules.spacing / d;
      lx += (x - lx) * t;
      ly += (y - ly) * t;
      trail.add(lx, ly);
      trail.smooth(SnakeRules.tighten);
      d = SnakeTrail._dist(x, y, lx, ly);
    }
    trail.trim(x, y, length);
  }
}

/// 먹이 한 알.
class Food {
  Food(this.id, this.x, this.y, this.value, this.color, {this.natural = true, this.bornAt = 0});

  final int id;
  final double x, y;

  /// 먹으면 늘어나는 크기.
  final double value;
  final int color;

  /// 저절로 깔린 먹이인가 (죽은 뱀·부스터가 남긴 것이면 false).
  final bool natural;

  /// 놓인 시각 (방장 기기의 판 시계). 너무 오래 아무도 안 먹으면 치운다.
  final double bornAt;

  double get radius => min(3.2 + value * 1.3, 11);
}

/// 각도를 -π..π로.
double wrapAngle(double a) {
  while (a > pi) {
    a -= 2 * pi;
  }
  while (a < -pi) {
    a += 2 * pi;
  }
  return a;
}
