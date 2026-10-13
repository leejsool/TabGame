import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/getcolor_rules.dart';
import '../core/getcolor_solver.dart';

class _Step {
  _Step(this.move, this.before);

  /// 붓기 한 수 (병을 더한 수는 null).
  final GcMove? move;
  final WaterState before;
}

/// 방금 부은 물의 정보 (화면이 붓는 모습을 보여주는 데 쓴다).
class GcPour {
  const GcPour({required this.from, required this.to, required this.count, required this.color, required this.serial});

  final int from;
  final int to;
  final int count;
  final int color;
  final int serial;
}

/// 겟 컬러 한 판의 진행: 병 고르기, 붓기, 되돌리기, 병 더하기, 힌트, 시간.
class GetColorController extends ChangeNotifier {
  GetColorController({
    required this.level,
    required WaterState initial,
    List<int>? moveCodes,
    int elapsedSeconds = 0,
  })  : initial = initial.copy(),
        state = initial.copy(),
        elapsed = ValueNotifier<int>(elapsedSeconds) {
    if (moveCodes != null) {
      for (final code in moveCodes) {
        if (code == _addCode) {
          if (extraUsed) break;
          _history.add(_Step(null, state.copy()));
          state.addEmptyBottle();
          continue;
        }
        final m = GcMove.fromCode(code);
        if (!state.canPour(m.from, m.to)) break; // 깨진 저장은 거기까지만 복원
        _history.add(_Step(m, state.copy()));
        state.pour(m.from, m.to);
      }
    }
    completed = state.isSolved;
  }

  /// 병을 더한 수를 저장할 때 쓰는 번호 (붓기 번호와 겹치지 않는다).
  static const int _addCode = 255;

  final GcLevel level;
  final WaterState initial;
  WaterState state;
  final ValueNotifier<int> elapsed;

  bool paused = false;
  bool completed = false;

  /// 지금 골라 둔 병 (들어 올려진 병).
  int? selected;

  /// 방금 부은 것 (애니메이션용). 없으면 null.
  GcPour? lastPour;
  int _pourSerial = 0;

  /// 힌트로 알려 주는 한 수 + 안내 문구 + 계산 중 여부.
  GcMove? hint;
  String? hintMessage;
  bool hintThinking = false;
  int _hintStamp = 0;

  /// 소리/진동 알림 ('select' | 'pour' | 'bottle' | 'win').
  void Function(String kind)? onFeedback;
  VoidCallback? onWon;

  final List<_Step> _history = [];

  /// 지금까지 붓기를 한 횟수.
  int get moveCount => _history.where((s) => s.move != null).length;

  bool get extraUsed => _history.any((s) => s.move == null);
  bool get canAddBottle => !completed && !extraUsed && state.count < 15;
  bool get canUndo => _history.isNotEmpty && !completed;
  bool get canAct => !completed && !paused;

  /// 이 판에서 아직 한 수도 두지 않았는가.
  bool get untouched => _history.isEmpty;

  /// 더 부을 수 있는 곳이 하나도 없는 막다른 상태.
  bool get noMoves => !completed && state.legalMoves().isEmpty;

  /// 끝난 병(한 가지 색으로 가득)의 수.
  int get doneCount => [for (var i = 0; i < state.count; i++) state.isDone(i)].where((d) => d).length;

  // ── 병 고르기 / 붓기 ──

  /// 병 [i]를 눌렀을 때. 고른 병이 없으면 고르고, 있으면 그 병에서 [i]로 붓는다.
  /// 부을 수 없는 병을 누르면 그 병으로 고른 병을 바꾼다 (빈 병이면 고름을 푼다).
  void tapBottle(int i) {
    if (!canAct || i < 0 || i >= state.count) return;
    final from = selected;
    if (from == null) {
      if (state.isEmpty(i) || state.isDone(i)) return;
      selected = i;
      _clearHint();
      onFeedback?.call('select');
      notifyListeners();
      return;
    }
    if (from == i) {
      selected = null;
      notifyListeners();
      return;
    }
    if (state.canPour(from, i)) {
      _pour(from, i);
      return;
    }
    // 부을 수 없다 → 눌러 본 병으로 옮겨 고른다
    selected = (state.isEmpty(i) || state.isDone(i)) ? null : i;
    if (selected != null) onFeedback?.call('select');
    notifyListeners();
  }

  /// 병 [i]를 고른다 (누르자마자 들어 올리거나, 끌기를 시작할 때). 이미 골랐으면 그대로 둔다.
  /// 비었거나 다 모은 병은 고를 수 없어 false.
  bool selectBottle(int i) {
    if (!canAct || i < 0 || i >= state.count || state.isEmpty(i) || state.isDone(i)) return false;
    if (selected == i) return true;
    selected = i;
    _clearHint();
    onFeedback?.call('select');
    notifyListeners();
    return true;
  }

  /// 고른 병을 내려놓는다 (끌다가 아무 데나 놓았을 때).
  void clearSelection() {
    if (selected == null) return;
    selected = null;
    notifyListeners();
  }

