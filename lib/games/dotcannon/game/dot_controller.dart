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

  /// 프레임마다 바뀌는 값 (그림이 다시 그려지도록 한다).
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  final ValueNotifier<int> elapsed;

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

  /// 벨트가 한 칸 도는 중 어디까지 왔는지 (0..1).
  double get stepFraction => (_acc / stepSeconds).clamp(0.0, 1.0);

  /// 아직 아무것도 올리지 않았다.
  bool get untouched => game.deploys == 0;

  /// 저장해 둘 만한 판인가.
  bool get savable => !completed && !gaveUp && !untouched;

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
  bool deploy(int column) {
    if (completed || gaveUp || paused || stalled) return false;
    if (!game.deploy(column)) {
      onFeedback?.call('full');
      return false;
    }
    onFeedback?.call('deploy');
    notifyListeners();
    return true;
  }

  /// [dt]초만큼 시간을 흘려보낸다 (화면의 프레임마다).
  void advance(double dt) {
    if (paused || completed || gaveUp || stalled) return;
    final scaled = dt * speed;
    clock += scaled;
    _acc += scaled;
    _secAcc += dt;
    while (_secAcc >= 1) {
      _secAcc -= 1;
      elapsed.value++;
    }
    var changed = false;
    while (_acc >= stepSeconds && !completed && !stalled) {
      _acc -= stepSeconds;
      final before = game.belt.toList();
      final shots = game.step();
      for (final s in shots) {
        fx.add(ShotFx(s, clock));
      }
      for (final c in before) {
        if (c.ammo <= 0) spent.add((c, clock));
      }
      if (shots.isNotEmpty) onFeedback?.call('hit');
      changed = true;
      if (game.won) {
        completed = true;
        onFeedback?.call('win');
        onWon?.call();
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
    elapsed.dispose();
    super.dispose();
  }
}
