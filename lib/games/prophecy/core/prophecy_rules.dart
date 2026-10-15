/// 예언 게임의 규칙 (책 '아주 이상한 수학책' 11장).
///
/// 행 [kMinSide]~[kMaxSide]개, 열 [kMinSide]~[kMaxSide]개의 표에 두 사람이 번갈아 빈칸에 숫자나 X를 쓴다.
/// 숫자는 "이 줄(행·열)에 결국 숫자가 몇 개 나타날지"에 대한 예언이다.
///
/// - 쓸 수 있는 숫자는 1부터 표의 가장 긴 줄의 칸 수([ProphState.maxNumber])까지.
/// - X는 칸을 그냥 채우고 거기에 숫자가 나타나지 않게 한다.
/// - 한 행이나 열에는 같은 숫자가 두 번 나타날 수 없다.
/// - 어떤 숫자를 써도 같은 숫자가 겹쳐서 채울 수 없는 칸은 저절로 X가 된다 (이것은 차례로 치지 않는다).
/// - 표가 가득 차면, 행마다 숫자(X 제외)가 몇 개인지 센다. 그 개수와 같은 숫자를 쓴 사람이 그 숫자만큼 점수를 얻는다.
///   열도 똑같이 센다. 한 숫자가 행과 열에서 두 번 점수를 낼 수도 있다. 점수가 더 높은 사람이 이긴다.
library;

import 'dart:math';

const int kMinSide = 4;
const int kMaxSide = 8;

/// 칸의 값: 빈칸 / X / 1 이상은 숫자.
const int kBlank = 0;
const int kCross = -1;

/// 쓰는 사람 (먼저 쓰는 쪽 0, 나중에 쓰는 쪽 1). 저절로 생긴 X는 주인이 없다.
const int kNoOwner = -1;

/// 한 수를 정수 하나로: 칸 번호 × 16 + (X면 0, 숫자면 그 숫자).
int encodeMove(int cell, int value) => cell * 16 + (value == kCross ? 0 : value);
int moveCell(int move) => move ~/ 16;
int moveValue(int move) => move % 16 == 0 ? kCross : move % 16;

/// 점수가 난 숫자 하나: 어느 칸이고, 행으로 맞았는지 열로 맞았는지.
class ProphHit {
  const ProphHit(this.cell, this.number, this.owner, {required this.byRow, required this.byCol});

  final int cell;
  final int number;
  final int owner;
  final bool byRow;
  final bool byCol;

  /// 이 숫자가 낸 점수 (행과 열에서 모두 맞으면 두 번).
  int get points => number * ((byRow ? 1 : 0) + (byCol ? 1 : 0));
}

class ProphState {
  ProphState(this.rows, this.cols)
      : assert(rows >= kMinSide && rows <= kMaxSide && cols >= kMinSide && cols <= kMaxSide),
        cells = List<int>.filled(rows * cols, kBlank),
        owners = List<int>.filled(rows * cols, kNoOwner),
        _rowMask = List<int>.filled(rows, 0),
        _colMask = List<int>.filled(cols, 0),
        blanks = rows * cols;

  ProphState._(this.rows, this.cols, this.cells, this.owners, this._rowMask, this._colMask, this.blanks, this.turns);

  /// 그림이나 시험용으로 칸 값과 주인을 직접 정해 만든다 (규칙대로 둔 순서와는 상관없다).
  factory ProphState.fromCells(int rows, int cols, List<int> cells, List<int> owners) {
    final s = ProphState(rows, cols);
    for (var i = 0; i < cells.length; i++) {
      final v = cells[i];
      if (v == kBlank) continue;
      s.cells[i] = v;
      s.owners[i] = owners[i];
      s.blanks--;
      if (v > 0) {
        s._rowMask[i ~/ cols] |= 1 << v;
        s._colMask[i % cols] |= 1 << v;
      }
      if (owners[i] != kNoOwner) s.turns++;
    }
    return s;
  }

