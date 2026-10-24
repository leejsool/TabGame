/// 바둑돌 옮기기 (수학 멘토링 '경우의 수와 민들레 게임' 7쪽 예제).
///
/// 3행 × 12칸. 행마다 흰 돌(갑) 하나가 왼쪽에, 검은 돌(을) 하나가 오른쪽에 있다.
/// 갑부터 번갈아 자기 돌 하나를 같은 행의 다른 빈칸으로 옮긴다 (다른 돌은 건너뛸 수 없다).
/// 더는 움직일 수 없는 사람이 진다.
///
/// 비법: 행마다 두 돌 사이 빈칸 수를 님(Nim) 더미로 보고, 세 수의 XOR(님 합)이 0이 되게 둔다.
/// 상대가 돌을 뒤로 물려 빈칸을 늘리면, 같은 행에서 그만큼 다가가 되돌려 놓으면 된다.
library;

import 'dart:math';

const int kRows = 3;
const int kCols = 12;

/// 빈칸 수(0~10)를 2진법으로 쓸 때의 자리값.
const List<int> kBits = [8, 4, 2, 1];

enum Side {
  white('갑', '흰 돌'),
  black('을', '검은 돌');

  const Side(this.name, this.stone);
  final String name;
  final String stone;

  Side get other => this == white ? black : white;
}

/// 한 수: [row]행의 내 돌을 [to]칸으로 (칸 번호는 0부터).
class StoneMove {
  const StoneMove(this.row, this.to);

  final int row;
  final int to;

  @override
  bool operator ==(Object other) => other is StoneMove && other.row == row && other.to == to;

  @override
  int get hashCode => row * 100 + to;

  /// 화면에 보이는 말 (행·칸은 1부터).
  String label(Side side, int from) => '${row + 1}행 ${side.stone}: ${from + 1}칸 → ${to + 1}칸';
}

class StonesState {
  StonesState(List<int> white, List<int> black, {this.turn = Side.white})
      : white = List<int>.of(white),
        black = List<int>.of(black) {
    for (var r = 0; r < kRows; r++) {
      assert(0 <= this.white[r] && this.white[r] < this.black[r] && this.black[r] < kCols);
    }
  }

  /// 행마다 흰 돌·검은 돌의 칸 (0부터).
  final List<int> white;
  final List<int> black;
  Side turn;

  StonesState copy() => StonesState(white, black, turn: turn);

  List<int> stonesOf(Side s) => s == Side.white ? white : black;

  /// [r]행 두 돌 사이 빈칸 수.
  int gap(int r) => black[r] - white[r] - 1;

  List<int> get gaps => [for (var r = 0; r < kRows; r++) gap(r)];

  /// 빈칸 수들의 XOR. 0이면 지금 둘 차례인 사람이 (상대가 잘하면) 진다.
  int get nimSum => gaps.fold(0, (a, b) => a ^ b);

  /// [r]행에서 지금 차례인 사람의 돌이 갈 수 있는 칸들.
  List<int> targets(int r, [Side? side]) {
    final s = side ?? turn;
    if (s == Side.white) return [for (var c = 0; c < black[r]; c++) if (c != white[r]) c];
    return [for (var c = white[r] + 1; c < kCols; c++) if (c != black[r]) c];
  }

  List<StoneMove> legalMoves() => [
        for (var r = 0; r < kRows; r++)
          for (final c in targets(r)) StoneMove(r, c),
      ];

  bool canMove(StoneMove m) => targets(m.row).contains(m.to);

  /// 지금 차례인 사람이 움직일 수 없으면 끝 (그 사람이 진다).
  bool get isOver => legalMoves().isEmpty;

  Side? get winner => isOver ? turn.other : null;

  void apply(StoneMove m) {
    assert(canMove(m));
    stonesOf(turn)[m.row] = m.to;
    turn = turn.other;
  }

  /// 이 수를 두면 상대에게 님 합 0을 넘겨 주는가 (= 이기는 수).
  bool isWinningMove(StoneMove m) => (copy()..apply(m)).nimSum == 0;

