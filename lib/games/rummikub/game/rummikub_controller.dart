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
    Iterable<int>? cpuSeats,
    this.cpuHost = false,
  }) : seed = seed ?? Random().nextInt(1 << 30) {
    assert(mode == PlayMode.vsCpu || (mode == PlayMode.wifi && players >= 2 && players <= 4));
    // CPU 대결은 나 말고 모두 CPU다. 같은 Wi‑Fi 방에서는 [cpuSeats]에 든 자리들이 CPU다.
    this.cpuSeats = {...?cpuSeats};
    if (mode == PlayMode.vsCpu && cpuSeats == null) {
      this.cpuSeats.addAll([for (var p = 0; p < players; p++) if (p != humanSeat) p]);
    }
    _deal();
  }

  final PlayMode mode;
  final int players;

  /// CPU가 앉은 자리들. 한 판 더 할 때마다 사람과 함께 한 칸씩 돈다.
  late final Set<int> cpuSeats;

  /// 같은 Wi‑Fi 방에서 CPU의 수를 이 기기가 정해서 다른 기기들에 알리는가 (방을 연 기기만).
  final bool cpuHost;

  /// 한 판 더 한 횟수 (자리가 이만큼 돌았다).
  int rotation = 0;

  /// CPU와 상대 기기의 수를 타일을 한 장씩 옮기는 모습으로 보여 주는가 (시험에서는 끄고 한 번에 반영한다).
  final bool animate;

  /// 이 기기에서 내가 맡은 자리 (0 = 먼저). 한 판 더 할 때마다 한 칸씩 돈다.
  int humanSeat;
  final RkLevel level;

  /// 패를 나눈 씨앗. 같은 Wi‑Fi 대결에서는 두 기기가 같은 값으로 시작한다.
  int seed;

  bool get vsCpu => mode == PlayMode.vsCpu;
  bool get online => mode == PlayMode.wifi;

  bool isCpuSeat(int seat) => cpuSeats.contains(seat);

  /// 이 기기가 CPU의 수를 정하는가 (CPU 대결, 또는 CPU가 낀 Wi‑Fi 방의 방장).
  bool get runsCpu => cpuSeats.isNotEmpty && (vsCpu || cpuHost);

  /// 판에 앉은 사람 수 (CPU 빼고).
  int get humans => players - cpuSeats.length;

  /// 다른 기기에서 온 수가 어긋났을 때 (대기열에 있던 수를 나중에 적용하다 알게 된 경우).
  void Function()? onDesync;

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


  /// 누군가 기권해서 멈춘 판인가.
  bool halted = false;

  /// 방금 한 동작이 안 된 이유 (화면 아래에 잠깐 보여 준다).
  String? notice;

  /// 내가 한 차례를 마칠 때 알린다 (Wi‑Fi 대결에서 상대에게 보내려고).
  void Function(Map<String, dynamic> move)? onLocalMove;

  /// 내가 이번 차례에 판을 만지는 동안, 바뀔 때마다 그 모습을 알린다 (Wi‑Fi 대결에서 상대 화면에 실시간으로 보이려고).
  void Function(Map<String, dynamic> live)? onLocalLive;

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
  /// 판이 시작된 뒤 지금까지 지나간 차례 수 (첫 차례에는 "내 차례" 알림을 띄우지 않으려고).
  int get moveCountForBanner => state.turnCount;

  bool get myTurn => !isOver && !halted && turn == humanSeat;

  /// 내가 지금 판을 만질 수 있는가.
  bool get canAct => myTurn && !thinking && !_animating;

  /// 내 손의 타일 순서를 바꿀 수 있는가. 손은 나만 보고 만지는 것이라, 상대 차례에도 마음대로 정리할 수 있다.
  bool get canArrange => !isOver && !halted;

  void _deal() {
    _queuedMoves.clear();
    state = RkState.deal(players, seed);
    moveCount = 0;
    hand = [...state.racks[humanSeat]]..sort(compareByColor);
    anchors.clear();
    _undo.clear();
    _recent.clear();
    _animEpoch++;
    _animating = false;
    flying.clear();
    opponentPick = null;
    work = _copyTable();
    _liveActive = false;
    _liveSig = _workSig();
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
    rotation++;
    final rotated = {for (final s in cpuSeats) (s + 1) % players};
    cpuSeats
      ..clear()
      ..addAll(rotated);
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

  /// 손에 남아 보이는 타일들 (내가 늘어놓은 순서 그대로).
  List<int> get rackTiles {
    final p = placed;
    return [for (final t in hand) if (!p.contains(t)) t];
  }

  /// 이번 차례에 판을 만졌는가 (손에서 한 장이라도 내려놓았는가).
  bool get changed => placed.isNotEmpty;

  /// 지금 판의 모습을 내놓을 수 있는지 살핀 결과 (내놓을 수 있으면 null).
  PlayError? get error => state.checkPlay(work);

  bool get canEnd => canAct && error == null;

  /// 손을 색 순서나 숫자 순서로 한 번 정렬한다. (그 뒤로는 끌어서 마음대로 바꿀 수 있다)
  void sortHand({required bool byColor}) {
    hand.sort(byColor ? compareByColor : compareByNumber);
    notifyListeners();
  }

  /// 손 안에서 타일 [ids]를 끌어 옮긴다: [beforeId] 타일 앞에 끼워 넣고, 없으면 맨 뒤에 놓는다.
  /// 이번 차례에 판에 올려 둔 타일이면 손으로 되돌아온다 (원래 판 위에 있던 타일은 못 옮긴다).
  void moveInHand(Iterable<int> ids, {int? beforeId}) {
    if (!canArrange) return;
    final p = canAct ? placed : const <int>{}; // (상대 차례에는 판에서 타일을 가져올 수 없다)
    final order = [for (final t in ids) if (hand.contains(t)) t];
    if (order.isEmpty || (beforeId != null && order.contains(beforeId))) {
      selected.clear();
      notifyListeners();
      return;
    }
    if (canAct) _remember();
    for (final s in work) {
      s.removeWhere((t) => order.contains(t) && p.contains(t));
    }
    work.removeWhere((s) => s.isEmpty);
    hand.removeWhere(order.contains);
    var at = beforeId == null ? -1 : hand.indexOf(beforeId);
    if (at < 0) at = hand.length;
    hand.insertAll(at, order);
    selected.clear();
    onFeedback?.call('place');
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

  /// 정리: 묶음은 그대로 두고 자리만 바꿔서 녹색 판 위쪽부터 가지런히 채운다.
  /// 런(같은 색 연속)은 색별로 작은 숫자부터, 그룹(같은 숫자)은 숫자 순으로, 올바르지 않은 묶음은 맨 끝에 놓고,
  /// 왼쪽에서 오른쪽으로, 넘치면 다음 줄로 이어 놓는다. 한 단계 되돌리기로 되돌릴 수 있다.
  void tidySets() {
    if (!canAct || work.isEmpty || layoutWidth <= 0) return;
    _remember();
    int kindOf(List<int> set) {
      final m = analyzeMeld(set);
      return m == null ? 2 : (m.isRun ? 0 : 1);
    }

    int firstNumber(List<int> set) {
      final m = analyzeMeld(set);
      final order = m?.order ?? arrangeSet(set);
      final plain = order.where((t) => !isJoker(t));
      return plain.isEmpty ? kMaxNumber + 1 : numberOf(plain.first);
    }

    int colorKey(List<int> set) {
      final plain = set.where((t) => !isJoker(t));
      return plain.isEmpty ? kColors : colorOf(plain.first);
    }

    final sorted = [...work]
      ..sort((a, b) {
        final k = kindOf(a).compareTo(kindOf(b));
        if (k != 0) return k;
        if (kindOf(a) == 0) {
          final c = colorKey(a).compareTo(colorKey(b));
          if (c != 0) return c;
        }
        final n = firstNumber(a).compareTo(firstNumber(b));
        return n != 0 ? n : b.length.compareTo(a.length);
      });
    var x = 0.0, y = 0.0, rowH = 1.0;
    for (final set in sorted) {
      final r = setRect(Offset.zero, set.length, layoutPerRow);
      final w = r.width;
      if (x > 0 && x + w > layoutWidth + 0.001) {
        x = 0;
        y += rowH;
        rowH = 1;
      }
      _setAnchor(set, Offset(x, y));
      x += w + 0.15;
      rowH = max(rowH, (set.length / layoutPerRow).ceil().toDouble());
    }
    _recent.clear();
    selected.clear();
    notifyListeners();
  }

  // ── 한 단계 되돌리기 ──

  /// 이번 차례에 만지기 전 모습들 (판·손·묶음 자리). 끝내기·뽑기·처음으로·새 판에서 비운다.
  final List<({List<List<int>> work, List<int> hand, Map<int, Offset> anchors})> _undo = [];

  bool get canUndoStep => canAct && _undo.isNotEmpty;

  void _remember() {
    _undo.add((work: [for (final s in work) [...s]], hand: [...hand], anchors: {...anchors}));
    if (_undo.length > 60) _undo.removeAt(0);
  }

  /// 방금 한 것(타일 옮기기·묶음 합치기 …) 하나를 되돌린다.
  void undoStep() {
    if (!canUndoStep) return;
    final prev = _undo.removeLast();
    work = prev.work;
    hand
      ..clear()
      ..addAll(prev.hand);
    anchors
      ..clear()
      ..addAll(prev.anchors);
    _recent.clear();
    selected.clear();
    notice = null;
    notifyListeners();
  }

  /// 방금 만진 묶음의 타일들 (자리를 정할 때 이 묶음의 자리를 가장 먼저 지킨다).
  final Set<int> _recent = {};

  /// 끌어 온 타일들 [ids]를 [topLeft](타일 칸 단위, 끌어 온 타일들의 왼쪽 위)에 놓으면 붙게 될 묶음 (없으면 null).
  ///
  /// 자석은 아주 좁게 걸린다: 낱개 한 장은 묶음에 거의 닿았을 때(틈 [singleMagnet]칸 이내), 여러 장이나 묶음 통째로 끌 때는 서로 겹쳐질 때만
  /// 붙는다. 빈 땅에 놓은 것이 가까운 묶음에 달라붙어 새 묶음을 만들 수 없는 일이 없도록 하려는 것이다.
  List<int>? dropTargetFor(Iterable<int> ids, Offset topLeft, {double singleMagnet = 0.12, double groupMagnet = 0.0}) {
    final moving = ids.toSet();
    if (moving.isEmpty) return null;
    final starts = layoutSets(layoutWidth, layoutPerRow);
    final want = _groupRect(topLeft, moving.length);
    final magnet = moving.length > 1 ? groupMagnet : singleMagnet;
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
    return near != null && nearGap <= magnet ? near : null;
  }

  /// 끌어 온 타일들이 차지하는 상자 (타일 칸 단위). 묶음의 여백은 넣지 않고 타일만 센다.
  Rect _groupRect(Offset topLeft, int count) {
    final cols = min(count, layoutPerRow);
    final rows = (count / layoutPerRow).ceil();
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, cols.toDouble(), rows - 0.12);
  }

  /// 끌어 온 타일들 [ids]를 판 위 [topLeft]에 놓는다.
  /// 가까이(위의 자석 거리 안) 다른 묶음이 있으면 그 묶음에 붙고, 아니면 낱개 한 장이라도 그 자리에 새 묶음으로 놓인다.
  void dropTiles(Iterable<int> ids, Offset topLeft, {double? magnet}) {
    if (!canAct) return;
    final moving = ids.toSet();
    if (moving.isEmpty) return;
    final near = magnet == null
        ? dropTargetFor(moving, topLeft)
        : dropTargetFor(moving, topLeft, singleMagnet: magnet, groupMagnet: magnet);
    if (near != null) {
      moveTiles(moving, to: near);
      return;
    }
    // 새 묶음: 끌어 온 타일이 빠져나갈 묶음의 자리는 비는 것으로 보고 빈자리를 찾는다
    final starts = layoutSets(layoutWidth, layoutPerRow);
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
    if (!canAct && !(canArrange && hand.contains(id))) return; // (상대 차례에는 내 손의 타일만 고를 수 있다)
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
    _remember();
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
    _remember();
    for (final s in work) {
      s.removeWhere(back.contains);
    }
    work.removeWhere((s) => s.isEmpty);
    selected.clear();
    onFeedback?.call('place');
    notifyListeners();
  }

  /// 이번 차례에 만진 것을 모두 처음으로 되돌린다.
  void reset() {
    if (!canAct) return;
    _undo.clear();
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
    if (drawn != null && mine.contains(drawn) && !hand.contains(drawn)) {
      // 방금 뽑은 사람이 나일 때만 손에 들어온다
      hand.add(drawn);
    }
    work = _copyTable();
    _liveActive = false;
    _liveSig = _workSig(); // (내 차례가 시작될 때의 모습은 따로 알릴 필요가 없다)
    _undo.clear();
    selected.clear();
    notice = null;
    if (isOver) {
      onFeedback?.call('win');
    } else if (drawn != null) {
      onFeedback?.call('draw');
    }
    notifyListeners();
  }

  // ── 실시간 중계 (Wi‑Fi 대결) ──

  /// 마지막으로 알린 판의 모습 (같은 모습을 다시 보내지 않으려고).
  String _liveSig = '';

  /// 지금 상대가 만지는 판을 실시간으로 받아 보여 주는 중인가.
  bool _liveActive = false;

  String _workSig() => [
        for (final set in work)
          '${set.join(',')}@${anchorOf(set)?.dx.toStringAsFixed(2)},${anchorOf(set)?.dy.toStringAsFixed(2)}',
      ].join('|');

  @override
  void notifyListeners() {
    super.notifyListeners();
    _maybeSendLive();
  }

  void _maybeSendLive() {
    final send = onLocalLive;
    if (send == null || !online || !canAct) return;
    final sig = _workSig();
    if (sig == _liveSig) return;
    _liveSig = sig;
    send({
      'i': moveCount,
      'sets': [for (final set in work) [...set]],
      'a': [
        for (final set in work)
          if (anchorOf(set) case final a?) [a.dx, a.dy] else null,
      ],
    });
  }

  /// 상대가 이번 차례에 판을 만지는 모습을 받는다: 그대로 내 화면의 판에 보여 준다 (끝낼 때 오는 수와는 따로, 보여 주기만 한다).
  /// 맞지 않는 내용은 조용히 버린다. 받았으면 true.
  bool receiveLive(Map<String, dynamic> m, {int? fromSeat}) {
    if (!online || isOver || halted || turn == humanSeat || _animating) return false;
    if (fromSeat != null && fromSeat != turn) return false;
    if (m['i'] != moveCount) return false;
    final rawSets = m['sets'];
    if (rawSets is! List) return false;
    final sets = <List<int>>[];
    final seen = <int>{};
    for (final raw in rawSets) {
      if (raw is! List) return false;
      final set = <int>[];
      for (final t in raw) {
        if (t is! int || t < 0 || t >= kTileCount || !seen.add(t)) return false;
        set.add(t);
      }
      if (set.isNotEmpty) sets.add(set);
    }
    // 지금 판에 있던 타일은 모두 그대로 있어야 한다 (상대는 판에서 타일을 가져갈 수 없다)
    if (!state.tableTiles.every(seen.contains)) return false;
    final rawA = m['a'];
    final before = {for (final set in work) ...set};
    flying
      ..removeWhere((t) => !seen.contains(t))
      ..addAll([for (final t in seen) if (!before.contains(t)) t]);
    work = sets;
    if (rawA is List) {
      for (var k = 0; k < sets.length && k < rawA.length; k++) {
        final a = rawA[k];
        if (a is List && a.length == 2 && a[0] is num && a[1] is num) {
          _setAnchor(sets[k], Offset((a[0] as num).toDouble(), (a[1] as num).toDouble()));
        }
      }
    }
    _recent.clear();
    _liveActive = true;
    notifyListeners();
    return true;
  }

  // ── 상대 기기의 수 (Wi‑Fi 대결) ──

  /// 상대 기기에서 온 수를 둔다. 순서가 어긋났거나 규칙에 안 맞는 수면 false (그러면 판이 어긋난 것이다).
  ///
  /// 방장은 손님이 보낸 수를 받을 때 그 손님의 자리 [fromSeat]를 알려 준다 (그 손님 차례의 수여야 한다).
  /// 앞선 수를 아직 한 장씩 보여 주는 중이면 대기열에 두었다가, 다 보여 준 뒤에 적용한다.
  bool receiveMove(Map<String, dynamic> m, {int? fromSeat}) {
    if (!online || isOver || halted) return false;
    if (_animating) {
      _queuedMoves.add((m: m, fromSeat: fromSeat));
      return true;
    }
    if (turn == humanSeat || (fromSeat != null && fromSeat != turn)) return false;
    if (m['i'] != moveCount) return false;
    if (m['draw'] == 1) {
      final pick = m['pick'];
      if (pick != null && (pick is! int || pick < 0 || pick >= state.pool.length)) return false;
      if (_liveActive) {
        // 실시간으로 보이던 것은 되돌려진다 (뽑으면 만져 둔 것이 사라진다)
        _liveActive = false;
        flying.clear();
        work = _copyTable();
      }
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
    if (_liveActive) {
      // 이미 한 장씩 실시간으로 봤으니, 다시 옮기는 모습을 보이지 않고 바로 반영한다
      _liveActive = false;
      flying.clear();
      _applyPlay(table);
      _maybeCpu();
      return true;
    }
    _playOpponent(table: table);
    return true;
  }

  /// 앞선 수를 보여 주는 동안 도착한 다른 기기의 수들 (보여 주기가 끝나면 차례로 적용한다).
  final List<({Map<String, dynamic> m, int? fromSeat})> _queuedMoves = [];

  void _drainQueued() {
    while (!_animating && _queuedMoves.isNotEmpty && !_cpu.disposed) {
      final next = _queuedMoves.removeAt(0);
      if (!receiveMove(next.m, fromSeat: next.fromSeat)) {
        _queuedMoves.clear();
        onDesync?.call();
        return;
      }
    }
  }

  // ── CPU ──

  void _maybeCpu() {
    if (_cpu.disposed || !runsCpu || isOver || halted || !isCpuSeat(turn)) return;
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
      final pick = state.pool.isEmpty ? null : _rng.nextInt(state.pool.length);
      if (online) onLocalMove?.call({'i': moveCount, 'draw': 1, 'pick': ?pick}); // (같은 Wi‑Fi 방이면 CPU의 수도 다른 기기들에 알린다)
      await _playOpponent(pick: pick, draw: true, fromCpu: true);
    } else {
      if (online) onLocalMove?.call({'i': moveCount, 'table': plan});
      await _playOpponent(table: plan, fromCpu: true);
    }
    _maybeCpu();
  }

  // ── 상대의 차례 보여 주기 ──

  /// 상대(CPU·다른 기기)의 차례를 반영한다. 판 위에서는 타일을 한 장씩 끌어다 놓는 모습으로, 타일을 뽑을 때는 바닥의 한 장을 들어 올리는
  /// 모습으로 보여 준 뒤 실제 판에 적용한다. [animate]가 꺼져 있으면 바로 적용한다.
  Future<void> _playOpponent({List<List<int>>? table, int? pick, bool draw = false, bool fromCpu = false}) async {
    final isDraw = table == null;
    if (!animate) {
      _finishOpponent(table, pick);
      if (!fromCpu) _maybeCpu(); // (CPU의 수 뒤에는 CPU 쪽에서 이어 간다)
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
        // 이미 제자리에 있는 타일은 옮길 게 없으니 소리도 기다림도 없이 넘어간다
        if (!step()) continue;
        onFeedback?.call('step'); // (상대가 타일을 실제로 한 장 옮길 때마다 딸깍 소리)
        notifyListeners();
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
    } else if (isDraw && pick != null && pick < state.pool.length) {
      opponentPick = state.pool[pick];
      onFeedback?.call('step');
      notifyListeners();
      await Future<void>.delayed(stepDelay * 1.4);
    }
    if (_cpu.disposed || epoch != _animEpoch) return;
    _animating = false;
    opponentPick = null;
    flying.clear();
    _finishOpponent(table, pick);
    _drainQueued(); // (보여 주는 동안 도착한 다른 기기의 수가 있으면 이어서 보여 준다)
    if (!fromCpu) _maybeCpu();
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
  /// 각 동작은 타일을 실제로 옮겼으면 true, 이미 제자리라 할 일이 없었으면 false를 돌려준다.
  List<bool Function()> _stepsFor(List<List<int>> target) {
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

    final steps = <bool Function()>[];
    for (var k = 0; k < target.length; k++) {
      for (final t in arrangeSet(target[k])) {
        steps.add(() {
          final host = hostFor(k);
          if (host.contains(t)) return false;
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
          return true;
        });
      }
    }
    return steps;
  }

  // ── 기권 ──

  /// 기권할 수 있는가. 3~4명이 Wi‑Fi로 할 때는 누가 이기는 건지 정할 수 없어 기권이 없다.
  bool get canResign => !isOver && !halted && moveCount > 0 && (vsCpu || players == 2);

  /// 기권한다. CPU가 생각 중이었으면 그 수는 버린다.
  bool resign() {
    if (!canResign) return false;
    _cpu.cancel();
    _queuedMoves.clear();
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
    _queuedMoves.clear();
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