  /// 수 목록(encodeMove)을 차례로 둔 판.
  factory ProphState.fromMoves(int rows, int cols, Iterable<int> moves) {
    final s = ProphState(rows, cols);
    for (final m in moves) {
      s.play(moveCell(m), moveValue(m));
    }
    return s;
  }

  final int rows, cols;

  /// 칸마다 [kBlank] / [kCross] / 숫자.
  final List<int> cells;

  /// 칸마다 쓴 사람 (0 / 1, 저절로 생긴 X와 빈칸은 [kNoOwner]).
  final List<int> owners;

  final List<int> _rowMask, _colMask;

  /// 남은 빈칸.
  int blanks;

  /// 지금까지 둔 수 (저절로 생긴 X는 세지 않는다).
  int turns = 0;

  ProphState copy() => ProphState._(rows, cols, List<int>.of(cells), List<int>.of(owners), List<int>.of(_rowMask), List<int>.of(_colMask), blanks, turns);

  /// 쓸 수 있는 가장 큰 숫자: 행과 열 중 더 긴 줄의 칸 수.
  int get maxNumber => rows > cols ? rows : cols;

  int rowOf(int cell) => cell ~/ cols;
  int colOf(int cell) => cell % cols;

  /// 지금 쓸 차례인 사람.
  int get turn => turns.isEven ? 0 : 1;

  bool get isOver => blanks == 0;

  /// 칸 [cell]에 쓸 수 있는 숫자들 (같은 행·열에 이미 있는 숫자는 뺀다).
  List<int> legalNumbers(int cell) {
    if (cells[cell] != kBlank) return const [];
    final used = _rowMask[rowOf(cell)] | _colMask[colOf(cell)];
    return [for (var n = 1; n <= maxNumber; n++) if (used & (1 << n) == 0) n];
  }

  /// 칸 [cell]에 [value](X 또는 숫자)를 쓸 수 있는가.
  bool canPlay(int cell, int value) {
    if (cell < 0 || cell >= cells.length || cells[cell] != kBlank) return false;
    if (value == kCross) return true;
    if (value < 1 || value > maxNumber) return false;
    return (_rowMask[rowOf(cell)] | _colMask[colOf(cell)]) & (1 << value) == 0;
  }

  /// 둘 수 있는 모든 수 (encodeMove).
  List<int> legalMoves() {
    final out = <int>[];
    for (var c = 0; c < cells.length; c++) {
      if (cells[c] != kBlank) continue;
      out.add(encodeMove(c, kCross));
      for (final n in legalNumbers(c)) {
        out.add(encodeMove(c, n));
      }
    }
    return out;
  }

  /// 현재 차례인 사람이 칸 [cell]에 [value]를 쓴다. 이때 저절로 X가 된 칸들을 돌려준다.
  List<int> play(int cell, int value) {
    assert(canPlay(cell, value));
    cells[cell] = value;
    owners[cell] = turn;
    blanks--;
    turns++;
    final r = rowOf(cell), c = colOf(cell);
    if (value > 0) {
      _rowMask[r] |= 1 << value;
      _colMask[c] |= 1 << value;
    }
    return value > 0 ? _autoCross(r, c) : const <int>[];
  }

  /// 숫자를 쓰고 나서, 같은 행·열에서 어떤 숫자도 쓸 수 없게 된 빈칸을 X로 채운다.
  /// (X는 숫자가 아니라서 다른 칸의 선택을 바꾸지 않으니, 한 번만 살피면 된다)
  List<int> _autoCross(int r, int c) {
    final crossed = <int>[];
    void check(int cell) {
      if (cells[cell] != kBlank) return;
      final used = _rowMask[rowOf(cell)] | _colMask[colOf(cell)];
      for (var n = 1; n <= maxNumber; n++) {
        if (used & (1 << n) == 0) return;
      }
      cells[cell] = kCross;
      blanks--;
      crossed.add(cell);
    }

    for (var j = 0; j < cols; j++) {
      check(r * cols + j);
    }
    for (var i = 0; i < rows; i++) {
      if (i != r) check(i * cols + c);
    }
    return crossed;
  }

