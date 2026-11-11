// 야추 확률 계산의 바탕: 주사위 5개의 모든 경우와, 한 차례(최대 3번 굴림)를
// 가장 좋게 푸는 계산. 화면 없이 쓰는 순수 Dart.
//
// "남긴 주사위"는 눈별 개수(합이 0~5)로 나타내고 462가지에 번호를 붙인다.
// 그중 합이 5인 252가지가 "굴린 결과"다.
import 'dart:typed_data';

import 'yacht_rules.dart';

class YachtDiceTables {
  YachtDiceTables._() {
    _build();
  }

  static final YachtDiceTables instance = YachtDiceTables._();

  /// 남긴 주사위의 가짓수 (0~5개).
  static const int keepCount = 462;

  /// 번호 → 눈별 개수.
  final List<List<int>> counts = [];

  /// 번호 → 주사위 개수.
  final Uint8List size = Uint8List(keepCount);

  /// 굴린 결과(주사위 5개)인 번호들. 252개.
  final List<int> rolls = [];

  /// 하나도 안 남긴 경우의 번호.
  int empty = 0;

  /// 번호 k를 남기고 나머지를 굴렸을 때 나오는 결과들:
  /// outTo[i], outP[i] (i = outStart[k] .. outStart[k + 1] - 1).
  final Int32List outStart = Int32List(keepCount + 1);
  late final Int16List outTo;
  late final Float64List outP;

  /// 굴린 결과 r에서 남길 수 있는 경우들:
  /// subKeep[i] (i = subStart[r] .. subStart[r + 1] - 1). r 자신(모두 남김)도 들어 있다.
  final Int32List subStart = Int32List(keepCount + 1);
  late final Int16List subKeep;

  /// 굴린 결과 r을 c 칸에 적을 때의 점수: score[r * kYachtSlots + c.index].
  final Int16List score = Int16List(keepCount * kYachtSlots);

  final Int16List _byKey = Int16List(46656);

  static int _key(List<int> c) {
    var key = 0;
    for (var i = 5; i >= 0; i--) {
      key = key * 6 + c[i];
    }
    return key;
  }

  /// 눈별 개수의 번호.
  int indexOf(List<int> counts) => _byKey[_key(counts)];

  /// 주사위 눈 목록(1~6)의 번호.
  int indexOfDice(List<int> dice) => indexOf(yachtCounts(dice));

  void _build() {
    final cur = List<int>.filled(6, 0);
    void gen(int face, int left) {
      if (face == 6) {
        final idx = counts.length;
        counts.add(List<int>.of(cur));
        size[idx] = kYachtDice - left;
        _byKey[_key(cur)] = idx;
        if (left == 0) rolls.add(idx);
        if (left == kYachtDice) empty = idx;
        return;
      }
      for (var n = 0; n <= left; n++) {
        cur[face] = n;
        gen(face + 1, left - n);
      }
      cur[face] = 0;
    }

    gen(0, kYachtDice);

    const fact = [1, 1, 2, 6, 24, 120];
    const pow6 = [1, 6, 36, 216, 1296, 7776];
    final to = <int>[];
    final p = <double>[];
    final sum = List<int>.filled(6, 0);
    for (var k = 0; k < keepCount; k++) {
      outStart[k] = to.length;
      final n = kYachtDice - size[k];
      for (var a = 0; a < keepCount; a++) {
        if (size[a] != n) continue;
        var ways = fact[n];
        for (var i = 0; i < 6; i++) {
          ways ~/= fact[counts[a][i]];
          sum[i] = counts[k][i] + counts[a][i];
        }
        to.add(indexOf(sum));
        p.add(ways / pow6[n]);
      }
    }
    outStart[keepCount] = to.length;
    outTo = Int16List.fromList(to);
    outP = Float64List.fromList(p);

    final subs = <int>[];
    for (var r = 0; r < keepCount; r++) {
      subStart[r] = subs.length;
      if (size[r] != kYachtDice) continue;
      for (var k = 0; k < keepCount; k++) {
        var inside = true;
        for (var i = 0; i < 6; i++) {
          if (counts[k][i] > counts[r][i]) {
            inside = false;
            break;
          }
        }
        if (inside) subs.add(k);
      }
      for (final c in YachtCategory.values) {
        score[r * kYachtSlots + c.index] = yachtScore(c, counts[r]);
      }
    }
    subStart[keepCount] = subs.length;
    subKeep = Int16List.fromList(subs);
  }
}

/// 한 차례를 가장 좋게 굴렸을 때의 값.
///
/// [solve]에 "마지막 주사위가 r일 때의 값"을 주면 아래가 채워진다.
/// - `w[n][r]`: 주사위가 r이고 다시 굴릴 기회가 n번 남았을 때 가장 좋은 값 (n = 0, 1, 2)
/// - `kv[n][k]`: k를 남기고 나머지를 굴리는 선택의 값. 굴린 뒤에 기회가 n번 남는다 (n = 0, 1)
/// - [start]: 아직 한 번도 안 굴렸을 때의 값
class YachtTurn {
  final List<Float64List> w = [
    for (var i = 0; i < 3; i++) Float64List(YachtDiceTables.keepCount),
  ];
  final List<Float64List> kv = [
    for (var i = 0; i < 2; i++) Float64List(YachtDiceTables.keepCount),
  ];
  double start = 0;

  void solve(Float64List terminal) {
    final t = YachtDiceTables.instance;
    final outStart = t.outStart;
    final outTo = t.outTo;
    final outP = t.outP;
    final subStart = t.subStart;
    final subKeep = t.subKeep;
    final rolls = t.rolls;
    w[0].setAll(0, terminal);
    for (var n = 0; n < 2; n++) {
      final src = w[n];
      final keepValue = kv[n];
      for (var k = 0; k < YachtDiceTables.keepCount; k++) {
        var sum = 0.0;
        final end = outStart[k + 1];
        for (var i = outStart[k]; i < end; i++) {
          sum += outP[i] * src[outTo[i]];
        }
        keepValue[k] = sum;
      }
      final dst = w[n + 1];
      for (final r in rolls) {
        var best = double.negativeInfinity;
        final end = subStart[r + 1];
        for (var i = subStart[r]; i < end; i++) {
          final v = keepValue[subKeep[i]];
          if (v > best) best = v;
        }
        dst[r] = best;
      }
    }
    var sum = 0.0;
    final src = w[2];
    final end = outStart[t.empty + 1];
    for (var i = outStart[t.empty]; i < end; i++) {
      sum += outP[i] * src[outTo[i]];
    }
    start = sum;
  }
}
