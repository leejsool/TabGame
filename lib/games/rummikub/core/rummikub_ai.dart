import 'dart:math';

import 'rummikub_rules.dart';

/// CPU 난이도.
enum RkLevel {
  easy('쉬움', '내 타일로만 묶음을 만들어요. 가끔 낼 수 있어도 넘겨요'),
  normal('보통', '판 위의 묶음도 풀어서 다시 맞춰 봐요'),
  hard('어려움', '판 위의 묶음을 아주 꼼꼼하게 다시 맞춰서 최대한 많이 내려놓아요');

  const RkLevel(this.label, this.description);
  final String label;
  final String description;

  /// 한 수를 찾을 때 둘러볼 경우의 수 한도.
  int get budget => switch (this) {
        RkLevel.easy => 4000,
        RkLevel.normal => 20000,
        RkLevel.hard => 120000,
      };
}

/// CPU가 한 차례에 할 일을 고른다.
class RkAi {
  RkAi._();

  /// 이번 차례에 판 위에 만들 묶음들을 돌려준다. 타일을 뽑는 게 낫다면 null.
  ///
  /// [rack]은 내 손, [table]은 판 위의 묶음들, [melded]는 처음 내려놓기를 마쳤는지.
  static List<List<int>>? plan({
    required List<int> rack,
    required List<List<int>> table,
    required bool melded,
    required RkLevel level,
    required Random rng,
  }) {
    final need = melded ? 0 : kInitialMeldPoints;
    // ① 내 타일로만 새 묶음을 만든다 (판 위는 그대로).
    final own = _Solver(mandatory: const [], optional: rack, need: need, budget: level.budget).solve();
    var best = own == null ? null : (placed: own.placed, score: own.score, sets: [for (final s in table) [...s], ...own.sets]);

    // ② 이미 내려놓은 적이 있으면 판 위의 묶음을 풀어서 다시 맞춘다.
    if (melded && level != RkLevel.easy && table.isNotEmpty) {
      final all = _Solver(mandatory: [for (final s in table) ...s], optional: rack, need: 0, budget: level.budget).solve();
      if (all != null && (best == null || all.score > best.score)) {
        best = (placed: all.placed, score: all.score, sets: all.sets);
      }
    }
    if (best == null || best.placed == 0) return null;
    // 쉬움: 낼 수 있어도 가끔 넘긴다 (손을 다 비울 수 있을 때는 빼고).
    if (level == RkLevel.easy && best.placed < rack.length && rng.nextInt(100) < 25) return null;
    return best.sets;
  }
}

class _Result {
  _Result(this.placed, this.score, this.sets);
  final int placed;
  final int score;
  final List<List<int>> sets;
}

/// 묶음 후보: 칸마다 타일 종류 번호(조커는 -1)와 묶음의 점수.
class _Cand {
  const _Cand(this.cells, this.value);
  final List<int> cells;
  final int value;
}

/// 판 위 타일(꼭 써야 함)과 내 타일(쓰든 말든 됨)을 모두 올바른 묶음들로 나누어, 내 타일을 가장 많이 쓰는 방법을 찾는다.
///
/// 타일 종류(색×숫자 52가지, 각각 최대 2장)를 순서대로 훑으면서, 아직 남은 가장 앞 종류를 포함하는 묶음을 하나씩 정한다.
/// 판 위 타일을 먼저 쓰는 것으로 세고, 정해진 경우의 수([budget])를 넘으면 그때까지 찾은 최선을 돌려준다.
class _Solver {
  _Solver({required List<int> mandatory, required List<int> optional, required this.need, required this.budget}) {
    for (final t in mandatory) {
      if (isJoker(t)) {
        _tableJ.add(t);
        _mj++;
      } else {
        _tableIds[_type(t)].add(t);
        _m[_type(t)]++;
      }
    }
    for (final t in optional) {
      if (isJoker(t)) {
        _rackJ.add(t);
        _oj++;
      } else {
        _rackIds[_type(t)].add(t);
        _o[_type(t)]++;
      }
    }
    _rackSize = optional.length;
    _optTotal = _rackSize;
  }

  /// 새로 만든 묶음들의 점수 합이 이 이상이어야 한다 (처음 내려놓기).
  final int need;
  final int budget;

  static int _type(int id) => colorOf(id) * kMaxNumber + numberOf(id) - 1;

  final List<int> _m = List.filled(52, 0); // 종류별 남은 판 위 타일 수
  final List<int> _o = List.filled(52, 0); // 종류별 남은 내 타일 수
  final List<List<int>> _tableIds = List.generate(52, (_) => []);
  final List<List<int>> _rackIds = List.generate(52, (_) => []);
  final List<int> _tableJ = [], _rackJ = [];
  int _mj = 0, _oj = 0; // 남은 판 위 조커 / 내 조커

  late final int _rackSize;
  int _optTotal = 0; // 아직 쓰지도 버리지도 않은 내 타일 수
  int _placed = 0; // 지금까지 쓴 내 타일 수
  int _jokersFromRack = 0;
  int _value = 0;
  int _nodes = 0;

  final List<List<int>> _melds = [];

  int _bestScore = -1;
  _Result? _best;

  _Result? solve() {
    _dfs(0);
    return _best;
  }

  int _tilesLeft(int t) => _m[t] + _o[t];

