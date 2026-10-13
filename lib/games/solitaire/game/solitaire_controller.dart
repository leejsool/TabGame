import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/solitaire_rules.dart';
import '../core/solitaire_solver.dart';

class _Step {
  _Step(this.move, this.auto, this.before);

  final SolMove move;

  /// 자동으로 올라간 수 (되돌리기 때 사용자의 수와 한 묶음으로 취급).
  final bool auto;
  final SolState before;
}

/// 솔리테어 한 판의 진행.
class SolitaireController extends ChangeNotifier {
  SolitaireController({
    required this.deal,
    this.draw = 1,
    List<int>? moveCodes,
    List<bool>? autoFlags,
    int elapsedSeconds = 0,
    this.autoMoveEnabled = true,
    this.autoDelay = const Duration(milliseconds: 170),
  })  : state = SolState.deal(deal, draw: draw),
        elapsed = ValueNotifier<int>(elapsedSeconds) {
    if (moveCodes != null) {
      for (var i = 0; i < moveCodes.length; i++) {
        final m = SolMove.fromCode(moveCodes[i]);
        if (!state.isLegal(m)) break; // 깨진 저장은 거기까지만 복원
        _history.add(_Step(m, autoFlags != null && autoFlags[i], state.copy()));
        state.apply(m);
      }
      completed = state.isWon;
    }
  }

  /// 판 번호와 한 번에 뽑는 장수 (1 또는 3).
  final int deal;
  final int draw;

  SolState state;
  final ValueNotifier<int> elapsed;

  /// 손해 없는 카드를 완성 칸으로 자동으로 올릴지 (설정).
  bool autoMoveEnabled;
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

  /// 힌트: 두면 좋은 수 (null이면 없음) + 안내 문구.
  SolMove? hint;
  String? hintMessage;

  /// 힌트를 계산하는 중 (풀이기가 도는 동안).
  bool hintThinking = false;
  int _hintStamp = 0;

  /// 수를 둘 때/완성했을 때 알림 ('drop' | 'win').
  void Function(String kind)? onFeedback;
  VoidCallback? onCompleted;
  VoidCallback? onNoMoves;

  /// 사용자가 둔 수 (자동 이동은 제외).
  int get moveCount => _history.where((s) => !s.auto).length;

  bool get canUndo => _history.isNotEmpty && !completed;
  bool get canAct => !completed && !paused && !busy;

  /// 이 판에서 아직 한 수도 두지 않았는가.
  bool get untouched => _history.isEmpty;

  /// 지금까지 둔 모든 수 (저장/다시보기용).
  List<SolMove> get moves => [for (final s in _history) s.move];

  // ── 시작 ──

  /// 화면이 준비되면 부른다 (복원된 판에서 끝낼 수 있으면 마무리).
  void start() => _pump(afterUser: false);

  // ── 수 두기 ──

  /// 사용자가 한 수를 둔다. 합법이 아니면 false.
  bool tryMove(SolMove m) {
    if (!canAct || !state.isLegal(m)) return false;
    _apply(m, auto: false);
    return true;
  }

  /// 더미를 눌렀을 때: 뽑거나, 비어 있으면 다시 넘긴다.
  bool drawFromStock() {
    if (state.stock.isNotEmpty) return tryMove(SolMove.draw);
    if (state.waste.isNotEmpty) return tryMove(SolMove.recycle);
    return false;
  }

  void _apply(SolMove m, {required bool auto}) {
    if (_disposed) return;
    final cards = _cardsOf(m);
    _history.add(_Step(m, auto, state.copy()));
    state.apply(m);
    hint = null;
    hintMessage = null;
    noMoves = false;
    moveSerial++;
    recentlyMoved = cards;
    _movedTimer?.cancel();
    _movedTimer = Timer(const Duration(milliseconds: 500), () {
      recentlyMoved = {};
      if (!_disposed) notifyListeners();
    });
    onFeedback?.call('drop');
    notifyListeners();
    _pump(afterUser: true);
  }

  /// 이 수로 움직이는 카드들 (이전 상태 기준).
  Set<int> _cardsOf(SolMove m) {
    switch (m.kind) {
      case SolKind.draw:
        final n = state.stock.length < state.draw ? state.stock.length : state.draw;
        return state.stock.sublist(state.stock.length - n).toSet();
      case SolKind.recycle:
        return state.waste.toSet();
      case SolKind.wasteToCol:
      case SolKind.wasteToFound:
        return {state.waste.last};
      case SolKind.colToCol:
        final col = state.tableau[m.from];
        return col.sublist(col.length - m.count).toSet();
      case SolKind.colToFound:
        return {state.tableau[m.from].last};
      case SolKind.foundToCol:
        return {state.cardOfFound(m.from)};
    }
  }

