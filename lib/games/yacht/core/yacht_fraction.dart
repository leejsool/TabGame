// 야추 확률을 분수로 다루는 도우미. 화면 없이 쓰는 순수 Dart.

int _gcd(int a, int b) {
  a = a.abs();
  b = b.abs();
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  return a;
}

/// 약분된 분수 ([num] / [den]). 확률을 "몇 분의 몇"으로 정확하게 나타낼 때 쓴다.
class YachtFrac {
  /// 분모가 0이면 안 된다. 만들 때 자동으로 약분한다 (0은 0/1).
  factory YachtFrac(int num, int den) {
    assert(den != 0);
    if (num == 0) return const YachtFrac._(0, 1);
    final g = _gcd(num, den);
    final sign = den < 0 ? -1 : 1;
    return YachtFrac._(sign * num ~/ g, sign * den ~/ g);
  }

  const YachtFrac._(this.num, this.den);

  static const YachtFrac zero = YachtFrac._(0, 1);
  static const YachtFrac one = YachtFrac._(1, 1);

  final int num;
  final int den;

  double get value => num / den;

  /// 자연수인가 (분모가 1).
  bool get isWhole => den == 1;

  YachtFrac operator +(YachtFrac o) => YachtFrac(num * o.den + o.num * den, den * o.den);

  YachtFrac operator *(YachtFrac o) => YachtFrac(num * o.num, den * o.den);

  @override
  bool operator ==(Object other) => other is YachtFrac && other.num == num && other.den == den;

  @override
  int get hashCode => Object.hash(num, den);

  /// "121/1296" 꼴 글자 (화면에서는 가로줄이 있는 분수로 그리고, 시험·기록용으로 쓴다).
  @override
  String toString() => isWhole ? '$num' : '$num/$den';
}

/// 에이스~식스 칸 하나만 노릴 때, 마지막에 그 눈이 몇 개 나올지의 확률 (길이 6: 0~5개).
///
/// 지금 그 눈이 [have]개 있고, [rerollsLeft]번 더 굴릴 수 있다. 굴릴 때마다 그 눈이 아닌 주사위만 다시 굴린다고 본다
/// (그 칸 점수만 보면 가장 좋은 방법이다). 그 눈이 이미 나온 주사위는 줄어들지 않으니 [have]개 미만의 확률은 0이다.
List<double> yachtUpperOdds(int have, int rerollsLeft) => [for (final f in yachtUpperOddsFrac(have, rerollsLeft)) f.value];

/// [yachtUpperOdds]를 정확한 분수로 (약분됨). 분모는 6의 (5 × 굴리는 횟수)제곱을 넘지 않는다.
List<YachtFrac> yachtUpperOddsFrac(int have, int rerollsLeft) {
  // 분모를 6^(5×횟수)로 고정해 정수로 센다 (한 번 굴릴 때마다 6^5를 곱해 가며 더한다)
  var ways = List<int>.filled(6, 0)..[have.clamp(0, 5)] = 1;
  var den = 1;
  for (var round = 0; round < rerollsLeft; round++) {
    final next = List<int>.filled(6, 0);
    for (var k = 0; k <= 5; k++) {
      if (ways[k] == 0) continue;
      final n = 5 - k; // 다시 굴리는 주사위 수
      for (var j = 0; j <= n; j++) {
        // n개 중 j개가 그 눈: C(n,j) × 5^(n-j) 가지 / 6^n  →  6^5 분모로 맞추면 × 6^(5-n)
        next[k + j] += ways[k] * _choose(n, j) * _pow(5, n - j) * _pow(6, 5 - n);
      }
    }
    ways = next;
    den *= 7776;
  }
  return [for (final w in ways) YachtFrac(w, den)];
}

int _pow(int x, int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= x;
  }
  return r;
}

int _choose(int n, int k) {
  var r = 1;
  for (var i = 1; i <= k; i++) {
    r = r * (n - k + i) ~/ i;
  }
  return r;
}
