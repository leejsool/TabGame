import 'dart:math' as math;
import 'dart:typed_data';

import 'freecell_rules.dart';

/// 한 판을 풀면서 잰 난이도 지표.
class FcRating {
  const FcRating({required this.style, required this.expanded, required this.length});

  /// 0 = 첫 방식으로 풀림, 1 = 두 번째 방식이 필요했음, -1 = 못 풂.
  final int style;

  /// 풀이를 찾기까지 펼친 상태 수.
  final int expanded;

  /// 찾은 풀이의 수 길이.
  final int length;

  bool get solved => style >= 0;

  /// 0~255 한 바이트로 줄인 난이도 점수 (클수록 어렵다). 못 푼 판은 255.
  /// 첫 방식으로 푼 판은 펼친 상태 수의 로그(0~210), 두 번째 방식이 필요했던 판은 215 이상.
  int get score {
    if (style < 0) return 255;
    final log2 = math.log(expanded + 1) / math.ln2;
    if (style == 1) return 215 + (log2 * 2).round().clamp(0, 35);
    return (log2 * 14).round().clamp(0, 210);
  }
}

/// 프리셀 풀이기: 현재 상태에서 끝까지 풀리는 수 순서를 찾는다 (힌트·풀이 가능 여부 확인용).
///
/// 우선순위 탐색(휴리스틱이 좋은 상태부터 펼침)이라 항상 가장 짧은 풀이는 아니지만 빠르다.
/// 안전한 "완성 칸 올리기"는 수마다 자동으로 이어서 처리한다 (경로에도 그 수들이 들어간다).
class FcSolver {
  FcSolver._();

  /// 풀이 수 순서. 못 찾으면(탐색 한도 초과·막힌 판) null.
  /// 첫 번째 평가 방식으로 못 풀면 다른 방식으로 한 번 더 시도한다.
  static List<FcMove>? solve(
    FcState start, {
    int maxNodes = 250000,
    Duration timeLimit = const Duration(seconds: 6),
  }) {
    // 전체 제한 시간을 두 번의 시도가 6:4로 나눠 쓴다
    for (var style = 0; style < 2; style++) {
      final limit = timeLimit * (style == 0 ? 0.6 : 0.4);
      final r = _search(start, style, maxNodes, limit).moves;
      if (r != null) return r;
    }
    return null;
  }

  /// 풀이를 찾으면서 "얼마나 헤맸는지"를 함께 잰다 (판의 난이도 평가용).
  ///
  /// - [FcRating.style] 0 = 첫 번째 평가 방식으로 풀림, 1 = 두 번째 방식이 필요했음, -1 = 못 풂
  /// - [FcRating.expanded] = 풀이에 이르기까지 펼친 상태 수 (많을수록 어려운 판)
  static FcRating rate(
    FcState start, {
    int maxNodes = 250000,
    Duration timeLimit = const Duration(seconds: 6),
  }) {
    final first = _search(start, 0, maxNodes, timeLimit * 0.6);
    if (first.moves != null) {
      return FcRating(style: 0, expanded: first.expanded, length: first.moves!.length);
    }
    final second = _search(start, 1, maxNodes, timeLimit * 0.4);
    if (second.moves != null) {
      return FcRating(style: 1, expanded: second.expanded, length: second.moves!.length);
    }
    return const FcRating(style: -1, expanded: 0, length: 0);
  }

