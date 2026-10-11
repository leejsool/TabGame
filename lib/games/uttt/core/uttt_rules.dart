/// 얼티밋 틱택토 규칙 엔진 (화면과 무관한 순수 로직).
///
/// 큰 판은 3×3 작은 판 9개. 한 수는 (작은 판 b, 그 안의 칸 c) → `b*9 + c` (0~80).
/// 내가 둔 칸의 위치(c)가 상대가 다음에 둘 작은 판 번호가 된다. 그 판이 이미 끝났으면 아무 판이나 고른다.
/// 작은 판에서 한 줄을 만들면 그 판을 차지하고, 큰 판에서 차지한 판 세 개를 한 줄로 이으면 이긴다.
library;

/// 가로·세로·대각선 승리 마스크 (칸 0~8 → 비트 0~8).
const List<int> kLineMasks = [0x7, 0x38, 0x1C0, 0x49, 0x92, 0x124, 0x111, 0x54];

/// 각 줄의 칸 번호.
const List<List<int>> kLines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6],
];

final List<bool> _winTable = List<bool>.generate(512, (m) => kLineMasks.any((w) => m & w == w));

/// 마스크 안에 세 줄이 하나라도 있는가.
bool hasLine(int mask) => _winTable[mask];

/// 0 = X(먼저 시작), 1 = O.
const int kX = 0;
const int kO = 1;

enum Outcome { ongoing, xWins, oWins, draw }

class UttState {
  UttState()
      : cellsX = List<int>.filled(9, 0),
        cellsO = List<int>.filled(9, 0);

  /// 작은 판 b에서 X / O가 차지한 칸의 비트마스크.
  final List<int> cellsX;
  final List<int> cellsO;

  /// 큰 판에서 X가 차지한 / O가 차지한 / 무승부로 끝난 작은 판의 비트마스크.
  int bigX = 0;
  int bigO = 0;
  int bigDraw = 0;

  /// 지금 둘 차례 (kX / kO).
  int turn = kX;

  /// 다음에 반드시 둬야 하는 작은 판 (-1 = 아무 판).
  int next = -1;

  int moveCount = 0;
  Outcome outcome = Outcome.ongoing;

  final List<int> _undo = []; // 수마다 [이전 next, 이전 bigX, 이전 bigO, 이전 bigDraw, 이전 outcome]

  /// 수 목록으로 상태를 만든다.
  factory UttState.fromMoves(Iterable<int> moves, {int firstTurn = kX}) {
    final s = UttState()..turn = firstTurn;
    for (final m in moves) {
      s.apply(m);
    }
    return s;
  }

  UttState copy() {
    final c = UttState();
    for (var i = 0; i < 9; i++) {
      c.cellsX[i] = cellsX[i];
      c.cellsO[i] = cellsO[i];
    }
    c.bigX = bigX;
    c.bigO = bigO;
    c.bigDraw = bigDraw;
    c.turn = turn;
    c.next = next;
    c.moveCount = moveCount;
    c.outcome = outcome;
    return c;
  }

  bool get isOver => outcome != Outcome.ongoing;

  /// 작은 판 [b]가 아직 진행 중인가.
  bool boardOpen(int b) => ((bigX | bigO | bigDraw) >> b) & 1 == 0;

  /// 작은 판 [b]의 결과: 0 = 진행 중, 1 = X, 2 = O, 3 = 무승부.
  int boardOwner(int b) {
    if ((bigX >> b) & 1 == 1) return 1;
    if ((bigO >> b) & 1 == 1) return 2;
    if ((bigDraw >> b) & 1 == 1) return 3;
    return 0;
  }

  /// 칸의 주인: 0 = 비어 있음, 1 = X, 2 = O.
  int cellOwner(int b, int c) {
    if ((cellsX[b] >> c) & 1 == 1) return 1;
    if ((cellsO[b] >> c) & 1 == 1) return 2;
    return 0;
  }

  /// 지금 둘 수 있는 모든 수.
  List<int> legalMoves() {
    if (isOver) return const [];
    final moves = <int>[];
    void addBoard(int b) {
      final empty = ~(cellsX[b] | cellsO[b]) & 511;
      for (var c = 0; c < 9; c++) {
        if ((empty >> c) & 1 == 1) moves.add(b * 9 + c);
      }
    }

    if (next >= 0) {
      addBoard(next);
    } else {
      for (var b = 0; b < 9; b++) {
        if (boardOpen(b)) addBoard(b);
      }
    }
    return moves;
  }

  bool isLegal(int move) {
    if (isOver || move < 0 || move > 80) return false;
    final b = move ~/ 9, c = move % 9;
    if (!boardOpen(b)) return false;
    if (next >= 0 && b != next) return false;
    return ((cellsX[b] | cellsO[b]) >> c) & 1 == 0;
  }

  /// 수를 둔다 (합법인지는 확인하지 않는다).
  void apply(int move) {
    final b = move ~/ 9, c = move % 9;
    _undo
      ..add(next)
      ..add(bigX)
      ..add(bigO)
      ..add(bigDraw)
      ..add(outcome.index);
    final bit = 1 << c;
    final mover = turn;
    if (mover == kX) {
      cellsX[b] |= bit;
    } else {
      cellsO[b] |= bit;
    }
    final mine = mover == kX ? cellsX[b] : cellsO[b];
    if (hasLine(mine)) {
      if (mover == kX) {
        bigX |= 1 << b;
      } else {
        bigO |= 1 << b;
      }
      final bigMine = mover == kX ? bigX : bigO;
      if (hasLine(bigMine)) outcome = mover == kX ? Outcome.xWins : Outcome.oWins;
    } else if ((cellsX[b] | cellsO[b]) == 511) {
      bigDraw |= 1 << b;
    }
    if (outcome == Outcome.ongoing && (bigX | bigO | bigDraw) == 511) outcome = Outcome.draw;
    next = boardOpen(c) ? c : -1;
    turn = 1 - mover;
    moveCount++;
  }

  /// 마지막 수를 되돌린다.
  void undo(int move) {
    final b = move ~/ 9, c = move % 9;
    final base = _undo.length - 5;
    next = _undo[base];
    bigX = _undo[base + 1];
    bigO = _undo[base + 2];
    bigDraw = _undo[base + 3];
    outcome = Outcome.values[_undo[base + 4]];
    _undo.length = base;
    turn = 1 - turn;
    moveCount--;
    final bit = ~(1 << c);
    if (turn == kX) {
      cellsX[b] &= bit;
    } else {
      cellsO[b] &= bit;
    }
  }

  /// 이긴 큰 줄의 작은 판 번호 세 개 (없으면 null).
  List<int>? get winningLine {
    final mask = outcome == Outcome.xWins ? bigX : bigO;
    if (outcome != Outcome.xWins && outcome != Outcome.oWins) return null;
    for (var i = 0; i < 8; i++) {
      if (mask & kLineMasks[i] == kLineMasks[i]) return kLines[i];
    }
    return null;
  }
}
