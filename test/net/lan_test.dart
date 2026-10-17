import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_discovery.dart';

/// 같은 기기 안(127.0.0.1)에서 이어진 연결 한 쌍.
Future<(LanConnection, LanConnection)> connectionPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final client = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
  final srv = await accepted;
  await server.close();
  return (LanConnection(client), LanConnection(srv));
}

void main() {
  group('LanConnection', () {
    test('메시지를 주고받는다 (한 줄 JSON, 줄바꿈이 섞인 글자도 그대로)', () async {
      final (a, b) = await connectionPair();
      final got = <Map<String, dynamic>>[];
      b.messages.listen(got.add);
      a.send({'t': 'move', 'i': 0, 'm': 33});
      a.send({'t': 'note', 'text': '줄\n바꿈 "따옴표"'});
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(got.length, 2);
      expect(got[0], {'t': 'move', 'i': 0, 'm': 33});
      expect(got[1]['text'], '줄\n바꿈 "따옴표"');
      await a.close();
      await b.close();
    });

    test('듣는 쪽이 없을 때 온 메시지는 모아 두었다가 듣기 시작하면 차례대로 준다', () async {
      final (a, b) = await connectionPair();
      for (var i = 0; i < 3; i++) {
        a.send({'t': 'move', 'i': i});
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final got = <int>[];
      b.messages.listen((m) => got.add(m['i'] as int));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      a.send({'t': 'move', 'i': 3});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(got, [0, 1, 2, 3]);
      await a.close();
      await b.close();
    });

    test('한쪽이 닫으면 다른 쪽도 끊김을 알아챈다', () async {
      final (a, b) = await connectionPair();
      expect(a.isClosed, isFalse);
      await a.close();
      await b.closed.timeout(const Duration(seconds: 2));
      expect(b.isClosed, isTrue);
      b.send({'t': 'x'}); // 끊긴 뒤 보내도 오류가 나지 않는다
    });

    test('신호가 한참 끊기고 포기 시간이 지나면 끊김으로 본다 (포기 시간을 정했을 때만)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      final raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      final srvSocket = await accepted;
      // 짧은 제한 시간으로: 상대(raw)는 아무 신호도 안 보낸다.
      final conn = LanConnection(srvSocket, heartbeat: const Duration(milliseconds: 40), timeout: const Duration(milliseconds: 100), giveUp: const Duration(milliseconds: 400));
      await conn.closed.timeout(const Duration(seconds: 2));
      expect(conn.isClosed, isTrue);
      raw.destroy();
      await server.close();
    });

    test('상대 신호가 끊기면 바로 끊지 않고 "응답 없음"으로 기다리다가, 신호가 다시 오면 이어진다', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      final raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      final srvSocket = await accepted;
      final conn = LanConnection(srvSocket, heartbeat: const Duration(milliseconds: 40), timeout: const Duration(milliseconds: 150));
      final got = <Map<String, dynamic>>[];
      conn.messages.listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 400)); // 상대(raw)는 조용하다
      expect(conn.isClosed, isFalse, reason: '조금 조용하다고 끊으면 안 돼요');
      expect(conn.stalled, isTrue);
      expect(LanConnection.stalledConnections.value, contains(conn));
      // 돌아와서 메시지를 보낸다
      raw.write('{"t":"x"}\n');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(got.map((m) => m['t']), ['x']);
      expect(conn.stalled, isFalse);
      expect(LanConnection.stalledConnections.value, isNot(contains(conn)));
      await conn.close();
      raw.destroy();
      await server.close();
    });

    test('신호(p)는 메시지로 나오지 않는다', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      final client = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      final a = LanConnection(client, heartbeat: const Duration(milliseconds: 30));
      final b = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 30));
      final got = <Map<String, dynamic>>[];
      b.messages.listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 200)); // 신호가 몇 번 오간다
      a.send({'t': 'hi'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(got.map((m) => m['t']), ['hi']);
      expect(a.isClosed || b.isClosed, isFalse);
      await a.close();
      await b.close();
      await server.close();
    });
  });

  group('방 열기와 찾기', () {
    const port = 45931; // 시험용 방 찾기 포트 (실제 앱과 다르게)

    test('방을 찾아 들어가면 손님으로 알려지고, 이미 손님이 있으면 다른 기기는 busy를 받는다', () async {
      final host = await LanHost.open(game: 'prophecy', info: {'rows': 5, 'cols': 4}, gamePort: 0, discoveryPort: port);
      final finder = await LanFinder.start(game: 'prophecy', interval: const Duration(milliseconds: 100), discoveryPort: port, extraTargets: ['127.0.0.1']);
      final rooms = await finder.rooms.firstWhere((r) => r.isNotEmpty).timeout(const Duration(seconds: 3));
      expect(rooms.single.info['rows'], 5);
      expect(rooms.single.info['cols'], 4);
      expect(rooms.single.port, host.port);

      final guestArrived = host.guests.first;
      final c1 = await LanConnection.connect('127.0.0.1', host.port);
      c1.send({'t': 'hello', 'game': 'prophecy'});
      final welcome = await c1.messages.firstWhere((m) => m['t'] == 'welcome').timeout(const Duration(seconds: 2));
      expect(welcome['t'], 'welcome');
      final server = await guestArrived.timeout(const Duration(seconds: 2));
      expect(host.hasGuest, isTrue);

      // 손님이 이어진 뒤에는 서로 메시지를 주고받는다
      final fromGuest = server.messages.firstWhere((m) => m['t'] == 'move');
      c1.send({'t': 'move', 'i': 0, 'm': 17});
      expect((await fromGuest.timeout(const Duration(seconds: 2)))['m'], 17);

      // 두 번째 기기는 들어올 수 없다
      final c2 = await LanConnection.connect('127.0.0.1', host.port);
      c2.send({'t': 'hello', 'game': 'prophecy'});
      final busy = await c2.messages.firstWhere((m) => m['t'] == 'busy').timeout(const Duration(seconds: 2));
      expect(busy['t'], 'busy');

      // 손님이 나가면 방이 다시 비어 다른 기기가 들어올 수 있다
      await c1.close();
      await server.closed.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(host.hasGuest, isFalse);
      final again = host.guests.first;
      final c3 = await LanConnection.connect('127.0.0.1', host.port);
      c3.send({'t': 'hello', 'game': 'prophecy'});
      await again.timeout(const Duration(seconds: 2));

      finder.close();
      await host.close();
      await c2.close();
      await c3.close();
    });

    test('다른 게임의 손님은 들어올 수 없고, 손님이 있는 방은 방 찾기에 답하지 않는다', () async {
      final host = await LanHost.open(game: 'prophecy', info: const {}, gamePort: 0, discoveryPort: port + 1);
      final other = await LanConnection.connect('127.0.0.1', host.port);
      other.send({'t': 'hello', 'game': 'something-else'});
      expect((await other.messages.firstWhere((m) => m['t'] == 'busy').timeout(const Duration(seconds: 2)))['t'], 'busy');

      final guest = await LanConnection.connect('127.0.0.1', host.port);
      guest.send({'t': 'hello', 'game': 'prophecy'});
      await host.guests.first.timeout(const Duration(seconds: 2));

      final finder = await LanFinder.start(game: 'prophecy', interval: const Duration(milliseconds: 80), discoveryPort: port + 1, extraTargets: ['127.0.0.1']);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(finder.current, isEmpty); // 손님이 찬 방은 보이지 않는다
      finder.close();
      await guest.close();
      await host.close();
    });

    test('방이 닫히면 목록에서 사라진다', () async {
      final host = await LanHost.open(game: 'prophecy', info: const {'rows': 4}, gamePort: 0, discoveryPort: port + 2);
      final finder = await LanFinder.start(game: 'prophecy', interval: const Duration(milliseconds: 80), discoveryPort: port + 2, extraTargets: ['127.0.0.1']);
      await finder.rooms.firstWhere((r) => r.isNotEmpty).timeout(const Duration(seconds: 3));
      await host.close();
      await finder.rooms.firstWhere((r) => r.isEmpty).timeout(const Duration(seconds: 3));
      expect(finder.current, isEmpty);
      finder.close();
    });

    test('이 기기의 Wi‑Fi 주소 목록을 얻을 수 있다 (없을 수는 있어도 오류는 없다)', () async {
      final a = await localLanAddresses();
      for (final x in a) {
        expect(InternetAddress.tryParse(x), isNotNull);
        expect(x.startsWith('127.'), isFalse);
      }
    });
  });
}
