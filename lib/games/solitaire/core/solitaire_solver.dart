/// 솔리테어 풀이기: 지금 판에서 끝까지 이길 수 있는지 따져 본다.
///
/// 뒤집힌 카드도 판 번호로 알고 있으니 "다 보이는" 상태에서 깊이 우선으로 탐색한다.
/// - 이기는 수순을 찾으면 [SolVerdict.winnable] + 그 첫 수.
/// - 갈 수 있는 모든 상태를 다 봐도 못 이기면 [SolVerdict.lost] (이미 망한 판이 확실함).
/// - 계산 한도를 넘기면 [SolVerdict.unknown].
///
/// 같은 상태를 두 번 보지 않고(열 순서만 다른 것도 같은 상태), 손해 없는 완성 칸 올리기는
/// 무조건 먼저 둔다. 이 둘은 결론을 바꾸지 않으므로 "망했다"는 판정은 믿어도 된다.
library;

import 'solitaire_rules.dart';

enum SolVerdict { winnable, lost, unknown }

class SolSolution {
  const SolSolution(this.verdict, {this.path = const [], this.nodes = 0});

  final SolVerdict verdict;

  /// 이기는 수순 (winnable일 때). 첫 수는 지금 상태에서 바로 둘 수 있는 수.
  final List<SolMove> path;
  final int nodes;

  SolMove? get firstMove => path.isEmpty ? null : path.first;
}

class _Frame {
  _Frame(this.state, this.moves, this.entered);

  final SolState state;
  final List<SolMove> moves;

  /// 부모에서 이 상태로 오기까지 둔 수 (고른 수 + 자동으로 올린 수들).
  final List<SolMove> entered;
  int next = 0;
}

/// [start]를 (건드리지 않고) 풀어 본다. 중간에 [cancelled]가 true가 되면 멈추고 unknown.
Future<SolSolution> solveSolitaire(
  SolState start, {
  int maxNodes = 250000,
  Duration maxTime = const Duration(seconds: 6),
  bool Function()? cancelled,
}) async {
  final clock = Stopwatch()..start();
  var nodes = 0;
  final visited = <String>{};

  final root = start.copy();
  final rootEntered = <SolMove>[];
  _playSafeFoundation(root, rootEntered);
  if (_isSolved(root)) return SolSolution(SolVerdict.winnable, path: rootEntered);
  visited.add(_key(root));

  final stack = <_Frame>[_Frame(root, _orderedMoves(root), rootEntered)];
  while (stack.isNotEmpty) {
    final top = stack.last;
    if (top.next >= top.moves.length) {
      stack.removeLast();
      continue;
    }
    nodes++;
    if (nodes % 1500 == 0) {
      // 화면이 멈추지 않도록 가끔 숨을 돌린다.
      await Future<void>.delayed(Duration.zero);
      if (cancelled != null && cancelled()) return SolSolution(SolVerdict.unknown, nodes: nodes);
    }
    if (nodes > maxNodes || (nodes % 256 == 0 && clock.elapsed > maxTime)) {
      return SolSolution(SolVerdict.unknown, nodes: nodes);
    }

    final move = top.moves[top.next++];
    final child = top.state.copy()..apply(move);
    final entered = <SolMove>[move];
    _playSafeFoundation(child, entered);
    if (_isSolved(child)) {
      return SolSolution(
        SolVerdict.winnable,
        path: [for (final f in stack) ...f.entered, ...entered],
        nodes: nodes,
      );
    }
    if (!visited.add(_key(child))) continue;
    stack.add(_Frame(child, _orderedMoves(child), entered));
  }
  return SolSolution(SolVerdict.lost, nodes: nodes);
}

bool _isSolved(SolState s) => s.isWon || s.canFinishAutomatically;

/// 손해 없는 카드를 완성 칸으로 올린다 (더 이상 열에서 쓸 일이 없는 카드라서 언제 올려도 같다).
void _playSafeFoundation(SolState s, List<SolMove> played) {
  var again = true;
  while (again) {
    again = false;
    if (s.waste.isNotEmpty && s.isSafeForFound(s.waste.last)) {
      const m = SolMove(SolKind.wasteToFound);
      s.apply(m);
      played.add(m);
      again = true;
    }
    for (var i = 0; i < 7; i++) {
      if (s.up[i] > 0 && s.isSafeForFound(s.tableau[i].last)) {
        final m = SolMove(SolKind.colToFound, from: i);
        s.apply(m);
        played.add(m);
        again = true;
      }
    }
  }
}

/// 이길 가능성이 높은 수부터 보도록 정렬한 수 목록.
List<SolMove> _orderedMoves(SolState s) {
  final scored = <(int, int, SolMove)>[];
  var order = 0;
  for (final m in s.legalMoves()) {
    final score = switch (m.kind) {
      SolKind.wasteToFound || SolKind.colToFound => 0,
      SolKind.colToCol => _isPointlessWholeColumn(s, m)
          ? -1
          : (s.up[m.from] == m.count && s.tableau[m.from].length > m.count ? 1 : 3),
      SolKind.wasteToCol => 2,
      SolKind.draw || SolKind.recycle => 4,
      SolKind.foundToCol => 5,
    };
    if (score < 0) continue; // 통째로 빈 열로 옮기는 수는 아무 변화가 없다
    scored.add((score, order++, m));
  }
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final e in scored) e.$3];
}

bool _isPointlessWholeColumn(SolState s, SolMove m) =>
    s.tableau[m.from].length == m.count && s.tableau[m.to].isEmpty;

/// 상태를 나타내는 문자열 (열 순서가 달라도 같은 상태는 같은 문자열).
String _key(SolState s) {
  final cols = <String>[
    for (var i = 0; i < 7; i++) String.fromCharCodes([48 + s.up[i], for (final c in s.tableau[i]) 48 + c]),
  ]..sort();
  return '${cols.join('|')}#${String.fromCharCodes([for (final c in s.stock) 48 + c])}'
      '#${String.fromCharCodes([for (final c in s.waste) 48 + c])}'
      '#${String.fromCharCodes([for (final n in s.found) 48 + n])}';
}
