/// 민들레 게임의 규칙 (책 '아주 이상한 수학책' 4장).
///
/// 5×5 초원에서 민들레(꽃을 심는 쪽)와 바람(씨앗을 날리는 쪽)이 번갈아 둔다.
/// 민들레가 먼저 꽃을 심고, 바람이 한 방향을 고르면 모든 꽃에서 그 방향으로 씨앗이 날아가
/// 빈칸을 채운다. 바람은 8방향 가운데 7방향만 불 수 있고, 일곱 번째 바람이 끝났을 때
/// 초원이 꽉 차 있으면 민들레, 한 칸이라도 비어 있으면 바람이 이긴다.
library;

const int kSize = 5;
const int kWindTurns = 7;

/// 칸의 상태.
const int kEmpty = 0;
const int kSeed = 1;
const int kFlower = 2;

enum Role {
  dandelion('민들레'),
  wind('바람');

  const Role(this.label);
  final String label;

  Role get other => this == dandelion ? wind : dandelion;
}

/// 바람이 부는 방향 (씨앗이 날아가는 쪽). 위에서부터 시계 방향.
enum WindDir {
  up('위', -1, 0),
  upRight('오른쪽 위', -1, 1),
  right('오른쪽', 0, 1),
  downRight('오른쪽 아래', 1, 1),
  down('아래', 1, 0),
  downLeft('왼쪽 아래', 1, -1),
  left('왼쪽', 0, -1),
  upLeft('왼쪽 위', -1, -1);

  const WindDir(this.label, this.dRow, this.dCol);
  final String label;
  final int dRow;
  final int dCol;
}

/// 바람 한 번에 새로 생긴 씨앗 하나: 어느 꽃에서([from]), 몇 칸 날아가([dist]), 어느 칸에([cell]) 앉았는가.
class Seeding {
  const Seeding(this.cell, this.from, this.dist);

  final int cell;
  final int from;
  final int dist;
}

class DandState {
  DandState() : cells = List<int>.filled(kSize * kSize, kEmpty);

  DandState._(this.cells, this.usedWinds, this.windCount, this.plies);

  /// 칸마다 [kEmpty] / [kSeed] / [kFlower].
  final List<int> cells;

  /// 이미 분 방향 (WindDir.index 비트).
  int usedWinds = 0;
  int windCount = 0;

  /// 지금까지 둔 수 (민들레·바람 합쳐서).
  int plies = 0;

  DandState copy() => DandState._(List<int>.of(cells), usedWinds, windCount, plies);

  /// 민들레가 먼저, 번갈아.
  Role get turn => plies.isEven ? Role.dandelion : Role.wind;

  int get emptyCount {
    var n = 0;
    for (final c in cells) {
      if (c == kEmpty) n++;
    }
    return n;
  }

  int get flowerCount => cells.where((c) => c == kFlower).length;

  /// 앞으로 남은 바람 횟수.
  int get windsLeft => kWindTurns - windCount;

  /// 초원이 꽉 차면 (바람이 남아 있어도) 민들레의 승리로 바로 끝난다.
  bool get isOver => windCount >= kWindTurns || (plies > 0 && emptyCount == 0);

  Role? get winner => !isOver ? null : (emptyCount == 0 ? Role.dandelion : Role.wind);

  bool windUsed(WindDir d) => usedWinds & (1 << d.index) != 0;

  bool canPlant(int cell) => !isOver && turn == Role.dandelion && cells[cell] != kFlower;

  bool canBlow(WindDir d) => !isOver && turn == Role.wind && !windUsed(d);

  /// 지금 둘 수 있는 수. 민들레 차례면 칸 번호들, 바람 차례면 WindDir.index들.
  List<int> legalMoves() {
    if (isOver) return const [];
    if (turn == Role.dandelion) {
      return [for (var i = 0; i < cells.length; i++) if (cells[i] != kFlower) i];
    }
    return [for (final d in WindDir.values) if (!windUsed(d)) d.index];
  }

