import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_discovery.dart';
import 'package:tabgame/net/lan_screens.dart';

/// 동아리 시간처럼 여러 기기가 한꺼번에 방을 열고 들어오는 상황.
void main() {
  group('여러 사람이 동시에', () {
    test('스무 대가 한꺼번에 같은 방에 들어오려 하면 정확히 한 대만 들어가고 나머지는 "찼어요"를 받는다', () async {
      final host = await LanHost.open(game: 'prophecy', info: const {}, gamePort: 0, discoveryPort: null);
      final arrived = <LanConnection>[];
      host.guests.listen(arrived.add);
      final results = await Future.wait([
        for (var i = 0; i < 20; i++)
          () async {
            final c = await LanConnection.connect('127.0.0.1', host.port);
            c.send({'t': 'hello', 'game': 'prophecy', 'nick': '친구$i'});
            final m = await c.messages.firstWhere((m) => m['t'] == 'welcome' || m['t'] == 'busy').timeout(const Duration(seconds: 5));
            return (c, m['t'] as String);
          }(),
      ]);
      expect(results.where((r) => r.$2 == 'welcome').length, 1);
      expect(results.where((r) => r.$2 == 'busy').length, 19);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(arrived.length, 1);
      // 들어간 한 대의 별명이 방을 연 쪽에 전해진다
      final winner = results.firstWhere((r) => r.$2 == 'welcome');
      final index = results.indexOf(winner);
      expect(arrived.single.peerNick, '친구$index');
      for (final r in results) {
        await r.$1.close();
      }
      await host.close();
    });

    test('방 10개에 스무 명이 둘씩 몰려도 방마다 한 명만 들어가고 서로 섞이지 않는다', () async {
      final hosts = [for (var i = 0; i < 10; i++) await LanHost.open(game: 'sprouts', info: {'room': '방$i'}, gamePort: 0, discoveryPort: null)];
      final guestOf = List<String?>.filled(10, null);
      for (var i = 0; i < hosts.length; i++) {
        hosts[i].guests.listen((c) => guestOf[i] = c.peerNick);
      }
      final rng = Random(3);
      final order = [for (var k = 0; k < 20; k++) k]..shuffle(rng); // 들어오는 순서는 뒤죽박죽
      final results = await Future.wait([
        for (final k in order)
          () async {
            final room = k % 10;
            final c = await LanConnection.connect('127.0.0.1', hosts[room].port);
            c.send({'t': 'hello', 'game': 'sprouts', 'nick': '학생$k'});
            final m = await c.messages.firstWhere((m) => m['t'] == 'welcome' || m['t'] == 'busy').timeout(const Duration(seconds: 5));
            return (room, k, m['t'] as String, c);
          }(),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      for (var room = 0; room < 10; room++) {
        final inRoom = results.where((r) => r.$1 == room).toList();
        expect(inRoom.length, 2);
        expect(inRoom.where((r) => r.$3 == 'welcome').length, 1, reason: '방 $room');
        final winner = inRoom.firstWhere((r) => r.$3 == 'welcome');
        expect(guestOf[room], '학생${winner.$2}', reason: '방 $room에 다른 방 손님이 섞였어요');
      }
      for (final r in results) {
        await r.$4.close();
      }
      for (final h in hosts) {
        await h.close();
      }
    });

    test('다른 게임 방에는 들어갈 수 없고, 소개 없이 연결만 하고 가만히 있는 기기는 곧 정리되어 방이 막히지 않는다', () async {
      final host = await LanHost.open(game: 'uttt', info: const {}, gamePort: 0, discoveryPort: null);
      final arrived = <LanConnection>[];
      host.guests.listen(arrived.add);
      // 연결만 하고 아무 말도 안 하는 기기가 먼저 와 있어도
      final idle = await LanConnection.connect('127.0.0.1', host.port);
      // 다른 기기는 바로 들어갈 수 있다
      final real = await LanConnection.connect('127.0.0.1', host.port);
      real.send({'t': 'hello', 'game': 'uttt', 'nick': '진짜'});
      final m = await real.messages.firstWhere((m) => m['t'] == 'welcome' || m['t'] == 'busy').timeout(const Duration(seconds: 3));
      expect(m['t'], 'welcome');
      expect(arrived.single.peerNick, '진짜');
      await idle.close();
      await real.close();
      await host.close();
    });
  });

  group('방 번호', () {
    const mine = ['192.168.0.15'];

    test('방 번호는 주소의 마지막 숫자다', () {
      expect(roomNumberOf(const ['192.168.0.37', '10.0.0.5']), '37');
      expect(roomNumberOf(const []), isNull);
    });

    test('번호만 입력하면 내 Wi‑Fi 앞부분을 붙이고, 주소(포트)도 그대로 받는다', () {
      expect(parseRoomInput('37', mine)?.host, '192.168.0.37');
      expect(parseRoomInput(' 37 ', mine)?.port, kLanGamePort);
      expect(parseRoomInput('37:45900', mine)?.port, 45900);
      expect(parseRoomInput('10.1.2.3', mine)?.host, '10.1.2.3');
      expect(parseRoomInput('10.1.2.3:46000', mine)?.port, 46000);
    });

    test('잘못된 입력은 받지 않는다', () {
      expect(parseRoomInput('', mine), isNull);
      expect(parseRoomInput('0', mine), isNull);
      expect(parseRoomInput('255', mine), isNull);
      expect(parseRoomInput('37', const []), isNull, reason: '내 Wi‑Fi 주소를 모르면 번호만으로는 알 수 없다');
      expect(parseRoomInput('abc', mine), isNull);
      expect(parseRoomInput('192.168.0', mine), isNull);
      expect(parseRoomInput('1.2.3.4:99999', mine), isNull);
      expect(parseRoomInput('1.2.3.4:5:6', mine), isNull);
    });
  });
}
