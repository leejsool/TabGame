part of 'rhythm_controller.dart';

/// judge 조각 (화면 코드를 역할별로 나눈 파일)
extension RcJudge on RhythmController {
  /// 매 프레임 호출: 곡 시간 [t](초)를 받아 소리를 내고, 놓친 박자를 처리한다.
  void update(double t) {
    if (status != RhythmStatus.playing) return;
    now = t;
    while (_cueIndex < _cues.length && _cues[_cueIndex].time - audioLead <= t) {
      sfx.play(_cues[_cueIndex].sfx);
      _cueIndex++;
    }
    for (final m in _judge.expire(t - inputOffset)) {
      _noteMiss(m);
    }
    final s = chart.stageAt(t);
    if (s != _stage) {
      final prev = _stage;
      _stage = s;
      stageBannerAt = t;
      if (_stageHits[prev] >= _stageTotals[prev] * 0.5) sfx.play(Sfx.stageClear);
    }
    pops.removeWhere((p) => t - p.at > 1.0);
    if (t > chart.endTime + 0.3) _finish();
    _notify();
  }

  /// 가만히 있을 때의 움직임(깜빡임 등)을 위해 화면만 다시 그리게 한다.
  void ping() => _notify();

  void _noteMiss(Judged m) {
    sfx.play(Sfx.miss);
    final guard = m.event?.isGuard ?? false;
    pops
      ..clear()
      ..add(RatingPop(Rating.miss, now, m.event?.side ?? Side.left, guard: guard));
    onJudged?.call(m);
    if (guard) {
      // 보스의 공격을 막지 못했다: 하트가 하나 깎인다
      _guardOutcomes[m.event!.wave] = GuardOutcome(m.event!, false, now);
      _loseHeart();
    }
  }

  void _loseHeart() {
    if (gameOver || !hasHearts) return;
    hearts = hearts > 0 ? hearts - 1 : 0;
    heartLostAt = now;
    if (hearts <= 0) _endGameOver();
  }

  /// 하트를 다 잃어서 바로 끝낸다 (남은 곡이 있어도, 점수·별과 상관없이 실패).
  void _endGameOver() {
    if (status == RhythmStatus.finished) return;
    gameOver = true;
    status = RhythmStatus.finished;
    sfx.play(Sfx.miss);
    onFinished?.call();
  }

  /// 플레이어가 화면 [side]쪽을 눌렀다. [t]는 [update]와 같은 시계의 시각.
  /// 꾹 누르기를 시작했다면 true (손을 뗄 때 [release]를 불러야 한다).
  bool tap(Side side, double t) {
    if (status != RhythmStatus.playing) return false;
    if (t < 0) return false; // 시작 전
    now = t;
    // 카운트다운 중에는 휘둘러 볼 수만 있고 판정은 하지 않는다
    if (t < chart.countInBeats * chart.beat) {
      sfx.play(side == Side.left ? Sfx.hitLeft : Sfx.hitRight);
      _playerSwingAt = t;
      _playerSwingSide = side;
      _playerSwingSwipe = false;
      _notify();
      return false;
    }
    final r = _judge.tap(t - inputOffset, side);
    if (r.rating == Rating.holdStart) {
      _holdStartT = t;
      _holdSide = side;
      _playerSwingAt = null;
      sfx.play(Sfx.charge);
      _notify();
      return true;
    }
    sfx.play(side == Side.left ? Sfx.hitLeft : Sfx.hitRight);
    _playerSwingAt = t;
    _playerSwingSide = side;
    _playerSwingSwipe = false;
    _afterJudge(r, t, side);
    return false;
  }

  /// 플레이어가 화면을 위로 쓱 밀었다 (보스의 공격 막기). 어느 손이든 상관없다.
  /// [t]는 [update]와 같은 시계의 시각.
  void guard(double t) {
    if (status != RhythmStatus.playing || t < 0) return;
    _swipeArmed = false;
    _armedGuard = false;
    now = t;
    _guardAt = t;
    sfx.play(Sfx.hitRight);
    if (t < chart.countInBeats * chart.beat) {
      _notify();
      return;
    }
    final r = _judge.guard(t - inputOffset);
    if (r.rating.isHit && r.event != null) {
      _guardOutcomes[r.event!.wave] = GuardOutcome(r.event!, true, t);
    }
    _afterJudge(r, t, Side.left, guard: true);
  }

