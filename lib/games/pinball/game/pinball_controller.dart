import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/pinball_run.dart';
import '../core/pinball_table.dart';
import '../core/pinball_upgrades.dart';
import '../data/pinball_history.dart';

/// 핀볼 화면의 두뇌: 시계(프레임마다 한 걸음)와 손가락 입력을 [PinballRun]에 이어 준다.
class PinballController extends ChangeNotifier {
  PinballController({int? seed}) : run = PinballRun(seed: seed);

  PinballRun run;

  /// 소리·진동 알림 (화면이 GameFx로 이어 준다).
  void Function(String kind)? onFeedback;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool paused = false;
  bool _saved = false;

  /// 화면 맨 위에 보이는 판 좌표의 y (카메라). 화면에 보이는 판의 높이는 [viewH].
  double camY = 0;
  double _viewH = 900;
  bool _camPlaced = false;

  set viewH(double v) {
    _viewH = v;
    if (!_camPlaced) {
      _camPlaced = true;
      camY = _maxCam; // 처음에는 아래쪽(플리퍼와 발사 통로)을 보여 준다
    }
  }

  double get _maxCam => max(0.0, kTableH - _viewH);

  /// 발사 막대를 당기는 중이면 0~1.
  double charge = 0;
  bool charging = false;

  void attach(TickerProvider vsync) {
    run.onFeedback = (k) => onFeedback?.call(k);
    _ticker = vsync.createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.25) return; // (처음 한 번이나 오래 멈췄다 돌아왔을 때는 건너뛴다)
    if (!paused) {
      if (charging) charge = min(1.0, charge + dt / 0.85);
      final before = run.phase;
      run.update(dt);
      if (before != RunPhase.over && run.phase == RunPhase.over) _saveRecord();
      _followBall(dt);
    }
    notifyListeners();
  }

  /// 카메라가 공을 따라간다: 가장 아래에 있는 공(곧 떨어질 공)이 화면 아래쪽 가까이에 오게 한다.
  void _followBall(double dt) {
    final e = run.engine;
    double? target;
    if (e.hasWaitingBall) {
      target = _maxCam;
    } else if (e.balls.isNotEmpty) {
      var low = e.balls.first;
      for (final b in e.balls) {
        if (b.y > low.y) low = b;
      }
      target = low.y + low.vy * 0.12 - _viewH * 0.62;
    } else if (e.held != null) {
      target = run.engine.table.saucer.y - _viewH * 0.5;
    }
    if (target == null) return;
    target = target.clamp(0.0, _maxCam);
    camY += (target - camY) * min(1.0, dt * 6);
  }

  void pause(bool value) {
    if (paused == value) return;
    paused = value;
    if (paused) {
      run.setFlipper(true, false);
      run.setFlipper(false, false);
      charging = false;
      charge = 0;
    }
    notifyListeners();
  }

  void setFlipper(bool left, bool pressed) {
    if (paused) return;
    run.setFlipper(left, pressed);
    if (pressed) onFeedback?.call('flip');
  }

  void startCharge() {
    if (paused || run.phase != RunPhase.playing || !run.engine.hasWaitingBall) return;
    charging = true;
    charge = 0;
  }

  void releaseCharge() {
    if (!charging) return;
    charging = false;
    run.launch(charge);
    charge = 0;
  }

  void nudge() {
    if (!paused) run.nudge();
  }

  /// 새로 도전한다.
  void restart() {
    run.onFeedback = null;
    run = PinballRun()..onFeedback = (k) => onFeedback?.call(k);
    _saved = false;
    paused = false;
    charging = false;
    charge = 0;
    notifyListeners();
  }

  void _saveRecord() {
    if (_saved) return;
    _saved = true;
    PinballHistory.add(PinballRecord(
      round: run.round,
      score: run.score,
      bestCombo: run.bestCombo,
      upgrades: run.upgradeCount,
      names: [for (final e in run.stacks.entries) e.value > 1 ? '${upgradeById(e.key).name} ×${e.value}' : upgradeById(e.key).name],
      at: DateTime.now(),
    ));
  }

  /// 도전 도중에 나갈 때도 지금까지를 기록으로 남긴다 (1라운드를 못 깬 도전은 남기지 않는다).
  void saveIfProgressed() {
    if (run.phase != RunPhase.over && run.round > 1) _saveRecord();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
