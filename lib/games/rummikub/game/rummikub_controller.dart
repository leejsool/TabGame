import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../../core/game_info.dart';
import '../../../versus/cpu_turn.dart';
import '../core/rummikub_ai.dart';
import '../core/rummikub_rules.dart';
import 'rummikub_layout.dart';

/// 루미큐브 한 판의 진행 (규칙 + 내 손/판 만지기 + CPU + 같은 Wi‑Fi 상대의 수 받기).
///
/// 남의 패가 보이면 안 되니 사람끼리는 같은 Wi‑Fi로 각자 기기에서만 한다 ([PlayMode.wifi], 2명).
/// [PlayMode.vsCpu]는 내가 한 명이고 나머지(1~3명)는 CPU다. 나는 [humanSeat]번째 자리다.
///
/// 내 차례에는 판 위 묶음 복사본([work])과 내 손([hand])을 마음껏 옮겨 보다가, 올바르게 맞춰졌을 때 [endTurn]으로 내놓는다.
/// 맞추기 어려우면 [reset]으로 처음 모습으로 돌리거나 [draw]로 타일을 뽑고 차례를 넘긴다.
class RummikubController extends ChangeNotifier {
  RummikubController({
    required this.mode,
    this.players = 2,
    this.humanSeat = 0,
    this.level = RkLevel.normal,
    int? seed,
    this.animate = true,
  }) : seed = seed ?? Random().nextInt(1 << 30) {
    assert(mode == PlayMode.vsCpu || (mode == PlayMode.wifi && players == 2));
    _deal();
  }

  final PlayMode mode;
  final int players;

  /// CPU와 상대 기기의 수를 타일을 한 장씩 옮기는 모습으로 보여 주는가 (시험에서는 끄고 한 번에 반영한다).
  final bool animate;

  /// 이 기기에서 내가 맡은 자리 (0 = 먼저). 한 판 더 할 때마다 한 칸씩 돈다.
  int humanSeat;
  final RkLevel level;

  /// 패를 나눈 씨앗. 같은 Wi‑Fi 대결에서는 두 기기가 같은 값으로 시작한다.
  int seed;

  bool get vsCpu => mode == PlayMode.vsCpu;
  bool get online => mode == PlayMode.wifi;

  late RkState state;

  /// 지금까지 끝난 차례 수.
  int moveCount = 0;

  /// 내 손의 타일들 (내가 늘어놓은 순서). 판 위에 올려 둔 타일도 포함한다 — 손에 보이는 것은 [rackTiles].
  List<int> hand = [];

  /// 이번 차례에 만지고 있는 판 (처음에는 [state.table]의 복사본).
  List<List<int>> work = [];

  /// 누른 타일들.
  final Set<int> selected = {};

  /// 방금 뽑은 타일 (손에서 반짝이게 한다).
  int? lastDrawn;

  /// 손을 색 순서로 정렬해서 보여 주는가 (아니면 숫자 순서).
  bool sortedByColor = true;

  /// "내 정리판": 정렬 단추와 상관없이 내가 놓은 순서 그대로 두는 칸의 타일들. 손에서 판에 올려 둔 타일도 자리를 기억한다.
  final List<int> custom = [];

  /// 누군가 기권해서 멈춘 판인가.
  bool halted = false;

  /// 방금 한 동작이 안 된 이유 (화면 아래에 잠깐 보여 준다).
  String? notice;

  /// 내가 한 차례를 마칠 때 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(Map<String, dynamic> move)? onLocalMove;

  /// 소리/진동 알림 ('place' | 'draw' | 'bad' | 'win').
  void Function(String kind)? onFeedback;

  final CpuTurnRunner _cpu = CpuTurnRunner();
  final Random _rng = Random();

  // ── 녹색 판의 자리 ──

  /// 타일 번호 → 그 타일이 든 묶음의 왼쪽 위 자리 (타일 칸 단위). 묶음이 바뀌어도 타일이 자리를 기억해서 놓은 자리가 유지된다.
  final Map<int, Offset> anchors = {};

  /// 화면이 알려 주는 판의 폭(칸 수)과 한 줄에 놓을 수 있는 타일 수.
  double layoutWidth = 8;
  int layoutPerRow = 8;

  // ── 상대의 수 보여 주기 ──

  /// 지금 상대(CPU·다른 기기)의 수를 한 장씩 옮겨 보여 주는 중인가.
  bool _animating = false;
  bool get animating => _animating;
  int _animEpoch = 0;