  List<StoneMove> winningMoves() => [for (final m in legalMoves()) if (isWinningMove(m)) m];

  /// 컴퓨터의 수: 이기는 수가 있으면 그중 빈칸을 줄이는(다가가는) 수를 먼저,
  /// 없으면 빈칸을 하나 줄이는 수를 골라 판이 오래 끌지 않게 한다.
  StoneMove cpuMove(Random rng) {
    final win = winningMoves();
    if (win.isNotEmpty) {
      final forward = win.where(_closesGap).toList();
      final pool = forward.isNotEmpty ? forward : win;
      return pool[rng.nextInt(pool.length)];
    }
    final all = legalMoves();
    final small = all.where((m) => _closesGap(m) && (m.to - stonesOf(turn)[m.row]).abs() == 1).toList();
    final pool = small.isNotEmpty ? small : all;
    return pool[rng.nextInt(pool.length)];
  }

  /// 모든 행의 빈칸이 0이면 승부는 정해졌다: 차례인 사람이 물러나면 상대가 그만큼 따라붙으면 된다.
  bool get isDecided => !isOver && gaps.every((g) => g == 0);

  /// 정해진 판([isDecided])을 끝까지 두는 수들. 지는 쪽은 한 행의 돌을 벽까지 물리고,
  /// 이기는 쪽은 바로 붙는다. 행마다 두 수씩이라 많아야 6수.
  List<StoneMove> finishMoves() {
    final s = copy();
    final moves = <StoneMove>[];
    while (!s.isOver) {
      final open = [for (var r = 0; r < kRows; r++) if (s.gap(r) > 0) r];
      final StoneMove m;
      if (open.isNotEmpty) {
        final r = open.first;
        m = StoneMove(r, s.turn == Side.white ? s.black[r] - 1 : s.white[r] + 1);
      } else {
        final r = [for (var r = 0; r < kRows; r++) if (s.targets(r).isNotEmpty) r].first;
        m = StoneMove(r, s.turn == Side.white ? 0 : kCols - 1);
      }
      s.apply(m);
      moves.add(m);
    }
    return moves;
  }

  /// 빈칸 수를 2진법으로 쓸 때 8·4·2·1 자리마다 1이 몇 개인지 (8 자리부터).
  List<int> get bitCounts => [for (final b in kBits) gaps.where((g) => g & b != 0).length];

  bool _closesGap(StoneMove m) {
    final from = stonesOf(turn)[m.row];
    return turn == Side.white ? m.to > from : m.to < from;
  }
}

/// 문제지의 판들 (칸 번호는 문제지처럼 1부터 적는다).
class StonesPuzzle {
  const StonesPuzzle({required this.title, required this.question, required this.white, required this.black, required this.turn});

  final String title;
  final String question;
  final List<int> white;
  final List<int> black;
  final Side turn;

  StonesState start() => StonesState([for (final c in white) c - 1], [for (final c in black) c - 1], turn: turn);
}

const kStartBoard = StonesPuzzle(
  title: '처음 판',
  question: '갑(흰 돌)부터 자유롭게 겨뤄 보세요.',
  white: [1, 2, 3],
  black: [12, 11, 10],
  turn: Side.white,
);

const kPuzzles = [
  StonesPuzzle(
    title: '문제 (1)',
    question: '갑 차례예요. 갑이 이기려면 어떤 흰 돌을 어디로 옮겨야 할까요?',
    white: [4, 2, 3],
    black: [8, 4, 4],
    turn: Side.white,
  ),
  StonesPuzzle(
    title: '문제 (2)',
    question: '갑이 첫 수를 둔 뒤예요. 을이 이기려면 어떤 검은 돌을 옮겨야 할까요?',
    white: [11, 2, 3],
    black: [12, 11, 10],
    turn: Side.black,
  ),
  StonesPuzzle(
    title: '문제 (3)',
    question: '갑이 첫 수를 둔 뒤예요. 을이 이기려면 어떤 검은 돌을 옮겨야 할까요?',
    white: [1, 9, 3],
    black: [12, 11, 10],
    turn: Side.black,
  ),
];
