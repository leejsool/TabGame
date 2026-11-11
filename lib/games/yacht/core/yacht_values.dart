// (야추 보너스 +100은 드물어서 이 표에는 넣지 않았다: 추천은 보너스를 빼고 계산한다.)
// 야추 "기대 점수 표": 점수판 상태마다, 앞으로 가장 좋게 했을 때 더 얻을 점수의 평균.
//
// 상태 = (적은 칸의 비트, 1~6 칸의 합(63에서 멈춤)) → 8192 x 64 칸 (13칸의 비트. 쓰리카드를 안 쓰는 판은 12번 비트가 처음부터 켜진 상태).
// 표는 `tool/make_yacht_table.dart`가 미리 계산해 `assets/yacht/values.bin`에 담는다
// (기기에서 매번 계산하기엔 오래 걸린다). 화면 없이 쓰는 순수 Dart.
import 'dart:typed_data';

import 'yacht_dice.dart';
import 'yacht_rules.dart';

class YachtValues {
  YachtValues._(this._v);

  /// [buildYachtValues]가 만든 값에서.
  factory YachtValues.fromDoubles(Float64List src) =>
      YachtValues._(Float32List.fromList(src));

  /// 파일(칸마다 2바이트, 값 x 100)에서.
  factory YachtValues.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final v = Float32List(length);
    for (var i = 0; i < length; i++) {
      v[i] = data.getUint16(i * 2, Endian.little) / 100;
    }
    return YachtValues._(v);
  }

  static const int length = (1 << kYachtSlots) * 64;

  final Float32List _v;

  /// 적은 칸이 [mask], 1~6 칸의 합이 [upper]일 때 앞으로 더 얻을 점수의 평균
  /// (나중에 받을 보너스 포함).
  double at(int mask, int upper) =>
      _v[mask * 64 + (upper > kYachtBonusAt ? kYachtBonusAt : upper)];

  Uint8List toBytes() {
    final data = ByteData(length * 2);
    for (var i = 0; i < length; i++) {
      data.setUint16(i * 2, (_v[i] * 100).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

/// 굴린 결과 [roll]을 [c] 칸에 적을 때 "이번에 받는 점수 + 새로 받는 보너스 + 그 뒤의 기대 점수".
/// [at]은 (mask, upper) → 기대 점수.
double _gain(
  YachtDiceTables t,
  double Function(int mask, int upper) at,
  int mask,
  int upper,
  int roll,
  int c,
) {
  final s = t.score[roll * kYachtSlots + c];
  final next = mask | (1 << c);
  if (c >= 6) return s + at(next, upper);
  var nu = upper + s;
  if (nu > kYachtBonusAt) nu = kYachtBonusAt;
  final bonus = upper < kYachtBonusAt && nu == kYachtBonusAt ? kYachtBonus : 0;
  return s + bonus + at(next, nu);
}

/// 표 [values]로 계산한 [_gain].
double yachtGain(YachtValues values, int mask, int upper, int roll, int c) =>
    _gain(YachtDiceTables.instance, values.at, mask, upper, roll, c);

/// 기대 점수 표를 처음부터 계산한다 (전체는 수십 초).
///
/// [minFilled]를 주면 적은 칸이 그 개수 이상인 상태만 계산한다 (시험용: 끝판만 빠르게).
/// 실제 게임에서 나올 수 없는 (칸, 합) 조합은 0으로 남는다.
Float64List buildYachtValues({int minFilled = 0, void Function(int mask)? onMask}) {
  final t = YachtDiceTables.instance;
  final v = Float64List(YachtValues.length);
  double at(int mask, int upper) => v[mask * 64 + upper];
  final turn = YachtTurn();
  final terminal = Float64List(YachtDiceTables.keepCount);

  for (var mask = (1 << kYachtSlots) - 2; mask >= 0; mask--) {
    var filled = 0;
    for (var i = 0; i < kYachtSlots; i++) {
      filled += (mask >> i) & 1;
    }
    if (filled < minFilled) continue;
    onMask?.call(mask);
    final reach = _reachableUppers(mask & 63);
    final upperDone = (mask & 63) == 63;
    double? shared;
    for (var u = 0; u <= kYachtBonusAt; u++) {
      if (!reach[u]) continue;
      if (upperDone && shared != null) {
        v[mask * 64 + u] = shared; // 1~6 칸이 다 찼으면 합은 더 상관없다
        continue;
      }
      for (final r in t.rolls) {
        var best = double.negativeInfinity;
        for (var c = 0; c < kYachtSlots; c++) {
          if ((mask >> c) & 1 == 1) continue;
          final g = _gain(t, at, mask, u, r, c);
          if (g > best) best = g;
        }
        terminal[r] = best;
      }
      turn.solve(terminal);
      v[mask * 64 + u] = turn.start;
      if (upperDone) shared = turn.start;
    }
  }
  return v;
}

/// 1~6 칸 중 [upperMask]에 적었을 때 나올 수 있는 합들 (63 이상은 63).
List<bool> _reachableUppers(int upperMask) {
  var sums = <int>{0};
  for (var face = 1; face <= 6; face++) {
    if ((upperMask >> (face - 1)) & 1 == 0) continue;
    final next = <int>{};
    for (final s in sums) {
      for (var n = 0; n <= kYachtDice; n++) {
        final total = s + n * face;
        next.add(total > kYachtBonusAt ? kYachtBonusAt : total);
      }
    }
    sums = next;
  }
  final reach = List<bool>.filled(kYachtBonusAt + 1, false);
  for (final s in sums) {
    reach[s] = true;
  }
  return reach;
}
