import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin_flow.dart';
import '../core/snake_ai.dart';
import '../core/snake_body.dart';
import '../core/snake_net.dart';
import '../core/snake_world.dart';
import '../data/snake_history.dart';
import 'snake_host_net.dart';

part 'snake_controller_rejoin.dart';

/// 내 뱀 한 마리가 죽었을 때 보여 줄 결과.
class SnakeLife {
  const SnakeLife({required this.score, required this.bestRank, required this.kills, required this.seconds, required this.killerName});

  final int score, bestRank, kills, seconds;

  /// 부딪힌 뱀 이름 (벽이면 빈 글).
  final String killerName;
}

/// 뱀 게임 한 판의 진행. 방장(혼자 하기 포함) 기기는 판을 직접 돌리고([SnakeWorld]),
/// 손님 기기는 방장이 보내 주는 판을 따라 그린다([SnakeMirror]). 화면은 어느 쪽이든 [bodies]·[foods]만 그린다.
class SnakeController {
  /// 방장: 나를 0번 자리에 두고 나머지를 CPU로 채워 바로 시작한다. [network]가 참이면 같은 Wi‑Fi 방도 연다 ([openRoom]).
  SnakeController.host({required String nick, Random? rng})
      : mySeat = 0,
        world = SnakeWorld(rng: rng),
        mirror = null,
        _conn = null {
    world!
      ..addSeat(0, nick)
      ..setUp()
      ..onDeath = _hostDeath;
  }

  /// 방장이 나가서 이 손님이 판을 이어받는다: 손님으로 따라 그리던 판([from])을 진짜 판으로 바꾼다.
  /// 나(seat)는 그대로 내 자리에 있고, 나간 방장([oldHostSeat])의 뱀은 먹이로 흩어지고, 다른 손님 자리는 다시 들어올 때까지 CPU가 몬다.
  /// [oldRoom]은 옛 방의 번호표 (다른 손님들이 새 방을 알아보고 같은 자리로 들어오는 데 쓴다).
  SnakeController.takeover({required SnakeMirror from, required int seat, required int oldHostSeat, required String oldRoom, required String nick, Random? rng})
      : mySeat = seat,
        world = SnakeWorld(rng: rng, hostSeat: seat),
        mirror = null,
        _conn = null {
    migratedFrom = oldRoom;
    final w = world!;
    // (명단에 내 자리가 없어도 나는 있다)
    from.seats.putIfAbsent(seat, () => nick);
    w.adoptMirror(from, oldHostSeat: oldHostSeat);
    w.onDeath = _hostDeath;
    migrants = {for (final s in w.seatNames.keys) if (s != seat) s};
  }

  /// 손님: 방장이 보낸 판 전체([snap])로 시작한다. 나는 [seat] 자리.
  SnakeController.guest({required LanConnection conn, required int seat, required Map<String, dynamic> snap})
      : mySeat = seat,
        world = null,
        mirror = SnakeMirror(snap),
        _conn = conn {
    mirror!.onDeath = _guestDeath;
    _sub = conn.messages.listen(_onGuestMessage);
    conn.closed.then((_) => _hostLost(false));
  }

  final int mySeat;
  final SnakeWorld? world;
  final SnakeMirror? mirror;
  final LanConnection? _conn;
  SnakeHostNet? hostNet;

  /// 방장을 이어받은 판이면 옛 방의 번호표와, 새 방에 다시 들어오기를 기다리는 손님들의 자리.
  String? migratedFrom;
  Set<int> migrants = const {};

  /// 화면이 열릴 때 한 번 보여 줄 알림 (방장이 바뀌었어요 …).
  String? startNote;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _disposed = false, _ended = false, _syncAsked = false;

  bool get isHost => world != null;

  /// 알림 글 (누가 들어왔다 / 잡았다 …).
  void Function(String text)? onToast;

  /// 손님: 방장이 판을 끝냈다.
  VoidCallback? onEnded;

  /// 손님: 방장과 연결이 끊겼다. [handover]이면 방장이 일부러 나가며 이어받기를 알린 것이다.
  void Function(bool handover)? onDropped;
  bool _lostFired = false;

  void _hostLost(bool handover) {
    if (_lostFired || _disposed || _ended) return;
    _lostFired = true;
    onDropped?.call(handover);
  }

  /// 방장이 사라지면 판을 이어받을 사람의 자리 (손님만, 모르면 null).
  int? get successorSeat => mirror?.successor();

  /// 진동·소리를 낼 일 ('kill', 'die', 'first' = 내가 1등이 됐다).
  void Function(String kind)? onFeedback;

  /// 다른 뱀이 죽었다 (그 머리 자리). 화면이 가까우면 소리를 낸다.
  void Function(double x, double y)? onOtherDeath;

