// 대성One Rule의 "기대 점수 표": 점수판 상태마다, 앞으로 가장 좋게 했을 때 더 얻을 점수의 평균.
//
// 상태 = (적은 칸의 비트 10개: [kDaesungCategories] 순서, 숫자 칸 합(55에서 멈춤)) → 1024 x 56 칸.
// 표는 `tool/make_yacht_table.dart`가 기본 규칙 표와 함께 미리 계산해 `assets/yacht/values_ds.bin`에 담는다.
import 'dart:typed_data';

import 'yacht_daesung.dart';
import 'yacht_daesung_dice.dart';
import 'yacht_dice.dart';
import 'yacht_rules.dart';

class YachtDaesungValues {
  YachtDaesungValues._(this._v);

  factory YachtDaesungValues.fromDoubles(Float64List src) => YachtDaesungValues._(Float32List.fromList(src));

  /// 파일(칸마다 2바이트, 값 x 100)에서.
  factory YachtDaesungValues.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final v = Float32List(length);
    for (var i = 0; i < length; i++) {
      v[i] = data.getUint16(i * 2, Endian.little) / 100;
    }
    return YachtDaesungValues._(v);
  }

  static const int slots = 10;
  static const int uppers = kDaesungBonusAt + 1;
  static const int length = (1 << slots) * uppers;

  final Float32List _v;

  /// 적은 칸이 [mask](10비트), 숫자 칸 합이 [upper]일 때 앞으로 더 얻을 점수의 평균.
  double at(int mask, int upper) => _v[mask * uppers + (upper > kDaesungBonusAt ? kDaesungBonusAt : upper)];

  Uint8List toBytes() {
    final data = ByteData(length * 2);
    for (var i = 0; i < length; i++) {
      data.setUint16(i * 2, (_v[i] * 100).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

/// 점수판의 적은 칸을 대성One 표의 10비트로 (i번 비트 = [kDaesungCategories]의 i번 칸).
int daesungMask(YachtCard card) {
  var mask = 0;
  for (var i = 0; i < kDaesungCategories.length; i++) {
    if (card.scores[kDaesungCategories[i].index] != null) mask |= 1 << i;
  }
  return mask;
}

/// 굴린 결과 [roll]을 i번 칸([kDaesungCategories])에 적을 때 "이번 점수 + 새로 받는 보너스 + 그 뒤의 기대 점수".
double daesungGain(double Function(int mask, int upper) at, int mask, int upper, int roll, int i) {
  final t = YachtDaesungTables.instance;
  final s = t.score[roll * kYachtSlots + kDaesungCategories[i].index];
  final next = mask | (1 << i);
  if (i >= 6) return s + at(next, upper);
  var nu = upper + s;
  if (nu > kDaesungBonusAt) nu = kDaesungBonusAt;
  final bonus = upper < kDaesungBonusAt && nu == kDaesungBonusAt ? kDaesungBonus : 0;
  return s + bonus + at(next, nu);
}

/// 기대 점수 표를 처음부터 계산한다.
Float64List buildDaesungValues({void Function(int mask)? onMask}) {
  final t = YachtDaesungTables.instance;
  final v = Float64List(YachtDaesungValues.length);
  double at(int mask, int upper) => v[mask * YachtDaesungValues.uppers + upper];
  final turn = YachtTurn(t);
  final terminal = Float64List(t.keeps);
  const all = (1 << YachtDaesungValues.slots) - 1;
  for (var mask = all - 1; mask >= 0; mask--) {
    onMask?.call(mask);
    final upperDone = (mask & 63) == 63;
    double? shared;
    for (var u = 0; u <= kDaesungBonusAt; u++) {
      if (upperDone && shared != null) {
        v[mask * YachtDaesungValues.uppers + u] = shared; // 숫자 칸이 다 찼으면 합은 더 상관없다
        continue;
      }
      for (final r in t.rolls) {
        var best = double.negativeInfinity;
        for (var i = 0; i < YachtDaesungValues.slots; i++) {
          if ((mask >> i) & 1 == 1) continue;
          final g = daesungGain(at, mask, u, r, i);
          if (g > best) best = g;
        }
        terminal[r] = best;
      }
      turn.solve(terminal);
      v[mask * YachtDaesungValues.uppers + u] = turn.start;
      if (upperDone) shared = turn.start;
    }
  }
  return v;
}