  /// 화면에 손을 댔을 때: 지금 해야 할 박자가 "옆으로 긋기"면 true.
  /// true이면 탭으로 치지 말고 손가락이 일정 거리 움직일 때까지 기다렸다가 [swipe]를 불러야 한다.
  bool beginSwipe(double t) {
    if (status != RhythmStatus.playing || t < 0) return false;
    final adj = t - inputOffset;
    final e = _judge.nextPending(adj);
    // 박자 바로 앞뒤에 닿았을 때만 (한참 먼 긋기를 미리 당겨 치는 건 아님)
    if (e == null || !(e.isSwipe || e.isGuard) || e.time - adj > 0.6) return false;
    _swipeArmed = true;
    _armedGuard = e.isGuard;
    _swipeArmSide = e.side;
    _notify();
    return true;
  }

  /// 긋기를 하다가 손을 뗐다 (거리를 못 채움).
  void cancelSwipe() {
    if (!_swipeArmed) return;
    _swipeArmed = false;
    _armedGuard = false;
    _notify();
  }

  /// 플레이어가 화면을 [dir] 쪽으로 일정 거리 그었다. [t]는 [update]와 같은 시계의 시각.
  void swipe(Side dir, double t) {
    if (status != RhythmStatus.playing || t < 0) return;
    _swipeArmed = false;
    _armedGuard = false;
    now = t;
    sfx.play(dir == Side.left ? Sfx.swipeLeft : Sfx.swipeRight);
    _playerSwingAt = t;
    _playerSwingSide = dir;
    _playerSwingSwipe = true;
    if (t < chart.countInBeats * chart.beat) {
      _notify();
      return;
    }
    _afterJudge(_judge.swipe(t - inputOffset, dir), t, dir);
  }

  /// 플레이어가 손을 뗐다. 꾹 누르고 있던 중이 아니면 아무 일도 없다.
  void release(double t) {
    if (status != RhythmStatus.playing) return;
    final r = _judge.release(t - inputOffset);
    if (r == null) return;
    now = t;
    sfx.play(_holdSide == Side.left ? Sfx.hitLeft : Sfx.hitRight);
    _playerSwingAt = t;
    _playerSwingSide = _holdSide;
    _playerSwingSwipe = false;
    _holdStartT = null;
    _afterJudge(r, t, _holdSide);
  }

  void _afterJudge(Judged r, double t, Side side, {bool guard = false}) {
    if (r.rating.isHit) {
      sfx.play(Sfx.chime);
      if (r.event != null) _stageHits[r.event!.stage]++;
    } else if (r.rating != Rating.stray) {
      sfx.play(Sfx.miss);
    }
    pops
      ..clear()
      ..add(RatingPop(r.rating, t, side, guard: guard));
    onJudged?.call(r);
    _notify();
  }

  void _finish() {
    if (status == RhythmStatus.finished) return;
    status = RhythmStatus.finished;
    sfx.play(Sfx.allClear);
    onFinished?.call();
  }

  /// 처음부터 다시.
  void restart() {
    _judge = RhythmJudge(chart.playerEvents);
    _cueIndex = 0;
    pops.clear();
    _playerSwingAt = null;
    _playerSwingSwipe = false;
    _swipeArmed = false;
    _armedGuard = false;
    _guardAt = null;
    _guardOutcomes.clear();
    hearts = chart.hearts;
    gameOver = false;
    heartLostAt = -10;
    _holdStartT = null;
    _stage = 0;
    for (var i = 0; i < _stageHits.length; i++) {
      _stageHits[i] = 0;
    }
    now = -1;
    status = RhythmStatus.ready;
    _notify();
  }
}
