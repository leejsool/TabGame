import 'dart:typed_data';

import 'rummikub_rules.dart';

/// 올바르지 않은 묶음을 올바른 묶음들로 쪼갠 결과.
class MeldSplit {
  const MeldSplit(this.melds, this.leftover);

  /// 쪼개서 나온 올바른 묶음들.
  final List<List<int>> melds;

  /// 어느 묶음에도 못 든 타일들 ([splitIntoMelds]의 `removable`에 든 것만 남을 수 있다).
  final List<int> leftover;
}

/// 묶음 하나를 쪼갤 수 있는 최대 타일 수 (더 크면 계산이 너무 오래 걸려서 포기한다).
const int kMaxSplitTiles = 14;

/// [tiles]를 올바른 묶음 여러 개로 쪼갠다. 예: 1-2-3-5-6-7 → 1-2-3 과 5-6-7.
///
/// [removable]에 든 타일은 어느 묶음에도 못 들면 [MeldSplit.leftover]로 빼 둘 수 있다 (남는 타일이 가장 적게, 그다음 묶음이 가장 적게).
/// 그렇게 해도 안 되거나 타일이 너무 많으면 null.
MeldSplit? splitIntoMelds(List<int> tiles, {Set<int> removable = const {}}) {
  final n = tiles.length;
  if (n == 0 || n > kMaxSplitTiles) return null;
  final full = (1 << n) - 1;
  var removableBits = 0;
  for (var i = 0; i < n; i++) {
    if (removable.contains(tiles[i])) removableBits |= 1 << i;
  }

  final valid = Uint8List(1 << n); // 0 모름, 1 올바른 묶음, 2 아님
  bool isValid(int mask) {
    var v = valid[mask];
    if (v == 0) {
      final picked = [for (var i = 0; i < n; i++) if ((mask >> i) & 1 == 1) tiles[i]];
      v = analyzeMeld(picked) != null ? 1 : 2;
      valid[mask] = v;
    }
    return v == 1;
  }

  const impossible = 1 << 30;
  const leftoverCost = 100; // (묶음 수보다 훨씬 커서, 남는 타일을 먼저 줄이고 그다음에 묶음 수를 줄인다)
  final cost = List<int>.filled(1 << n, -1);
  final pick = List<int>.filled(1 << n, 0); // 고른 묶음 (0이면 가장 낮은 타일을 남긴다)

  int solve(int mask) {
    if (mask == 0) return 0;
    if (cost[mask] >= 0) return cost[mask];
    final low = mask & -mask;
    final rest = mask ^ low;
    var best = impossible, bestPick = 0;
    if (removableBits & low != 0) {
      final sub = solve(rest);
      if (sub < impossible) best = sub + leftoverCost;
    }
    var s = rest;
    while (true) {
      final m = s | low;
      if (isValid(m)) {
        final sub = solve(mask ^ m);
        if (sub < impossible && sub + 1 < best) {
          best = sub + 1;
          bestPick = m;
        }
      }
      if (s == 0) break;
      s = (s - 1) & rest;
    }
    cost[mask] = best;
    pick[mask] = bestPick;
    return best;
  }

  if (solve(full) >= impossible) return null;
  final melds = <List<int>>[];
  final leftover = <int>[];
  var mask = full;
  while (mask != 0) {
    final m = pick[mask];
    if (m == 0) {
      final low = mask & -mask;
      leftover.add(tiles[low.bitLength - 1]);
      mask ^= low;
    } else {
      melds.add([for (var i = 0; i < n; i++) if ((m >> i) & 1 == 1) tiles[i]]);
      mask ^= m;
    }
  }
  return MeldSplit(melds, leftover);
}
