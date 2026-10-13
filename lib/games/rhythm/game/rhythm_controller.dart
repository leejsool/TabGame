import 'package:flutter/foundation.dart';

import '../audio/rhythm_audio.dart';
import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';

enum RhythmStatus { ready, playing, finished }

/// 화면에 잠깐 떴다 사라지는 판정 글자.
class RatingPop {
  const RatingPop(this.rating, this.at, this.side);
  final Rating rating;
  final double at;
  final Side side;
}

/// 선배(또는 플레이어)가 휘두르는 중인 동작.
class SwingState {
  const SwingState(this.progress, this.side, this.sinceImpact, {this.charge, this.swipe = false});

  /// 0 = 들어올리기 시작, [kImpactProgress] = 맞는 순간, 1 = 자세 회복.
  final double progress;
  final Side side;

  /// 맞은 뒤 지난 시간(초). 맞기 전이면 음수.
  final double sinceImpact;

  /// 꾹 눌러 힘을 모으는 중이면 모인 정도 0~1, 아니면 null.
  final double? charge;

  /// 옆으로 휘두르는 동작인가 (화면을 옆으로 긋는 박자). [side]는 칼이 휘둘러지는 쪽.
  final bool swipe;
}

/// 안내 링 하나: 남은 시간(1에서 시작해 0에서 맞음), 방향, 꾹 누르기 여부.
class CueInfo {
  const CueInfo(this.remain, this.side, {this.isHold = false, this.releasing = false, this.isSwipe = false});

  final double remain;
  final Side side;

  /// 꾹 누르기 박자인가.
  final bool isHold;

  /// 이미 누르고 있고 이제 떼야 하는 때인가.
  final bool releasing;

  /// 옆으로 긋는 박자인가 ([side]는 긋는 방향).
  final bool isSwipe;
}

/// 들어올리는 시간 / 맞은 뒤 자세 회복 시간 (초).
const double kWindup = 0.26;
const double kRecover = 0.42;

class _Cue {
  const _Cue(this.time, this.sfx);
  final double time;
  final Sfx sfx;
}

/// 코스 한 판을 진행한다. 시계는 화면이 가진다: 화면이 [update]에 곡 시간(초)을 넘겨 준다.
class RhythmController extends ChangeNotifier {
  RhythmController({
    RhythmChart? chart,
    RhythmSfx? sfx,
    this.inputOffset = 0,
    this.audioLead = 0.0,
  })  : chart = chart ?? RhythmChart.tutorial(),
        sfx = sfx ?? const SilentSfx() {
    _judge = RhythmJudge(this.chart.playerEvents);
    _buildCues();
    for (var a = 0; a < 4; a++) {
      _byActor[a] = [for (final e in this.chart.events) if (e.actor == a) e];
    }
    _stageTotals = List.filled(this.chart.stages.length, 0);
    _stageHits = List.filled(this.chart.stages.length, 0);
    for (final e in this.chart.playerEvents) {
      _stageTotals[e.stage]++;
    }
  }

  final RhythmChart chart;
  final RhythmSfx sfx;

  /// 탭 시각 보정(초). 양수면 "기기가 늦게 반응하니 그만큼 빼 준다".
  double inputOffset;

  /// 소리를 이만큼 일찍 낸다(초).
  final double audioLead;

  late RhythmJudge _judge;
  RhythmJudge get judge => _judge;

  RhythmStatus status = RhythmStatus.ready;

  /// 가장 최근에 [update]로 받은 곡 시간(초). 시작 전에는 음수.
  double now = -1;

  final List<_Cue> _cues = [];
  int _cueIndex = 0;
  final Map<int, List<ChartEvent>> _byActor = {};
  late final List<int> _stageTotals;
  late final List<int> _stageHits;

  final List<RatingPop> pops = [];

  /// 플레이어가 마지막으로 내려친 시각/방향 (애니메이션용).
  double? _playerSwingAt;
  Side _playerSwingSide = Side.left;

  /// 플레이어가 마지막으로 내려친 동작이 옆으로 긋기였는가.
  bool _playerSwingSwipe = false;

  /// 긋기를 하려고 화면에 손을 댄 채 기다리는 중 (칼을 뒤로 빼 든 자세를 보여 준다).
  bool _swipeArmed = false;
  Side _swipeArmSide = Side.right;

  /// 플레이어가 꾹 누르기 시작한 시각/방향.
  double? _holdStartT;
  Side _holdSide = Side.left;

  int _stage = 0;
  int get stage => _stage;
  TutorialStage get stageInfo => chart.stages[_stage];

  /// 새 단계가 막 시작되었을 때의 시각 (이름표 띄우기용).
  double stageBannerAt = -10;

  /// 판정 때마다 불리는 콜백 (진동 등).
  void Function(Judged j)? onJudged;
  VoidCallback? onFinished;

