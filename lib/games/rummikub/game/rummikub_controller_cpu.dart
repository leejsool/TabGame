part of 'rummikub_controller.dart';

/// cpu 조각 (화면 코드를 역할별로 나눈 파일)
extension RummikubControllerCpu on RummikubController {
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
    _notify();
    if (table != null) {
      layoutSets(layoutWidth, layoutPerRow); // 지금 판의 묶음들이 모두 자리를 갖게
      final steps = _stepsFor(table);
      var ms = steps.length > 8 ? max(220, stepDelay.inMilliseconds * 8 ~/ steps.length) : stepDelay.inMilliseconds;
      ms = (ms * GameSpeed.factor).round();
      await Future<void>.delayed(Duration(milliseconds: ms ~/ 2));
      for (final step in steps) {
        if (_cpu.disposed || epoch != _animEpoch) return;
        // 이미 제자리에 있는 타일은 옮길 게 없으니 소리도 기다림도 없이 넘어간다
        if (!step()) continue;
        onFeedback?.call('step'); // (상대가 타일을 실제로 한 장 옮길 때마다 딸깍 소리)
        _notify();
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
    } else if (isDraw && pick != null && pick < state.pool.length) {
      opponentPick = state.pool[pick];
      onFeedback?.call('step');
      _notify();
      await Future<void>.delayed(GameSpeed.scale(stepDelay) * 1.4);
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
    _notify();
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
    _notify();
  }
}
