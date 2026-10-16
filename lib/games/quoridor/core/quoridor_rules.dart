/// 쿼리도의 규칙 (화면·네트워크와 무관한 순수 계산).
///
/// 9×9 판에서 말을 한 칸씩 움직여 맞은편 줄에 먼저 닿는 사람이 이긴다. 자기 차례에는 말을 움직이거나 벽을 하나 세운다.
/// 벽은 두 칸 길이이고, 모든 사람의 길을 완전히 막아서는 안 된다.
///
/// 칸 번호는 `행 * 9 + 열` (행 0이 맨 위). 벽은 8×8 격자점(앵커)에 가로 또는 세로로 놓는다:
///  - 가로 벽 (r, c): r행과 r+1행 사이, c열과 c+1열을 가로질러 막는다.
///  - 세로 벽 (r, c): c열과 c+1열 사이, r행과 r+1행을 가로질러 막는다.
const int kBoard = 9;
const int kCells = kBoard * kBoard;
const int kAnchors = kBoard - 1;

/// 한 수의 부호: 말 이동은 도착 칸 번호(0~80), 벽 세우기는 100 + 방향*64 + 행*8 + 열 (방향 0 = 가로, 1 = 세로).
const int kWallBase = 100;

int wallMove(int orient, int r, int c) => kWallBase + orient * 64 + r * kAnchors + c;
bool isWallMove(int move) => move >= kWallBase;
int wallOrient(int move) => (move - kWallBase) ~/ 64;
int wallRow(int move) => ((move - kWallBase) % 64) ~/ kAnchors;
int wallCol(int move) => ((move - kWallBase) % 64) % kAnchors;

/// 자리(0~3)별 시작 칸과 도착 줄. 2명이면 아래(0)·위(1), 4명이면 아래(0)→왼쪽(1)→위(2)→오른쪽(3) 시계 방향.
const List<int> _start4 = [8 * kBoard + 4, 4 * kBoard + 0, 0 * kBoard + 4, 4 * kBoard + 8];

int startCell(int players, int seat) => players == 2 ? _start4[seat == 0 ? 0 : 2] : _start4[seat];

/// 말이 [cell]에서 도착 줄에 닿았는가. (아래 말은 맨 위 줄, 왼쪽 말은 맨 오른쪽 줄, 위 말은 맨 아래 줄, 오른쪽 말은 맨 왼쪽 줄)
bool reachedGoal(int players, int seat, int cell) {
  final r = cell ~/ kBoard, c = cell % kBoard;
  final side = players == 2 ? (seat == 0 ? 0 : 2) : seat;
  return switch (side) {
    0 => r == 0,
    1 => c == kBoard - 1,
    2 => r == kBoard - 1,
    _ => c == 0,
  };
}

/// 사람 수별 처음에 나눠 주는 벽 수 (2명 10개, 4명 5개).
int wallsPerPlayer(int players) => players == 2 ? 10 : 5;

/// 쿼리도 한 판의 상태.
class QState {
  QState._(this.players, this.pawn, this.wallsLeft, this.h, this.v, this.hOwner, this.vOwner);

  /// 처음 모습. [players]는 2 또는 4.
  factory QState.start(int players) {
    assert(players == 2 || players == 4);
    return QState._(
      players,
      [for (var s = 0; s < players; s++) startCell(players, s)],
      List.filled(players, wallsPerPlayer(players)),
      List.filled(kAnchors * kAnchors, false),
      List.filled(kAnchors * kAnchors, false),
      List.filled(kAnchors * kAnchors, -1),
      List.filled(kAnchors * kAnchors, -1),
    );
  }

  /// 수들 [moves]를 처음부터 차례로 둔 상태 (되돌리기·시험용).
  factory QState.fromMoves(int players, Iterable<int> moves) {
    final s = QState.start(players);
    for (final m in moves) {
      s.apply(m);
    }
    return s;
  }

  QState clone() {
    final s = QState._(players, [...pawn], [...wallsLeft], [...h], [...v], [...hOwner], [...vOwner]);
    s.turn = turn;
    s.winner = winner;
    s.moveCount = moveCount;
    return s;
  }

  final int players;

  /// 사람마다 말이 선 칸.
  final List<int> pawn;

  /// 사람마다 남은 벽 수.
  final List<int> wallsLeft;

  /// 세워진 가로 벽 / 세로 벽 (앵커 번호 `행 * 8 + 열`).
  final List<bool> h, v;

  /// 세워진 가로 벽 / 세로 벽을 세운 사람의 자리 (벽이 없는 곳은 -1). 벽이 누구 것인지 색으로 보여 주는 데 쓴다.
  final List<int> hOwner, vOwner;

