/// 겟 컬러 풀이기: 지금 판에서 끝까지 풀 수 있는지 따져 본다.
///
/// - 푸는 수순을 찾으면 [GcVerdict.winnable] + 그 수순 (첫 수가 힌트).
/// - 갈 수 있는 모든 상태를 다 봐도 못 풀면 [GcVerdict.lost] (이미 막힌 판이 확실함).
/// - 계산 한도를 넘기면 [GcVerdict.unknown].
///
/// 같은 상태(병 순서만 다른 것 포함)를 두 번 보지 않고, 색이 많이 모인 쪽부터 살펴본다.
/// 아무 의미 없는 수(이미 끝난 병을 건드리기, 한 가지 색뿐인 병을 빈 병으로 옮기기, 똑같은 빈 병 여러 개 중
/// 둘째부터 고르기)는 건너뛰는데, 이 셋은 결론을 바꾸지 않으므로 "막혔다"는 판정은 믿어도 된다.
library;

import 'dart:math';
import 'dart:typed_data';

import 'getcolor_rules.dart';

enum GcVerdict { winnable, lost, unknown }

class GcSolution {
  const GcSolution(this.verdict, {this.path = const [], this.nodes = 0});

  final GcVerdict verdict;

  /// 푸는 수순 (winnable일 때). 첫 수는 지금 상태에서 바로 둘 수 있는 수.
  final List<GcMove> path;
  final int nodes;

  GcMove? get firstMove => path.isEmpty ? null : path.first;
}

const int _empty = 255;
const int _cap = kBottleCapacity;

class _Node {
  _Node(this.cells, this.parent, this.move);

  /// 병 i 의 칸들은 cells[i*cap ..], 아래에서 위로. 빈 칸은 [_empty].
  final Uint8List cells;
  final int parent;
  final GcMove? move;
}

Uint8List _encode(WaterState s) {
  final cells = Uint8List(s.count * _cap)..fillRange(0, s.count * _cap, _empty);
  for (var i = 0; i < s.count; i++) {
    for (var k = 0; k < s.bottles[i].length; k++) {
      cells[i * _cap + k] = s.bottles[i][k];
    }
  }
  return cells;
}

String _keyOf(Uint8List cells, int nb) {
  final parts = <String>[
    for (var i = 0; i < nb; i++)
      String.fromCharCodes([
        for (var k = 0; k < _cap; k++)
          if (cells[i * _cap + k] != _empty) 65 + cells[i * _cap + k],
      ]),
  ]..sort();
  return parts.join('|');
}

/// 풀린 상태인가 + 아직 풀어야 할 정도(작을수록 가까움).
int _score(Uint8List cells, int nb) {
  var blocks = 0;
  final seen = <int>{};
  for (var i = 0; i < nb; i++) {
    var prev = -1;
    for (var k = 0; k < _cap; k++) {
      final c = cells[i * _cap + k];
      if (c == _empty) break;
      if (c != prev) blocks++;
      seen.add(c);
      prev = c;
    }
  }
  return blocks - seen.length;
}

bool _isSolved(Uint8List cells, int nb) {
  for (var i = 0; i < nb; i++) {
    final first = cells[i * _cap];
    if (first == _empty) continue;
    for (var k = 1; k < _cap; k++) {
      if (cells[i * _cap + k] != first) return false;
    }
  }
  return true;
}

/// 작은 최소 힙 (우선순위 * 2^24 + 번호 를 한 정수로).
class _Heap {
  final List<int> _a = [];
  static const int _base = 16777216;

  bool get isEmpty => _a.isEmpty;

  void push(int priority, int id) {
    _a.add(priority * _base + id);
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_a[p] <= _a[i]) break;
      final t = _a[p];
      _a[p] = _a[i];
      _a[i] = t;
      i = p;
    }
  }

  int pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _a.length && _a[l] < _a[m]) m = l;
        if (r < _a.length && _a[r] < _a[m]) m = r;
        if (m == i) break;
        final t = _a[m];
        _a[m] = _a[i];
        _a[i] = t;
        i = m;
      }
    }
    return top % _base;
  }
}

