import 'dart:math';

import 'package:flutter/material.dart';

import 'pinball_engine.dart';
import 'pinball_table.dart';
import 'pinball_upgrades.dart';

/// 한 번의 도전 안에서의 단계.
enum RunPhase {
  /// 라운드를 시작하기 전 3·2·1 (판은 멈춰 있다).
  countdown,
  playing,

  /// 목표 점수를 채워서 멈춘 채 업그레이드를 고르는 중.
  choosing,
  over,
}

/// 업그레이드 고르는 창의 카드 한 장. [price]가 0이면 공짜 카드.
class Offer {
  Offer(this.upgrade, this.price);

  final Upgrade upgrade;
  final int price;
  bool bought = false;
}

/// 판 위에 잠깐 떴다 사라지는 글자 (+점수, -시간 …).
class Popup {
  Popup(this.x, this.y, this.text, this.color, {this.banner = false});

  /// true면 판 위가 아니라 화면 가운데에 크게 뜨는 알림 (잭팟!, 틸트! …).
  final bool banner;

  final double x, y;
  final String text;
  final Color color;
  double age = 0;
}

/// 라운드를 깰 때 받는 시간 보너스·점수 이자의 상한 (각각 다음 라운드에 새로 모아야 하는 점수의 비율).
const double kBonusCap = 0.2;

/// 라운드를 깰 때 받은 보너스 (창에 보여 줄 용도).
class ClearBonus {
  const ClearBonus({required this.timeLeft, required this.timePts, required this.interestPts});

  final double timeLeft;
  final int timePts, interestPts;
}

/// 핀볼 도전 한 번의 규칙: 제한 시간 안에 목표 점수에 닿으면 업그레이드를 고르고 다음 라운드로,
/// 못 채우거나 공(목숨)을 모두 놓치면 끝. 점수는 하나의 "지갑"이라서 유료 업그레이드를 사면 그만큼 줄어든다.
class PinballRun {
  PinballRun({int? seed, PinballTable? table}) : rng = Random(seed) {
    engine = PinballEngine(table ?? PinballTable.standard(), rng: rng);
    _applyMods();
    _beginRound();
    engine.spawnWaitingBall();
  }

  final Random rng;
  late final PinballEngine engine;

  /// 판에서 일어난 일을 화면에 알린다 (소리·진동).
  void Function(String kind)? onFeedback;

  RunPhase phase = RunPhase.countdown;
  double countdownLeft = 3;

