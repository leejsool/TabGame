import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/snake/core/snake_body.dart';

/// 머리를 [radius]짜리 원 위로 [seconds]초 동안 달리게 한다 (몸 선은 [SnakeBody.layTrail]이 잇는다).
SnakeBody _circle({required double mass, required double radius, required double seconds, double dt = 1 / 60}) {
  final b = SnakeBody(id: 1, name: 't', color: 0)..mass = mass;
  const cx = 1000.0, cy = 1000.0;
  final w = SnakeRules.speed / radius; // 각속도
  b.x = cx + radius;
  b.y = cy;
  b.layTrail();
  for (var t = 0.0; t < seconds; t += dt) {
    b.x = cx + cos(w * t) * radius;
    b.y = cy + sin(w * t) * radius;
    b.layTrail();
  }
  return b;
}

double _fromCenter(SnakeBody b, int i) => sqrt(pow(b.trail.xAt(i) - 1000, 2) + pow(b.trail.yAt(i) - 1000, 2)).toDouble();

void main() {
  test('곧게 가는 몸은 그대로고 (안쪽으로 파고들지 않는다)', () {
    final b = SnakeBody(id: 1, name: 't', color: 0)..mass = 300;
    b.x = 100;
    b.y = 500;
    b.layTrail();
    for (var i = 0; i < 600; i++) {
      b.x += SnakeRules.speed / 60;
      b.layTrail();
    }
    for (var i = 0; i < b.trail.length; i++) {
      expect(b.trail.yAt(i), closeTo(500, 1e-6));
    }
  });

  test('같은 자리를 빙빙 돌면 몸이 서서히 안쪽으로 조여든다 (꼬리 쪽일수록 많이)', () {
    final b = _circle(mass: 3000, radius: 82, seconds: 60);
    final n = b.trail.length;
    expect(n, greaterThan(500));
    final head = _fromCenter(b, n - 1);
    final mid = _fromCenter(b, n ~/ 2);
    final tail = _fromCenter(b, 2);
    // 머리 쪽은 머리가 지난 길 그대로, 꼬리 쪽은 안쪽으로 들어와 있다
    expect(head, closeTo(82, 0.5));
    expect(mid, lessThan(head - 1));
    expect(tail, lessThan(mid - 3));
    expect(tail, greaterThan(40), reason: '순식간에 무너지지는 않는다 (미세하게)');
    // 몸이 짧아져도 몸 길이는 대체로 유지된다
    var len = 0.0;
    for (var i = 1; i < n; i++) {
      len += sqrt(pow(b.trail.xAt(i) - b.trail.xAt(i - 1), 2) + pow(b.trail.yAt(i) - b.trail.yAt(i - 1), 2));
    }
    expect(len, inInclusiveRange(b.length * 0.9, b.length * 1.15));
  });

  test('작은 뱀은 거의 티가 안 난다', () {
    final b = _circle(mass: 30, radius: 45, seconds: 40);
    final n = b.trail.length;
    expect(_fromCenter(b, 2), greaterThan(45 * 0.93));
    expect(n, greaterThan(10));
  });

  test('조여드는 정도는 화면 빠르기와 상관없다 (60Hz든 144Hz든 같은 모양)', () {
    final a = _circle(mass: 1500, radius: 70, seconds: 40, dt: 1 / 60);
    final c = _circle(mass: 1500, radius: 70, seconds: 40, dt: 1 / 144);
    for (final f in [0.1, 0.5, 0.9]) {
      final ia = (a.trail.length * f).floor(), ic = (c.trail.length * f).floor();
      expect(_fromCenter(a, ia), closeTo(_fromCenter(c, ic), 2.5));
    }
  });
}
