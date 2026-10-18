import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_wifi_screen.dart';
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
  conn.send({'t': 'hello', 'game': 'davinci_code', 'nick': nick});
  return conn;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DavinciController.animateByDefault = false;
    await loadAppFonts();
  });

  testWidgets('3명 방에서 손님이 앱을 끄면 방장이 CPU에게 맡기고, 그 손님이 표를 들고 돌아오면 받은 판의 모습으로 화면이 열린다', (tester) async {
    const port = 46092, discovery = 46093;
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
        home: const DavinciHostScreen(hostSide: 0, players: 3, gamePort: port, discoveryPort: discovery),
      ),
    ));
    await settle(tester, rounds: 4);

    final logs = [for (var i = 0; i < 2; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 2; i++) await joinAs(tester, '손님${i + 1}', port, logs[i])];
    await settle(tester, rounds: 6);
    final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
    expect(starts.every((s) => s['rejoin'] is Map), isTrue);
    final c = (tester.state(find.byType(DavinciScreen)) as dynamic).c;
    expect(c.cpuSeats, isEmpty);

    // 첫 번째 손님이 앱을 껐다
    await tester.runAsync(guests[0].close);
    await settle(tester, rounds: 5);
    expect(find.textContaining('손님1 님이 나갔어요'), findsOneWidget);
    expect(find.text('CPU가 대신하기'), findsOneWidget);

    await tester.tap(find.text('CPU가 대신하기'));
    await settle(tester, rounds: 3);
    final away = starts[0]['side'] as int;
    expect(c.cpuSeats, {away});
    expect(logs[1].where((m) => m['t'] == 'cpu').map((m) => m['seat']), [away]);
    expect(find.textContaining('CPU가 대신하고 있어요'), findsOneWidget);

    // 돌아온다
    final t = starts[0]['rejoin'] as Map;
    final ticket = RejoinTicket(
      game: 'davinci_code',
      roomId: t['room'] as String,
      token: t['token'] as String,
      host: '127.0.0.1',
      port: port,
      hostNick: '방장',
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    Future<LanRejoinResult>? pending;
    await tester.runAsync(() async {
      pending = lanRejoin(ticket, nick: '손님1');
    });
    await settle(tester, rounds: 8);
    final result = (await tester.runAsync(() => pending!))!;
    expect(result.ok, isTrue, reason: '실패 까닭: ${result.fail}');
    await settle(tester, rounds: 3);
    expect(result.resume!['seat'], away);
    expect(c.cpuSeats, isEmpty);
    expect(find.textContaining('CPU가 대신하고 있어요'), findsNothing);
    expect(logs[1].where((m) => m['t'] == 'back').map((m) => m['seat']), [away]);

    // 받은 판의 모습으로 이 기기의 화면이 열린다
    final restored = davinciResume(result.resume!, result.conn!);
    expect(restored, isNotNull);
    await tester.pumpWidget(const SizedBox()); // 방장 화면을 닫고 (곧 연결이 끊긴다는 소식이 온다)
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: restored!),
    ));
    await tester.pump(); // (그 소식이 오기 전에 확인한다)
    expect(find.byType(DavinciScreen), findsOneWidget);
    final back = (tester.state(find.byType(DavinciScreen)) as dynamic).c;
    expect(back.humanSeat, away);
    expect(back.online, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(result.conn!.close);
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4);
  });
}
