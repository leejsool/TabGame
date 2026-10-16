import 'dart:math';

/// 다빈치 코드의 규칙 (화면·네트워크와 무관한 순수 계산).
///
/// 타일은 26장: 검정 0~11, 흰색 0~11, 그리고 조커("‑") 검정·흰색 한 장씩. 번호표(id)는
///  - 0~11: 검정 0~11
///  - 12~23: 흰색 0~11
///  - 24: 검정 조커, 25: 흰색 조커
/// 사람마다 타일을 숫자가 작은 쪽부터 왼쪽에서 오른쪽으로 늘어놓고(같은 숫자면 검정이 먼저, 조커는 아무 데나) 자기 것만 본다.
/// 차례마다 타일 한 장을 뽑고, 상대 타일의 숫자를 맞힌다. 맞히면 그 타일이 공개되고 계속 맞히거나 멈출 수 있다.
/// 틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어간다. 숨은 타일이 모두 공개되면 탈락, 마지막까지 남은 사람이 이긴다.
const int kDvNumbers = 12; // 0~11
const int kDvTiles = 26;
const int kJokerGuess = 12; // 숫자를 맞힐 때 "조커"를 가리키는 값

bool dvIsJoker(int id) => id >= 24;

/// 0 = 검정, 1 = 흰색.
int dvColor(int id) => id >= 24 ? id - 24 : id ~/ kDvNumbers;

/// 숫자 (조커는 -1).
int dvNumber(int id) => id >= 24 ? -1 : id % kDvNumbers;

int dvTile(int color, int number) => color * kDvNumbers + number;

/// 두 숫자 타일의 순서: 숫자가 작은 쪽이 앞, 같으면 검정이 앞. (조커는 순서에 끼지 않는다)
int dvCompare(int a, int b) {
  final n = dvNumber(a).compareTo(dvNumber(b));
  return n != 0 ? n : dvColor(a).compareTo(dvColor(b));
}

/// 한 차례 안에서 지금 할 일.
enum DvPhase {
  /// 더미(검정/흰색)에서 타일을 한 장 뽑는다.
  draw,

  /// 뽑은 조커를 내 줄의 어느 자리에 놓을지 고른다.
  placeJoker,

  /// 상대 타일 하나를 골라 숫자를 맞힌다.
  guess,

  /// 맞혔다: 계속 맞히거나 멈춘다.
  decide,

  /// 틀렸는데 방금 뽑은 타일이 없다(더미가 비었다): 내 숨은 타일 하나를 직접 공개한다.
  reveal,
}

/// 한 수의 종류 (수는 `[종류, …]` 정수 목록으로 나타낸다).
class DvMove {
  const DvMove._();

  /// `[0, 색]` 더미에서 뽑기 (0 검정, 1 흰색).
  static List<int> drawMove(int color) => [0, color];

  /// `[1, 자리]` 뽑은 조커를 내 줄 [자리]번째 칸에 놓기 (0 = 맨 왼쪽).
  static List<int> placeJoker(int pos) => [1, pos];

  /// `[2, 상대 자리, 타일 순서, 숫자]` 상대의 [타일 순서]번째 타일이 [숫자]라고 맞히기 (조커는 [kJokerGuess]).
  static List<int> guess(int seat, int index, int number) => [2, seat, index, number];

  /// `[3]` 맞힌 뒤 멈추기.
  static const List<int> stop = [3];

  /// `[4, 순서]` 내 숨은 타일 하나를 직접 공개하기.
  static List<int> reveal(int index) => [4, index];
}

/// 마지막으로 일어난 맞히기 (화면 안내와 애니메이션용).
class DvGuessEvent {
  const DvGuessEvent({required this.guesser, required this.target, required this.tile, required this.index, required this.number, required this.correct});

  final int guesser, target;

  /// 맞히려던 타일의 번호표 (맞힌 뒤에는 공개된다).
  final int tile;
  final int index;
  final int number;
  final bool correct;
}

/// 다빈치 코드 한 판의 상태.
class DvState {
  DvState._(this.players, this.rows, this.blackPool, this.whitePool);