  static ({List<FcMove>? moves, int expanded}) _search(
    FcState start,
    int style,
    int maxNodes,
    Duration timeLimit,
  ) {
    final watch = Stopwatch()..start();
    final states = <Uint8List>[];
    final parents = <int>[];
    final moves = <List<int>>[];
    final visited = <String>{};
    final heap = _MinHeap();

    int add(FcState s, int parent, List<int> mv, int depth) {
      states.add(_encode(s));
      parents.add(parent);
      moves.add(mv);
      final idx = states.length - 1;
      heap.push(_priority(s, depth, style), idx);
      return idx;
    }

    // 시작 상태에서 가능한 자동 올리기를 먼저 처리
    final root = start.copy();
    final rootMoves = <int>[];
    for (var m = root.safeAutoMove(); m != null; m = root.safeAutoMove()) {
      root.apply(m);
      rootMoves.add(m.code);
    }
    visited.add(root.key);
    add(root, -1, rootMoves, 0);
    final depths = <int>[0];

    var expanded = 0;
    while (heap.isNotEmpty) {
      final idx = heap.pop();
      final s = _decode(states[idx]);
      if (s.isWon) return (moves: _path(idx, parents, moves), expanded: expanded);
      if (++expanded > maxNodes) return (moves: null, expanded: expanded);
      if (expanded % 512 == 0 && watch.elapsed > timeLimit) return (moves: null, expanded: expanded);

      for (final m in s.legalMoves(forSolver: true)) {
        final child = s.copy()..apply(m);
        final mv = <int>[m.code];
        for (var a = child.safeAutoMove(); a != null; a = child.safeAutoMove()) {
          child.apply(a);
          mv.add(a.code);
        }
        if (!visited.add(child.key)) continue;
        final d = depths[idx] + 1;
        add(child, idx, mv, d);
        depths.add(d);
      }
    }
    return (moves: null, expanded: expanded);
  }

  static List<FcMove> _path(int idx, List<int> parents, List<List<int>> moves) {
    final chunks = <List<int>>[];
    for (var i = idx; i >= 0; i = parents[i]) {
      chunks.add(moves[i]);
    }
    return [
      for (final chunk in chunks.reversed)
        for (final code in chunk) FcMove.fromCode(code),
    ];
  }

  /// 작을수록 먼저 펼친다.
  static int _priority(FcState s, int depth, int style) {
    var blockers = 0;
    for (final col in s.columns) {
      var minBelow = 99;
      for (final c in col) {
        final r = rankOf(c);
        if (r > minBelow) blockers++; // 더 작은 카드 위에 얹혀 있는 카드
        if (r < minBelow) minBelow = r;
      }
    }
    final remaining = 52 - s.foundationTotal;
    final cellsUsed = 4 - s.freeCells;
    if (style == 1) {
      // 막힌 카드(blockers)를 더 무겁게 보고, 깊이에도 더 신경 쓰는 방식
      return remaining + blockers * 6 + cellsUsed * 3 - s.emptyColumns * 3 + depth;
    }
    return remaining * 2 + blockers * 3 + cellsUsed * 2 - s.emptyColumns * 2 + depth ~/ 2;
  }

  static Uint8List _encode(FcState s) {
    final out = Uint8List(8 + 52 + 4 + 4);
    var p = 0;
    for (final col in s.columns) {
      out[p++] = col.length;
      for (final c in col) {
        out[p++] = c;
      }
    }
    for (final c in s.cells) {
      out[p++] = c < 0 ? 255 : c;
    }
    for (final f in s.found) {
      out[p++] = f;
    }
    return out;
  }

  static FcState _decode(Uint8List b) {
    var p = 0;
    final cols = <List<int>>[];
    for (var i = 0; i < 8; i++) {
      final n = b[p++];
      cols.add([for (var k = 0; k < n; k++) b[p++]]);
    }
    final cells = [for (var i = 0; i < 4; i++) b[p++] == 255 ? -1 : b[p - 1]];
    final found = [for (var i = 0; i < 4; i++) b[p++]];
    return FcState(cols, cells, found);
  }
}

/// 작은 값이 먼저 나오는 이진 힙 (우선순위, 번호).
class _MinHeap {
  final List<int> _prio = [];
  final List<int> _item = [];

  bool get isNotEmpty => _prio.isNotEmpty;

  void push(int priority, int item) {
    _prio.add(priority);
    _item.add(item);
    var i = _prio.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_prio[parent] <= _prio[i]) break;
      _swap(parent, i);
      i = parent;
    }
  }

  int pop() {
    final top = _item.first;
    final lastP = _prio.removeLast();
    final lastI = _item.removeLast();
    if (_prio.isNotEmpty) {
      _prio[0] = lastP;
      _item[0] = lastI;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _prio.length && _prio[l] < _prio[m]) m = l;
        if (r < _prio.length && _prio[r] < _prio[m]) m = r;
        if (m == i) break;
        _swap(m, i);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final p = _prio[a];
    _prio[a] = _prio[b];
    _prio[b] = p;
    final it = _item[a];
    _item[a] = _item[b];
    _item[b] = it;
  }
}