  void _buildCues() {
    final beat = chart.beat;
    for (var b = 0; b < chart.countInBeats; b++) {
      _cues.add(_Cue(b * beat, b == 0 ? Sfx.tickHi : Sfx.tick));
    }
    // 곡 내내 이어지는 기본 박자 (킥 + 하이햇)
    final lastBeat = (chart.endTime / beat).floor();
    for (var b = chart.countInBeats; b <= lastBeat; b++) {
      _cues.add(_Cue(b * beat, Sfx.kick));
      _cues.add(_Cue((b + 0.5) * beat, Sfx.hat));
    }
    for (final e in chart.events) {
      if (e.isPlayer) continue;
      if (e.isHold) _cues.add(_Cue(e.pressTime, Sfx.charge));
      final left = e.side == Side.left;
      _cues.add(_Cue(e.time, e.isSwipe ? (left ? Sfx.npcSwipeLeft : Sfx.npcSwipeRight) : (left ? Sfx.npcLeft : Sfx.npcRight)));
    }
    _cues.sort((a, b) => a.time.compareTo(b.time));
  }

  void start() {
    status = RhythmStatus.playing;
    now = -0.5;
    stageBannerAt = 0;
    notifyListeners();
  }

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
    notifyListeners();
  }

  /// 가만히 있을 때의 움직임(깜빡임 등)을 위해 화면만 다시 그리게 한다.
  void ping() => notifyListeners();

  void _noteMiss(Judged m) {
    sfx.play(Sfx.miss);
    pops
      ..clear()
      ..add(RatingPop(Rating.miss, now, m.event?.side ?? Side.left));
    onJudged?.call(m);
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
      notifyListeners();
      return false;
    }
    final r = _judge.tap(t - inputOffset, side);
    if (r.rating == Rating.holdStart) {
      _holdStartT = t;
      _holdSide = side;
      _playerSwingAt = null;
      sfx.play(Sfx.charge);
      notifyListeners();
      return true;
    }
    sfx.play(side == Side.left ? Sfx.hitLeft : Sfx.hitRight);
    _playerSwingAt = t;
    _playerSwingSide = side;
    _playerSwingSwipe = false;
    _afterJudge(r, t, side);
    return false;
  }

  /// 화면에 손을 댔을 때: 지금 해야 할 박자가 "옆으로 긋기"면 true.
  /// true이면 탭으로 치지 말고 손가락이 일정 거리 움직일 때까지 기다렸다가 [swipe]를 불러야 한다.
  bool beginSwipe(double t) {
    if (status != RhythmStatus.playing || t < 0) return false;
    final adj = t - inputOffset;
    final e = _judge.nextPending(adj);
    // 박자 바로 앞뒤에 닿았을 때만 (한참 먼 긋기를 미리 당겨 치는 건 아님)
    if (e == null || !e.isSwipe || e.time - adj > 0.6) return false;
    _swipeArmed = true;
    _swipeArmSide = e.side;
    notifyListeners();
    return true;
  }

  /// 긋기를 하다가 손을 뗐다 (거리를 못 채움).
  void cancelSwipe() {
    if (!_swipeArmed) return;
    _swipeArmed = false;
    notifyListeners();
  }

  /// 플레이어가 화면을 [dir] 쪽으로 일정 거리 그었다. [t]는 [update]와 같은 시계의 시각.
  void swipe(Side dir, double t) {
    if (status != RhythmStatus.playing || t < 0) return;
    _swipeArmed = false;
    now = t;
    sfx.play(dir == Side.left ? Sfx.swipeLeft : Sfx.swipeRight);
    _playerSwingAt = t;
    _playerSwingSide = dir;
    _playerSwingSwipe = true;
    if (t < chart.countInBeats * chart.beat) {
      notifyListeners();
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

  void _afterJudge(Judged r, double t, Side side) {
    if (r.rating.isHit) {
      sfx.play(Sfx.chime);
      if (r.event != null) _stageHits[r.event!.stage]++;
    } else if (r.rating != Rating.stray) {
      sfx.play(Sfx.miss);
    }
    pops
      ..clear()
      ..add(RatingPop(r.rating, t, side));
    onJudged?.call(r);
    notifyListeners();
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
    _holdStartT = null;
    _stage = 0;
    for (var i = 0; i < _stageHits.length; i++) {
      _stageHits[i] = 0;
    }
    now = -1;
    status = RhythmStatus.ready;
    notifyListeners();
  }

  // ── 그리기용 질의 ──

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
    return CueInfo((remain / span).clamp(-0.2, 1.0), e.side, isHold: e.isHold, releasing: releasing, isSwipe: e.isSwipe);
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

/// swing()의 progress에서 "맞는 순간"에 해당하는 값.
const double kImpactProgress = 0.38;
