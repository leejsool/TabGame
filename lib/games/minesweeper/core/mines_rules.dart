/// 지뢰찾기 규칙 엔진 (화면과 무관한 순수 로직).
library;

import 'dart:math';

enum MinesLevel {
  beginner('초급', 9, 9, 10),
  intermediate('중급', 16, 16, 40),
  expert('고급', 16, 30, 99);

  const MinesLevel(this.label, this.rows, this.cols, this.mines);

  final String label;
  final int rows;
  final int cols;
  final int mines;

  String get description => '$rows×$cols · 지뢰 $mines개';
}

/// 칸의 표시 상태. (지뢰가 있는지는 [MinesBoard.mine]에 따로 있다)
/// 칸의 표시. [question]은 "잘 모르겠다"는 물음표(?)로, 깃발과 달리 지뢰 수에 들어가지 않고 열 수도 있다.
/// (저장된 판에 숫자(index)로 남으므로 새 값은 맨 뒤에만 추가한다)
enum CellMark { hidden, revealed, flagged, question }

class MinesBoard {
  MinesBoard(this.rows, this.cols, this.mineCount)
      : mine = List<bool>.filled(rows * cols, false),
        adj = List<int>.filled(rows * cols, 0),
        marks = List<CellMark>.filled(rows * cols, CellMark.hidden);

  factory MinesBoard.forLevel(MinesLevel level) => MinesBoard(level.rows, level.cols, level.mines);

  final int rows;
  final int cols;
  final int mineCount;

  /// 칸마다 지뢰가 있는가 / 주변 8칸의 지뢰 수 / 표시 상태.
  final List<bool> mine;
  final List<int> adj;
  final List<CellMark> marks;

  /// 첫 칸을 연 뒤에야 지뢰가 놓인다 (첫 칸은 늘 안전하다).
  bool minesPlaced = false;
  int revealedCount = 0;
  int flagCount = 0;

  /// 지뢰를 밟은 칸 (없으면 null).
  int? explodedCell;

  int get size => rows * cols;
  int index(int r, int c) => r * cols + c;
  int rowOf(int i) => i ~/ cols;
  int colOf(int i) => i % cols;

