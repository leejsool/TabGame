import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/snake/core/snake_body.dart';
import 'package:tabgame/games/snake/core/snake_net.dart';
import 'package:tabgame/games/snake/core/snake_world.dart';
import 'package:tabgame/games/snake/game/snake_controller.dart';
import 'package:tabgame/games/snake/game/snake_host_net.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';

void main() {
  /// JSON을 한 번 거쳐서 (실제로 보내는 것처럼).
  Map<String, dynamic> wire(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  test('손님 기기의 판은 방장이 보내는 변화만으로 방장 판을 따라간다', () {
    final w = SnakeWorld(rng: Random(1));
    w.addSeat(0, '방장');
    w.setUp();
    var seq = 0;
    final mirror = SnakeMirror(wire(encodeFull(w, seq)));
    expect(mirror.snakes.length, w.snakes.length);
    expect(mirror.food.length, w.food.length);
    var clock = 0.0;
    for (var i = 0; i < 60 * 20; i++) {
      w.step(1 / 60);
      clock += 1 / 60;
      if (i % 4 == 3) mirror.apply(wire(encodeDelta(w, ++seq)), clock);
      mirror.frame(clock);
    }
    mirror.apply(wire(encodeDelta(w, ++seq)), clock);
    mirror.frame(clock + 1);
    expect(mirror.needSync, isFalse);
    expect(mirror.snakes.keys.toSet(), w.byId.keys.toSet());
    expect(mirror.food.keys.toSet(), w.food.keys.toSet());
    for (final s in w.snakes) {
      final m = mirror.snakes[s.id]!;
      expect(m.x, closeTo(s.x, 0.2));
      expect(m.mass, closeTo(s.mass, 0.1));
      // 몸도 거의 같은 자리에 그려진다 (꼬리 끝)
      expect(snakeDist(m.trail.xAt(0), m.trail.yAt(0), s.trail.xAt(0), s.trail.yAt(0)), lessThan(s.radius * 1.5));
    }
  });

  test('손님 기기에도 방장이 알려 준 "먹힌 먹이"로 먹은 뱀과 먹이 크기가 전해진다 (큰 먹이 소리용)', () {
    final w = SnakeWorld(rng: Random(5));
    w.addSeat(0, '방장');
    w.setUp();
    final mirror = SnakeMirror(wire(encodeFull(w, 0)));
    final eaten = <(double, int?)>[];
    mirror.onEat = (f, by) => eaten.add((f.value, by?.seat));
    final me = w.snakeOfSeat(0)!;
    w.addFood(me.x, me.y, SnakeRules.bigFoodValue, 0, natural: false);
    mirror.apply(wire(encodeDelta(w, 1)), 0.1); // 먹이가 놓였다 (아직 안 먹힘)
    expect(eaten, isEmpty);
    w.step(1 / 60);
    mirror.apply(wire(encodeDelta(w, 2)), 0.2);
    expect(eaten.where((e) => e.$1 >= SnakeRules.bigFoodValue && e.$2 == 0), isNotEmpty);
  });

  test('변화를 하나 놓치면 판 전체를 다시 받을 때까지 기다린다', () {
    final w = SnakeWorld(rng: Random(2));
    w.setUp();
    final mirror = SnakeMirror(wire(encodeFull(w, 0)));
    w.step(1 / 60);
    encodeDelta(w, 1); // 놓친 변화
    w.step(1 / 60);
    mirror.apply(wire(encodeDelta(w, 2)), 0.1);
    expect(mirror.needSync, isTrue);
    mirror.load(wire(encodeFull(w, 2)));
    expect(mirror.needSync, isFalse);
    w.step(1 / 60);
    mirror.apply(wire(encodeDelta(w, 3)), 0.2);
    expect(mirror.seq, 3);
  });

  test('같은 Wi‑Fi: 판 도중에 손님이 들어오면 사람이 한 명 늘고, 조종이 전해지고, 나가면 자리가 없어진다', () async {
    SharedPreferences.setMockInitialValues({});
    final host = SnakeController.host(nick: '방장', rng: Random(3));
    final net = SnakeHostNet(host.world!, hostNick: '방장', cover: host.world!.coverSeat, uncover: host.world!.uncoverSeat, gamePort: 0, discoveryPort: null);
    host.hostNet = net;
    await net.open();
    expect(net.isOpen, isTrue);
    final conn = await LanConnection.connect('127.0.0.1', net.port!);
    final start = Completer<Map<String, dynamic>>();
    final sub = conn.messages.listen((m) {
      if (m['t'] == 'start' && !start.isCompleted) start.complete(m);
    });
    conn.send({'t': 'hello', 'game': kSnakeLanGame, 'nick': '친구'});
    final m = await start.future.timeout(const Duration(seconds: 5));
    await sub.cancel();
    expect(m['seat'], 1);
    expect(m['rejoin'], isA<Map>());
    expect(host.world!.headcount, 31);
    final guest = SnakeControllerRejoin.fromWifiSnapshot(m, conn)!;
    expect(guest.me?.name, '친구');
    // 몇 초 돌린다: 손님은 위쪽(-π/2)으로 가고 싶다고 보낸다
    guest.steer(-pi / 2);
    for (var i = 0; i < 90; i++) {
      host.frame(1 / 30);
      guest.frame(1 / 30);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final hostSide = host.world!.snakeOfSeat(1);
    if (hostSide != null) expect(hostSide.targetAngle, closeTo(-pi / 2, 0.01));
    expect(guest.bodies.length, greaterThan(25));
    await guest.leave();
    for (var i = 0; i < 20 && host.world!.seatNames.containsKey(1); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(host.world!.seatNames.containsKey(1), isFalse);
    guest.dispose();
    host.dispose();
  });

  test('같은 Wi‑Fi: 연결이 끊긴 손님 뱀은 CPU가 몰고, 표를 들고 돌아오면 같은 자리에 다시 앉는다', () async {
    SharedPreferences.setMockInitialValues({});
    final host = SnakeController.host(nick: '방장', rng: Random(4));
    final net = SnakeHostNet(host.world!, hostNick: '방장', cover: host.world!.coverSeat, uncover: host.world!.uncoverSeat, gamePort: 0, discoveryPort: null);
    host.hostNet = net;
    await net.open();
    final conn = await LanConnection.connect('127.0.0.1', net.port!);
    final start = Completer<Map<String, dynamic>>();
    final sub = conn.messages.listen((m) {
      if (m['t'] == 'start' && !start.isCompleted) start.complete(m);
    });
    conn.send({'t': 'hello', 'game': kSnakeLanGame, 'nick': '친구'});
    final m = await start.future.timeout(const Duration(seconds: 5));
    await sub.cancel();
    final t = m['rejoin'] as Map;
    // 손님 앱이 꺼졌다 (나가기 없이 끊김)
    await conn.close();
    for (var i = 0; i < 20 && !net.links.first.suspended; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(net.links.first.suspended, isTrue);
    expect(host.world!.seatNames.containsKey(1), isTrue, reason: '끊겼다고 바로 자리를 없애지 않는다');
    net.links.first.onTakeOver!(); // (오래 응답이 없으면 방장 기기가 저절로 한다)
    expect(host.world!.snakeOfSeat(1)?.covered, isTrue);
    final back = await lanRejoin(
      RejoinTicket(game: kSnakeLanGame, roomId: '${t['room']}', token: '${t['token']}', host: '127.0.0.1', port: net.port!, hostNick: '방장', savedAt: DateTime.now().millisecondsSinceEpoch),
      nick: '친구',
      lookFor: const Duration(milliseconds: 100),
    );
    expect(back.ok, isTrue);
    expect(host.world!.snakeOfSeat(1)?.covered, isFalse);
    final guest = SnakeControllerRejoin.fromWifiSnapshot(back.resume!, back.conn!)!;
    expect(guest.mySeat, 1);
    expect(guest.me, isNotNull);
    guest.dispose();
    host.dispose();
  });
}
