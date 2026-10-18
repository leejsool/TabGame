import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_discovery.dart';
import 'package:tabgame/net/lan_rejoin.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';

const _wait = Duration(milliseconds: 150);

void main() {
  group('LanConnection: 나갔다 다시 들어오기', () {
    test('다시 들어올 수 있는 연결은 소켓이 닫혀도 끝나지 않고 "나간 상태"로 있다가, 새 소켓을 이어 붙이면 계속 쓴다', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final conns = server.asBroadcastStream();
      final accepted = conns.first;
      final raw1 = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      final host = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 40));
      host.canResume = () => true;
      final got = <Map<String, dynamic>>[];
      host.messages.listen(got.add);

      raw1.destroy(); // 손님이 앱을 껐다
      await Future<void>.delayed(_wait);
      expect(host.isClosed, isFalse, reason: '다시 들어올 수 있는 연결은 끝나면 안 돼요');
      expect(host.suspended, isTrue);
      expect(host.stalled, isTrue);
      expect(LanConnection.stalledConnections.value, contains(host));
      host.send({'t': 'lost'}); // 나가 있는 동안 보내도 오류가 나지 않는다

      // 같은 손님이 다시 들어온다: 방이 받은 새 연결의 소켓을 이어 붙인다
      final accepted2 = conns.first;
      final guest = LanConnection(await Socket.connect(InternetAddress.loopbackIPv4, server.port), heartbeat: const Duration(milliseconds: 40));
      final fresh = LanConnection(await accepted2, heartbeat: const Duration(milliseconds: 40));
      host.adopt(fresh);
      expect(host.suspended, isFalse);
      expect(host.stalled, isFalse);
      expect(LanConnection.stalledConnections.value, isNot(contains(host)));

      final guestGot = <Map<String, dynamic>>[];
      guest.messages.listen(guestGot.add);
      host.send({'t': 'hi'});
      guest.send({'t': 'yo'});
      await Future<void>.delayed(_wait);
      expect(guestGot.map((m) => m['t']), ['hi']);
      expect(got.map((m) => m['t']), ['yo']);

      // 새 소켓이 또 닫혀도 마찬가지
      await guest.close();
      await Future<void>.delayed(_wait);
      expect(host.suspended, isTrue);
      expect(host.isClosed, isFalse);

      await host.close(); // 진짜로 끝낸다
      expect(host.isClosed, isTrue);
      expect(LanConnection.stalledConnections.value, isNot(contains(host)));
      await server.close();
    });

    test('다시 들어올 수 없는 연결(기본)은 소켓이 닫히면 바로 끝난다', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      final raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      final host = LanConnection(await accepted);
      raw.destroy();
      await host.closed.timeout(const Duration(seconds: 2));
      expect(host.suspended, isFalse);
      expect(host.suspend(), isFalse);
      await server.close();
    });
  });

  group('접수처와 다시 들어가기', () {
    late LanHost host;
    late LanConnection link;
    late LanConnection guest;
    late LanRejoinDesk desk;
    late LanHubKeeper keeper;
    final covered = <int>[], uncovered = <int>[];
    final sent = <Map<String, dynamic>>[];
    var active = true;

    setUp(() async {
      covered.clear();
      uncovered.clear();
      sent.clear();
      active = true;
      host = await LanHost.open(game: 'rj', info: {'x': 1}, gamePort: 0, discoveryPort: null, bindAddress: InternetAddress.loopbackIPv4);
      final arrived = host.guests.first;
      guest = await LanConnection.connect('127.0.0.1', host.port);
      guest.send({'t': 'hello', 'game': 'rj', 'nick': '민수'});
      link = await arrived;
      desk = LanRejoinDesk.open(host: host, guests: [link], info: {'x': 1});
      keeper = LanHubKeeper(
        desk: desk,
        seatOfLink: (i) => 2,
        isActive: () => active,
        cover: covered.add,
        uncover: uncovered.add,
        snapshot: (seat) => {'turn': seat, 'moves': [1, 2, 3]},
        sendAll: (m, {except}) => sent.add(m),
      );
    });

    tearDown(() async {
      keeper.dispose();
      await link.close();
      await guest.close();
    });

    RejoinTicket ticket({String? token}) => RejoinTicket(
          game: 'rj',
          roomId: desk.roomId,
          token: token ?? desk.ticketFor(0)['token'] as String,
          host: '127.0.0.1',
          port: host.port,
          hostNick: '철수',
          savedAt: DateTime.now().millisecondsSinceEpoch,
        );

    test('손님이 나가면 방장은 CPU가 대신하게 할 수 있고, 손님이 표를 들고 돌아오면 바로 자리를 되찾는다', () async {
      await guest.close(); // 손님이 앱을 껐다
      await Future<void>.delayed(_wait);
      expect(link.suspended, isTrue);
      expect(link.isClosed, isFalse);
      expect(link.onTakeOver, isNotNull);

      link.onTakeOver!(); // 방장이 "CPU가 대신하기"를 눌렀다
      expect(covered, [2]);
      expect(link.cpuCovered, isTrue);
      expect(sent, [
        {'t': 'cpu', 'seat': 2},
      ]);
      expect(LanConnection.stalledConnections.value, contains(link), reason: 'CPU가 대신하는 동안에도 안내가 남아야 해요');
      link.onTakeOver!(); // 한 번 더 눌러도 두 번 맡기지 않는다
      expect(covered, [2]);

      // 같은 표로 다시 들어온다
      final result = await lanRejoin(ticket(), nick: '민수');
      expect(result.ok, isTrue);
      expect(result.resume!['seat'], 2);
      expect(result.resume!['snap'], {'turn': 2, 'moves': [1, 2, 3]});
      expect(uncovered, [2], reason: '돌아오면 CPU가 맡던 자리를 사람에게 돌려줘야 해요');
      expect(sent.last, {'t': 'back', 'seat': 2});
      expect(link.suspended, isFalse);
      expect(link.cpuCovered, isFalse);
      expect(LanConnection.stalledConnections.value, isNot(contains(link)));

      // 이어진 연결로 서로 메시지를 주고받는다
      final back = result.conn!;
      final hostGot = <Map<String, dynamic>>[], backGot = <Map<String, dynamic>>[];
      link.messages.listen(hostGot.add);
      back.messages.listen(backGot.add);
      link.send({'t': 'move', 'i': 3});
      back.send({'t': 'move', 'i': 4});
      await Future<void>.delayed(_wait);
      expect(backGot.map((m) => m['i']), [3]);
      expect(hostGot.map((m) => m['i']), [4]);
      await back.close();
    });

    test('CPU가 대신하지 않았어도 (앱만 껐다 켠 경우) 표가 맞으면 자리로 돌아온다', () async {
      await guest.close();
      await Future<void>.delayed(_wait);
      final result = await lanRejoin(ticket(), nick: '민수');
      expect(result.ok, isTrue);
      expect(covered, isEmpty);
      expect(uncovered, isEmpty);
      await result.conn!.close();
    });

    test('표가 틀리면 돌려보내고, 판이 끝났으면 "이미 끝났어요"로 알린다', () async {
      await guest.close();
      await Future<void>.delayed(_wait);
      final bad = await lanRejoin(ticket(token: 'nope'), nick: '민수');
      expect(bad.ok, isFalse);
      expect(bad.fail, LanRejoinFail.gone);
      expect(link.suspended, isTrue, reason: '엉뚱한 표가 자리를 가로채면 안 돼요');

      active = false; // 판이 끝났다
      final late = await lanRejoin(ticket(), nick: '민수');
      expect(late.fail, LanRejoinFail.gone);
    });

    test('방이 없으면 "찾지 못했어요"로 알린다 (표는 그대로 둔다)', () async {
      await keeper.desk.close();
      final r = await lanRejoin(ticket(), nick: '민수', discoveryPort: 46998, lookFor: const Duration(milliseconds: 800));
      expect(r.fail, LanRejoinFail.notFound);
    });

    test('판이 끝나면 나가 있던 손님의 연결을 정리한다 (안내 카드가 남지 않게)', () async {
      await guest.close();
      await Future<void>.delayed(_wait);
      link.onTakeOver!();
      active = false;
      keeper.settleIfEnded();
      await link.closed.timeout(const Duration(seconds: 1));
      expect(LanConnection.stalledConnections.value, isNot(contains(link)));
    });

    test('표 보관은 보관소가 없는 시험에서도 깨지지 않는다', () async {
      await RejoinTickets.save(ticket());
      await RejoinTickets.forget('rj');
      expect(await RejoinTickets.of('rj'), isNull);
    });
  });
}