  /// 병 [from]의 물을 [to]로 붓는다 (힌트를 따라 하기에도 쓴다). 합법이 아니면 false.
  bool pourTo(int from, int to) {
    if (!canAct || !state.canPour(from, to)) return false;
    _pour(from, to);
    return true;
  }

  void _pour(int from, int to) {
    final color = state.topColor(from)!;
    _history.add(_Step(GcMove(from, to), state.copy()));
    final n = state.pour(from, to);
    selected = null;
    _clearHint();
    lastPour = GcPour(from: from, to: to, count: n, color: color, serial: ++_pourSerial);
    final becameDone = state.isDone(to);
    completed = state.isSolved;
    onFeedback?.call(completed ? 'win' : (becameDone ? 'bottle' : 'pour'));
    notifyListeners();
    if (completed) onWon?.call();
  }

  /// 빈 병 하나를 더한다 (한 판에 한 번).
  void addBottle() {
    if (!canAddBottle) return;
    _history.add(_Step(null, state.copy()));
    state.addEmptyBottle();
    selected = null;
    _clearHint();
    lastPour = null;
    onFeedback?.call('select');
    notifyListeners();
  }

  // ── 되돌리기 / 다시 ──

  void undo() {
    if (!canUndo) return;
    final step = _history.removeLast();
    state = step.before;
    selected = null;
    lastPour = null;
    _clearHint();
    notifyListeners();
  }

  /// 같은 판을 처음부터 다시.
  void restart() {
    state = initial.copy();
    _history.clear();
    selected = null;
    lastPour = null;
    completed = false;
    paused = false;
    elapsed.value = 0;
    _clearHint();
    notifyListeners();
  }

  // ── 힌트 ──

  void _clearHint() {
    hint = null;
    hintMessage = null;
    hintThinking = false;
    _hintStamp++;
  }

  /// 힌트: 이 판을 끝까지 풀어 보고, 풀 수 있으면 다음 한 수를, 이미 막혔으면 막혔다고 알려 준다.
  Future<void> requestHint() async {
    if (!canAct || hintThinking) return;
    selected = null;
    final stamp = ++_hintStamp;
    hint = null;
    hintThinking = true;
    hintMessage = '풀 수 있는 길을 찾는 중이에요…';
    notifyListeners();

    final before = state.copy();
    final result = await solveWater(before, cancelled: () => _disposed || stamp != _hintStamp);
    if (_disposed) return;
    if (stamp != _hintStamp) return; // 기다리는 사이에 수를 두었거나 닫았으면 낡은 답은 버린다
    hintThinking = false;

    switch (result.verdict) {
      case GcVerdict.winnable:
        final m = result.firstMove;
        if (m == null) {
          hint = null;
          hintMessage = null;
        } else {
          hint = m;
          hintMessage = '풀 수 있어요! 반짝이는 병의 물을 표시된 병에 부어 보세요.';
        }
      case GcVerdict.lost:
        hint = null;
        hintMessage = await _lostMessage(before, stamp);
        if (stamp != _hintStamp || _disposed) return;
      case GcVerdict.unknown:
        hint = null;
        hintMessage = '판이 복잡해서 아직 답을 못 찾았어요. 한 수 두고 다시 눌러 보세요.';
    }
    notifyListeners();
  }

  /// 막힌 판에서 해 줄 말: 병 더하기로 풀리는지도 따져 본다.
  Future<String> _lostMessage(WaterState s, int stamp) async {
    const base = '이 판은 이미 막혔어요. 어떻게 해도 이길 수 없어요.';
    if (canAddBottle) {
      final extra = s.copy()..addEmptyBottle();
      final r = await solveWater(extra, cancelled: () => _disposed || stamp != _hintStamp);
      if (r.verdict == GcVerdict.winnable) return '$base 병 더하기를 쓰면 풀 수 있어요! (또는 되돌리기)';
    }
    return '$base 되돌리기로 돌아가거나 처음부터 다시 해 보세요.';
  }

  void dismissHint() {
    if (hint == null && hintMessage == null && !hintThinking) return;
    _clearHint();
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
    selected = null;
    notifyListeners();
  }

  // ── 저장 ──

  Map<String, dynamic> toJson() => {
        'level': level.index,
        'initial': [for (final b in initial.bottles) b],
        'moves': [for (final s in _history) s.move?.code ?? _addCode],
        'elapsed': elapsed.value,
      };

  static GetColorController fromJson(Map<String, dynamic> j) {
    final level = GcLevel.values[(j['level'] as int).clamp(0, GcLevel.values.length - 1)];
    final initial = WaterState([
      for (final b in j['initial'] as List) List<int>.from(b as List),
    ]);
    return GetColorController(
      level: level,
      initial: initial,
      moveCodes: List<int>.from(j['moves'] as List),
      elapsedSeconds: j['elapsed'] as int,
    );
  }

  /// 새 판을 만든다 (풀 수 있는 판만).
  static Future<GetColorController> create(GcLevel level, {Random? rng}) async {
    final puzzle = await generateWaterPuzzle(level, rng ?? Random());
    return GetColorController(level: level, initial: puzzle);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    elapsed.dispose();
    super.dispose();
  }
}