  // ── 세기와 점수 ──

  /// 행 [r]에 지금 쓰인 숫자의 개수 (X는 세지 않는다).
  int rowCount(int r) {
    var n = 0;
    for (var j = 0; j < cols; j++) {
      if (cells[r * cols + j] > 0) n++;
    }
    return n;
  }

  int colCount(int c) {
    var n = 0;
    for (var i = 0; i < rows; i++) {
      if (cells[i * cols + c] > 0) n++;
    }
    return n;
  }

  /// 행 [r]이 끝났을 때 숫자가 몇 개일 수 있는가: 지금 개수 ~ 지금 개수 + 남은 빈칸.
  (int, int) rowRange(int r) {
    var blank = 0;
    for (var j = 0; j < cols; j++) {
      if (cells[r * cols + j] == kBlank) blank++;
    }
    final now = rowCount(r);
    return (now, now + blank);
  }

  (int, int) colRange(int c) {
    var blank = 0;
    for (var i = 0; i < rows; i++) {
      if (cells[i * cols + c] == kBlank) blank++;
    }
    final now = colCount(c);
    return (now, now + blank);
  }

  /// 점수가 난 숫자들 (칸 번호 순). 판이 끝난 뒤에 의미가 있다.
  List<ProphHit> hits() {
    final rc = [for (var r = 0; r < rows; r++) rowCount(r)];
    final cc = [for (var c = 0; c < cols; c++) colCount(c)];
    final out = <ProphHit>[];
    for (var i = 0; i < cells.length; i++) {
      final n = cells[i];
      if (n <= 0) continue;
      final byRow = rc[rowOf(i)] == n, byCol = cc[colOf(i)] == n;
      if (byRow || byCol) out.add(ProphHit(i, n, owners[i], byRow: byRow, byCol: byCol));
    }
    return out;
  }

  /// 두 사람의 점수 (행에서 얻은 것과 열에서 얻은 것을 따로).
  ({List<int> rowPts, List<int> colPts}) scoreParts() {
    final rowPts = [0, 0], colPts = [0, 0];
    for (final h in hits()) {
      if (h.owner < 0) continue;
      if (h.byRow) rowPts[h.owner] += h.number;
      if (h.byCol) colPts[h.owner] += h.number;
    }
    return (rowPts: rowPts, colPts: colPts);
  }

  /// 두 사람의 점수 합계.
  List<int> scores() {
    final p = scoreParts();
    return [p.rowPts[0] + p.colPts[0], p.rowPts[1] + p.colPts[1]];
  }

  /// 이긴 사람 (끝난 판에서). 무승부거나 안 끝났으면 null.
  int? get winner {
    if (!isOver) return null;
    final s = scores();
    return s[0] == s[1] ? null : (s[0] > s[1] ? 0 : 1);
  }
}

/// 무작위로 끝까지 둔다 (시험용): 칸을 아무거나 고르고, X나 쓸 수 있는 숫자 가운데 아무거나 쓴다.
void playRandomly(ProphState s, Random rng, {int? untilBlanks}) {
  final blanksList = <int>[];
  while (!s.isOver && (untilBlanks == null || s.blanks > untilBlanks)) {
    blanksList
      ..clear()
      ..addAll([for (var i = 0; i < s.cells.length; i++) if (s.cells[i] == kBlank) i]);
    final cell = blanksList[rng.nextInt(blanksList.length)];
    final nums = s.legalNumbers(cell);
    final pick = rng.nextInt(nums.length + 1);
    s.play(cell, pick == nums.length ? kCross : nums[pick]);
  }
}
