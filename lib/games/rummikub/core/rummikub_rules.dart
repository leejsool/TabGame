import 'dart:math';

/// 루미큐브의 규칙 (화면·네트워크와 무관한 순수 계산).
///
/// 타일은 0~105 번호표(id)로 나타낸다.
///  - 0~103: 숫자 타일. 같은 타일이 2벌씩 있다. `copy = id ~/ 52`, `color = (id % 52) ~/ 13`, `number = id % 13 + 1`.
///  - 104, 105: 조커.
/// 색은 0 검정, 1 파랑, 2 빨강, 3 주황.
const int kColors = 4;
const int kMaxNumber = 13;
const int kTileCount = 106;
const int kJokerA = 104;
const int kJokerB = 105;

/// 처음에 나눠 주는 타일 수와, 처음 내려놓을 때 필요한 점수.
const int kRackSize = 14;
const int kInitialMeldPoints = 30;

/// 조커가 손에 남았을 때의 벌점.
const int kJokerPenalty = 30;

bool isJoker(int id) => id >= 104;
int colorOf(int id) => (id % 52) ~/ kMaxNumber;
int numberOf(int id) => id % kMaxNumber + 1;

/// 색 [color], 숫자 [number]인 타일의 번호표 ([copy]는 0 또는 1).
int tileId(int color, int number, [int copy = 0]) => copy * 52 + color * kMaxNumber + (number - 1);

/// 타일의 점수 (손에 남은 타일의 벌점): 숫자 그대로, 조커는 30점.
int tilePoints(int id) => isJoker(id) ? kJokerPenalty : numberOf(id);

/// 묶음 하나를 살핀 결과.
class Meld {
  const Meld(this.value, this.order, this.isRun);

  /// 묶음의 점수 (조커는 대신하는 타일의 숫자로 센다. 여러 가지로 볼 수 있으면 높은 쪽).
  final int value;

  /// 눈에 보이는 순서로 늘어놓은 타일들 (런은 작은 숫자부터, 그룹은 색 순서).
  final List<int> order;

  /// 런(같은 색 연속 숫자)이면 true, 그룹(같은 숫자 다른 색)이면 false.
  final bool isRun;
}

/// 타일들이 올바른 묶음이면 [Meld]를, 아니면 null.
///
///  - 그룹: 같은 숫자, 서로 다른 색 3~4장
///  - 런: 같은 색, 이어지는 숫자 3장 이상 (13 다음에 1은 안 이어진다)
///  - 조커는 어느 타일 대신으로도 쓸 수 있다.
Meld? analyzeMeld(List<int> tiles) {
  final n = tiles.length;
  if (n < 3 || n > kMaxNumber) return null;
  final jokers = tiles.where(isJoker).length;
  final plain = [for (final t in tiles) if (!isJoker(t)) t];
  if (plain.isEmpty) return null;

  Meld? best;
  void consider(Meld? m) {
    if (m != null && (best == null || m.value > best!.value)) best = m;
  }

  // 그룹
  if (n <= kColors) {
    final num = numberOf(plain.first);
    final colors = <int>{};
    var ok = true;
    for (final t in plain) {
      if (numberOf(t) != num || !colors.add(colorOf(t))) ok = false;
    }
    if (ok) {
      final sorted = [...plain]..sort((a, b) => colorOf(a).compareTo(colorOf(b)));
      consider(Meld(num * n, [...sorted, ...tiles.where(isJoker)], false));
    }
  }

  // 런
  final color = colorOf(plain.first);
  if (plain.every((t) => colorOf(t) == color)) {
    final nums = [for (final t in plain) numberOf(t)]..sort();
    var distinct = true;
    for (var i = 1; i < nums.length; i++) {
      if (nums[i] == nums[i - 1]) distinct = false;
    }
    if (distinct) {
      final lo = nums.first, hi = nums.last;
      final gaps = (hi - lo + 1) - nums.length;
      if (gaps <= jokers && n <= kMaxNumber) {
        // 시작 숫자 s: 모든 숫자를 덮고(s ≤ lo, s+n-1 ≥ hi) 1~13 안에 들어야 한다. 가장 큰 s가 점수가 가장 높다.
        final s = min(lo, kMaxNumber + 1 - n);
        if (s >= 1 && s + n - 1 >= hi) {
          final byNumber = {for (final t in plain) numberOf(t): t};
          final jokerIds = tiles.where(isJoker).toList();
          var j = 0;
          final order = <int>[];
          var value = 0;
          for (var p = s; p < s + n; p++) {
            value += p;
            order.add(byNumber[p] ?? jokerIds[j++]);
          }
          consider(Meld(value, order, true));
        }
      }
    }
  }
  return best;
}