  int turn = 0;

  /// 이긴 사람 (끝나기 전에는 null).
  int? winner;

  /// 지금까지 둔 수.
  int moveCount = 0;

  bool get isOver => winner != null;

  // ── 벽과 길 ──

  bool hWallAt(int r, int c) => r >= 0 && r < kAnchors && c >= 0 && c < kAnchors && h[r * kAnchors + c];
  bool vWallAt(int r, int c) => r >= 0 && r < kAnchors && c >= 0 && c < kAnchors && v[r * kAnchors + c];

  /// 이웃한 두 칸 [a], [b] 사이가 벽으로 막혔는가.
  bool blockedBetween(int a, int b) {
    final ar = a ~/ kBoard, ac = a % kBoard, br = b ~/ kBoard, bc = b % kBoard;
    if (ac == bc) {
      final r = ar < br ? ar : br; // 위쪽 칸의 행
      return hWallAt(r, ac) || hWallAt(r, ac - 1);
    }
    final c = ac < bc ? ac : bc; // 왼쪽 칸의 열
    return vWallAt(ar, c) || vWallAt(ar - 1, c);
  }

  static const _dr = [-1, 1, 0, 0];
  static const _dc = [0, 0, -1, 1];

  /// 벽에 막히지 않고 이웃한 칸들 (말은 무시).
  Iterable<int> neighbors(int cell) sync* {
    final r = cell ~/ kBoard, c = cell % kBoard;
    for (var d = 0; d < 4; d++) {
      final nr = r + _dr[d], nc = c + _dc[d];
      if (nr < 0 || nr >= kBoard || nc < 0 || nc >= kBoard) continue;
      final n = nr * kBoard + nc;
      if (!blockedBetween(cell, n)) yield n;
    }
  }

  /// [seat]의 말이 [from]에서 도착 줄까지 가는 가장 짧은 걸음 수 (다른 말은 무시). 길이 없으면 -1.
  int distanceFrom(int seat, int from) => _bfs(seat, from, null);

  int distance(int seat) => distanceFrom(seat, pawn[seat]);

  /// 가장 짧은 길의 칸들 ([from] 다음 칸부터 도착 줄 칸까지). 길이 없으면 null.
  List<int>? shortestPath(int seat, [int? from]) {
    final path = <int>[];
    return _bfs(seat, from ?? pawn[seat], path) < 0 ? null : path;
  }

  int _bfs(int seat, int from, List<int>? pathOut) {
    if (reachedGoal(players, seat, from)) return 0;
    final dist = List<int>.filled(kCells, -1);
    final prev = List<int>.filled(kCells, -1);
    final queue = <int>[from];
    dist[from] = 0;
    for (var i = 0; i < queue.length; i++) {
      final cur = queue[i];
      for (final n in neighbors(cur)) {
        if (dist[n] >= 0) continue;
        dist[n] = dist[cur] + 1;
        prev[n] = cur;
        if (reachedGoal(players, seat, n)) {
          if (pathOut != null) {
            for (var x = n; x != from; x = prev[x]) {
              pathOut.add(x);
            }
            pathOut.setAll(0, pathOut.reversed.toList());
          }
          return dist[n];
        }
        queue.add(n);
      }
    }
    return -1;
  }

  // ── 말 움직이기 ──

  bool occupied(int cell) => pawn.contains(cell);

  /// [seat]의 말이 갈 수 있는 칸들: 이웃한 빈 칸, 이웃에 말이 있으면 그 말을 뛰어넘은 칸
  /// (뒤가 막혔거나 다른 말이 있으면 그 말의 양옆 칸).
  List<int> legalPawnMoves([int? seat]) {
    final p = seat ?? turn;
    final from = pawn[p];
    final out = <int>[];
    final r = from ~/ kBoard, c = from % kBoard;
    for (var d = 0; d < 4; d++) {
      final nr = r + _dr[d], nc = c + _dc[d];
      if (nr < 0 || nr >= kBoard || nc < 0 || nc >= kBoard) continue;
      final n = nr * kBoard + nc;
      if (blockedBetween(from, n)) continue;
      if (!occupied(n)) {
        out.add(n);
        continue;
      }
      // 말을 뛰어넘는다: 바로 뒤 칸
      final jr = nr + _dr[d], jc = nc + _dc[d];
      if (jr >= 0 && jr < kBoard && jc >= 0 && jc < kBoard) {
        final j = jr * kBoard + jc;
        if (!blockedBetween(n, j) && !occupied(j)) {
          out.add(j);
          continue;
        }
      }
      // 뒤가 막혔거나 말이 있으면 양옆으로 비껴 간다
      for (var e = 0; e < 4; e++) {
        if (_dr[e] == _dr[d] && _dc[e] == _dc[d]) continue;
        if (_dr[e] == -_dr[d] && _dc[e] == -_dc[d]) continue;
        final sr = nr + _dr[e], sc = nc + _dc[e];
        if (sr < 0 || sr >= kBoard || sc < 0 || sc >= kBoard) continue;
        final s = sr * kBoard + sc;
        if (!blockedBetween(n, s) && !occupied(s)) out.add(s);
      }
    }
    return out;
  }