  /// 한 장 옮길 때마다 기다리는 시간.
  Duration stepDelay = const Duration(milliseconds: 520);

  /// 상대가 이번에 손에서 꺼내 판에 올리는 타일들 (화면 위쪽에서 날아 들어오게 한다).
  final Set<int> flying = {};

  /// 상대가 더미에서 고르는 중인 바닥 타일의 번호 (그 타일을 들어 올려 보여 준다). 없으면 null.
  int? opponentPick;

  bool get thinking => _cpu.thinking;
  bool get isOver => state.over;
  int get turn => state.turn;
  bool get myTurn => !isOver && !halted && turn == humanSeat;

  /// 내가 지금 판을 만질 수 있는가.
  bool get canAct => myTurn && !thinking && !_animating;

  void _deal() {
    state = RkState.deal(players, seed);
    moveCount = 0;
    hand = [...state.racks[humanSeat]]..sort(compareByColor);
    custom.clear();
    anchors.clear();
    _recent.clear();
    _animEpoch++;
    _animating = false;
    flying.clear();
    opponentPick = null;
    work = _copyTable();
    selected.clear();
    lastDrawn = null;
    notice = null;
  }

  List<List<int>> _copyTable() => [for (final s in state.table) [...s]];

  /// 화면이 준비되면 부른다 (CPU가 먼저 시작하는 판이면 CPU가 둔다).
  void start() => _maybeCpu();

  /// 새 판. 씨앗이 바뀌고 자리가 한 칸 돈다. Wi‑Fi 대결에서는 두 기기가 같은 순서로 부르면 같은 판이 된다.
  void restart() {
    _cpu.cancel();
    seed = nextSeed(seed);
    humanSeat = (humanSeat + 1) % players;
    halted = false;
    _deal();
    notifyListeners();
    _maybeCpu();
  }

  /// 한 판 더 할 때의 다음 씨앗 (두 기기가 똑같이 계산한다).
  static int nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x3fffffff;

  // ── 손 ──

  /// 판 위에 올려 둔(아직 손에서 내놓은) 타일들.
  Set<int> get placed {
    final onTable = {for (final s in state.table) ...s};
    return {for (final s in work) for (final t in s) if (!onTable.contains(t)) t};
  }

  /// 손에 남아 보이는 타일들 전부 (정리판 포함).
  List<int> get rackTiles {
    final p = placed;
    return [for (final t in hand) if (!p.contains(t)) t];
  }

  /// 손의 "정렬 칸" 타일들: 색/숫자 순서 단추를 따른다.
  List<int> get autoTiles {
    final p = placed, c = custom.toSet();
    return [for (final t in hand) if (!p.contains(t) && !c.contains(t)) t];
  }

  /// 손의 "내 정리판" 타일들: 내가 놓은 순서 그대로.
  List<int> get customTiles {
    final p = placed;
    return [for (final t in custom) if (!p.contains(t)) t];
  }

  /// 이번 차례에 판을 만졌는가 (손에서 한 장이라도 내려놓았는가).
  bool get changed => placed.isNotEmpty;

  /// 지금 판의 모습을 내놓을 수 있는지 살핀 결과 (내놓을 수 있으면 null).
  PlayError? get error => state.checkPlay(work);

  bool get canEnd => canAct && error == null;

  void sortHand({required bool byColor}) {
    sortedByColor = byColor;
    hand.sort(byColor ? compareByColor : compareByNumber);
    notifyListeners();
  }

  /// 타일 [ids]를 "내 정리판"으로 옮긴다. [beforeId] 앞에 끼워 넣고, 없으면 맨 뒤에 놓는다.
  /// 이번 차례에 판에 올려 둔 타일이면 손으로 되돌아온다 (원래 판 위에 있던 타일은 못 옮긴다).
  void moveToCustom(Iterable<int> ids, {int? beforeId}) {
    if (!canAct) return;
    final p = placed;
    final inHand = rackTiles.toSet();
    final moving = [for (final t in hand) if (ids.contains(t) && (inHand.contains(t) || p.contains(t))) t];
    // 끌어 온 순서를 지키려면 요청 순서대로 모은다
    final order = [for (final t in ids) if (moving.contains(t)) t];
    if (order.isEmpty) {
      onFeedback?.call('bad');
      return;
    }
    for (final s in work) {
      s.removeWhere((t) => order.contains(t) && p.contains(t));
    }
    work.removeWhere((s) => s.isEmpty);
    custom.removeWhere(order.contains);
    var at = beforeId == null ? -1 : custom.indexOf(beforeId);
    if (at < 0) at = custom.length;
    custom.insertAll(at, order);
    selected.clear();
    notifyListeners();
  }

