part of 'rhythm_controller.dart';

/// views 조각 (화면 코드를 역할별로 나눈 파일)
extension RcViews on RhythmController {
  /// [actor]의 지금 동작. 쉬는 중이면 null.
  SwingState? swing(int actor, double t) {
    if (actor == 3) {
      // 꾹 눌러 힘을 모으는 중
      final held = _judge.holdingEvent;
      final hs = _holdStartT;
      if (held != null && hs != null) {
        final len = (held.time - held.pressTime).clamp(0.05, 10.0);
        final charge = ((t - hs) / len).clamp(0.0, 1.0);
        return SwingState(kImpactProgress * 0.9, _holdSide, -0.05, charge: charge);
      }
      // 위로 밀어서 막은 직후: 검을 들어 막는 자세를 잠깐 유지한다
      final ga = _guardAt;
      if (ga != null && t >= ga && t - ga < 0.5) return SwingState(kImpactProgress, Side.left, t - ga, guard: true);
      // 막으려고(위로 밀려고) 손을 댄 채 기다리는 중: 검을 들어 올릴 준비
      if (_swipeArmed && _armedGuard) return SwingState(kImpactProgress * 0.9, Side.left, -0.05, guard: true);
      // 옆으로 긋기를 하려고 손을 댄 채 기다리는 중: 칼을 뒤로 빼 든다
      if (_swipeArmed) return SwingState(kImpactProgress * 0.9, _swipeArmSide, -0.05, swipe: true);
      final at = _playerSwingAt;
      if (at == null) return null;
      final dt = t - at;
      if (dt < 0 || dt > kRecover) return null;
      // 플레이어는 탭한(또는 손을 뗀, 그은) 순간이 곧 내려치는 순간
      return SwingState(kImpactProgress + dt / kRecover * (1 - kImpactProgress), _playerSwingSide, dt, swipe: _playerSwingSwipe);
    }
    final list = _byActor[actor]!;
    // 꾹 누르는 중인 선배: 힘을 모으는 자세를 유지한다
    for (final e in list) {
      if (e.isHold && t >= e.pressTime - 0.02 && t < e.time) {
        final charge = ((t - e.pressTime) / (e.time - e.pressTime)).clamp(0.0, 1.0);
        return SwingState(kImpactProgress * 0.9, e.side, t - e.time, charge: charge);
      }
    }
    ChartEvent? best;
    var bestAbs = 1e9;
    for (final e in list) {
      final dt = t - e.time; // 0이 맞는 순간
      if (dt < -kWindup) break;
      if (dt > kRecover) continue;
      if (e.isHold && dt < 0) continue; // 위에서 처리
      if (dt.abs() < bestAbs) {
        bestAbs = dt.abs();
        best = e;
      }
    }
    if (best != null) {
      final dt = t - best.time;
      final p = dt < 0
          ? (1 + dt / kWindup) * kImpactProgress
          : kImpactProgress + dt / kRecover * (1 - kImpactProgress);
      return SwingState(p, best.side, dt, swipe: best.isSwipe);
    }
    return null;
  }

  /// 안내 링: 남은 시간(1에서 시작해 0에서 맞음), 방향, 꾹 누르기 여부.
  CueInfo? cue(double t) {
    if (!stageInfo.cue || status != RhythmStatus.playing) return null;
    final tAdj = t - inputOffset;
    final e = _judge.nextPending(tAdj);
    if (e == null || e.stage != _stage && chart.stages[e.stage].cue == false) return null;
    final releasing = _judge.holdingEvent != null;
    final ref = releasing ? e.time : e.pressTime;
    final remain = ref - tAdj;
    final span = chart.beat * 1.4;
    if (remain > span) return null;
    return CueInfo((remain / span).clamp(-0.2, 1.0), e.side, isHold: e.isHold, releasing: releasing, isSwipe: e.isSwipe, isGuard: e.isGuard);
  }

  /// 보스 슬라임이 곡 시간 [t]에 하는 일. 막기 박자마다: 세 박 동안 힘을 모으고(windup),
  /// 덮친 뒤(lunge) — 막았으면 튕겨 나가고(blocked), 못 막았으면 내리찍는다(slam).
  BossState bossState(double t) {
    final b = chart.beat;
    for (final e in chart.guards) {
      final start = e.time - BossTiming.windupBeats * b;
      final lungeAt = e.time - BossTiming.lungeSeconds;
      if (t < start) return const BossState(BossPhase.idle, 0);
      if (t < lungeAt) return BossState(BossPhase.windup, ((t - start) / (lungeAt - start)).clamp(0.0, 1.0));
      if (t < e.time) return BossState(BossPhase.lunge, ((t - lungeAt) / BossTiming.lungeSeconds).clamp(0.0, 1.0));
      final out = _guardOutcomes[e.wave];
      if (out != null && out.blocked) {
        final since = t - out.at;
        if (since < BossTiming.recoilSeconds) return BossState(BossPhase.blocked, (since / BossTiming.recoilSeconds).clamp(0.0, 1.0));
        continue;
      }
      final since = t - e.time;
      if (since < BossTiming.slamSeconds) return BossState(BossPhase.slam, (since / BossTiming.slamSeconds).clamp(0.0, 1.0));
    }
    return const BossState(BossPhase.idle, 0);
  }

  /// 지금 박자에 쳐야 하는 사람(0~3). 카운트다운 중이거나 시작 전이면 -1.
  int activeActor(double t) {
    if (t < 0) return -1;
    ChartEvent? best;
    for (final e in chart.events) {
      if (e.pressTime - 0.1 <= t && t <= e.time + 0.25) {
        if (best == null || e.pressTime > best.pressTime) best = e;
      }
    }
    return best?.actor ?? -1;
  }

  /// 지금 박(beat) 안에서의 위치 0~1 (배경 맥박 효과용). 시작 전엔 0.
  double beatPhase(double t) {
    if (t < 0) return 0;
    final b = t / chart.beat;
    return b - b.floorToDouble();
  }

  /// 몇 번째 박자인지 (카운트다운 숫자용).
  int beatIndex(double t) => t < 0 ? -1 : (t / chart.beat).floor();
}