  // ── 벽 세우기 ──

  /// 벽을 이 자리에 세울 수 있는가 (겹치거나 십자로 엇갈리지 않고, 누구의 길도 완전히 막지 않고, 남은 벽이 있을 때).
  bool canPlaceWall(int orient, int r, int c, [int? seat]) {
    final p = seat ?? turn;
    if (wallsLeft[p] <= 0) return false;
    if (r < 0 || r >= kAnchors || c < 0 || c >= kAnchors) return false;
    if (!_wallFits(orient, r, c)) return false;
    // 놓아 보고 모든 말에게 길이 남는지 살핀다
    final i = r * kAnchors + c;
    final list = orient == 0 ? h : v;
    list[i] = true;
    var ok = true;
    for (var s = 0; s < players && ok; s++) {
      if (distance(s) < 0) ok = false;
    }
    list[i] = false;
    return ok;
  }

  /// 이미 있는 벽과 겹치거나 엇갈리지 않는가 (길 확인은 따로).
  bool _wallFits(int orient, int r, int c) {
    if (orient == 0) {
      return !hWallAt(r, c) && !vWallAt(r, c) && !hWallAt(r, c - 1) && !hWallAt(r, c + 1);
    }
    return !vWallAt(r, c) && !hWallAt(r, c) && !vWallAt(r - 1, c) && !vWallAt(r + 1, c);
  }

  /// [move]가 지금 차례의 사람이 둘 수 있는 수인가.
  bool isLegal(int move) {
    if (isOver) return false;
    if (isWallMove(move)) {
      final o = wallOrient(move);
      if (move < kWallBase || o > 1) return false;
      return canPlaceWall(o, wallRow(move), wallCol(move));
    }
    return legalPawnMoves().contains(move);
  }

  /// 수를 둔다 ([isLegal]이어야 한다). 말이 도착 줄에 닿으면 끝난다.
  void apply(int move) {
    assert(isLegal(move), '둘 수 없는 수 $move');
    applyTrusted(move);
  }

  /// [apply]와 같지만 규칙에 맞는지 다시 확인하지 않는다 (이미 확인한 수를 탐색에서 빠르게 둘 때).
  void applyTrusted(int move) {
    if (isWallMove(move)) {
      final i = wallRow(move) * kAnchors + wallCol(move);
      (wallOrient(move) == 0 ? h : v)[i] = true;
      (wallOrient(move) == 0 ? hOwner : vOwner)[i] = turn;
      wallsLeft[turn]--;
    } else {
      pawn[turn] = move;
      if (reachedGoal(players, turn, move)) {
        winner = turn;
        moveCount++;
        return;
      }
    }
    moveCount++;
    turn = (turn + 1) % players;
  }

  /// 지금 둘 수 있는 모든 수 (말 이동 + 세울 수 있는 모든 벽).
  List<int> allLegalMoves() {
    final out = [...legalPawnMoves()];
    if (wallsLeft[turn] > 0) {
      for (var o = 0; o < 2; o++) {
        for (var r = 0; r < kAnchors; r++) {
          for (var c = 0; c < kAnchors; c++) {
            if (canPlaceWall(o, r, c)) out.add(wallMove(o, r, c));
          }
        }
      }
    }
    return out;
  }

  /// 칸 [a]에서 이웃한 [b]로 가는 길을 막는 벽 수들 (놓을 수 있는지는 따로 확인).
  static List<int> wallsBlocking(int a, int b) {
    final ar = a ~/ kBoard, ac = a % kBoard, br = b ~/ kBoard, bc = b % kBoard;
    if (ac == bc) {
      final r = ar < br ? ar : br;
      return [
        for (final c in [ac - 1, ac])
          if (r >= 0 && r < kAnchors && c >= 0 && c < kAnchors) wallMove(0, r, c),
      ];
    }
    final c = ac < bc ? ac : bc;
    return [
      for (final r in [ar - 1, ar])
        if (r >= 0 && r < kAnchors && c >= 0 && c < kAnchors) wallMove(1, r, c),
    ];
  }
}