  /// 내 뱀이 죽어 있는 동안의 결과 (살아 있으면 null).
  final ValueNotifier<SnakeLife?> lastLife = ValueNotifier(null);

  /// 순위표를 다시 그릴 때마다 올라간다 (1초에 4번).
  final ValueNotifier<int> hud = ValueNotifier(0);

  double get field => world?.field ?? mirror!.field;
  Iterable<SnakeBody> get bodies => world?.snakes ?? mirror!.snakes.values;
  Iterable<Food> get foods => world?.food.values ?? mirror!.food.values;
  /// CPU 단계 (사람이 1등인 채로 500점을 넘을 때마다 올라간다).
  int get cpuLevel => world?.cpuLevel ?? mirror!.cpuLevel;

  SnakeBody? get me => world?.snakeOfSeat(mySeat) ?? mirror?.ofSeat(mySeat);

  /// 함께 있는 사람 수 (나 포함).
  int get people => isHost ? 1 + (hostNet?.guests ?? 0) : max(1, bodies.where((b) => b.human).length);

  /// 같은 Wi‑Fi 방을 연다 (방장).
  Future<void> openRoom({required String nick}) async {
    final w = world;
    if (w == null || hostNet != null) return;
    final net = SnakeHostNet(w, hostNick: nick, cover: coverSeat, uncover: uncoverSeat, onToast: (t) => onToast?.call(t), predecessorRoom: migratedFrom, migrants: migrants);
    hostNet = net;
    await net.open();
  }

  // ── 조종 ──

  double _angle = 0, _sentAngle = 99, _sendTimer = 0;
  bool _boost = false, _sentBoost = false;

  /// 가고 싶은 방향 (라디안).
  void steer(double angle) => _angle = angle;
  set boost(bool on) => _boost = on;
  bool get boosting => _boost;

  /// 죽은 뒤 "다시 하기".
  void again() {
    lastLife.value = null;
    _lifeStart = null;
    if (isHost) {
      world!.respawnSeat(mySeat);
    } else {
      _conn!.send(const {'t': 'again'});
    }
  }

  // ── 진행 ──

  double _clock = 0, _acc = 0, _hudTimer = 0;
  double? _lifeStart;
  int _bestRank = 999;

  void frame(double dt) {
    if (_disposed) return;
    dt = min(dt, 0.1);
    _clock += dt;
    final w = world;
    if (w != null) {
      _acc += dt;
      while (_acc >= 1 / 60) {
        _acc -= 1 / 60;
        if (w.snakeOfSeat(mySeat) != null) w.steer(mySeat, _angle, _boost);
        w.step(1 / 60);
      }
      hostNet?.tick(dt);
    } else {
      mirror!.frame(_clock);
      _sendInput(dt);
      // 방장 기기가 아무 말 없이 사라졌다 (연결은 안 끊겼는데 오래 응답이 없다)
      final since = _conn?.stalledSince;
      if (since != null && DateTime.now().difference(since) > const Duration(seconds: 10)) _hostLost(false);
    }
    _hudTimer += dt;
    if (_hudTimer >= 0.25) {
      _hudTimer = 0;
      _trackLife();
      hud.value++;
    }
  }

  void _sendInput(double dt) {
    _sendTimer += dt;
    final changed = (wrapAngle(_angle - _sentAngle)).abs() > 0.03 || _boost != _sentBoost;
    if ((changed && _sendTimer >= 0.05) || _sendTimer >= 0.4) {
      _sendTimer = 0;
      _sentAngle = _angle;
      _sentBoost = _boost;
      _conn!.send(encodeInput(_angle, _boost));
    }
  }

  /// 크기 순서 (1등부터).
  List<SnakeBody> ranking() => rankSnakes(bodies);

  /// 내 순위 (죽어 있으면 null).
  int? myRank(List<SnakeBody> ranked) {
    final i = ranked.indexWhere((s) => s.seat == mySeat);
    return i < 0 ? null : i + 1;
  }

  void _trackLife() {
    final lv = cpuLevel;
    if (lv >= CpuBrain.packLevel && _shownLevel < CpuBrain.packLevel) {
      onToast?.call('조심! CPU들이 떼로 사냥하기 시작해요 ($lv단계)');
    } else if (lv > _shownLevel) {
      onToast?.call('CPU가 더 강해졌어요! ($lv단계)');
    }
    _shownLevel = lv;
    final m = me;
    if (m == null) return;
    if (_lifeStart == null) {
      _lifeStart = _clock;
      _bestRank = 999;
      _lastRank = null;
      lastLife.value = null;
    }
    final rank = myRank(ranking());
    if (rank != null) _bestRank = min(_bestRank, rank);
    // 1등이 되는 순간 (막 태어나 처음 잰 순위는 빼고, 1·2등을 오가며 자꾸 울리지 않게 10초에 한 번까지)
    if (rank == 1 && _lastRank != null && _lastRank! > 1 && _clock - _firstAt > 10) {
      _firstAt = _clock;
      onFeedback?.call('first');
      onToast?.call('1등이 되었어요!');
    }
    _lastRank = rank;
  }