  /// 가장자리를 벗어나지 않는 이웃 칸들.
  List<int> neighbors(int i) {
    final r = rowOf(i), c = colOf(i);
    final out = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) out.add(nr * cols + nc);
      }
    }
    return out;
  }

  /// 첫 칸 [safe]와 (자리가 충분하면) 그 이웃에는 지뢰를 놓지 않는다.
  void placeMines(int safe, Random rng) {
    final banned = <int>{safe};
    if (size - 9 >= mineCount) banned.addAll(neighbors(safe));
    final candidates = [for (var i = 0; i < size; i++) if (!banned.contains(i)) i]..shuffle(rng);
    setMines(candidates.take(mineCount));
  }

  /// 정해 둔 지뢰 배치[preset]를 쓰되, 첫 칸 [safe]와 (자리가 충분하면) 그 이웃은 안전하게 한다.
  /// 그 자리에 있던 지뢰는 다른 빈 칸으로 옮긴다 (포기했던 판에 다시 도전할 때 쓴다).
  void placePresetMines(Iterable<int> preset, int safe, Random rng) {
    final banned = <int>{safe};
    if (size - 9 >= mineCount) banned.addAll(neighbors(safe));
    final kept = <int>{for (final m in preset) if (!banned.contains(m)) m};
    final moved = preset.length - kept.length;
    final spare = [for (var i = 0; i < size; i++) if (!banned.contains(i) && !kept.contains(i)) i]..shuffle(rng);
    setMines([...kept, ...spare.take(moved)]);
  }

  /// 지뢰 위치를 정해 놓고 주변 숫자를 계산한다 (저장 복원/테스트용).
  void setMines(Iterable<int> mines) {
    mine.fillRange(0, size, false);
    for (final i in mines) {
      mine[i] = true;
    }
    for (var i = 0; i < size; i++) {
      adj[i] = neighbors(i).where((n) => mine[n]).length;
    }
    minesPlaced = true;
  }

  bool get isLost => explodedCell != null;
  bool get isWon => minesPlaced && !isLost && revealedCount == size - mineCount;

  /// 남은 지뢰 수 표시용 (깃발을 많이 꽂으면 음수가 될 수 있다).
  int get minesLeft => mineCount - flagCount;

  /// 아직 안 열렸고 깃발도 없어서 열 수 있는 칸 (그냥 닫힌 칸이거나 물음표 칸).
  bool canOpen(int i) => marks[i] == CellMark.hidden || marks[i] == CellMark.question;

  /// 칸을 연다. 새로 열린 칸들을 (칸, 시작 칸으로부터의 거리) 순서로 돌려준다.
  /// 깃발이 꽂힌 칸이나 이미 열린 칸이면 빈 목록. 지뢰를 밟으면 [explodedCell]이 정해진다.
  List<(int, int)> reveal(int i) {
    if (!canOpen(i)) return const [];
    if (mine[i]) {
      marks[i] = CellMark.revealed;
      explodedCell = i;
      return [(i, 0)];
    }
    final out = <(int, int)>[];
    final dist = <int, int>{i: 0};
    final queue = [i];
    marks[i] = CellMark.revealed;
    revealedCount++;
    out.add((i, 0));
    for (var head = 0; head < queue.length; head++) {
      final cur = queue[head];
      if (adj[cur] != 0) continue;
      for (final n in neighbors(cur)) {
        if (!canOpen(n) || mine[n]) continue;
        marks[n] = CellMark.revealed;
        revealedCount++;
        dist[n] = dist[cur]! + 1;
        queue.add(n);
        out.add((n, dist[n]!));
      }
    }
    return out;
  }

  /// 깃발을 꽂거나 뽑는다 (물음표 칸에는 깃발로 바꿔 꽂는다). 이미 열린 칸이면 false.
  bool toggleFlag(int i) {
    switch (marks[i]) {
      case CellMark.hidden:
      case CellMark.question:
        marks[i] = CellMark.flagged;
        flagCount++;
        return true;
      case CellMark.flagged:
        marks[i] = CellMark.hidden;
        flagCount--;
        return true;
      case CellMark.revealed:
        return false;
    }
  }

  /// 물음표를 달거나 뗀다 (깃발 칸에는 깃발을 뽑고 물음표로 바꾼다). 이미 열린 칸이면 false.
  bool toggleQuestion(int i) {
    switch (marks[i]) {
      case CellMark.hidden:
        marks[i] = CellMark.question;
        return true;
      case CellMark.question:
        marks[i] = CellMark.hidden;
        return true;
      case CellMark.flagged:
        marks[i] = CellMark.question;
        flagCount--;
        return true;
      case CellMark.revealed:
        return false;
    }
  }

  int flaggedNeighbors(int i) => neighbors(i).where((n) => marks[n] == CellMark.flagged).length;

  /// 열린 숫자 칸에서, 주변 깃발 수가 숫자와 같으면 나머지 칸을 한꺼번에 연다.
  /// 열 수 있는 칸이 없으면 빈 목록.
  List<(int, int)> chord(int i) {
    if (marks[i] != CellMark.revealed || adj[i] == 0 || flaggedNeighbors(i) != adj[i]) return const [];
    final out = <(int, int)>[];
    for (final n in neighbors(i)) {
      if (!canOpen(n)) continue;
      out.addAll(reveal(n));
      if (isLost) break;
    }
    return out;
  }

  /// 이기면 남은 지뢰에 깃발을 모두 꽂는다.
  void flagAllMines() {
    for (var i = 0; i < size; i++) {
      if (mine[i] && canOpen(i)) {
        marks[i] = CellMark.flagged;
        flagCount++;
      }
    }
  }

  MinesBoard copy() {
    final b = MinesBoard(rows, cols, mineCount);
    b.mine.setAll(0, mine);
    b.adj.setAll(0, adj);
    b.marks.setAll(0, marks);
    b.minesPlaced = minesPlaced;
    b.revealedCount = revealedCount;
    b.flagCount = flagCount;
    b.explodedCell = explodedCell;
    return b;
  }
}
