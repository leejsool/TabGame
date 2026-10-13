/// 겟 컬러(물병 색 모으기) 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 병마다 물(색 칸)이 아래에서 위로 쌓여 있고, 한 병에는 최대 [kBottleCapacity]칸이 들어간다.
/// 병의 맨 위 색을 다른 병으로 부어서, 한 병에 한 가지 색만 가득 차게 모으면 이긴다.
library;

import 'dart:math';

/// 병 하나에 들어가는 칸 수.
const int kBottleCapacity = 4;

/// 색마다 칸 수는 병 하나를 가득 채우는 만큼 (= [kBottleCapacity]).
enum GcLevel {
  easy('쉬움', '4가지 색', 4, 2),
  normal('보통', '6가지 색', 6, 2),
  hard('어려움', '8가지 색', 8, 2),
  master('달인', '12가지 색', 12, 2);

  const GcLevel(this.label, this.description, this.colors, this.empties);

  final String label;
  final String description;

  /// 색 가짓수.
  final int colors;

  /// 처음에 비어 있는 병 수.
  final int empties;

  int get bottles => colors + empties;
}

/// 한 수: [from] 병의 맨 위 물을 [to] 병으로 붓는다.
class GcMove {
  const GcMove(this.from, this.to);

  final int from;
  final int to;

  /// 저장용 숫자 (병은 16개 미만).
  int get code => from * 16 + to;

  static GcMove fromCode(int code) => GcMove(code ~/ 16, code % 16);

  @override
  bool operator ==(Object other) => other is GcMove && other.from == from && other.to == to;

  @override
  int get hashCode => from * 31 + to;

  @override
  String toString() => 'GcMove($from→$to)';
}

class WaterState {
  WaterState(this.bottles);

  /// 처음 판을 섞어서 만든다 (아직 풀 수 있는지는 확인하지 않는다). 풀 수 있는 판은 solver 가 걸러 준다.
  factory WaterState.shuffled(GcLevel level, Random rng) {
    for (var attempt = 0; attempt < 50; attempt++) {
      final units = <int>[
        for (var c = 0; c < level.colors; c++) ...List.filled(kBottleCapacity, c),
      ]..shuffle(rng);
      final bottles = <List<int>>[
        for (var b = 0; b < level.colors; b++)
          units.sublist(b * kBottleCapacity, (b + 1) * kBottleCapacity),
        for (var e = 0; e < level.empties; e++) <int>[],
      ];
      final s = WaterState(bottles);
      // 처음부터 한 가지 색으로 찬 병이 없고, 같은 색이 너무 뭉쳐 있지 않은 판만
      if (!bottles.any((b) => b.length == kBottleCapacity && b.every((c) => c == b.first)) &&
          s.blockCount > level.colors * 2.2) {
        return s;
      }
    }
    final units = <int>[
      for (var c = 0; c < level.colors; c++) ...List.filled(kBottleCapacity, c),
    ]..shuffle(rng);
    return WaterState([
      for (var b = 0; b < level.colors; b++) units.sublist(b * kBottleCapacity, (b + 1) * kBottleCapacity),
      for (var e = 0; e < level.empties; e++) <int>[],
    ]);
  }

  /// 병마다 아래에서 위로 쌓인 색 번호들.
  final List<List<int>> bottles;

  int get count => bottles.length;

  WaterState copy() => WaterState([for (final b in bottles) List<int>.of(b)]);

  bool isEmpty(int i) => bottles[i].isEmpty;
  bool isFull(int i) => bottles[i].length >= kBottleCapacity;

  int? topColor(int i) => bottles[i].isEmpty ? null : bottles[i].last;

  /// 맨 위에서부터 같은 색이 이어진 칸 수.
  int topRun(int i) {
    final b = bottles[i];
    if (b.isEmpty) return 0;
    var n = 1;
    while (n < b.length && b[b.length - 1 - n] == b.last) {
      n++;
    }
    return n;
  }

  /// 한 가지 색만 담긴 병인가 (빈 병은 아님).
  bool isUniform(int i) => bottles[i].isNotEmpty && topRun(i) == bottles[i].length;

  /// 한 가지 색으로 가득 찬 병 (끝난 병).
  bool isDone(int i) => isFull(i) && isUniform(i);

  bool get isSolved {
    for (var i = 0; i < count; i++) {
      if (!isEmpty(i) && !isDone(i)) return false;
    }
    return true;
  }

  /// 색이 바뀌는 덩어리(연속된 같은 색)의 총 개수. 풀릴수록 줄어든다.
  int get blockCount {
    var n = 0;
    for (final b in bottles) {
      for (var k = 0; k < b.length; k++) {
        if (k == 0 || b[k] != b[k - 1]) n++;
      }
    }
    return n;
  }

  bool canPour(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) return false;
    if (isEmpty(from) || isFull(to)) return false;
    return isEmpty(to) || topColor(to) == topColor(from);
  }

  /// 붓는 칸 수: 맨 위 같은 색 덩어리 중 받는 병에 들어갈 만큼.
  int pourAmount(int from, int to) {
    if (!canPour(from, to)) return 0;
    final room = kBottleCapacity - bottles[to].length;
    final run = topRun(from);
    return run < room ? run : room;
  }

  /// 붓는다. 합법이 아니면 0을 돌려주고 아무것도 하지 않는다. 옮긴 칸 수를 돌려준다.
  int pour(int from, int to) {
    final n = pourAmount(from, to);
    for (var k = 0; k < n; k++) {
      bottles[to].add(bottles[from].removeLast());
    }
    return n;
  }

  List<GcMove> legalMoves() => [
        for (var i = 0; i < count; i++)
          for (var j = 0; j < count; j++)
            if (canPour(i, j)) GcMove(i, j),
      ];

  /// 빈 병 하나를 더한다 (도움 기능).
  void addEmptyBottle() => bottles.add(<int>[]);

  /// 상태를 나타내는 문자열 (병 순서가 달라도 같은 상태면 같은 문자열).
  String get key {
    final parts = [for (final b in bottles) String.fromCharCodes([for (final c in b) 65 + c])]..sort();
    return parts.join('|');
  }
}
