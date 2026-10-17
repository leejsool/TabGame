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
}