/// [start]를 (건드리지 않고) 풀어 본다. 중간에 [cancelled]가 true가 되면 멈추고 unknown.
Future<GcSolution> solveWater(
  WaterState start, {
  int maxNodes = 120000,
  bool Function()? cancelled,
}) async {
  final nb = start.count;
  final root = _Node(_encode(start), -1, null);
  if (_isSolved(root.cells, nb)) return const GcSolution(GcVerdict.winnable);

  final nodes = <_Node>[root];
  final depth = <int>[0];
  final visited = <String>{_keyOf(root.cells, nb)};
  final heap = _Heap()..push(_score(root.cells, nb) * 4, 0);

  final len = List<int>.filled(nb, 0);
  final top = List<int>.filled(nb, 0);
  final run = List<int>.filled(nb, 0);
  final uniform = List<bool>.filled(nb, false);
  var expanded = 0;

  while (!heap.isEmpty) {
    final id = heap.pop();
    final node = nodes[id];
    expanded++;
    if (expanded % 2000 == 0) {
      await Future<void>.delayed(Duration.zero); // 화면이 멈추지 않도록 가끔 숨을 돌린다
      if (cancelled != null && cancelled()) return GcSolution(GcVerdict.unknown, nodes: expanded);
    }
    if (expanded > maxNodes) return GcSolution(GcVerdict.unknown, nodes: expanded);

    var firstEmpty = -1;
    for (var i = 0; i < nb; i++) {
      var n = 0;
      while (n < _cap && node.cells[i * _cap + n] != _empty) {
        n++;
      }
      len[i] = n;
      if (n == 0) {
        if (firstEmpty < 0) firstEmpty = i;
        top[i] = -1;
        run[i] = 0;
        uniform[i] = false;
        continue;
      }
      top[i] = node.cells[i * _cap + n - 1];
      var r = 1;
      while (r < n && node.cells[i * _cap + n - 1 - r] == top[i]) {
        r++;
      }
      run[i] = r;
      uniform[i] = r == n;
    }

    for (var i = 0; i < nb; i++) {
      if (len[i] == 0) continue;
      if (len[i] == _cap && uniform[i]) continue; // 이미 끝난 병
      for (var j = 0; j < nb; j++) {
        if (i == j || len[j] == _cap) continue;
        if (len[j] == 0) {
          if (j != firstEmpty || uniform[i]) continue; // 똑같은 빈 병은 하나만 / 한 색뿐인 병을 옮겨 봐야 그대로
        } else if (top[j] != top[i]) {
          continue;
        }
        if (run[i] > _cap - len[j]) continue; // 같은 색 덩어리가 통째로 들어갈 자리가 있어야 한다
        final amount = run[i];
        final cells = Uint8List.fromList(node.cells);
        for (var k = 0; k < amount; k++) {
          cells[j * _cap + len[j] + k] = top[i];
          cells[i * _cap + len[i] - 1 - k] = _empty;
        }
        final move = GcMove(i, j);
        if (_isSolved(cells, nb)) {
          final path = <GcMove>[move];
          for (var at = id; nodes[at].parent >= 0; at = nodes[at].parent) {
            path.add(nodes[at].move!);
          }
          return GcSolution(GcVerdict.winnable, path: path.reversed.toList(), nodes: expanded);
        }
        if (!visited.add(_keyOf(cells, nb))) continue;
        nodes.add(_Node(cells, id, move));
        depth.add(depth[id] + 1);
        heap.push(_score(cells, nb) * 4 + depth[id] + 1, nodes.length - 1);
      }
    }
  }
  return GcSolution(GcVerdict.lost, nodes: expanded);
}

/// 후보를 여럿 섞어 풀어 보고, 풀리는 판 중 풀이기가 가장 많은 상태를 살펴야 했던 판(= 가장 어려운 판)을 고른다.
/// 풀이 속도(상태 수)는 사람에게도 "막다른 길에 빠지기 쉬운 정도"와 잘 맞아서 난이도의 잣대로 쓴다.
Future<WaterState?> _hardestOf(GcLevel level, Random rng) async {
  WaterState? best;
  var bestNodes = -1;
  for (var t = 0; t < level.candidates; t++) {
    final s = WaterState.shuffled(level, rng);
    final r = await solveWater(s, maxNodes: 60000);
    if (r.verdict != GcVerdict.winnable) continue;
    if (r.nodes > bestNodes) {
      best = s;
      bestNodes = r.nodes;
    }
  }
  return best;
}

/// 풀 수 있는 새 판을 만든다. 섞고 → 풀어 보고 → 안 풀리면 다시 섞는다.
/// 후보가 여럿인 난이도([GcLevel.candidates])는 그 중 가장 어려운 판을 낸다.
/// 끝내 확인하지 못해도 마지막으로 섞은 판을 돌려준다 (도움 기능으로 풀 수 있다).
Future<WaterState> generateWaterPuzzle(GcLevel level, Random rng, {int maxTries = 30}) async {
  if (level.candidates > 1) {
    final hardest = await _hardestOf(level, rng);
    if (hardest != null) return hardest;
  }
  WaterState? last;
  for (var t = 0; t < maxTries; t++) {
    final s = WaterState.shuffled(level, rng);
    last = s;
    final r = await solveWater(s, maxNodes: 30000);
    if (r.verdict == GcVerdict.winnable) return s;
  }
  return last!;
}
