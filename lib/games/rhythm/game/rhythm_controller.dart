import 'package:flutter/foundation.dart';

import '../audio/rhythm_audio.dart';
import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';

part 'rhythm_controller_judge.dart';
part 'rhythm_controller_views.dart';

enum RhythmStatus { ready, playing, finished }

/// 화면에 잠깐 떴다 사라지는 판정 글자.
class RatingPop {
  const RatingPop(this.rating, this.at, this.side, {this.guard = false});
  final Rating rating;
  final double at;
  final Side side;

  /// 보스의 공격을 막는 박자의 판정인가 (글자가 "막았다!" 식으로 나온다).
  final bool guard;
}

/// 보스의 공격 하나를 막았는지 못 막았는지.
class GuardOutcome {
  const GuardOutcome(this.event, this.blocked, this.at);

  final ChartEvent event;
  final bool blocked;

  /// 결과가 정해진 곡 시간(초).
  final double at;
}

/// 보스 슬라임이 지금 하는 일 (화면이 모습을 고르는 데 쓴다).
enum BossPhase {
  /// 가만히 있다.
  idle,

  /// 힘을 모으는 중 (떨리고 점점 커진다).
  windup,

  /// 내게 덮쳐 오는 중.
  lunge,

  /// 막혀서 튕겨 나가는 중.
  blocked,

  /// 막지 못해 내리찍은 모습.
  slam,
}

class BossState {
  const BossState(this.phase, this.progress);

  final BossPhase phase;

  /// 그 동작이 얼마나 진행됐는지 0~1.
  final double progress;
}

/// 선배(또는 플레이어)가 휘두르는 중인 동작.
class SwingState {
  const SwingState(this.progress, this.side, this.sinceImpact, {this.charge, this.swipe = false, this.guard = false});

  /// 0 = 들어올리기 시작, [kImpactProgress] = 맞는 순간, 1 = 자세 회복.
  final double progress;
  final Side side;

  /// 맞은 뒤 지난 시간(초). 맞기 전이면 음수.
  final double sinceImpact;

  /// 꾹 눌러 힘을 모으는 중이면 모인 정도 0~1, 아니면 null.
  final double? charge;

  /// 옆으로 휘두르는 동작인가 (화면을 옆으로 긋는 박자). [side]는 칼이 휘둘러지는 쪽.
  final bool swipe;

  /// 검을 들어 막는 자세인가 (보스의 공격을 막는 중).
  final bool guard;
}

/// 안내 링 하나: 남은 시간(1에서 시작해 0에서 맞음), 방향, 꾹 누르기 여부.
class CueInfo {
  const CueInfo(this.remain, this.side, {this.isHold = false, this.releasing = false, this.isSwipe = false, this.isGuard = false});

  final double remain;
  final Side side;

  /// 꾹 누르기 박자인가.
  final bool isHold;

  /// 이미 누르고 있고 이제 떼야 하는 때인가.
  final bool releasing;

  /// 옆으로 긋는 박자인가 ([side]는 긋는 방향).
  final bool isSwipe;

  /// 보스의 공격을 막는 박자인가 (위로 쓱 밀기).
  final bool isGuard;
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
  /// 다른 파일(part)에 나눠 둔 조각에서 화면에 바뀐 것을 알릴 때 쓴다.
  void _notify() => notifyListeners();

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
    hearts = this.chart.hearts;
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

  /// 긋기(또는 막기)를 하려고 화면에 손을 댄 채 기다리는 중 (칼을 뒤로 빼 든 자세를 보여 준다).
  bool _swipeArmed = false;

  /// 기다리는 것이 막기(위로 밀기)인가 — 그러면 가로가 아니라 위로 밀어야 한다.
  bool _armedGuard = false;
  bool get armedGuard => _swipeArmed && _armedGuard;
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

  // ── 하트 / 게임 오버 (보스 코스) ──

  /// 남은 하트. 보스의 공격을 막지 못할 때마다 하나 깎이고, 0이 되면 [gameOver].
  late int hearts;

  /// 하트가 있는 곡인가.
  bool get hasHearts => chart.hearts > 0;

  /// 하트를 다 잃어서 끝났는가. 이때는 점수·별과 상관없이 실패다.
  bool gameOver = false;

  /// 마지막으로 하트를 잃은 곡 시간 (하트가 깎이는 모습·화면 번쩍임용).
  double heartLostAt = -10;

  final Map<int, GuardOutcome> _guardOutcomes = {};

  /// 막기 박자 [e]의 결과 (아직 안 정해졌으면 null).
  GuardOutcome? guardOutcome(ChartEvent e) => _guardOutcomes[e.wave];

  /// 막으려고 위로 쓱 민 마지막 시각 (검 든 자세·방어 효과용).
  double? _guardAt;
  double? get lastGuardAt => _guardAt;

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
    for (final e in chart.guards) {
      // 보스가 힘을 모으는 소리: 덮치기 한 박 전부터 올라가서, 덮치는 순간에 터진다
      _cues.add(_Cue(e.time - beat, Sfx.charge));
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

  // ── 그리기용 질의 ──


}

/// swing()의 progress에서 "맞는 순간"에 해당하는 값.
const double kImpactProgress = 0.38;

/// 보스 공격 동작의 길이들 (초).
class BossTiming {
  BossTiming._();

  /// 힘을 모으는 박 수 (곡 쪽 [RhythmChart.guardWindupBeats]와 같다).
  static const int windupBeats = RhythmChart.guardWindupBeats;

  /// 덮치는 데 걸리는 시간 (맞는 순간 직전).
  static const double lungeSeconds = 0.18;

  /// 막혀서 튕겨 나가는 시간 / 막지 못해 내리찍은 모습이 남는 시간.
  static const double recoilSeconds = 0.6;
  static const double slamSeconds = 0.7;
}
