part of 'yacht_controller.dart';

// 한 차례의 제한 시간: 사람의 차례마다 [YachtController.turnSeconds]초가 주어지고,
// 시간이 다 되면 지금 주사위로 가장 높은 점수가 나는 칸에 저절로 적는다 (아직 안 굴렸으면 한 번 굴린 뒤).
// 같은 Wi‑Fi 판과 CPU(봇)의 차례에는 시계가 없다.

/// 시간이 다 됐을 때 적을 칸: 지금 주사위로 점수가 가장 높은 빈 칸. 같으면 점수판 위쪽 칸.
YachtCategory yachtTimeoutCategory(YachtCard card, List<int> dice) {
  YachtCategory? best;
  var bestScore = -1;
  for (final c in card.categories) {
    if (!card.isOpen(c)) continue;
    final s = card.scoreOf(c, dice);
    if (s > bestScore) {
      best = c;
      bestScore = s;
    }
  }
  return best!;
}

extension YachtClock on YachtController {
  /// 시계를 지금 판의 상황에 맞춘다: 새 사람 차례가 시작됐으면 처음부터, 시계가 필요 없으면 멈춘다.
  void _syncClock() {
    final secs = turnSeconds;
    if (secs == null || online || game.over || !humanTurn) {
      _stopClock();
      return;
    }
    final key = '$_epoch:${game.turn}:${game.card.filledCount}';
    if (key == _clockFor) return;
    _stopClock();
    _clockFor = key;
    _timeUp = false;
    secondsLeft = secs;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
    _clockFor = null;
    secondsLeft = null;
  }

  void _tick() {
    final now = secondsLeft;
    if (now == null || _disposed) return;
    final left = now - 1 < 0 ? 0 : now - 1;
    secondsLeft = left; // (막대만 다시 그린다: [YachtController.clock])
    if (left == 0) _onTimeUp();
  }

  /// 시간이 다 됐다: 사람은 더 누를 수 없고, 가장 높은 점수 칸에 저절로 적는다.
  Future<void> _onTimeUp() async {
    _clock?.cancel();
    _clock = null;
    if (_timeUp) return;
    _timeUp = true;
    pick = null;
    final epoch = _epoch;
    final seat = game.turn;
    if (game.rollsUsed == 0 && !rolling) {
      if (!await _roll()) return;
    }
    while (rolling) {
      if (!await _wait(50)) return;
    }
    if (_disposed || epoch != _epoch || game.over || game.turn != seat || game.rollsUsed == 0) return;
    final c = yachtTimeoutCategory(game.card, game.dice);
    pick = c;
    _rawNotify();
    if (!await _wait(600)) return; // 어느 칸에 적히는지 잠깐 보여 준다
    if (game.turn != seat || game.over) return;
    _score(c);
    _runCpu();
  }
}