  /// 씨앗으로 섞어 나눈다. 처음에는 2명이면 4장, 3~4명이면 3장씩 받는다 (조커는 무작위 자리에 놓인다). 첫 차례는 0번.
  factory DvState.deal(int players, int seed) {
    assert(players >= 2 && players <= 4);
    final rng = Random(seed);
    final ids = List<int>.generate(kDvTiles, (i) => i)..shuffle(rng);
    final each = players == 2 ? 4 : 3;
    final rows = <List<int>>[];
    var at = 0;
    for (var p = 0; p < players; p++) {
      final hand = ids.sublist(at, at + each);
      at += each;
      rows.add(_arrange(hand, rng));
    }
    final rest = ids.sublist(at);
    final black = [for (final t in rest) if (dvColor(t) == 0) t];
    final white = [for (final t in rest) if (dvColor(t) == 1) t];
    final s = DvState._(players, rows, black, white);
    s._startTurn();
    return s;
  }

  /// 타일들을 순서대로 늘어놓는다. 조커는 순서에 끼지 않으니 무작위 자리에 끼워 넣는다.
  static List<int> _arrange(List<int> hand, Random rng) {
    final plain = [for (final t in hand) if (!dvIsJoker(t)) t]..sort(dvCompare);
    final jokers = [for (final t in hand) if (dvIsJoker(t)) t];
    final row = [...plain];
    for (final j in jokers) {
      row.insert(rng.nextInt(row.length + 1), j);
    }
    return row;
  }

  DvState clone() {
    final s = DvState._(players, [for (final r in rows) [...r]], [...blackPool], [...whitePool]);
    s.revealed.addAll(revealed);
    s.turn = turn;
    s.phase = phase;
    s.drawn = drawn;
    s.pendingJoker = pendingJoker;
    s.winner = winner;
    s.turnCount = turnCount;
    s.lastGuess = lastGuess;
    s.guessedThisTurn = guessedThisTurn;
    return s;
  }

  final int players;

  /// 사람마다 타일 줄 (왼쪽 → 오른쪽).
  final List<List<int>> rows;

  /// 공개된(모두가 볼 수 있는) 타일들.
  final Set<int> revealed = {};

  /// 더미에 남은 타일 (색별, 맨 뒤에서부터 뽑는다).
  final List<int> blackPool, whitePool;

  int turn = 0;
  DvPhase phase = DvPhase.draw;

  /// 이번 차례에 뽑아서 내 줄에 끼워 넣은 타일 (틀리면 공개된다). 없으면 null.
  int? drawn;

  /// 뽑았지만 아직 자리를 못 정한 조커.
  int? pendingJoker;

  /// 이긴 사람 (끝나기 전에는 null).
  int? winner;

  /// 지금까지 지난 차례 수.
  int turnCount = 0;

  /// 가장 최근의 맞히기.
  DvGuessEvent? lastGuess;

  /// 이번 차례에 맞히기를 한 번이라도 했는가.
  bool guessedThisTurn = false;

  bool get isOver => winner != null;

  // ── 조회 ──

  bool isRevealed(int tile) => revealed.contains(tile);

  /// [seat]의 숨은 타일 수.
  int hiddenCount(int seat) => rows[seat].where((t) => !revealed.contains(t)).length;

  /// 모든 타일이 공개되어 탈락했는가.
  bool isOut(int seat) => hiddenCount(seat) == 0;

  int get alive => [for (var p = 0; p < players; p++) if (!isOut(p)) p].length;

  int get poolCount => blackPool.length + whitePool.length;
  int poolOf(int color) => color == 0 ? blackPool.length : whitePool.length;

  /// 지금 차례인 사람이 더미에서 뽑을 수 있는 색들.
  List<int> get drawableColors => [if (blackPool.isNotEmpty) 0, if (whitePool.isNotEmpty) 1];

  // ── 수 두기 ──

  bool isLegal(List<int> m) {
    if (isOver || m.isEmpty) return false;
    switch (m[0]) {
      case 0:
        return phase == DvPhase.draw && m.length == 2 && (m[1] == 0 || m[1] == 1) && poolOf(m[1]) > 0;
      case 1:
        return phase == DvPhase.placeJoker && m.length == 2 && m[1] >= 0 && m[1] <= rows[turn].length - 1 + 1 && pendingJoker != null;
      case 2:
        if ((phase != DvPhase.guess && phase != DvPhase.decide) || m.length != 4) return false;
        final seat = m[1], idx = m[2], number = m[3];
        if (seat < 0 || seat >= players || seat == turn || isOut(seat)) return false;
        if (idx < 0 || idx >= rows[seat].length || revealed.contains(rows[seat][idx])) return false;
        return number >= 0 && number <= kJokerGuess;
      case 3:
        return phase == DvPhase.decide && m.length == 1;
      case 4:
        if (phase != DvPhase.reveal || m.length != 2) return false;
        final i = m[1];
        return i >= 0 && i < rows[turn].length && !revealed.contains(rows[turn][i]);
    }
    return false;
  }

