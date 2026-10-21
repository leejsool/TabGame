import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/snake/core/snake_net.dart';
import 'package:tabgame/games/snake/core/snake_world.dart';
import 'package:tabgame/games/snake/game/snake_controller.dart';
import 'package:tabgame/games/snake/game/snake_host_net.dart';
import 'package:tabgame/games/snake/game/snake_migrate.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';

Map<String, dynamic> _wire(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void main() {
  test('손님 기기는 사람 명단을 받아 두고, 이어받을 사람은 모두 같은 답을 낸다', () {
    final w = SnakeWorld(rng: Random(1));
    w.addSeat(0, '방장');
    w.addSeat(1, '가');
    w.addSeat(2, '나');
    w.addSeat(3, '다');
    w.setUp();
    final m = SnakeMirror(_wire(encodeFull(w, 0)));
    expect(m.seats, {0: '방장', 1: '가', 2: '나', 3: '다'});
    expect(m.hostSeat, 0);
    expect(m.successor(), 1);
    // CPU가 대신하는 자리는 건너뛴다
    w.coverSeat(1);
    m.load(_wire(encodeFull(w, 0)));
    expect(m.away, {1});
    expect(m.successor(), 2);
    m.setAway(2, true);
    expect(m.successor(), 3);
    m.removeSeat(3);
    expect(m.successor(), isNull);
    m.addSeat(4, '라');
    expect(m.successor(), 4);
  });

  test('손님이 방장 판을 이어받으면 뱀·먹이·점수가 그대로이고, 나간 방장의 뱀은 흩어지고, 다른 손님은 CPU가 몬다', () {
    final a = SnakeWorld(rng: Random(5));
    a.addSeat(0, '방장');
    a.addSeat(1, '가');
    a.addSeat(2, '나');
    a.setUp();
    for (var i = 0; i < 60 * 15; i++) {
      for (final s in a.snakes) {
        if (s.human) a.steer(s.seat, i * 0.01 + s.seat, false);
      }
      a.step(1 / 60);
      // (사람 뱀이 죽으면 다시 태어나게 해서 시험 내내 세 사람이 있게)
      for (final seat in [0, 1, 2]) {
        a.respawnSeat(seat);
      }
    }
    final mirror = SnakeMirror(_wire(encodeFull(a, 0)));
    final b = SnakeWorld(rng: Random(6), hostSeat: 1);
    b.adoptMirror(mirror, oldHostSeat: 0);

    expect(b.seatNames.keys.toSet(), {1, 2});
    expect(b.awaySeats, {2});
    expect(b.snakeOfSeat(0), isNull, reason: '나간 방장의 뱀은 없다');
    expect(b.snakeOfSeat(1)!.covered, isFalse);
    expect(b.snakeOfSeat(2)!.covered, isTrue);
    expect(b.snakeOfSeat(1)!.mass, closeTo(a.snakeOfSeat(1)!.mass, 0.2));
    expect(b.snakeOfSeat(1)!.trail.length, greaterThan(5));
    final cpus = b.snakes.where((s) => !s.human);
    expect(cpus, isNotEmpty);
    expect(cpus.every((s) => s.brain != null), isTrue);
    expect(b.food.length, greaterThan(500));
    expect(b.born, isEmpty);
    expect(b.deaths, isEmpty);

    // 그대로 계속 돌릴 수 있고, 모자란 CPU는 다시 채워진다
    for (var i = 0; i < 60 * 60; i++) {
      b.steer(1, i * 0.013, false);
      b.step(1 / 60);
    }
    // (죽은 CPU는 2~4초 뒤에 다시 태어나므로 순간적으로 한두 마리 모자랄 수 있다)
    expect(b.headcount, inInclusiveRange(b.population - 3, b.population));
    expect(b.snakeOfSeat(2) == null || b.snakeOfSeat(2)!.covered, isTrue);
  });

  test('방장이 나가면(handover) 가장 앞 손님이 이어받고, 다른 손님은 새 방을 찾아 같은 자리로 다시 들어간다', () async {
    SharedPreferences.setMockInitialValues({});
    const dPort = 45873;
    final a = SnakeController.host(nick: '방장', rng: Random(11));
    final netA = SnakeHostNet(a.world!, hostNick: '방장', cover: a.world!.coverSeat, uncover: a.world!.uncoverSeat, gamePort: 0, discoveryPort: null);
    a.hostNet = netA;
    await netA.open();

    // 손님 둘이 들어온다 (표도 보관한다)
    final tickets = <int, RejoinTicket>{};
    Future<SnakeController> join(String nick) async {
      final conn = await LanConnection.connect('127.0.0.1', netA.port!);
      final start = Completer<Map<String, dynamic>>();
      final sub = conn.messages.listen((m) {
        if (m['t'] == 'start' && !start.isCompleted) start.complete(m);
      });
      conn.send({'t': 'hello', 'game': kSnakeLanGame, 'nick': nick});
      final m = await start.future.timeout(const Duration(seconds: 5));
      await sub.cancel();
      tickets[m['seat'] as int] = RejoinTicket(
        game: kSnakeLanGame,
        roomId: (m['rejoin'] as Map)['room'] as String,
        token: (m['rejoin'] as Map)['token'] as String,
        host: '127.0.0.1',
        port: netA.port!,
        hostNick: '방장',
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return SnakeController.guest(conn: conn, seat: m['seat'] as int, snap: m['snap'] as Map<String, dynamic>);
    }

    final b = await join('가');
    final c = await join('나');
    expect([b.mySeat, c.mySeat], [1, 2]);
    var clock = 0.0;
    for (var i = 0; i < 40; i++) {
      a.frame(0.05);
      b.frame(0.05);
      c.frame(0.05);
      clock += 0.05;
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    expect(b.successorSeat, 1);
    expect(c.successorSeat, 1);
    final droppedB = Completer<bool>(), droppedC = Completer<bool>();
    b.onDropped = droppedB.complete;
    c.onDropped = droppedC.complete;
    final aMass = b.bodies.firstWhere((s) => s.seat == 1).mass;
    final foodBefore = b.foods.length;

    await a.leave(); // 방장이 "나가기"
    expect(await droppedB.future.timeout(const Duration(seconds: 5)), isTrue);
    expect(await droppedC.future.timeout(const Duration(seconds: 5)), isTrue);

    // 가장 앞 손님(b)이 이어받는다
    await RejoinTickets.save(tickets[1]!);
    final nb = (await snakeRecoverHost(b, handover: true, nick: '가', discoveryPort: dPort, extraTargets: const ['127.0.0.1']))!;
    expect(nb.isHost, isTrue);
    expect(nb.mySeat, 1);
    expect(nb.world!.hostSeat, 1);
    expect(nb.world!.snakeOfSeat(0), isNull);
    expect(nb.world!.snakeOfSeat(1)!.mass, closeTo(aMass, 5));
    expect(nb.world!.awaySeats, {2}, reason: '다른 손님은 돌아올 때까지 CPU가 몬다');
    expect(nb.world!.food.length, greaterThan(foodBefore ~/ 2));
    expect(await RejoinTickets.of(kSnakeLanGame), isNull, reason: '방장은 표가 필요 없다');

    final netB = SnakeHostNet(nb.world!,
        hostNick: '가',
        cover: nb.world!.coverSeat,
        uncover: nb.world!.uncoverSeat,
        gamePort: 0,
        discoveryPort: dPort,
        predecessorRoom: nb.migratedFrom,
        migrants: nb.migrants);
    nb.hostNet = netB;
    await netB.open();

    // 다른 손님(c)은 새 방을 찾아 같은 자리(2번)로 들어간다
    await RejoinTickets.save(tickets[2]!);
    final nc = (await snakeRecoverHost(c, handover: true, nick: '나', discoveryPort: dPort, extraTargets: const ['127.0.0.1'], lookFor: const Duration(seconds: 10)))!;
    expect(nc.isHost, isFalse);
    expect(nc.mySeat, 2);
    expect(netB.guests, 1);
    expect(nb.world!.awaySeats, isEmpty, reason: '돌아온 자리는 사람에게 돌려준다');
    expect(nc.me, isNotNull);
    final saved = await RejoinTickets.of(kSnakeLanGame);
    expect(saved!.roomId, isNot(tickets[2]!.roomId), reason: '새 방의 표로 바뀐다');
    expect(saved.port, netB.port);

    // 새 방이 계속 돌아가고, 새 손님도 받는다
    for (var i = 0; i < 30; i++) {
      nb.frame(0.05);
      nc.frame(0.05);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    expect(nc.bodies.length, nb.bodies.length);
    expect(clock, greaterThan(0));

    for (final x in [nc, nb, b, c, a]) {
      x.dispose();
    }
    await netB.close();
  });

  test('이어받은 방에 끝내 안 돌아온 손님의 자리는 비운다', () async {
    SharedPreferences.setMockInitialValues({});
    final a = SnakeWorld(rng: Random(3));
    a.addSeat(0, '방장');
    a.addSeat(1, '가');
    a.addSeat(2, '나');
    a.setUp();
    final mirror = SnakeMirror(_wire(encodeFull(a, 0)));
    final nb = SnakeController.takeover(from: mirror, seat: 1, oldHostSeat: 0, oldRoom: 'old', nick: '가', rng: Random(4));
    final net = SnakeHostNet(nb.world!,
        hostNick: '가',
        cover: nb.world!.coverSeat,
        uncover: nb.world!.uncoverSeat,
        gamePort: 0,
        discoveryPort: null,
        predecessorRoom: nb.migratedFrom,
        migrants: nb.migrants,
        migrantWait: const Duration(milliseconds: 200));
    nb.hostNet = net;
    await net.open();
    expect(nb.world!.seatNames.keys.toSet(), {1, 2});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(nb.world!.seatNames.keys.toSet(), {1});
    expect(nb.world!.snakeOfSeat(2), isNull);
    nb.dispose();
  });
}