  void _dfs(int from) {
    if (_nodes++ > budget) return;
    // 남은 내 타일을 전부 써도 지금까지의 최고를 넘지 못하면 그만둔다.
    final reach = _placed + _optTotal;
    if (reach * 2 + (reach == _rackSize ? 1000 : 0) <= _bestScore) return;
    var t = from;
    while (t < 52 && _tilesLeft(t) == 0) {
      t++;
    }
    if (t == 52) {
      _leaf();
      return;
    }
    for (final cand in _candidates(t)) {
      final taken = _apply(cand);
      _dfs(t);
      _undo(cand, taken);
      if (_nodes > budget) return;
    }
    // 내 타일만 남은 종류는 쓰지 않고 손에 둘 수도 있다.
    if (_m[t] == 0) {
      final dropped = _o[t];
      _o[t] = 0;
      _optTotal -= dropped;
      _dfs(t + 1);
      _o[t] = dropped;
      _optTotal += dropped;
    }
  }

  void _leaf() {
    if (_mj > 0 || _value < need) return; // 판 위의 조커는 꼭 다시 써야 한다
    // 많이 낼수록 좋고, 손을 다 비우면 가장 좋다. 내 조커는 아껴 두는 쪽을 조금 더 친다.
    final score = _placed * 2 - _jokersFromRack + (_placed == _rackSize ? 1000 : 0);
    if (score <= _bestScore) return;
    _bestScore = score;
    _best = _Result(_placed, score, _assemble());
  }

  /// 타일 종류 [t]를 포함하고 [t]가 가장 앞인 묶음 후보들 (조커 적은 순, 타일 많은 순).
  List<_Cand> _candidates(int t) {
    final color = t ~/ kMaxNumber, number = t % kMaxNumber + 1;
    final jokersLeft = _mj + _oj;
    final out = <_Cand>[];

    // 런: number부터 위로 한 칸씩 늘린다. 타일이 없으면 조커로 메운다.
    final cells = <int>[t];
    var jokers = 0, sum = number, p = number + 1;
    while (true) {
      if (cells.length >= 3) out.add(_Cand([...cells], sum));
      if (p > kMaxNumber) break;
      final idx = color * kMaxNumber + p - 1;
      if (_tilesLeft(idx) > 0) {
        cells.add(idx);
      } else if (jokers < jokersLeft) {
        cells.add(-1);
        jokers++;
      } else {
        break;
      }
      sum += p++;
    }
    // 13에서 끝나는데 3장이 안 되면 앞쪽에 조커를 붙인다 (예: 조커 12 13).
    if (p > kMaxNumber && cells.length < 3) {
      for (var lead = 1; lead <= 2 && number - lead >= 1 && jokers + lead <= jokersLeft; lead++) {
        if (cells.length + lead < 3) continue;
        var v = sum;
        for (var q = number - lead; q < number; q++) {
          v += q;
        }
        out.add(_Cand([...List.filled(lead, -1), ...cells], v));
      }
    }

    // 그룹: 같은 숫자에서 이 색 + 더 큰 색들 중 일부 (+ 조커)
    final higher = <int>[];
    for (var c = color + 1; c < kColors; c++) {
      final idx = c * kMaxNumber + number - 1;
      if (_tilesLeft(idx) > 0) higher.add(idx);
    }
    for (var mask = 0; mask < (1 << higher.length); mask++) {
      final chosen = [for (var i = 0; i < higher.length; i++) if (mask & (1 << i) != 0) higher[i]];
      for (var j = 0; j <= 2 && j <= jokersLeft; j++) {
        final size = 1 + chosen.length + j;
        if (size < 3 || size > kColors) continue;
        out.add(_Cand([t, ...chosen, ...List.filled(j, -1)], number * size));
      }
    }

    int jokerCount(_Cand c) => c.cells.where((x) => x < 0).length;
    out.sort((a, b) {
      final d = jokerCount(a).compareTo(jokerCount(b));
      return d != 0 ? d : b.cells.length.compareTo(a.cells.length);
    });
    return out;
  }

  /// 후보를 쓴다. 칸마다 판 위 타일에서 가져왔는지(true), 내 타일에서 가져왔는지(false)를 돌려준다 (판 위 타일을 먼저 쓴다).
  List<bool> _apply(_Cand cand) {
    final taken = <bool>[];
    for (final c in cand.cells) {
      if (c < 0) {
        if (_mj > 0) {
          _mj--;
          taken.add(true);
        } else {
          _oj--;
          _placed++;
          _jokersFromRack++;
          _optTotal--;
          taken.add(false);
        }
      } else if (_m[c] > 0) {
        _m[c]--;
        taken.add(true);
      } else {
        _o[c]--;
        _placed++;
        _optTotal--;
        taken.add(false);
      }
    }
    _value += cand.value;
    _melds.add(cand.cells);
    return taken;
  }

  void _undo(_Cand cand, List<bool> taken) {
    _melds.removeLast();
    _value -= cand.value;
    for (var i = cand.cells.length - 1; i >= 0; i--) {
      final c = cand.cells[i];
      if (c < 0) {
        if (taken[i]) {
          _mj++;
        } else {
          _oj++;
          _placed--;
          _jokersFromRack--;
          _optTotal++;
        }
      } else if (taken[i]) {
        _m[c]++;
      } else {
        _o[c]++;
        _placed--;
        _optTotal++;
      }
    }
  }

  /// 지금까지 정한 묶음들을 실제 타일 번호표로 바꾼다.
  List<List<int>> _assemble() {
    final tableIds = [for (final l in _tableIds) [...l]];
    final rackIds = [for (final l in _rackIds) [...l]];
    final tj = [..._tableJ], rj = [..._rackJ];
    final sets = <List<int>>[];
    for (final meld in _melds) {
      final tiles = <int>[];
      for (final c in meld) {
        if (c < 0) {
          tiles.add(tj.isNotEmpty ? tj.removeLast() : rj.removeLast());
        } else {
          tiles.add(tableIds[c].isNotEmpty ? tableIds[c].removeLast() : rackIds[c].removeLast());
        }
      }
      sets.add(tiles);
    }
    return sets;
  }
}
