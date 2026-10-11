import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/freecell_rules.dart';
import '../core/freecell_solver.dart';

class _Step {
  _Step(this.move, this.auto, this.before);

  final FcMove move;

  /// 자동으로 올라간 수 (되돌리기 때 사용자의 수와 한 묶음으로 취급).
  final bool auto;
  final FcState before;
}

/// 힌트 한 개: 어떤 수를 두면 좋은지.
class FcHint {
  const FcHint(this.move, {this.fromSolver = true});

  final FcMove move;

  /// true면 끝까지 풀리는 수 순서에서 나온 수, false면 단순 추천.
  final bool fromSolver;
}

/// 프리셀 한 판의 진행.
class FreecellController extends ChangeNotifier {
  FreecellController({
    required this.deal,
    List<int>? moveCodes,
    List<bool>? autoFlags,
    int elapsedSeconds = 0,
    this.autoMoveEnabled = true,
    this.autoDelay = const Duration(milliseconds: 170),
  })  : state = FcState.deal(deal),
        elapsed = ValueNotifier<int>(elapsedSeconds) {
    if (moveCodes != null) {
      for (var i = 0; i < moveCodes.length; i++) {
        final m = FcMove.fromCode(moveCodes[i]);
        if (!state.isLegal(m)) break; // 깨진 저장은 거기까지만 복원
        _history.add(_Step(m, autoFlags != null && autoFlags[i], state.copy()));
        state.apply(m);
      }
      completed = state.isWon;
    }
  }

  /// 판 번호 (1~32000).
  final int deal;

  FcState state;
  final ValueNotifier<int> elapsed;

  /// 안전한 카드를 완성 칸으로 자동으로 올릴지 (설정).
  bool autoMoveEnabled;

  /// 자동으로 올릴 때 한 장씩 사이의 간격.
  final Duration autoDelay;

  final List<_Step> _history = [];
  Timer? _autoTimer;
  Timer? _movedTimer;
  bool _disposed = false;

  bool completed = false;
  bool paused = false;

  /// 자동 이동이 진행 중이라 사용자 입력을 잠시 받지 않는다.
  bool busy = false;

  /// 더 둘 수 있는 수가 없는 막다른 상태.
  bool noMoves = false;

  /// 방금 움직인 카드들 (이동 중에 다른 카드 위에 보이도록).
  Set<int> recentlyMoved = {};

  /// 움직임 횟수 (애니메이션/저장 트리거용).
  int moveSerial = 0;

  FcHint? hint;
  bool thinkingHint = false;
  String? hintMessage;
  List<FcMove>? _plan;

  /// 카드를 집거나 놓을 때 알림 ('drop' | 'win').
  void Function(String kind)? onFeedback;
  VoidCallback? onCompleted;
  VoidCallback? onNoMoves;

  /// 사용자가 둔 수 (자동 이동은 제외).
  int get moveCount => _history.where((s) => !s.auto).length;

  bool get canUndo => _history.isNotEmpty && !completed;
  bool get canAct => !completed && !paused && !busy;

  /// 이 판에서 아직 한 수도 두지 않았는가 (이어하기 저장/기록 판단용).
  bool get untouched => _history.isEmpty;

  // ── 시작 ──

  /// 화면이 준비되면 부른다 (복원된 판에서 자동으로 올릴 카드가 있으면 처리).
  void start() => _pump();

  // ── 수 두기 ──

  /// 사용자가 한 수를 둔다. 합법이 아니면 false.
  bool tryMove(FcMove m) {
    if (!canAct || !state.isLegal(m)) return false;
    _apply(m, auto: false);
    return true;
  }

  void _apply(FcMove m, {required bool auto}) {
    if (_disposed) return;
    final cards = _cardsOf(m);
    _history.add(_Step(m, auto, state.copy()));
    state.apply(m);
    hint = null;
    hintMessage = null;
    noMoves = false;
    moveSerial++;
    // 풀이 계획에 있던 수를 그대로 두면 다음 힌트를 바로 쓸 수 있다
    if (_plan != null && _plan!.isNotEmpty && _plan!.first == m) {
      _plan!.removeAt(0);
    } else if (!auto) {
      _plan = null;
    }
    recentlyMoved = cards;
    _movedTimer?.cancel();
    _movedTimer = Timer(const Duration(milliseconds: 500), () {
      recentlyMoved = {};
      if (!_disposed) notifyListeners();
    });
    onFeedback?.call('drop');
    notifyListeners();
    _pump();
  }