  /// 칸 [cell]에 꽃을 심는다 (빈칸 또는 씨앗 위).
  void plant(int cell) {
    assert(canPlant(cell));
    cells[cell] = kFlower;
    plies++;
  }

  /// 바람 [d]가 분다. 모든 꽃에서 그 방향의 빈칸이 씨앗이 된다. 새로 생긴 씨앗을 가까운 순서로 돌려준다.
  List<Seeding> blow(WindDir d) {
    assert(canBlow(d));
    final out = _spread(d);
    usedWinds |= 1 << d.index;
    windCount++;
    plies++;
    return out;
  }

  List<Seeding> _spread(WindDir d) {
    final out = <Seeding>[];
    final flowers = [for (var i = 0; i < cells.length; i++) if (cells[i] == kFlower) i];
    for (final f in flowers) {
      var r = f ~/ kSize + d.dRow, c = f % kSize + d.dCol, dist = 1;
      while (r >= 0 && r < kSize && c >= 0 && c < kSize) {
        final i = r * kSize + c;
        if (cells[i] == kEmpty) {
          cells[i] = kSeed;
          out.add(Seeding(i, f, dist));
        }
        r += d.dRow;
        c += d.dCol;
        dist++;
      }
    }
    out.sort((a, b) => a.dist.compareTo(b.dist));
    return out;
  }

  /// 차례에 맞는 수를 둔다 ([legalMoves]의 수).
  void apply(int move) {
    if (turn == Role.dandelion) {
      plant(move);
    } else {
      blow(WindDir.values[move]);
    }
  }

  /// 수 목록으로 판을 되살린다.
  static DandState fromMoves(Iterable<int> moves) {
    final s = DandState();
    for (final m in moves) {
      s.apply(m);
    }
    return s;
  }

  /// 꽃이 [flowers]에 있을 때 [winds]를 차례로 불면 어떻게 되는지 (교과학습·계산용: 차례는 따지지 않는다).
  static List<int> sow(Iterable<int> flowers, Iterable<WindDir> winds) {
    final s = DandState();
    for (final f in flowers) {
      s.cells[f] = kFlower;
    }
    for (final d in winds) {
      s._spread(d);
    }
    return s.cells;
  }

  /// 빈칸마다 "아직 안 분 방향 가운데, 지금 있는 꽃에서 그 칸으로 씨앗이 닿는 방향"의 비트(WindDir.index)들.
  /// 빈칸이 아니면 0.
  static List<int> reachMasks(List<int> cells, int usedWinds) {
    final out = List<int>.filled(cells.length, 0);
    for (var f = 0; f < cells.length; f++) {
      if (cells[f] != kFlower) continue;
      for (final d in WindDir.values) {
        if (usedWinds & (1 << d.index) != 0) continue;
        for (var k = 1;; k++) {
          final c = step(f, d, k);
          if (c < 0) break;
          if (cells[c] == kEmpty) out[c] |= 1 << d.index;
        }
      }
    }
    return out;
  }

  /// 앞으로 씨앗이 반드시 앉는 빈칸들.
  ///
  /// 바람은 남은 방향 가운데 딱 하나만 빼고 모두 불기 때문에, 지금 있는 꽃에서 두 가지 이상의
  /// 방향으로 닿는 칸은 바람이 어떤 방향을 빼도 결국 채워진다. (새 꽃은 따지지 않는다)
  static Set<int> guaranteed(List<int> cells, int usedWinds) {
    final masks = reachMasks(cells, usedWinds);
    return {
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == kEmpty && _bits(masks[i]) >= 2) i,
    };
  }

  static int _bits(int m) {
    var n = 0;
    while (m != 0) {
      m &= m - 1;
      n++;
    }
    return n;
  }

  /// [dir] 방향으로 [cell]에서 [dist]칸 떨어진 칸 (판 밖이면 -1).
  static int step(int cell, WindDir dir, int dist) {
    final r = cell ~/ kSize + dir.dRow * dist, c = cell % kSize + dir.dCol * dist;
    if (r < 0 || r >= kSize || c < 0 || c >= kSize) return -1;
    return r * kSize + c;
  }
}
