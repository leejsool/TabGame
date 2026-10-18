import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';
import 'package:tabgame/net/lan_stall_overlay.dart';

import '../support/preview_kit.dart';

Future<void> settle(WidgetTester tester, {int rounds = 6, int ms = 40}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<LanConnection> joinAs(WidgetTester tester, String nick, int port, List<Map<String, dynamic>> log) async {
  final conn = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
  conn.messages.listen(log.add);
  conn.send({'t': 'hello', 'game': 'quoridor', 'nick': nick});
  return conn;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('4명 방에서 손님이 앱을 끄면 방장이 CPU에게 맡기고, 그 손님이 표를 들고 돌아오면 같은 판의 자리로 돌아온다', (tester) async {
    const port = 46090, discovery = 46091;
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
        builder: (context, child) => LanStallOverlay(decisionAfter: Duration.zero, child: child!),
        home: const QuoridorHostScreen(hostSide: 0, players: 4, gamePort: port, discoveryPort: discovery),
      ),
    ));
    await settle(tester, rounds: 4);

    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 3; i++) await joinAs(tester, '손님${i + 1}', port, logs[i])];
    await settle(tester, rounds: 6);
    final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
    final seats = [for (final s in starts) s['side'] as int];
    expect(starts.every((s) => s['rejoin'] is Map), isTrue, reason: '시작할 때 손님마다 다시 들어오기 표를 받아야 해요');
    expect({for (final s in starts) (s['rejoin'] as Map)['token']}.length, 3, reason: '표는 손님마다 달라야 해요');

    final c = (tester.state(find.byType(QuoridorScreen)) as dynamic).c;
    expect(c.tapCell(7 * 9 + 4), isTrue); // 방장(0번)이 한 수
    await settle(tester, rounds: 3);
    expect(c.turn, 1);

    // 1번 자리에 앉은 손님이 앱을 껐다
    final away = seats.indexOf(1);
    await tester.runAsync(guests[away].close);
    await settle(tester, rounds: 5);
    expect(find.textContaining('손님${away + 1} 님이 나갔어요'), findsOneWidget);
    expect(find.text('CPU가 대신하기'), findsOneWidget);
    expect(c.cpuSeats, isEmpty, reason: '누르기 전에는 CPU가 맡지 않아요');
    expect(c.turn, 1, reason: '나간 사람 차례에서는 기다려요');

    // 방장이 CPU에게 맡긴다
    await tester.tap(find.text('CPU가 대신하기'));
    await settle(tester, rounds: 2);
    expect(c.cpuSeats, {1});
    expect(find.textContaining('CPU가 대신하고 있어요'), findsOneWidget);
    for (var k = 0; k < 3; k++) {
      if (k == away) continue;
      expect(logs[k].where((m) => m['t'] == 'cpu').map((m) => m['seat']), [1], reason: '다른 손님들도 알아야 해요');
    }
    // CPU가 1번 자리의 수를 두고, 그 수가 다른 손님들에게 간다
    await settle(tester, rounds: 45, ms: 60);
    expect(c.turn, 2, reason: 'CPU가 1번 자리의 수를 두지 않았어요');
    expect(c.moveCount, 2);
    for (var k = 0; k < 3; k++) {
      if (k == away) continue;
      expect(logs[k].where((m) => m['t'] == 'move').length, 2);
    }

    // 나갔던 손님이 표를 들고 돌아온다
    final ticketJson = starts[away]['rejoin'] as Map;
    final ticket = RejoinTicket(
      game: 'quoridor',
      roomId: ticketJson['room'] as String,
      token: ticketJson['token'] as String,
      host: '127.0.0.1',
      port: port,
      hostNick: '방장',
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    // (방장 쪽 화면이 소식을 받아 처리하도록 기다리는 동안 화면을 계속 돌려 준다)
    Future<LanRejoinResult>? pending;
    await tester.runAsync(() async {
      pending = lanRejoin(ticket, nick: '손님${away + 1}'); // (끝나길 기다리지 않고 바로 돌아온다)
    });
    await settle(tester, rounds: 8);
    final result = (await tester.runAsync(() => pending!))!;
    expect(result.ok, isTrue, reason: '실패 까닭: ${result.fail}');
    await settle(tester, rounds: 3);
    expect(result.resume!['seat'], 1);
    expect(c.cpuSeats, isEmpty, reason: '돌아오면 자리를 사람에게 돌려줘야 해요');
    expect(find.textContaining('CPU가 대신하고 있어요'), findsNothing);
    expect(find.textContaining('나갔어요'), findsNothing);
    for (var k = 0; k < 3; k++) {
      if (k == away) continue;
      expect(logs[k].where((m) => m['t'] == 'back').map((m) => m['seat']), [1]);
    }

    // 받은 판의 모습으로 이 기기의 화면을 만든다
    final restored = quoridorResume(result.resume!, result.conn!);
    expect(restored, isNotNull);
    final guestLog = <Map<String, dynamic>>[];
    result.conn!.messages.listen(guestLog.add);
    // 다음 수는 2번 자리 손님이 두고 방장이 모두에게 전한다. 돌아온 손님도 그 수를 받는다
    final seat2 = seats.indexOf(2);
    guests[seat2].send({'t': 'move', 'i': 2, 'm': 3});
    await settle(tester, rounds: 4);
    expect(c.moveCount, 3);
    expect(guestLog.where((m) => m['t'] == 'move').map((m) => m['i']), [2]);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(result.conn!.close);
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4);
  });
}
