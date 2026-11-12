// 대성One Rule의 주사위 경우들: 보통 주사위 4개(서로 같은 주사위) + 대성One 주사위 1개(따로 센다).
// 기본 규칙의 [YachtDiceTables]와 같은 모양이라 한 차례 계산([YachtTurn])을 그대로 쓴다. 화면 없이 쓰는 순수 Dart.
//
// 남긴 주사위 = (보통 주사위의 눈별 개수 0~4개, 대성One 상태 g). g = 0이면 대성One을 남기지 않음, 1~6이면 그 눈으로 남김.
// 번호 = 보통 번호 x 7 + g. 굴린 결과는 보통 주사위 4개 + 대성One 눈(1~6)이 모두 정해진 것.
import 'dart:typed_data';

import 'yacht_daesung.dart';
import 'yacht_dice.dart';
import 'yacht_rules.dart';

class YachtDaesungTables implements YachtDiceSpace {
  YachtDaesungTables._() {
    _build();
  }

  static final YachtDaesungTables instance = YachtDaesungTables._();

  /// 보통 주사위 수.
  static const int others = kYachtDice - 1;

  /// 보통 주사위(0~4개)의 눈별 개수 가짓수.
  static const int normCount = 210;

  @override
  int get keeps => normCount * 7;

  /// 보통 번호 → 눈별 개수 · 개수.
  final List<List<int>> norms = [];
  final Uint8List normSize = Uint8List(normCount);
  final Int16List _normByKey = Int16List(15625); // 5^6

  @override
  final List<int> rolls = [];
  @override
  int empty = 0;
  @override
  final Int32List outStart = Int32List(normCount * 7 + 1);
  @override
  late final Int16List outTo;
  @override
  late final Float64List outP;
  @override
  final Int32List subStart = Int32List(normCount * 7 + 1);
  @override
  late final Int16List subKeep;

  /// 굴린 결과 r을 c 칸에 적을 때의 점수: score[r * kYachtSlots + c.index].
  final Int16List score = Int16List(normCount * 7 * kYachtSlots);

  static int _key(List<int> c) {
    var key = 0;
    for (var i = 5; i >= 0; i--) {
      key = key * 5 + c[i];
    }
    return key;
  }

  int normIndex(List<int> counts) => _normByKey[_key(counts)];

  /// 남긴 주사위의 번호.
  int keepIndex(int norm, int green) => norm * 7 + green;

  int normOf(int keep) => keep ~/ 7;
  int greenOf(int keep) => keep % 7;

  /// 주사위 눈 5개(0번이 대성One)의 번호.
  int indexOfDice(List<int> dice) {
    final counts = List<int>.filled(6, 0);
    for (var i = 0; i < dice.length; i++) {
      if (i != kDaesungDie) counts[dice[i] - 1]++;
    }
    return keepIndex(normIndex(counts), dice[kDaesungDie]);
  }

  /// 남긴 주사위의 개수 (대성One 포함).
  int sizeOf(int keep) => normSize[normOf(keep)] + (greenOf(keep) > 0 ? 1 : 0);

  void _build() {
    final cur = List<int>.filled(6, 0);
    void gen(int face, int left) {
      if (face == 6) {
        final idx = norms.length;
        norms.add(List<int>.of(cur));
        normSize[idx] = others - left;
        _normByKey[_key(cur)] = idx;
        return;
      }
      for (var n = 0; n <= left; n++) {
        cur[face] = n;
        gen(face + 1, left - n);
      }
      cur[face] = 0;
    }

    gen(0, others);
    assert(norms.length == normCount);
    empty = keepIndex(normIndex(List<int>.filled(6, 0)), 0);
    for (var n = 0; n < normCount; n++) {
      if (normSize[n] != others) continue;
      for (var g = 1; g <= 6; g++) {
        rolls.add(keepIndex(n, g));
      }
    }

    const fact = [1, 1, 2, 6, 24];
    const pow6 = [1, 6, 36, 216, 1296];
    final to = <int>[];
    final p = <double>[];
    final sum = List<int>.filled(6, 0);
    for (var k = 0; k < keeps; k++) {
      outStart[k] = to.length;
      final n = normOf(k), g = greenOf(k);
      final m = others - normSize[n];
      for (var a = 0; a < normCount; a++) {
        if (normSize[a] != m) continue;
        var ways = fact[m];
        for (var i = 0; i < 6; i++) {
          ways ~/= fact[norms[a][i]];
          sum[i] = norms[n][i] + norms[a][i];
        }
        final base = ways / pow6[m];
        final next = normIndex(sum);
        if (g > 0) {
          to.add(keepIndex(next, g));
          p.add(base);
        } else {
          for (var gv = 1; gv <= 6; gv++) {
            to.add(keepIndex(next, gv));
            p.add(base / 6);
          }
        }
      }
    }
    outStart[keeps] = to.length;
    outTo = Int16List.fromList(to);
    outP = Float64List.fromList(p);

    final subs = <int>[];
    final rollSet = rolls.toSet();
    for (var r = 0; r < keeps; r++) {
      subStart[r] = subs.length;
      if (!rollSet.contains(r)) continue;
      final rn = normOf(r), rg = greenOf(r);
      for (var k = 0; k < normCount; k++) {
        var inside = true;
        for (var i = 0; i < 6; i++) {
          if (norms[k][i] > norms[rn][i]) {
            inside = false;
            break;
          }
        }
        if (!inside) continue;
        subs.add(keepIndex(k, 0));
        subs.add(keepIndex(k, rg));
      }
      for (final c in YachtCategory.values) {
        score[r * kYachtSlots + c.index] = daesungScoreParts(c, rg, norms[rn]);
      }
    }
    subStart[keeps] = subs.length;
    subKeep = Int16List.fromList(subs);
  }
}
