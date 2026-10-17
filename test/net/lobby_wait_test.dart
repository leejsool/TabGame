import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/net/keep_awake.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_screens.dart';

Future<void> settle(WidgetTester tester, {int rounds = 6, int ms = 40}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('3명 방: 먼저 들어온 손님이 오래 기다려도 방이 터지지 않고, 늦게 온 손님이 들어오면 모두 시작한다', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'nickname': '방장'});
    final settings = await Settings.load();
    final started = <Map<String, dynamic>>[];
    final guestConns = <LanConnection>[];
    final baseHolders = KeepAwake.holders;
    const port = 46310, discovery = 46311;

    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: MaterialApp(
              home: LanLobbyScreen(
                game: 'lobbytest',
                gameName: '시험',
                info: const {},
                summary: const ['시험 방'],
                needGuests: 2,
                gamePort: port,
                discoveryPort: discovery,
                onFull: (guests) => LanLobbyPlan(
                  messages: [for (var i = 0; i < guests.length; i++) {'side': i + 1}],
                  hostScreen: (g) => const Scaffold(body: Text('방장 게임 화면')),
                ),
              ),
            ),
          ),
          Expanded(
            child: MaterialApp(
              home: LanJoinScreen(
                game: 'lobbytest',
                color: Colors.blue,
                roomTitle: (r) => '시험 방',
                roomSubtitle: (r) => '',
                discoveryPort: discovery,
                extraTargets: const ['127.0.0.1'],
                buildGame: (m, conn) {
                  started.add(m);
                  guestConns.add(conn);
                  return const Scaffold(body: Text('손님1 게임 화면'));
                },
              ),
            ),
          ),
        ],
      ),
    ));
    await settle(tester, rounds: 12, ms: 150); // 방 찾기 응답을 기다린다
    expect(find.text('들어가기'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
    await settle(tester, rounds: 6);
    expect(find.textContaining('방장이 시작하기를 기다리는 중이에요'), findsOneWidget);

    // 늦게 오는 사람을 오래 기다린다 (예전에는 이 사이에 터졌다)
    for (var i = 0; i < 24; i++) {
      await settle(tester, rounds: 1, ms: 500);
    }
    expect(find.textContaining('방장이 시작하기를 기다리는 중이에요'), findsOneWidget, reason: '기다리는 동안 손님 화면이 풀렸어요');
    expect(find.text('모인 사람 (2/3명)'), findsOneWidget, reason: '기다리는 동안 방장 화면에서 손님이 빠졌어요');
    expect(started, isEmpty);
    // 방을 열고 손님이 이어져 있는 동안 화면이 꺼지지 않게 붙들고 있다
    expect(KeepAwake.holders, greaterThan(baseHolders));

    // 늦게 온 두 번째 손님
    final late = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
    final lateLog = <Map<String, dynamic>>[];
    late.messages.listen(lateLog.add);
    late.send({'t': 'hello', 'game': 'lobbytest', 'nick': '늦은손님'});
    await settle(tester, rounds: 8);
    expect(lateLog.any((m) => m['t'] == 'start'), isTrue);
    expect(started.length, 1, reason: '먼저 온 손님에게 시작 메시지가 안 왔어요');
    expect(find.text('방장 게임 화면'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(late.close);
    for (final g in guestConns) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 6);
    expect(KeepAwake.holders, baseHolders, reason: '끝난 뒤에도 화면 켜짐 요청이 남았어요');
  });

  testWidgets('화면 켜짐 유지: 요청한 수를 세어서 처음 켜고 마지막에 푼다', (tester) async {
    final calls = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('tabgame/awake'), (call) async {
      calls.add((call.arguments as Map)['on'] as bool);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('tabgame/awake'), null));
    final base = KeepAwake.holders;
    KeepAwake.acquire();
    KeepAwake.acquire();
    KeepAwake.release();
    await tester.pump();
    if (base == 0) expect(calls, [true], reason: '둘이 요청해도 한 번만 켜고, 하나가 풀어도 아직 켜 둔다');
    KeepAwake.release();
    await tester.pump();
    expect(KeepAwake.holders, base);
    if (base == 0) expect(calls, [true, false]);
  });
}