  /// 매번 상태가 바뀐 뒤: 완성/자동 올리기/막힘을 확인한다.
  void _pump({required bool afterUser}) {
    _autoTimer?.cancel();
    if (_disposed || completed) return;
    if (state.isWon) {
      _complete();
      return;
    }
    SolMove? next;
    if (state.canFinishAutomatically) {
      // 남은 카드가 전부 앞면이면 끝까지 자동으로 올린다 (낮은 숫자부터)
      var bestRank = 99;
      for (final m in state.legalMoves()) {
        if (m.kind != SolKind.colToFound) continue;
        final r = rankOf(state.tableau[m.from].last);
        if (r < bestRank) {
          bestRank = r;
          next = m;
        }
      }
    } else if (autoMoveEnabled && afterUser) {
      next = _safeFoundationMove();
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
    if (afterUser && state.isStuck) {
      noMoves = true;
      notifyListeners();
      onNoMoves?.call();
    }
  }

  SolMove? _safeFoundationMove() {
    for (final m in state.legalMoves()) {
      if (m.kind == SolKind.wasteToFound && state.isSafeForFound(state.waste.last)) return m;
      if (m.kind == SolKind.colToFound && state.isSafeForFound(state.tableau[m.from].last)) return m;
    }
    return null;
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

  /// 버린 카드 맨 위를 탭: 완성 칸 > 이어 붙일 수 있는 열 > 빈 열.
  bool smartMoveWaste() {
    if (!canAct || state.waste.isEmpty) return false;
    return _smart((m) => m.kind == SolKind.wasteToFound || m.kind == SolKind.wasteToCol);
  }

  /// 열의 카드 [count]장(맨 위부터)을 탭.
  bool smartMoveColumn(int col, int count) {
    if (!canAct) return false;
    return _smart((m) =>
        (m.kind == SolKind.colToFound && m.from == col && count == 1) ||
        (m.kind == SolKind.colToCol && m.from == col && m.count == count));
  }

  /// 완성 칸의 맨 위 카드를 탭: 이어 붙일 수 있는 열로.
  bool smartMoveFoundation(int suit) {
    if (!canAct) return false;
    return _smart((m) => m.kind == SolKind.foundToCol && m.from == suit);
  }

  bool _smart(bool Function(SolMove) test) {
    SolMove? best;
    var bestScore = 99;
    for (final m in state.legalMoves()) {
      if (!test(m)) continue;
      final score = switch (m.kind) {
        SolKind.wasteToFound || SolKind.colToFound => 0,
        _ => state.tableau[m.to].isEmpty ? 2 : 1,
      };
      // 통째로 빈 열로 옮기는 수는 의미가 없으니 거른다
      if (m.kind == SolKind.colToCol && state.tableau[m.to].isEmpty && state.tableau[m.from].length == m.count) {
        continue;
      }
      if (score < bestScore) {
        bestScore = score;
        best = m;
      }
    }
    if (best == null) return false;
    return tryMove(best);
  }

  /// 집은 카드(들)를 놓을 수 있는 곳들.
  List<SolMove> targetsForWaste() => [
        for (final m in state.legalMoves())
          if (m.kind == SolKind.wasteToCol || m.kind == SolKind.wasteToFound) m,
      ];

  List<SolMove> targetsForColumn(int col, int count) => [
        for (final m in state.legalMoves())
          if ((m.kind == SolKind.colToCol && m.from == col && m.count == count) ||
              (m.kind == SolKind.colToFound && m.from == col && count == 1))
            m,
      ];

  List<SolMove> targetsForFoundation(int suit) => [
        for (final m in state.legalMoves())
          if (m.kind == SolKind.foundToCol && m.from == suit) m,
      ];

  // ── 되돌리기 / 다시 시작 ──

  /// 마지막 사용자의 수를 되돌린다 (그 뒤에 자동으로 올라간 수들과 함께).
  void undo() {
    if (!canUndo) return;
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
    recentlyMoved = {};
    moveSerial++;
    notifyListeners();
  }

  /// 같은 번호의 판을 처음부터 다시.
  void restart() {
    _autoTimer?.cancel();
    state = SolState.deal(deal, draw: draw);
    _history.clear();
    completed = false;
    busy = false;
    noMoves = false;
    paused = false;
    hint = null;
    hintMessage = null;
    recentlyMoved = {};
    elapsed.value = 0;
    moveSerial++;
    notifyListeners();
  }

  // ── 힌트 ──

  /// 힌트: 이 판을 끝까지 풀어 보고, 이길 수 있으면 그 길의 첫 수를, 이미 졌으면 졌다고 알려 준다.
  /// 너무 복잡해서 못 따져 보면 기존 규칙 기반 추천으로 대신한다.
  Future<void> requestHint() async {
    if (!canAct || hintThinking) return;
    final serial = moveSerial;
    final stamp = ++_hintStamp;
    hintThinking = true;
    hint = null;
    hintMessage = '이길 수 있는 길을 찾는 중이에요…';
    notifyListeners();

    final before = state.copy();
    final result = await solveSolitaire(
      before,
      cancelled: () => _disposed || serial != moveSerial || stamp != _hintStamp,
    );
    if (_disposed) return;
    hintThinking = false;
    if (serial != moveSerial || stamp != _hintStamp) {
      // 기다리는 사이에 수를 두었거나 닫았으면 낡은 답은 버린다.
      notifyListeners();
      return;
    }

    switch (result.verdict) {
      case SolVerdict.winnable:
        final m = result.firstMove!;
        hint = m;
        hintMessage = '이길 수 있는 판이에요! ${_describe(before, m)}';
      case SolVerdict.lost:
        hint = null;
        hintMessage = '이 판은 이미 망했어요. 어떻게 해도 끝까지 풀 수 없어요. '
            '되돌리기로 돌아가거나 처음부터 다시 해 보세요.';
      case SolVerdict.unknown:
        final h = before.hint();
        if (h == null) {
          hint = null;
          hintMessage = '더 둘 수 있는 수가 없어요. 되돌리기로 다른 길을 시도해 보세요.';
        } else {
          hint = h;
          hintMessage = '이 판은 너무 복잡해서 이길 수 있는지는 확인하지 못했어요. 일단 이 수를 추천해요. '
              '${_describe(before, h)}';
        }
    }
    notifyListeners();
  }

  /// 추천한 수가 왜 좋은지 짧게 설명한다 ([s]는 그 수를 두기 전 상태).
  String _describe(SolState s, SolMove m) {
    switch (m.kind) {
      case SolKind.draw:
        return '둘 곳이 없으니 더미에서 카드를 뽑아 보세요.';
      case SolKind.recycle:
        return '더미를 다시 넘겨 보세요.';
      case SolKind.wasteToFound:
      case SolKind.colToFound:
        return '노란 카드를 완성 칸으로 올려요.';
      case SolKind.wasteToCol:
        return '버린 카드를 표시된 열에 붙여요.';
      case SolKind.colToCol:
        final hidden = s.tableau[m.from].length - s.up[m.from];
        if (s.up[m.from] == m.count && hidden > 0) return '뒤집힌 카드를 열 수 있어요. 노란 카드를 표시된 곳으로 옮겨 보세요.';
        if (s.up[m.from] == m.count && s.tableau[m.to].isEmpty) return '열을 비워 K를 놓을 자리를 만들어요.';
        return '노란 카드를 표시된 곳으로 옮겨 보세요.';
      case SolKind.foundToCol:
        return '완성 칸의 카드를 열로 내려요. 다음 수를 위한 준비예요.';
    }
  }

  void dismissHint() {
    if (hint == null && hintMessage == null && !hintThinking) return;
    _hintStamp++;
    hintThinking = false;
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
        'draw': draw,
        'moves': [for (final s in _history) s.move.code],
        'autos': [for (final s in _history) s.auto ? 1 : 0],
        'elapsed': elapsed.value,
      };

  static SolitaireController fromJson(Map<String, dynamic> j, {bool autoMove = true}) {
    return SolitaireController(
      deal: j['deal'] as int,
      draw: j['draw'] as int,
      moveCodes: List<int>.from(j['moves'] as List),
      autoFlags: [for (final a in j['autos'] as List) a == 1],
      elapsedSeconds: j['elapsed'] as int,
      autoMoveEnabled: autoMove,
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