  int? _lastRank;
  int _shownLevel = 0;
  double _firstAt = -100;

  void _endLife(SnakeBody dead, String killerName) {
    final start = _lifeStart ?? _clock;
    final life = SnakeLife(
      score: dead.score,
      bestRank: _bestRank == 999 ? (myRank(ranking()) ?? bodies.length) : _bestRank,
      kills: dead.kills,
      seconds: (_clock - start).round(),
      killerName: killerName,
    );
    _lifeStart = null;
    lastLife.value = life;
    onFeedback?.call('die');
    SnakeHistory.add(SnakeRecord(score: life.score, bestRank: life.bestRank, kills: life.kills, seconds: life.seconds, people: people, at: DateTime.now()))
        .catchError((Object _) {});
  }

  void _hostDeath(SnakeDeath d) {
    final w = world!;
    if (d.seat == mySeat) {
      final s = w.byId[d.id];
      if (s != null) _endLife(s, d.killerName);
      return;
    }
    final dead = w.byId[d.id];
    if (dead != null) onOtherDeath?.call(dead.x, dead.y);
    if (d.killer >= 0 && w.byId[d.killer]?.seat == mySeat) _gotKill(dead?.name ?? '');
  }

  void _guestDeath(MirrorSnake dead, SnakeBody? killer) {
    if (dead.seat == mySeat) {
      _endLife(dead, killer?.name ?? '');
      return;
    }
    onOtherDeath?.call(dead.x, dead.y);
    if (killer != null && killer.seat == mySeat) _gotKill(dead.name);
  }

  void _gotKill(String name) {
    onFeedback?.call('kill');
    onToast?.call('$name${objectParticle(name)} 잡았어요!');
  }

  void _onGuestMessage(Map<String, dynamic> m) {
    final mi = mirror!;
    switch (m['t']) {
      case 'w':
        mi.apply(m, _clock);
        if (mi.needSync && !_syncAsked) {
          _syncAsked = true;
          _conn!.send(const {'t': 'sync'});
        }
      case 'full':
        if (m['snap'] is Map<String, dynamic>) mi.load(m['snap'] as Map<String, dynamic>);
        _syncAsked = false;
      case 'join':
        if (m['seat'] is int) mi.addSeat(m['seat'] as int, '${m['name']}');
        onToast?.call('${m['name']}님이 들어왔어요');
      case 'left':
        if (m['seat'] is int) mi.removeSeat(m['seat'] as int);
        onToast?.call('${m['name']}님이 나갔어요');
      case 'cpu':
        if (m['seat'] is int) mi.setAway(m['seat'] as int, true);
        onToast?.call('${_seatName(m['seat'])}님의 연결이 끊겨 CPU가 대신 움직여요');
      case 'back':
        if (m['seat'] is int) mi.setAway(m['seat'] as int, false);
        onToast?.call('${_seatName(m['seat'])}님이 돌아왔어요');
      case 'handover':
        _hostLost(true);
      case 'end':
        _ended = true;
        onEnded?.call();
    }
  }

  String _seatName(Object? seat) => seat is int ? (mirror?.seats[seat] ?? mirror?.ofSeat(seat)?.name ?? '친구') : '친구';

  /// 판에서 나간다. 방장이면 방을 닫고(손님이 있으면 손님 중 한 명이 이어받는다), 손님이면 방장에게 알리고 다시 들어오기 표를 버린다.
  Future<void> leave() async {
    if (_disposed) return;
    _ended = true;
    if (isHost) {
      await hostNet?.close(handover: true);
    } else {
      _conn!.send(const {'t': 'bye'});
      await _conn.close();
      await RejoinTickets.forget(kSnakeLanGame);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub?.cancel();
    hostNet?.close();
    _conn?.close();
    lastLife.dispose();
    hud.dispose();
  }
}

/// 이름 뒤에 붙일 "을/를" (받침이 있으면 "을"). 한글로 끝나지 않으면 "을(를)".
String objectParticle(String name) {
  if (name.isEmpty) return '를';
  final c = name.codeUnitAt(name.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return '을(를)';
  return (c - 0xAC00) % 28 == 0 ? '를' : '을';
}
