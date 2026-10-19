import 'package:flutter/foundation.dart';

import '../core/dot_levels.dart';
import '../core/dot_rules.dart';

/// 화면에 그릴 효과 한 개: 쏜 탄과 그 자리에서 터지는 도트.
class ShotFx {
  const ShotFx(this.shot, this.at);

  final Shot shot;

  /// 쏜 때 (게임 시계, 초).
  final double at;
}

/// 도트 캐논 한 판: 규칙([DotGame])에 시간과 입출력을 얹는다.
///
/// 벨트는 [stepSeconds]마다 한 칸씩 돈다. 화면은 프레임마다 [advance]를 불러 시간을 흘려보낸다.
class DotController extends ChangeNotifier {
  DotController({required this.level, DotGame? game, int elapsedSeconds = 0})
      : game = game ?? level.newGame(),
        elapsed = ValueNotifier<int>(elapsedSeconds);

  final DotLevel level;
  DotGame game;

  /// 벨트가 한 칸 도는 데 걸리는 시간 (1배속일 때).
  static const double stepSeconds = 0.14;

  /// 탄이 날아가는 시간 (게임 시계 기준).
  static const double flightSeconds = 0.16;

  /// 도트가 터지는 시간.
  static const double popSeconds = 0.22;

  static const List<int> speeds = [1, 2, 4];

  /// 기본 빠르기: 게임 시계가 실제 시간보다 이만큼 빨리 흐른다 (2026-10-18 사용자 요청: 예전 2배속을 1배속으로).
  /// 벨트·탄·터짐이 모두 같이 빨라진다. 화면의 "N배속"은 이 위에 곱해진다.
  static const double baseSpeed = 2;

  /// 프레임마다 바뀌는 값 (그림이 다시 그려지도록 한다).
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  final ValueNotifier<int> elapsed;

  /// 대기 중인 대포를 꾹 누르고 있는 동안, 그 대포의 색 번호 (판·벨트·대기열에서 같은 색을 돋보이게 한다). 평소엔 null.
  final ValueNotifier<int?> highlight = ValueNotifier<int?>(null);

  /// 입구가 막혀서 기다리는 중인 줄 번호. 입구가 비면 차례로 벨트에 올라간다.
  final List<int> pending = [];

  int speedIndex = 0;
  int get speed => speeds[speedIndex];

  bool paused = false;
  bool completed = false;
  bool gaveUp = false;

  /// 막다른 길에 몰렸다 (처음부터 다시 하거나 나가야 한다).
  bool stalled = false;

  /// 게임 시계 (초) — 효과의 시간을 잰다.
  double clock = 0;
  double _acc = 0;
  double _secAcc = 0;

  final List<ShotFx> fx = [];

  /// 방금 벨트에서 탄이 떨어져 사라진 대포 (효과용).
  final List<(Cannon, double)> spent = [];

  void Function(String kind)? onFeedback;
  VoidCallback? onWon;
  VoidCallback? onStalled;

  /// 마지막 도트를 맞힌 바로 그 순간 (완성 창은 한참 뒤에 뜨니까, 기록은 이때 남긴다).
  VoidCallback? onSolved;

  /// 벨트가 한 칸 도는 중 어디까지 왔는지 (0..1).
  double get stepFraction => (_acc / stepSeconds).clamp(0.0, 1.0);

  /// 아직 아무것도 올리지 않았다.
  bool get untouched => game.deploys == 0;

  /// 저장해 둘 만한 판인가.
  bool get savable => !completed && !game.won && !gaveUp && !untouched;

  /// 마지막 도트를 맞혔을 때, 이 시간(실제 초)이 지나면 [completed]가 된다.
  /// 마지막 탄이 날아가 도트가 터지는 모습까지 보여 준 뒤에 이겼다고 알린다.
  double? _winDelay;

  void cycleSpeed() {
    speedIndex = (speedIndex + 1) % speeds.length;
    notifyListeners();
  }

  void setPaused(bool v) {
    if (paused == v || completed) return;
    paused = v;
    notifyListeners();
  }

  /// 열 [column]의 맨 앞 대포를 벨트에 올린다.
  ///
  /// 벨트 자리는 남았는데 입구에 다른 대포가 지나가는 중이면, 거절하지 않고 기다렸다가 입구가 비는 대로 올린다.
  bool deploy(int column) {
    if (completed || game.won || gaveUp || paused || stalled) return false;
    if (_entryBusyOnly(column)) {
      if (!pending.contains(column)) {
        pending.add(column);
        notifyListeners();
      }
      return true;
    }
    if (!game.deploy(column)) {
      onFeedback?.call('full');
      return false;
    }
    onFeedback?.call('deploy');
    notifyListeners();
    return true;
  }