  /// 타일 [ids]를 정렬 칸으로 돌려보낸다 (정리판에서 빼고, 판에 올려 둔 것이면 손으로 되돌린다).
  void moveToAuto(Iterable<int> ids) {
    if (!canAct) return;
    final p = placed;
    final back = ids.where((t) => custom.contains(t) || p.contains(t)).toSet();
    if (back.isEmpty) {
      selected.clear();
      notifyListeners();
      return;
    }
    for (final s in work) {
      s.removeWhere((t) => back.contains(t) && p.contains(t));
    }
    work.removeWhere((s) => s.isEmpty);
    custom.removeWhere(back.contains);
    selected.clear();
    notifyListeners();
  }

  // ── 녹색 판 자리 계산과 놓기 ──

  /// 묶음의 자리 (타일 중 자리를 기억하는 것이 있으면 그 자리).
  Offset? anchorOf(List<int> set) {
    for (final t in set) {
      final a = anchors[t];
      if (a != null) return a;
    }
    return null;
  }

  void _setAnchor(Iterable<int> tiles, Offset a) {
    for (final t in tiles) {
      anchors[t] = a;
    }
  }

  /// 판 위 묶음들의 자리를 정한다 (화면이 판 크기와 함께 부른다). 자리가 없던 묶음은 빈자리를 찾아 놓고 그 자리를 기억한다.
  List<Offset> layoutSets(double widthUnits, int perRow) {
    layoutWidth = widthUnits;
    layoutPerRow = perRow;
    final n = work.length;
    final want = List<Offset?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      var a = anchorOf(work[i]);
      if (a == null) continue;
      final maxX = max(0.0, widthUnits - setRect(a, work[i].length, perRow).width);
      if (a.dx > maxX) a = Offset(maxX, a.dy);
      want[i] = a;
    }
    // 겹치지 않게 자리를 정한다: 방금 만진 묶음을 가장 먼저 (그 자리를 지킨다), 그다음 이미 자리가 있던 묶음들을 위에서 아래로, 새 묶음은 맨 나중에.
    // 앞서 놓인 묶음과 겹치면 뒤에 오는 묶음이 가장 가까운 빈자리로 비켜 준다.
    final order = List<int>.generate(n, (i) => i)
      ..sort((x, y) {
        int rank(int i) => _recent.isNotEmpty && work[i].any(_recent.contains) ? 0 : (want[i] != null ? 1 : 2);
        final r = rank(x).compareTo(rank(y));
        if (r != 0) return r;
        final ax = want[x], ay = want[y];
        if (ax == null || ay == null) return x.compareTo(y);
        final dy = ax.dy.compareTo(ay.dy);
        return dy != 0 ? dy : ax.dx.compareTo(ay.dx);
      });
    final res = List<Offset?>.filled(n, null);
    final placed = <Rect>[];
    for (final i in order) {
      final size = setRect(Offset.zero, work[i].length, perRow);
      var spot = want[i];
      if (spot == null) {
        spot = findFreeSpot(placed, size, widthUnits);
      } else if (overlapsAny(setRect(spot, work[i].length, perRow), placed, margin: 0.12)) {
        spot = snapToFree(placed, size, widthUnits, spot);
      }
      res[i] = spot;
      placed.add(setRect(spot, work[i].length, perRow));
    }
    for (var i = 0; i < n; i++) {
      _setAnchor(work[i], res[i]!);
    }
    return [for (final a in res) a!];
  }

  /// 방금 만진 묶음의 타일들 (자리를 정할 때 이 묶음의 자리를 가장 먼저 지킨다).
  final Set<int> _recent = {};

  /// 끌어 온 타일들 [ids]를 판 위 [topLeft](타일 칸 단위, 끌어 온 상자의 왼쪽 위)에 놓는다.
  /// 아주 가까이(틈 [magnet]칸 이내) 다른 묶음이 있으면 자석처럼 그 묶음에 붙고, 아니면 낱개 한 장이라도 그 자리에 새 묶음으로 놓인다.
  void dropTiles(Iterable<int> ids, Offset topLeft, {double magnet = 0.4}) {
    if (!canAct) return;
    final moving = ids.toSet();
    if (moving.isEmpty) return;
    final starts = layoutSets(layoutWidth, layoutPerRow);
    final want = setRect(topLeft, moving.length, layoutPerRow);
    List<int>? near;
    var nearGap = double.infinity;
    for (var i = 0; i < work.length; i++) {
      final set = work[i];
      // 끌어 온 타일로만 이루어진 묶음은 어차피 비게 되니 붙을 대상이 아니다
      if (set.every(moving.contains)) continue;
      final gap = rectGap(want, setRect(starts[i], set.length, layoutPerRow));
      if (gap < nearGap) {
        nearGap = gap;
        near = set;
      }
    }
    if (near != null && nearGap <= magnet) {
      moveTiles(moving, to: near);
      return;
    }
    // 새 묶음: 끌어 온 타일이 빠져나갈 묶음의 자리는 비는 것으로 보고 빈자리를 찾는다
    final others = <Rect>[
      for (var i = 0; i < work.length; i++)
        if (!work[i].every(moving.contains)) setRect(starts[i], work[i].length, layoutPerRow),
    ];
    final size = setRect(Offset.zero, moving.length, layoutPerRow);
    final spot = snapToFree(others, size, layoutWidth, topLeft);
    moveTiles(moving, at: spot);
  }

  // ── 만지기 ──

  /// 타일 [id]를 눌러 고르거나 고름을 푼다.
  void toggleSelect(int id) {
    if (!canAct) return;
    if (!selected.remove(id)) selected.add(id);
    notifyListeners();
  }

  void clearSelection() {
    if (selected.isEmpty) return;
    selected.clear();
    notifyListeners();
  }

  /// 고른 타일 [ids]를 묶음 [to]로 옮긴다 ([to]가 null이면 새 묶음). 판 위에 원래 있던 타일은 손으로 못 돌아온다.
  void moveTiles(Iterable<int> ids, {List<int>? to, Offset? at}) {
    if (!canAct) return;
    final moving = ids.toSet();
    if (moving.isEmpty) return;
    final inHand = rackTiles.toSet();
    final onWork = {for (final s in work) ...s};
    if (!moving.every((t) => inHand.contains(t) || onWork.contains(t))) return;
    // 이미 그 묶음에 있는 타일만이면 할 일이 없다.
    if (to != null && moving.every(to.contains)) {
      selected.clear();
      notifyListeners();
      return;
    }
    for (final s in work) {
      s.removeWhere(moving.contains);
    }
    final order = [for (final t in hand) if (moving.contains(t)) t];
    for (final t in moving) {
      if (!order.contains(t)) order.add(t);
    }
    if (to != null && work.any((s) => identical(s, to))) {
      final a = anchorOf(to);
      to.addAll(order);
      if (a != null) _setAnchor(order, a); // 붙은 타일은 그 묶음의 자리를 따른다
    } else {
      work.add([...order]);
      if (at != null) _setAnchor(order, at);
    }
    work.removeWhere((s) => s.isEmpty);
    _recent
      ..clear()
      ..addAll(order);
    for (final s in work) {
      if (s.any(order.contains)) _recent.addAll(s);
    }
    selected.clear();
    notice = null;
    onFeedback?.call('place');
    notifyListeners();
  }

  /// 이번 차례에 판에 올린 타일 [ids]를 다시 손으로 가져온다 (원래 판 위에 있던 타일은 못 가져온다).
  void returnToHand(Iterable<int> ids) {
    if (!canAct) return;
    final p = placed;
    final back = ids.where(p.contains).toSet();
    if (back.isEmpty) {
      onFeedback?.call('bad');
      return;
    }
    for (final s in work) {
      s.removeWhere(back.contains);
    }
    work.removeWhere((s) => s.isEmpty);
    selected.clear();
    notifyListeners();
  }

  /// 이번 차례에 만진 것을 모두 처음으로 되돌린다.
  void reset() {
    if (!canAct) return;
    work = _copyTable();
    selected.clear();
    notice = null;
    notifyListeners();
  }

  // ── 차례 마치기 ──

  /// 지금 판의 모습으로 차례를 마친다. 안 되면 이유를 [notice]에 두고 false.
  bool endTurn() {
    if (!canAct) return false;
    final err = error;
    if (err != null) {
      notice = err.message;
      onFeedback?.call('bad');
      notifyListeners();
      return false;
    }
    final table = [for (final s in work) if (s.isNotEmpty) [...s]];
    _applyPlay(table);
    onLocalMove?.call(_withIndex({'table': table}));
    _maybeCpu();
    return true;
  }

  /// 바닥에 엎어 둔 타일들 중 [index]번째를 직접 골라 뽑고 차례를 넘긴다 (만져 둔 것은 되돌려진다).
  /// [index]를 안 주면 맨 뒤 한 장. 더미가 비었으면 그냥 넘긴다.
  void draw({int? index}) {
    if (!canAct) return;
    final pick = state.pool.isEmpty ? null : (index ?? state.pool.length - 1);
    if (pick != null && (pick < 0 || pick >= state.pool.length)) return;
    _record(drew: true, count: 0);
    final drawn = state.applyDraw(pick);
    lastDrawn = drawn;
    _afterMove(drawn: drawn);
    onLocalMove?.call(_withIndex({'draw': 1, 'pick': ?pick}));
    _maybeCpu();
  }

  Map<String, dynamic> _withIndex(Map<String, dynamic> m) => {'i': moveCount - 1, ...m};

  void _applyPlay(List<List<int>> table) {
    _record(drew: false, count: table.fold<int>(0, (a, s) => a + s.length) - state.tableTiles.length);
    state.applyPlay(table);
    lastDrawn = null;
    _afterMove();
  }

  /// 방금 차례를 마친 사람과 그 내용 (화면의 안내 글에 쓴다).
  int lastActor = -1;
  bool lastDrew = false;
  int lastCount = 0;

  void _record({required bool drew, required int count}) {
    lastActor = state.turn;
    lastDrew = drew;
    lastCount = count;
  }

  /// 한 차례가 끝난 뒤의 정리: 손 목록을 맞추고, 내 차례면 판을 새로 복사한다.
  void _afterMove({int? drawn}) {
    moveCount++;
    final mine = state.racks[humanSeat].toSet();
    hand.removeWhere((t) => !mine.contains(t));
    custom.removeWhere((t) => !mine.contains(t));
    if (drawn != null && mine.contains(drawn) && !hand.contains(drawn)) {
      // 방금 뽑은 사람이 나일 때만 손에 들어온다
      hand.add(drawn);
    }
    work = _copyTable();
    selected.clear();
    notice = null;
    if (isOver) {
      onFeedback?.call('win');
    } else if (drawn != null) {
      onFeedback?.call('draw');
    }
    notifyListeners();
  }

  // ── 상대 기기의 수 (Wi‑Fi 대결) ──

  /// 상대 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  bool receiveMove(Map<String, dynamic> m) {
    if (!online || isOver || halted || turn == humanSeat) return false;
    if (m['i'] != moveCount) return false;
    if (m['draw'] == 1) {
      final pick = m['pick'];
      if (pick != null && (pick is! int || pick < 0 || pick >= state.pool.length)) return false;
      _playOpponent(pick: pick as int?); // 뽑은 사람은 상대이니 내 손은 그대로
      return true;
    }
    final raw = m['table'];
    if (raw is! List) return false;
    final table = <List<int>>[];
    for (final s in raw) {
      if (s is! List) return false;
      final set = <int>[];
      for (final t in s) {
        if (t is! int || t < 0 || t >= kTileCount) return false;
        set.add(t);
      }
      table.add(set);
    }
    if (state.checkPlay(table) != null) return false;
    _playOpponent(table: table);
    return true;
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_cpu.disposed || !vsCpu || isOver || halted || turn == humanSeat) return;
    _cpuTurn();
  }

  Future<void> _cpuTurn() async {
    final args = <Object>[
      level.index,
      _rng.nextInt(1 << 30),
      [...state.currentRack],
      [for (final s in state.table) [...s]],
      state.melded[turn],
    ];
    final plan = await _cpu.run<List<List<int>>>(
      task: () => compute(_cpuTask, args),
      minTime: const Duration(milliseconds: 900),
      onStart: notifyListeners,
    );
    if (plan == null) return;
    if (plan.isEmpty || state.checkPlay(plan) != null) {
      await _playOpponent(pick: state.pool.isEmpty ? null : _rng.nextInt(state.pool.length), draw: true);
    } else {
      await _playOpponent(table: plan);
    }
    _maybeCpu();
  }

  // ── 상대의 차례 보여 주기 ──

  /// 상대(CPU·다른 기기)의 차례를 반영한다. 판 위에서는 타일을 한 장씩 끌어다 놓는 모습으로, 타일을 뽑을 때는 바닥의 한 장을 들어 올리는
  /// 모습으로 보여 준 뒤 실제 판에 적용한다. [animate]가 꺼져 있으면 바로 적용한다.
  Future<void> _playOpponent({List<List<int>>? table, int? pick, bool draw = false}) async {
    final isDraw = table == null;
    if (!animate) {
      _finishOpponent(table, pick);
      return;
    }
    final epoch = ++_animEpoch;
    _animating = true;
    notifyListeners();
    if (table != null) {
      layoutSets(layoutWidth, layoutPerRow); // 지금 판의 묶음들이 모두 자리를 갖게
      final steps = _stepsFor(table);
      final ms = steps.length > 8 ? max(220, stepDelay.inMilliseconds * 8 ~/ steps.length) : stepDelay.inMilliseconds;
      await Future<void>.delayed(Duration(milliseconds: ms ~/ 2));
      for (final step in steps) {
        if (_cpu.disposed || epoch != _animEpoch) return;
        step();
        notifyListeners();
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
    } else if (isDraw && pick != null && pick < state.pool.length) {
      opponentPick = state.pool[pick];
      notifyListeners();
      await Future<void>.delayed(stepDelay * 1.4);
    }
    if (_cpu.disposed || epoch != _animEpoch) return;
    _animating = false;
    opponentPick = null;
    flying.clear();
    _finishOpponent(table, pick);
  }

  void _finishOpponent(List<List<int>>? table, int? pick) {
    if (table != null) {
      _applyPlay(table);
    } else {
      _record(drew: true, count: 0);
      state.applyDraw(pick);
      _afterMove();
    }
  }

  /// 지금 판([work])에서 [target] 모습이 되도록 타일을 한 장씩 옮기는 동작들 (각 동작이 판을 한 걸음 바꾼다).
  /// 목표 묶음마다 지금 판에서 가장 많이 겹치는 묶음을 "바탕"으로 삼고, 나머지 타일을 그 묶음으로 옮겨 온다.
  List<void Function()> _stepsFor(List<List<int>> target) {
    final hosts = List<List<int>?>.filled(target.length, null);
    final claimed = <List<int>>[];
    List<int> hostFor(int k) {
      final cached = hosts[k];
      if (cached != null) return cached;
      List<int>? best;
      var bestN = 0;
      for (final set in work) {
        if (claimed.any((c) => identical(c, set))) continue;
        final n = set.where(target[k].contains).length;
        if (n > bestN) {
          bestN = n;
          best = set;
        }
      }
      if (best == null) {
        best = <int>[];
        work.add(best); // 새 묶음 (첫 타일이 들어올 때 자리를 정한다)
      }
      claimed.add(best);
      return hosts[k] = best;
    }

    final steps = <void Function()>[];
    for (var k = 0; k < target.length; k++) {
      for (final t in arrangeSet(target[k])) {
        steps.add(() {
          final host = hostFor(k);
          if (host.contains(t)) return;
          final wasOnTable = work.any((s) => s.contains(t));
          for (final s in work) {
            s.remove(t);
          }
          if (!wasOnTable) flying.add(t);
          Offset? a = anchorOf(host);
          if (a == null) {
            // 새 묶음: 판에서 빈자리를 찾는다
            final others = [for (final s in work) if (!identical(s, host) && anchorOf(s) != null) setRect(anchorOf(s)!, s.length, layoutPerRow)];
            a = findFreeSpot(others, setRect(Offset.zero, target[k].length, layoutPerRow), layoutWidth);
          }
          host.add(t);
          _setAnchor(host, a);
          work.removeWhere((s) => s.isEmpty);
        });
      }
    }
    return steps;
  }

  // ── 기권 ──

  bool get canResign => !isOver && !halted && moveCount > 0;

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다.
  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    _animEpoch++;
    _animating = false;
    flying.clear();
    opponentPick = null;
    halted = true;
    selected.clear();
    notifyListeners();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결).
  void opponentResigned() {
    if (!online || isOver || halted) return;
    _animEpoch++;
    _animating = false;
    flying.clear();
    opponentPick = null;
    halted = true;
    selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _cpu.dispose();
    super.dispose();
  }
}

/// 다른 isolate에서 CPU의 차례를 정한다. args = [난이도, 씨앗, 손, 판, 처음 내려놓기를 마쳤는지]. 빈 목록이면 타일을 뽑는다.
List<List<int>> _cpuTask(List<Object> args) {
  final plan = RkAi.plan(
    rack: (args[2] as List).cast<int>(),
    table: [for (final s in args[3] as List) (s as List).cast<int>()],
    melded: args[4] as bool,
    level: RkLevel.values[args[0] as int],
    rng: Random(args[1] as int),
  );
  return plan ?? const [];
}