  /// 이 수로 움직이는 카드들 (이전 상태 기준).
  Set<int> _cardsOf(FcMove m) {
    if (m.from == Place.cell) return {state.cells[m.fromIndex]};
    final col = state.columns[m.fromIndex];
    return col.sublist(col.length - m.count).toSet();
  }

  /// 매번 상태가 바뀐 뒤: 완성/자동 올리기/막힘을 확인한다.
  void _pump() {
    _autoTimer?.cancel();
    if (_disposed || completed) return;
    if (state.isWon) {
      _complete();
      return;
    }
    FcMove? next;
    if (autoMoveEnabled) next = state.safeAutoMove();
    // 남은 카드가 전부 풀려 있으면(모든 열이 내림차순) 끝까지 자동으로 올린다
    if (next == null && state.canFinishAutomatically) {
      FcMove? best;
      var bestRank = 99;
      for (final m in state.legalMoves()) {
        if (m.to != Place.foundation) continue;
        final card = m.from == Place.cell
            ? state.cells[m.fromIndex]
            : state.columns[m.fromIndex].last;
        if (rankOf(card) < bestRank) {
          bestRank = rankOf(card);
          best = m;
        }
      }
      next = best;
    }
    if (next != null) {
      busy = true;
      final m = next;
      _autoTimer = Timer(autoDelay, () => _apply(m, auto: true));
      notifyListeners();
      return;
    }
    if (busy) {
      busy = false;
      notifyListeners();
    }
    if (state.legalMoves().isEmpty) {
      noMoves = true;
      notifyListeners();
      onNoMoves?.call();
    }
  }

  void _complete() {
    completed = true;
    busy = false;
    hint = null;
    onFeedback?.call('win');
    notifyListeners();
    onCompleted?.call();
  }

  // ── 탭으로 이동 ──

  /// 카드를 탭했을 때 가장 좋은 곳으로 보낸다. 갈 곳이 없으면 false.
  /// 우선순위: 완성 칸 > 이어 붙일 수 있는 열 > 빈 열. (프리셀로는 자동으로 보내지 않는다)
  bool smartMove(Place from, int index, int count) {
    if (!canAct) return false;
    FcMove? best;
    var bestScore = 99;
    for (final m in state.legalMoves()) {
      if (m.from != from || m.fromIndex != index || m.count != count) continue;
      final score = switch (m.to) {
        Place.foundation => 0,
        Place.column => state.columns[m.toIndex].isEmpty ? 2 : 1,
        Place.cell => 9,
      };
      if (score >= 9) continue;
      if (score < bestScore) {
        bestScore = score;
        best = m;
      }
    }
    if (best == null) return false;
    return tryMove(best);
  }

  /// 집은 카드(들)를 놓을 수 있는 곳들.
  List<FcMove> targetsFor(Place from, int index, int count) => [
        for (final m in state.legalMoves())
          if (m.from == from && m.fromIndex == index && m.count == count) m,
      ];

  /// 이 열에서 [card]부터 맨 위까지 한꺼번에 집을 수 있는가 (집을 수 있으면 장수).
  int? grabCount(int column, int card) {
    final col = state.columns[column];
    final idx = col.indexOf(card);
    if (idx < 0) return null;
    final n = col.length - idx;
    return n <= state.runLength(column) ? n : null;
  }

  // ── 되돌리기 / 다시 시작 ──

  /// 마지막 사용자의 수를 되돌린다 (그 뒤에 자동으로 올라간 수들과 함께).
  void undo() {
    if (!canUndo || busy && _history.isEmpty) return;
    _autoTimer?.cancel();
    busy = false;
    while (_history.isNotEmpty) {
      final step = _history.removeLast();
      state = step.before;
      if (!step.auto) break;
    }
    hint = null;
    hintMessage = null;
    noMoves = false;
    _plan = null;
    recentlyMoved = {};
    moveSerial++;
    notifyListeners();
    _pump();
  }

  /// 같은 번호의 판을 처음부터 다시.
  void restart() {
    _autoTimer?.cancel();
    state = FcState.deal(deal);
    _history.clear();
    completed = false;
    busy = false;
    noMoves = false;
    paused = false;
    hint = null;
    hintMessage = null;
    _plan = null;
    recentlyMoved = {};
    elapsed.value = 0;
    moveSerial++;
    notifyListeners();
    _pump();
  }

  // ── 힌트 ──