  /// 입구가 막힌 것 말고는 올릴 수 있는 상태인가.
  bool _entryBusyOnly(int column) =>
      !game.canDeploy(column) &&
      column >= 0 &&
      column < game.queue.length &&
      game.queue[column].isNotEmpty &&
      game.belt.length < game.capacity;

  /// 기다리던 대포를 입구가 빈 만큼 올린다. 올릴 수 없게 된 것(벨트가 가득 참 등)은 접는다.
  /// 올린 것이 있으면 true.
  bool _flushPending() {
    var placed = false;
    while (pending.isNotEmpty) {
      final col = pending.first;
      if (game.canDeploy(col)) {
        pending.removeAt(0);
        game.deploy(col);
        onFeedback?.call('deploy');
        placed = true;
      } else if (_entryBusyOnly(col)) {
        break; // 아직 입구가 막혀 있다: 더 기다린다
      } else {
        pending.removeAt(0);
        onFeedback?.call('full');
      }
    }
    return placed;
  }

  /// [dt]초만큼 시간을 흘려보낸다 (화면의 프레임마다).
  void advance(double dt) {
    if (paused || completed || gaveUp || stalled) return;
    final scaled = dt * speed * baseSpeed;
    clock += scaled;
    final winDelay = _winDelay;
    if (winDelay != null) {
      // 다 맞혔다: 벨트는 멈추고, 마지막 탄이 날아가 터지는 동안 기다렸다가 이겼다고 알린다
      _winDelay = winDelay - dt;
      if (_winDelay! <= 0) {
        _winDelay = null;
        completed = true;
        onFeedback?.call('win');
        onWon?.call();
        notifyListeners();
      }
      fx.removeWhere((e) => clock - e.at > flightSeconds + popSeconds + 0.1);
      frame.value++;
      return;
    }
    _acc += scaled;
    _secAcc += dt;
    while (_secAcc >= 1) {
      _secAcc -= 1;
      elapsed.value++;
    }
    var changed = false;
    while (_acc >= stepSeconds && !completed && !stalled && _winDelay == null) {
      _acc -= stepSeconds;
      final before = game.belt.toList();
      final shots = game.step();
      _flushPending();
      for (final s in shots) {
        fx.add(ShotFx(s, clock));
      }
      for (final c in before) {
        if (c.ammo <= 0) spent.add((c, clock));
      }
      if (shots.isNotEmpty) onFeedback?.call('hit');
      changed = true;
      if (game.won) {
        // 탄이 날아가 터지는 시간(게임 시계)을 실제 초로 바꾸고, 터진 뒤 잠깐 더 보여 준다
        _winDelay = (flightSeconds + popSeconds) / (speed * baseSpeed) + 0.3;
        _acc = 0;
        onSolved?.call();
      } else if (game.stuck) {
        stalled = true;
        onFeedback?.call('stuck');
        onStalled?.call();
      }
    }
    fx.removeWhere((e) => clock - e.at > flightSeconds + popSeconds + 0.1);
    spent.removeWhere((e) => clock - e.$2 > 0.5);
    frame.value++;
    if (changed) notifyListeners();
  }

  /// 같은 단계를 처음부터 다시.
  void restart() {
    game = level.newGame();
    fx.clear();
    spent.clear();
    completed = false;
    gaveUp = false;
    stalled = false;
    paused = false;
    clock = 0;
    _acc = 0;
    _secAcc = 0;
    _winDelay = null;
    pending.clear();
    highlight.value = null;
    elapsed.value = 0;
    notifyListeners();
  }

  /// 포기.
  bool giveUp() {
    if (completed || gaveUp || untouched) return false;
    gaveUp = true;
    notifyListeners();
    return true;
  }

  Map<String, dynamic> toJson() => {
        'lv': level.id,
        // 내가 만든 그림은 그림 자체도 같이 보관한다 (목록에서 지워도 이어할 수 있게)
        if (level.custom) 'level': level.toJson(),
        'game': game.toJson(),
        'sec': elapsed.value,
      };

  static DotController fromJson(Map<String, dynamic> j) {
    final DotLevel level;
    if (j['level'] != null) {
      level = DotLevel.fromJson(j['level'] as Map<String, dynamic>);
    } else {
      level = dotLevels.firstWhere((l) => l.id == j['lv'], orElse: () => throw const FormatException('모르는 단계예요'));
    }
    final game = DotGame.fromJson(j['game'] as Map<String, dynamic>);
    if (game.width != level.width || game.height != level.height) {
      throw const FormatException('그림 크기가 맞지 않아요');
    }
    return DotController(level: level, game: game, elapsedSeconds: j['sec'] as int);
  }

  @override
  void dispose() {
    frame.dispose();
    highlight.dispose();
    elapsed.dispose();
    super.dispose();
  }
}