  /// 3·2·1 동안 판이 흐르는 빠르기(0~1). 3은 멈춰 있다가, 2부터 서서히 빨라져서 0이 되는 순간 1(원래 속도).
  double get countdownSpeed {
    if (phase != RunPhase.countdown) return 1;
    final t = (1 - countdownLeft / 2).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  int round = 1;
  int score = 0;

  /// 남은 공(목숨). 공을 놓칠 때마다 하나씩 줄고, 0이 되면 끝.
  static const int startLives = 3;
  int lives = startLives;

  /// 공을 다 놓쳐서 끝났는지 (아니면 시간이 다 돼서 끝난 것).
  bool outOfBalls = false;

  /// 이번 창에서 공짜 카드를 이미 골랐는지.
  bool freePicked = false;
  int targetScore = 0;
  double timeLeft = 0;
  double roundTime = 0;
  double bankedTime = 0;

  final Map<String, int> stacks = {};
  PinballMods mods = PinballMods({});

  int combo = 0;
  double comboTimer = 0;
  int bestCombo = 0;

  /// 흔들기 게이지 (1이 되면 틸트).
  double tilt = 0;
  double tiltedLeft = 0;

  /// 볼 세이브: 공을 쏜 뒤 이 시간(초) 동안 공이 빠져도 목숨이 줄지 않고 공을 다시 쏴 준다 (한 번만).
  /// 상점의 "볼 세이브 켜기"를 사면 무한대가 되어, 시간과 상관없이 다음에 공이 빠질 때까지 켜져 있다.
  static const double ballSaveSecs = 8;
  double ballSaveLeft = 0;
  bool get ballSaveOn => ballSaveLeft > 0;

  List<Offer> freeOffers = [];
  List<Offer> paidOffers = [];
  ClearBonus? lastBonus;
  final List<Popup> popups = [];

  /// 지나간 시간 (불빛 깜빡임용, 초).
  double clock = 0;

  /// 롤오버 레인을 다 켜서 얻은 이번 라운드의 점수 배수 보너스.
  double roundMult = 0;

  /// 왼쪽·오른쪽 표적 묶음을 쓰러뜨렸는지 (둘 다 하면 블랙홀에 불이 켜진다).
  final List<bool> _sideBank = [false, false];

  /// 범퍼·슬링샷이 맞고 반짝이는 정도 (b0, b1 … / s0, s1 → 1에서 0으로 식는다).
  final Map<String, double> glow = {};

  // ── 라운드 곡선 ──

  /// [n]라운드에서 새로 모아야 하는 점수.
  static int gainFor(int n) => (3000 * pow(1.38, n - 1) / 100).round() * 100;

  /// [n]라운드를 깨려면 지갑에 있어야 하는 점수 (앞 라운드 몫을 모두 합친 값).
  static int targetFor(int n) {
    var sum = 0;
    for (var i = 1; i <= n; i++) {
      sum += gainFor(i);
    }
    return sum;
  }

  static double timeFor(int n) => 40 + min(n - 1, 8) * 2.5;

  /// 라운드가 오를수록 같은 부딪힘이 더 큰 점수가 된다.
  static double pointScale(int n) => pow(1.3, n - 1).toDouble();

  /// 지금 지갑에 모인 점수로는 얼마나 더 필요한지.
  int get remaining => max(0, targetScore - score);
  double get multiplier => min(5.0, 1 + (combo ~/ 3) * mods.comboStep) + roundMult;
  bool get tilted => tiltedLeft > 0;

  // ── 조작 ──

  void setFlipper(bool left, bool pressed) {
    if (phase != RunPhase.playing) return;
    engine.setFlipper(left, pressed);
  }

  /// 통로의 공을 쏜다. [power]는 0~1.
  void launch(double power) {
    if (phase != RunPhase.playing || !engine.hasWaitingBall) return;
    final speed = PinballEngine.launchSpeed(power);
    engine.launch(power);
    ballSaveLeft = max(ballSaveLeft, ballSaveSecs);
    if (power > 0.5) {
      for (var k = 1; k <= mods.twin; k++) {
        engine.launchExtra(0.28 * k, speed * (0.93 + rng.nextDouble() * 0.1));
      }
    }
  }

  void nudge() {
    if (phase != RunPhase.playing || tilted) return;
    engine.nudge();
    tilt += 0.38 * mods.tiltEase;
    onFeedback?.call('nudge');
    if (tilt >= 1) {
      tilt = 0.5;
      tiltedLeft = 2.5;
      engine.locked = true;
      for (final f in engine.flippers) {
        f.pressed = false;
      }
      _banner('틸트!', const Color(0xFFFF5252));
      onFeedback?.call('tilt');
    }
  }

  // ── 진행 ──

  void update(double dt) {
    clock += dt;
    for (final p in popups) {
      p.age += dt;
    }
    popups.removeWhere((p) => p.age > 1.1);
    if (glow.isNotEmpty) {
      glow.updateAll((k, v) => v - dt * 4);
      glow.removeWhere((k, v) => v <= 0);
    }
    switch (phase) {
      case RunPhase.countdown:
        countdownLeft -= dt;
        final s = countdownSpeed;
        if (s > 0) _runEngine(dt * s);
        if (phase == RunPhase.countdown && countdownLeft <= 0) phase = RunPhase.playing;
      case RunPhase.playing:
        _tickPlaying(dt);
      case RunPhase.choosing:
      case RunPhase.over:
        break;
    }
  }

  void _tickPlaying(double dt) {
    timeLeft -= dt;
    tilt = max(0, tilt - 0.3 * dt);
    if (tiltedLeft > 0) {
      tiltedLeft -= dt;
      if (tiltedLeft <= 0) {
        tiltedLeft = 0;
        engine.locked = false;
      }
    }
    if (ballSaveLeft > 0 && !engine.hasWaitingBall) ballSaveLeft = max(0, ballSaveLeft - dt);
    if (combo > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 0;
    }
    _runEngine(dt);
    if (phase == RunPhase.over) return;
    if (score >= targetScore) {
      _clearRound();
    } else if (timeLeft <= 0) {
      timeLeft = 0;
      phase = RunPhase.over;
      onFeedback?.call('over');
    }
  }

  void _runEngine(double dt) {
    engine.advance(dt);
    final events = List<HitEvent>.of(engine.events);
    engine.events.clear();
    for (final e in events) {
      _handle(e);
    }
  }

  void _handle(HitEvent e) {
    switch (e.kind) {
      case HitKind.bumper:
        glow['b${e.index}'] = 1;
        _gain(60 * mods.bumperMul, e);
        onFeedback?.call('bumper');
      case HitKind.sling:
        glow['s${e.index}'] = 1;
        _gain(25, e);
        onFeedback?.call('sling');
      case HitKind.target:
        _gain(250 * mods.targetMul, e);
        onFeedback?.call('target');
      case HitKind.bank:
        if (e.index == 0) {
          _gain(1500 * mods.targetMul, e);
          _banner('잭팟!', const Color(0xFFFFD84D));
          onFeedback?.call('jackpot');
        } else {
          _gain(800 * mods.targetMul, e);
          _pop(e.x + (e.index == 1 ? 90 : -90), e.y - 40, '표적 완성!', const Color(0xFFFFD84D));
          onFeedback?.call('jackpot');
          if (e.index <= _sideBank.length) _sideBank[e.index - 1] = true;
          if (_sideBank.every((d) => d) && !engine.saucerLit) {
            _sideBank.fillRange(0, _sideBank.length, false);
            engine.saucerLit = true;
            _banner('블랙홀 열림!', const Color(0xFF69F0AE));
          }
        }
      case HitKind.lane:
        _gain(100 * mods.laneMul, e);
        onFeedback?.call('post');
      case HitKind.lanesDone:
        _gain(600 * mods.laneMul, e);
        roundMult = min(2.0, roundMult + 0.25);
        _banner('배수 UP!', const Color(0xFFFFD84D));
        onFeedback?.call('jackpot');
      case HitKind.orbit:
        _gain(400 * mods.laneMul, e);
        onFeedback?.call('target');
      case HitKind.spin:
        _gain(15 * mods.spinMul, e);
      case HitKind.saucer:
        _gain(400 * mods.holeMul, e);
        onFeedback?.call('target');
      case HitKind.multiball:
        _gain(3000 * mods.holeMul, e);
        _banner('멀티볼!', const Color(0xFF69F0AE));
        onFeedback?.call('jackpot');
      case HitKind.post:
        _gain(10, e);
        onFeedback?.call('post');
      case HitKind.flipper:
        onFeedback?.call('flipper');
      case HitKind.wall:
        if (e.strength > 400) onFeedback?.call('wall');
      case HitKind.launch:
        onFeedback?.call('launch');
      case HitKind.saved:
        _pop(e.x, e.y - 30, '보호막!', const Color(0xFF4FC3F7));
        onFeedback?.call('saved');
      case HitKind.drain:
        if (e.index == 0 && ballSaveOn) {
          // 볼 세이브: 목숨은 그대로, 공을 곧장 다시 쏴 준다 (세이브는 이걸로 끝)
          ballSaveLeft = 0;
          combo = 0;
          _banner('볼 세이브!', const Color(0xFFFFD84D));
          onFeedback?.call('saved');
          engine.spawnWaitingBall();
          engine.launch(0.9);
        } else if (e.index == 0) {
          lives--;
          combo = 0;
          onFeedback?.call('drain');
          if (lives <= 0) {
            lives = 0;
            outOfBalls = true;
            phase = RunPhase.over;
            onFeedback?.call('over');
          } else {
            _banner('남은 공 $lives개', const Color(0xFFFF5252));
            engine.spawnWaitingBall();
          }
        }
    }
  }

  void _gain(double base, HitEvent e) {
    combo++;
    bestCombo = max(bestCombo, combo);
    comboTimer = 2.5 + mods.comboExtra;
    final pts = (base * pointScale(round) * multiplier * mods.scoreMul).round();
    score += pts;
    _pop(e.x, e.y - 24, '+$pts', multiplier > 1 ? const Color(0xFFFFD84D) : Colors.white);
  }

  void _pop(double x, double y, String text, Color color) {
    popups.add(Popup(x, y, text, color));
    if (popups.length > 14) popups.removeAt(0);
  }

  void _banner(String text, Color color) {
    popups.add(Popup(0, 0, text, color, banner: true));
    if (popups.length > 14) popups.removeAt(0);
  }

  // ── 라운드 끝: 업그레이드 고르기 ──

  void _clearRound() {
    // 보너스는 각각 다음 라운드 몫의 [kBonusCap]까지만: 보너스만으로 라운드가 저절로 깨지지 않게.
    final cap = (gainFor(round + 1) * kBonusCap).round();
    final timePts = min((timeLeft * mods.timeBonus * gainFor(round)).round(), cap);
    final interestPts = min((score * mods.interest).round(), cap);
    score += timePts + interestPts;
    lastBonus = ClearBonus(timeLeft: timeLeft, timePts: timePts, interestPts: interestPts);
    phase = RunPhase.choosing;
    freePicked = false;
    combo = 0;
    for (final f in engine.flippers) {
      f.pressed = false;
    }
    _makeOffers();
    onFeedback?.call('clear');
  }

  /// 상점 값: 다음 라운드 몫에 비례하고, 같은 걸 또 살수록(×1.6) 그리고 업그레이드를 많이 모을수록(1개마다 +10%) 비싸진다.
  int priceOf(Upgrade u) {
    final tierMul = u.consumable ? 0.22 : (u.tier == 2 ? 0.55 : 0.28);
    final again = u.consumable ? 1.0 : pow(1.6, stacks[u.id] ?? 0).toDouble();
    final raw = gainFor(round + 1) * tierMul * again * (1 + 0.1 * upgradeCount) * mods.price;
    return max(100, (raw / 10).round() * 10);
  }

  void _makeOffers() {
    bool open(Upgrade u) => (stacks[u.id] ?? 0) < u.max;
    Upgrade? draw(List<Upgrade> pool, int Function(Upgrade) weight) {
      if (pool.isEmpty) return null;
      final total = pool.fold<int>(0, (s, u) => s + weight(u));
      var r = rng.nextInt(total);
      for (final u in pool) {
        r -= weight(u);
        if (r < 0) return u;
      }
      return pool.last;
    }

    final pool = kUpgrades.where((u) => open(u) && !u.consumable).toList();
    final free = <Upgrade>[];
    while (free.length < 3) {
      final u = draw(pool, (u) => u.tier == 2 ? 1 : 3);
      if (u == null) break;
      free.add(u);
      pool.remove(u);
    }
    // (볼 세이브 불이 아직 켜져 있으면 "볼 세이브 켜기"는 팔지 않는다)
    final shop = kUpgrades.where((u) => open(u) && !free.contains(u) && !(u.id == 'save_light' && ballSaveLeft.isInfinite)).toList();
    final paid = <Upgrade>[];
    while (paid.length < 3) {
      final u = draw(shop, (u) => u.consumable ? 2 : (u.tier == 2 ? 3 : 2));
      if (u == null) break;
      paid.add(u);
      shop.remove(u);
    }
    freeOffers = [for (final u in free) Offer(u, 0)];
    paidOffers = [for (final u in paid) Offer(u, priceOf(u))];
  }

  bool canBuy(Offer o) => phase == RunPhase.choosing && !o.bought && score >= o.price;

  /// 유료 카드를 산다 (점수를 쓴다). 창은 그대로 열려 있다.
  bool buy(int i) {
    final o = paidOffers[i];
    if (!canBuy(o)) return false;
    score -= o.price;
    o.bought = true;
    _add(o.upgrade);
    onFeedback?.call('buy');
    return true;
  }

  /// 공짜 카드 하나를 고른다 (한 장만). 상점은 그 뒤에도 쓸 수 있고, [startNextRound]로 넘어간다.
  void pickFree(int i) {
    if (phase != RunPhase.choosing || freePicked) return;
    freePicked = true;
    freeOffers[i].bought = true;
    _add(freeOffers[i].upgrade);
    onFeedback?.call('pick');
  }

  /// 공짜 카드를 골랐거나 고를 게 없으면 다음 라운드를 시작할 수 있다.
  bool get canStartNext => phase == RunPhase.choosing && (freePicked || freeOffers.isEmpty);

  void startNextRound() {
    if (!canStartNext) return;
    round++;
    _beginRound();
    onFeedback?.call('start');
  }

  void _add(Upgrade u) {
    if (u.id == 'save_light') {
      ballSaveLeft = double.infinity;
    } else if (u.consumable) {
      bankedTime += 12;
    } else {
      if (u.id == 'extra_ball') lives++;
      stacks[u.id] = (stacks[u.id] ?? 0) + 1;
    }
    _applyMods();
  }

  void _applyMods() {
    mods = PinballMods(stacks);
    engine
      ..gravityMul = mods.gravity
      ..flipperLenMul = mods.flipLen
      ..flipperPowerMul = mods.flipPow
      ..ballScale = mods.ballScale;
  }

  void _beginRound() {
    targetScore = targetFor(round);
    roundTime = timeFor(round) + mods.roundTime + bankedTime;
    timeLeft = roundTime;
    bankedTime = 0;
    engine.shields = mods.shieldsPerRound;
    engine.resetTargets();
    roundMult = 0;
    phase = RunPhase.countdown;
    countdownLeft = 3;
  }

  /// 지금까지 고른 업그레이드 수 (시간 팩 제외).
  int get upgradeCount => stacks.values.fold(0, (a, b) => a + b);
}