/// 묶음 하나가 올바른가.
bool isValidMeld(List<int> tiles) => analyzeMeld(tiles) != null;

/// 올바른 묶음이면 보기 좋은 순서로 정렬해서, 아니면 숫자·색 순서로 늘어놓는다 (화면에 그릴 때 쓴다).
List<int> arrangeSet(List<int> tiles) {
  final m = analyzeMeld(tiles);
  if (m != null) return m.order;
  return [...tiles]..sort(compareByNumber);
}

/// 숫자 순서(같은 숫자는 색 순서), 조커는 맨 뒤.
int compareByNumber(int a, int b) {
  if (isJoker(a) != isJoker(b)) return isJoker(a) ? 1 : -1;
  if (isJoker(a)) return a.compareTo(b);
  final c = numberOf(a).compareTo(numberOf(b));
  return c != 0 ? c : colorOf(a).compareTo(colorOf(b)) != 0 ? colorOf(a).compareTo(colorOf(b)) : a.compareTo(b);
}

/// 색 순서(같은 색은 숫자 순서), 조커는 맨 뒤.
int compareByColor(int a, int b) {
  if (isJoker(a) != isJoker(b)) return isJoker(a) ? 1 : -1;
  if (isJoker(a)) return a.compareTo(b);
  final c = colorOf(a).compareTo(colorOf(b));
  return c != 0 ? c : numberOf(a).compareTo(numberOf(b)) != 0 ? numberOf(a).compareTo(numberOf(b)) : a.compareTo(b);
}

/// 한 번의 차례를 확인한 결과가 틀렸을 때의 이유.
enum PlayError {
  /// 판 위의 타일을 손으로 가져갔거나, 없는 타일이 있다.
  tilesMismatch('판 위의 타일은 손으로 가져올 수 없어요'),

  /// 내 손에서 한 장도 내려놓지 않았다.
  nothingPlaced('내 타일을 한 장 이상 내려놓아야 해요'),

  /// 올바르지 않은 묶음이 있다.
  badSet('올바르지 않은 묶음이 있어요'),

  /// 처음 내려놓을 때 점수가 모자란다.
  needPoints('처음에는 내 타일로만 합쳐서 30점 이상 내려놓아야 해요'),

  /// 처음 내려놓을 때는 판 위의 묶음을 건드릴 수 없다.
  touchedTable('처음 내려놓을 때는 판 위의 묶음을 건드릴 수 없어요');

  const PlayError(this.message);
  final String message;
}

/// 루미큐브 한 판의 상태.
///
/// [RkState.deal]은 같은 [seed]면 언제나 같은 패를 나눈다. 같은 Wi‑Fi 대결에서는 두 기기가 같은 씨앗으로 시작해서
/// 서로의 "수"(차례에 만든 판의 모습, 또는 타일 뽑기)만 주고받으면 같은 판이 된다.
class RkState {
  RkState._(this.players, this.racks, this.pool, this.table, this.melded);

  /// 씨앗으로 패를 나눈다. 첫 차례는 0번.
  factory RkState.deal(int players, int seed) {
    assert(players >= 2 && players <= 4);
    final ids = List<int>.generate(kTileCount, (i) => i)..shuffle(Random(seed));
    final racks = <List<int>>[];
    for (var p = 0; p < players; p++) {
      racks.add(ids.sublist(p * kRackSize, (p + 1) * kRackSize));
    }
    final pool = ids.sublist(players * kRackSize);
    return RkState._(players, racks, pool, [], List.filled(players, false));
  }

  RkState clone() {
    final s = RkState._(players, [for (final r in racks) [...r]], [...pool], [for (final t in table) [...t]], [...melded]);
    s.turn = turn;
    s.passStreak = passStreak;
    s.over = over;
    s.winner = winner;
    s.turnCount = turnCount;
    return s;
  }

  final int players;

  /// 사람마다 손에 든 타일.
  final List<List<int>> racks;

  /// 더미에 남은 타일 (바닥에 엎어 둔 타일들). 뽑는 사람이 그중 한 장을 직접 고른다.
  final List<int> pool;

  /// 판 위의 묶음들.
  final List<List<int>> table;

  /// 처음 내려놓기(30점)를 마쳤는지.
  final List<bool> melded;

  int turn = 0;

  /// 연달아 "뽑을 게 없어서 넘긴" 차례 수 (더미가 비었을 때만 늘어난다).
  int passStreak = 0;

  bool over = false;

  /// 이긴 사람 (끝났는데 null이면 무승부).
  int? winner;

  /// 지금까지 지나간 차례 수.
  int turnCount = 0;

  List<int> get currentRack => racks[turn];