  /// 다음에 둘 좋은 수를 알려준다. 끝까지 풀리는 수 순서를 찾으면 그 첫 수, 못 찾으면 단순 추천.
  Future<void> requestHint() async {
    if (!canAct || thinkingHint) return;
    hint = null;
    hintMessage = null;
    // 이전에 찾아 둔 풀이 계획이 아직 유효하면 바로 쓴다
    if (_plan != null && _plan!.isNotEmpty && state.isLegal(_plan!.first)) {
      hint = FcHint(_plan!.first);
      notifyListeners();
      return;
    }
    thinkingHint = true;
    notifyListeners();
    final serial = moveSerial;
    final codes = await compute(_solveTask, _encode(state));
    if (_disposed) return;
    thinkingHint = false;
    if (serial != moveSerial) {
      notifyListeners();
      return; // 생각하는 사이에 판이 바뀌었다
    }
    if (codes != null && codes.isNotEmpty) {
      _plan = [for (final c in codes) FcMove.fromCode(c)];
      hint = FcHint(_plan!.first);
    } else if (codes != null) {
      hintMessage = '이미 다 풀렸어요!';
    } else {
      final fallback = _simpleHint();
      if (fallback != null) {
        hint = FcHint(fallback, fromSolver: false);
        hintMessage = '끝까지 풀리는 길은 못 찾았지만, 이 수를 추천해요.';
      } else {
        hintMessage = '이 판은 풀이를 찾지 못했어요. 되돌리기로 다른 길을 시도해 보세요.';
      }
    }
    notifyListeners();
  }

  /// 풀이를 못 찾았을 때의 단순 추천: 완성 칸 → 열을 비우는 수 → 이어 붙이는 수.
  FcMove? _simpleHint() {
    final moves = state.legalMoves(forSolver: true);
    for (final m in moves) {
      if (m.to == Place.foundation) return m;
    }
    for (final m in moves) {
      if (m.to == Place.column && m.from == Place.column && state.columns[m.fromIndex].length == m.count) {
        return m;
      }
    }
    for (final m in moves) {
      if (m.to == Place.column && state.columns[m.toIndex].isNotEmpty) return m;
    }
    return null;
  }

  void dismissHint() {
    if (hint == null && hintMessage == null) return;
    hint = null;
    hintMessage = null;
    notifyListeners();
  }

  // ── 시계 ──

  void tick() {
    if (paused || completed) return;
    elapsed.value++;
  }

  void setPaused(bool v) {
    if (completed || paused == v) return;
    paused = v;
    notifyListeners();
  }

  // ── 저장 ──

  Map<String, dynamic> toJson() => {
        'deal': deal,
        'moves': [for (final s in _history) s.move.code],
        'autos': [for (final s in _history) s.auto ? 1 : 0],
        'elapsed': elapsed.value,
        'auto': autoMoveEnabled,
      };

  static FreecellController fromJson(Map<String, dynamic> j, {bool? autoMove}) {
    return FreecellController(
      deal: j['deal'] as int,
      moveCodes: List<int>.from(j['moves'] as List),
      autoFlags: [for (final a in j['autos'] as List) a == 1],
      elapsedSeconds: j['elapsed'] as int,
      autoMoveEnabled: autoMove ?? (j['auto'] as bool? ?? true),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _autoTimer?.cancel();
    _movedTimer?.cancel();
    elapsed.dispose();
    super.dispose();
  }
}

/// 상태를 숫자 목록으로 (isolate에 넘기기 위해). 열마다 [길이, 카드...], 그다음 프리셀 4, 완성 칸 4.
List<int> _encode(FcState s) => [
      for (final c in s.columns) ...[c.length, ...c],
      ...s.cells,
      ...s.found,
    ];

FcState _decode(List<int> e) {
  var p = 0;
  final cols = <List<int>>[];
  for (var i = 0; i < 8; i++) {
    final n = e[p++];
    cols.add([for (var k = 0; k < n; k++) e[p++]]);
  }
  final cells = [for (var i = 0; i < 4; i++) e[p++]];
  final found = [for (var i = 0; i < 4; i++) e[p++]];
  return FcState(cols, cells, found);
}

/// 다른 isolate에서 풀이를 찾는다. 풀이가 없으면 null, 이미 풀렸으면 빈 목록.
List<int>? _solveTask(List<int> encoded) {
  final sol = FcSolver.solve(_decode(encoded), timeLimit: const Duration(seconds: 4));
  return sol == null ? null : [for (final m in sol) m.code];
}
