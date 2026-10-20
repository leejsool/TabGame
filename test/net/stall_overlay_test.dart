import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_stall_overlay.dart';

void main() {
  testWidgets('상대 응답이 끊기면 "기다리는 중"이 뜨고, 한참 뒤에는 계속 기다릴지 판을 끝낼지 고른다', (tester) async {
    late LanConnection conn;
    late Socket raw;
    late ServerSocket server;
    await tester.runAsync(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      conn = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 30), timeout: const Duration(milliseconds: 300));
      conn.peer = {'nick': '철수'};
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    expect(conn.stalled, isTrue);

    await tester.pumpWidget(const MaterialApp(home: LanStallOverlay(decisionAfter: Duration.zero, child: Scaffold(body: Text('게임')))));
    await tester.pump();
    expect(find.textContaining('철수의 응답을 기다리는 중'), findsOneWidget);
    expect(find.text('게임'), findsOneWidget); // 판은 그대로 보인다
    expect(find.text('이 판 끝내기'), findsOneWidget);

    // 계속 기다리기: 결정 단추가 접힌다
    await tester.tap(find.text('계속 기다리기'));
    await tester.pump();
    expect(find.text('이 판 끝내기'), findsNothing);
    expect(find.textContaining('철수의 응답을 기다리는 중'), findsOneWidget);

    // 상대가 돌아오면 안내가 사라진다
    await tester.runAsync(() async {
      raw.write('{"t":"x"}\n');
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    expect(find.textContaining('응답을 기다리는 중'), findsNothing);

    // 다시 끊겼을 때 판을 끝내면 연결이 닫힌다
    conn.decisionSnoozedUntil = null;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await tester.pump();
    expect(find.text('이 판 끝내기'), findsOneWidget);
    await tester.tap(find.text('이 판 끝내기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(conn.isClosed, isTrue);
    await tester.pump();
    expect(find.textContaining('응답을 기다리는 중'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      raw.destroy();
      await server.close();
    });
  });

  testWidgets('방장 화면에서는 한참 기다린 뒤 "CPU가 대신하기"를 고를 수 있고, 맡기면 한 줄 안내가 잠깐 뜬다', (tester) async {
    late LanConnection conn;
    late Socket raw;
    late ServerSocket server;
    await tester.runAsync(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      conn = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 30), timeout: const Duration(milliseconds: 300));
      conn.peer = {'nick': '영희'};
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    var taken = 0;
    conn.onTakeOver = () {
      taken++;
      conn.cpuCovered = true;
    };

    await tester.pumpWidget(const MaterialApp(
      home: LanStallOverlay(
        decisionAfter: Duration.zero,
        coveredNoticeFor: Duration(milliseconds: 300),
        child: Scaffold(body: Text('게임')),
      ),
    ));
    await tester.pump();
    expect(find.text('CPU가 대신하기'), findsOneWidget);
    expect(find.text('이 판 끝내기'), findsOneWidget);

    await tester.tap(find.text('CPU가 대신하기'));
    await tester.pump();
    expect(taken, 1);
    expect(find.textContaining('영희 자리는 CPU가 대신하고 있어요'), findsOneWidget);
    expect(find.text('CPU가 대신하기'), findsNothing);
    expect(find.text('이 판 끝내기'), findsNothing);

    // 한 줄 안내는 잠깐 뒤 저절로 사라진다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('CPU가 대신하고 있어요'), findsNothing);

    // 돌려주면 안내가 사라진다
    conn.cpuCovered = false;
    await tester.runAsync(() async {
      raw.write('{"t":"x"}\n');
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    expect(find.textContaining('CPU가 대신하고 있어요'), findsNothing);
    expect(find.textContaining('응답을 기다리는 중'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await conn.close();
      raw.destroy();
      await server.close();
    });
  });

  testWidgets('CPU가 대신할 수 없는 연결(손님 쪽)에는 그 단추가 없다', (tester) async {
    late LanConnection conn;
    late Socket raw;
    late ServerSocket server;
    await tester.runAsync(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      raw = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
      conn = LanConnection(await accepted, heartbeat: const Duration(milliseconds: 30), timeout: const Duration(milliseconds: 300));
      conn.peer = {'nick': '철수'};
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pumpWidget(const MaterialApp(home: LanStallOverlay(decisionAfter: Duration.zero, child: Scaffold(body: Text('게임')))));
    await tester.pump();
    expect(find.text('이 판 끝내기'), findsOneWidget);
    expect(find.text('CPU가 대신하기'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await conn.close();
      raw.destroy();
      await server.close();
    });
  });
}
