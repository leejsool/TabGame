part of 'davinci_controller.dart';

/// turns 조각 (화면 코드를 역할별로 나눈 파일)
extension DavinciControllerTurns on DavinciController {
  void _next() {
    if (_disposed || !runsCpu || isOver || halted || !isCpuSeat(turn) || _cpuRunning) return;
    _cpuLoop();
  }

  /// CPU 차례 동안 수를 하나씩 둔다 (사람이 볼 수 있게 수마다 잠깐 쉰다). 사람 차례가 오면 멈춘다.
  Future<void> _cpuLoop() async {
    final epoch = ++_epoch;
    _cpuRunning = true;
    _notify();
    while (!_disposed && epoch == _epoch && !isOver && !halted && isCpuSeat(turn)) {
      await Future<void>.delayed(GameSpeed.scale(cpuStepDelay));
      await _effectsIdle(); // (직전에 다른 사람이 둔 수를 다 보여 준 뒤에 둔다)
      while (cpuHold && !_disposed && epoch == _epoch) {
        await Future<void>.delayed(const Duration(milliseconds: 100)); // (사람이 고르는 동안 기다린다)
      }
      if (_disposed || epoch != _epoch || isOver || halted || !isCpuSeat(turn)) break;
      final move = DvAi.choose(state, level, _rng);
      _apply(move);
      if (online) onLocalMove?.call(move); // (같은 Wi‑Fi 방이면 CPU의 수도 다른 기기들에 알린다)
      // 조커를 뽑았으면 자리도 바로 정한다 (보는 사람에게는 뽑기 하나로 보인다)
      if (state.phase == DvPhase.placeJoker && isCpuSeat(turn)) {
        final place = DvAi.choose(state, level, _rng);
        _apply(place);
        if (online) onLocalMove?.call(place);
      }
      // 이 수가 어떤 수였는지 다 보여 줄 때까지 기다렸다가 다음 수를 둔다
      await _effectsIdle();
    }
    if (_disposed || epoch != _epoch) return;
    _cpuRunning = false;
    _notify();
  }

  /// 기권할 수 있는가. 3~4명이 Wi‑Fi로 할 때는 누가 이기는 건지 정할 수 없어 기권이 없다.
  bool get canResign => !isOver && !halted && moves.isNotEmpty && (vsCpu || players == 2);

  /// 기권한다 (CPU가 두던 수는 버린다). 이긴 사람은 [resignWinner]. 기권했으면 true.
  bool resign() {
    if (!canResign) return false;
    _epoch++;
    _clearEffects();
    _cpuRunning = false;
    clearSelection();
    halted = true;
    resignWinner = _winnerWhenResigned(humanSeat);
    _notify();
    return true;
  }

  /// 사람이 모두 탈락한 판을 여기서 끝낸다 (CPU끼리의 남은 순위 싸움은 보지 않는다).
  /// 이긴 사람은 [resignWinner]: 그 시점에 숨은 타일이 가장 많이 남은 CPU. 끝냈으면 true.
  bool endWatching() {
    if (!_humansOutNow) return false;
    _epoch++;
    _clearEffects();
    _cpuRunning = false;
    clearSelection();
    var best = -1, bestN = -1;
    for (var p = 0; p < players; p++) {
      if (state.isOut(p)) continue;
      final n = state.hiddenCount(p);
      if (n > bestN) {
        bestN = n;
        best = p;
      }
    }
    halted = true;
    endedWatching = true;
    resignWinner = best;
    _notify();
    return true;
  }

  /// 상대가 기권했다는 소식을 받았다 (Wi‑Fi 대결). 내가 이긴 것으로 끝난다.
  void opponentResigned() {
    if (!online || isOver || halted) return;
    _epoch++;
    _clearEffects();
    clearSelection();
    halted = true;
    resignWinner = humanSeat;
    _notify();
  }

  /// [seat]이 기권했을 때 이긴 사람: 2명이면 상대, 그 이상이면 숨은 타일이 가장 많이 남은 사람.
  int _winnerWhenResigned(int seat) {
    var best = -1, bestN = -1;
    for (var p = 0; p < players; p++) {
      if (p == seat) continue;
      final n = state.hiddenCount(p);
      if (n > bestN) {
        bestN = n;
        best = p;
      }
    }
    return best;
  }
}