  /// 수를 둔다 ([isLegal]이어야 한다).
  void apply(List<int> m) {
    assert(isLegal(m), '둘 수 없는 수 $m');
    switch (m[0]) {
      case 0:
        final tile = (m[1] == 0 ? blackPool : whitePool).removeLast();
        if (dvIsJoker(tile)) {
          pendingJoker = tile;
          phase = DvPhase.placeJoker;
        } else {
          _insert(turn, tile);
          drawn = tile;
          phase = DvPhase.guess;
        }
      case 1:
        final j = pendingJoker!;
        rows[turn].insert(m[1], j);
        drawn = j;
        pendingJoker = null;
        phase = DvPhase.guess;
      case 2:
        _guess(m[1], m[2], m[3]);
      case 3:
        _endTurn();
      case 4:
        revealed.add(rows[turn][m[1]]);
        _endTurn();
    }
  }

  void _guess(int seat, int idx, int number) {
    final tile = rows[seat][idx];
    final correct = number == kJokerGuess ? dvIsJoker(tile) : (!dvIsJoker(tile) && dvNumber(tile) == number);
    lastGuess = DvGuessEvent(guesser: turn, target: seat, tile: tile, index: idx, number: number, correct: correct);
    guessedThisTurn = true;
    if (correct) {
      revealed.add(tile);
      if (alive <= 1) {
        winner = turn;
        return;
      }
      phase = DvPhase.decide;
      return;
    }
    // 틀렸다: 방금 뽑은 타일이 있으면 공개되고 차례가 넘어간다. 없으면 내 타일 하나를 직접 공개한다.
    final d = drawn;
    if (d != null && !revealed.contains(d)) {
      revealed.add(d);
      _endTurn();
    } else {
      phase = DvPhase.reveal;
      if (hiddenCount(turn) == 0) _endTurn();
    }
  }

  /// 숫자 순서에 맞는 자리에 끼워 넣는다 (조커는 순서에 끼지 않으니 건너뛴다).
  void _insert(int seat, int tile) {
    final row = rows[seat];
    var at = 0;
    for (var i = 0; i < row.length; i++) {
      if (dvIsJoker(row[i])) continue;
      if (dvCompare(row[i], tile) < 0) at = i + 1;
    }
    row.insert(at, tile);
  }

  void _endTurn() {
    turnCount++;
    if (alive <= 1) {
      // 남은 사람 하나: 그 사람이 이긴다
      winner = [for (var p = 0; p < players; p++) if (!isOut(p)) p].first;
      return;
    }
    var next = turn;
    do {
      next = (next + 1) % players;
    } while (isOut(next));
    turn = next;
    _startTurn();
  }

  void _startTurn() {
    drawn = null;
    pendingJoker = null;
    guessedThisTurn = false;
    // 더미가 비었으면 뽑지 않고 바로 맞힌다
    phase = drawableColors.isEmpty ? DvPhase.guess : DvPhase.draw;
  }

  // ── 맞히기 후보 ──

  /// [viewer]가 가진 정보로 볼 때, [seat]의 [idx]번째 타일이 될 수 있는 숫자들 (조커는 [kJokerGuess]).
  /// 내 타일·공개된 타일은 후보에서 빼고, 양옆의 공개된 타일과의 순서에 맞는 숫자만 남긴다.
  List<int> candidates(int viewer, int seat, int idx) {
    final tile = rows[seat][idx];
    final color = dvColor(tile);
    final known = <int>{...revealed, ...rows[viewer]};
    final row = rows[seat];
    int? left, right;
    for (var i = idx - 1; i >= 0; i--) {
      if (!dvIsJoker(row[i]) && (revealed.contains(row[i]) || seat == viewer)) {
        left = row[i];
        break;
      }
    }
    for (var i = idx + 1; i < row.length; i++) {
      if (!dvIsJoker(row[i]) && (revealed.contains(row[i]) || seat == viewer)) {
        right = row[i];
        break;
      }
    }
    final out = <int>[];
    for (var n = 0; n < kDvNumbers; n++) {
      final t = dvTile(color, n);
      if (known.contains(t)) continue;
      if (left != null && dvCompare(left, t) > 0) continue;
      if (right != null && dvCompare(t, right) > 0) continue;
      out.add(n);
    }
    // 조커는 어디에나 있을 수 있다 (같은 색 조커를 아직 모르면)
    if (!known.contains(24 + color)) out.add(kJokerGuess);
    return out;
  }
}