  int get poolCount => pool.length;

  /// 손에 남은 타일의 벌점 합.
  int rackPoints(int p) => racks[p].fold(0, (a, t) => a + tilePoints(t));

  /// 판 위 타일 전부.
  List<int> get tableTiles => [for (final s in table) ...s];

  /// 묶음들 [newTable]을 이번 차례의 결과로 내려놓을 수 있는지 살핀다. 괜찮으면 null.
  PlayError? checkPlay(List<List<int>> newTable) {
    final sets = [for (final s in newTable) if (s.isNotEmpty) s];
    final newTiles = [for (final s in sets) ...s];
    final newSet = newTiles.toSet();
    if (newSet.length != newTiles.length) return PlayError.tilesMismatch;
    final oldTiles = tableTiles;
    for (final t in oldTiles) {
      if (!newSet.contains(t)) return PlayError.tilesMismatch;
    }
    final oldSet = oldTiles.toSet();
    final rackSet = racks[turn].toSet();
    final placed = <int>[];
    for (final t in newTiles) {
      if (oldSet.contains(t)) continue;
      if (!rackSet.contains(t)) return PlayError.tilesMismatch;
      placed.add(t);
    }
    if (placed.isEmpty) return PlayError.nothingPlaced;

    final melds = <Meld>[];
    for (final s in sets) {
      final m = analyzeMeld(s);
      if (m == null) return PlayError.badSet;
      melds.add(m);
    }

    if (!melded[turn]) {
      // 판 위의 묶음은 그대로 있어야 한다.
      final remaining = [for (final s in sets) _key(s)];
      for (final s in table) {
        if (!remaining.remove(_key(s))) return PlayError.touchedTable;
      }
      if (_newPoints(sets, melds) < kInitialMeldPoints) return PlayError.needPoints;
    }
    return null;
  }

  static String _key(List<int> s) => ([...s]..sort()).join(',');

  /// 판 위에 원래 있던 묶음을 한 번씩 빼고 남은 묶음들의 점수 합.
  int _newPoints(List<List<int>> sets, List<Meld> melds) {
    final olds = [for (final s in table) _key(s)];
    var points = 0;
    for (var i = 0; i < sets.length; i++) {
      if (olds.remove(_key(sets[i]))) continue;
      points += melds[i].value;
    }
    return points;
  }

  /// 차례의 결과를 적용한다 ([checkPlay]가 통과해야 한다). 손이 비면 끝난다.
  void applyPlay(List<List<int>> newTable) {
    assert(checkPlay(newTable) == null);
    final sets = [for (final s in newTable) if (s.isNotEmpty) arrangeSet(s)];
    final used = {for (final s in sets) ...s};
    racks[turn].removeWhere((t) => used.contains(t));
    table
      ..clear()
      ..addAll(sets);
    melded[turn] = true;
    passStreak = 0;
    turnCount++;
    if (racks[turn].isEmpty) {
      over = true;
      winner = turn;
      return;
    }
    turn = (turn + 1) % players;
  }

  /// 더미(바닥에 엎어 둔 타일들)에서 [index]번째 타일을 한 장 뽑고 차례를 넘긴다 ([index]가 없으면 맨 뒤 한 장).
  /// 더미가 비었으면 그냥 넘긴다. 뽑은 타일 (없으면 null).
  int? applyDraw([int? index]) {
    int? drawn;
    if (pool.isNotEmpty) {
      final i = index ?? pool.length - 1;
      assert(i >= 0 && i < pool.length);
      drawn = pool.removeAt(i);
      racks[turn].add(drawn);
      passStreak = 0;
    } else {
      passStreak++;
    }
    turnCount++;
    if (pool.isEmpty && passStreak >= players) {
      // 아무도 더 낼 수 없다: 손에 남은 벌점이 가장 낮은 사람이 이긴다 (같으면 무승부).
      over = true;
      var bestP = -1, bestV = 1 << 30;
      var tie = false;
      for (var p = 0; p < players; p++) {
        final v = rackPoints(p);
        if (v < bestV) {
          bestV = v;
          bestP = p;
          tie = false;
        } else if (v == bestV) {
          tie = true;
        }
      }
      winner = tie ? null : bestP;
      return drawn;
    }
    turn = (turn + 1) % players;
    return drawn;
  }

  /// 판이 끝났을 때 이긴 사람이 얻는 점수: 다른 사람들이 손에 남긴 벌점의 합.
  int get winnerBonus {
    final w = winner;
    if (w == null) return 0;
    var sum = 0;
    for (var p = 0; p < players; p++) {
      if (p != w) sum += rackPoints(p);
    }
    return sum;
  }
}
