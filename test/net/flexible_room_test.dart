import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_wifi_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_wifi_screen.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_screen.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_screens.dart';

import '../support/preview_kit.dart';

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<LanConnection> joinAs(WidgetTester tester, String game, String nick, int port, List<Map<String, dynamic>> log) async {
  final conn = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
  conn.messages.listen(log.add);
  conn.send({'t': 'hello', 'game': game, 'nick': nick});
  return conn;
}

Future<void> pumpHome(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  await tester.pumpWidget(SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  ));
  await settle(tester, rounds: 4);
}

Finder startBtn(int cpus) => find.byKey(ValueKey('start-cpus$cpus'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    RummikubScreen.playSounds = false; // (시험에는 소리 플러그인이 없다)
    await loadAppFonts();
  });

  test('시작 단추로 고를 수 있는 CPU 수: 허용된 전체 인원이 되는 만큼만', () {
    const any = LanFlexibleRoom(allowedPlayers: {2, 3, 4}, onStart: _never);
    expect(any.cpuChoices(1), [1, 2, 3]); // (사람 한 명만 있으면 2명 이상이어야 하지만, 단추는 사람이 둘 이상일 때만 보인다)
    expect(any.cpuChoices(2), [0, 1, 2]);
    expect(any.cpuChoices(3), [0, 1]);
    expect(any.cpuChoices(4), [0]);
    const even = LanFlexibleRoom(allowedPlayers: {2, 4}, onStart: _never);
    expect(even.cpuChoices(2), [0, 2]);
    expect(even.cpuChoices(3), [1]);
    expect(even.cpuChoices(4), [0]);
  });

  group('다빈치 코드', () {
    testWidgets('아무도 없으면 시작 단추가 없고, 한 명이 들어오면 "이대로 / CPU 1명 / CPU 2명" 단추가 나타난다', (tester) async {
      await pumpHome(tester, const DavinciHostScreen(hostSide: 0, flexible: true, gamePort: 46410, discoveryPort: 46411, seed: 77));
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('모인 사람 (1명 · 최대 4명)'), findsOneWidget);
      expect(startBtn(0), findsNothing);
      expect(startBtn(1), findsNothing);
      expect(find.textContaining('아무도 들어오지 않았어요'), findsOneWidget);

      final log = <Map<String, dynamic>>[];
      final guest = await joinAs(tester, 'davinci_code', '손님', 46410, log);
      await settle(tester, rounds: 5);
      expect(find.text('모인 사람 (2명 · 최대 4명)'), findsOneWidget);
      expect(find.text('이대로 시작하기 (2명)'), findsOneWidget);
      expect(find.text('CPU 1명 넣고 시작하기 (3명)'), findsOneWidget);
      expect(find.text('CPU 2명 넣고 시작하기 (4명)'), findsOneWidget);
      // 손님에게는 사람 목록만 가고 필요한 인원은 알리지 않는다 (인원이 정해지지 않았으니)
      final lobby = log.lastWhere((m) => m['t'] == 'lobby');
      expect((lobby['names'] as List).length, 2);
      expect(lobby.containsKey('need'), isFalse);
      expect(log.any((m) => m['t'] == 'start'), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(guest.close);
      await settle(tester, rounds: 4);
    });

    testWidgets('"CPU 2명 넣고 시작하기": 사람 2명 + CPU 2명으로 시작하고, 손님은 CPU 자리를 아는 시작 메시지를 받는다', (tester) async {
      await pumpHome(tester, const DavinciHostScreen(hostSide: 0, flexible: true, gamePort: 46412, discoveryPort: 46413, seed: 77));
      final log = <Map<String, dynamic>>[];
      final guest = await joinAs(tester, 'davinci_code', '손님', 46412, log);
      await settle(tester, rounds: 5);
      await tester.tap(startBtn(2));
      await settle(tester, rounds: 6);
      final start = log.firstWhere((m) => m['t'] == 'start');
      expect(start['players'], 4);
      expect((start['cpus'] as List).length, 2);
      expect(start['seed'], 77);
      final names = (start['names'] as List).cast<String>();
      expect(names.where((n) => n.startsWith('CPU')).length, 2);
      expect(names.contains('손님'), isTrue);
      final screen = tester.widget<DavinciScreen>(find.byType(DavinciScreen));
      expect(screen.players, 4);
      expect(screen.cpuSeats!.length, 2);
      expect(screen.humanSeat, 0); // 방장이 먼저를 골랐다
      expect(screen.links!.length, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(guest.close);
      await settle(tester, rounds: 4);
    });

    testWidgets('"이대로 시작하기": 사람 둘만으로 시작한다 (CPU 없음)', (tester) async {
      await pumpHome(tester, const DavinciHostScreen(hostSide: 1, flexible: true, gamePort: 46414, discoveryPort: 46415));
      final log = <Map<String, dynamic>>[];
      final guest = await joinAs(tester, 'davinci_code', '손님', 46414, log);
      await settle(tester, rounds: 5);
      await tester.tap(startBtn(0));
      await settle(tester, rounds: 6);
      final start = log.firstWhere((m) => m['t'] == 'start');
      expect(start['players'], 2);
      expect(start['cpus'], isEmpty);
      expect(start['side'], 0); // 방장이 두 번째를 골랐으니 손님이 먼저
      expect(tester.widget<DavinciScreen>(find.byType(DavinciScreen)).humanSeat, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(guest.close);
      await settle(tester, rounds: 4);
    });

    testWidgets('둘이 들어오면 "CPU 2명" 단추는 사라지고, 한 명이 나가면 다시 나타난다. 셋이 들어오면 저절로 시작한다', (tester) async {
      await pumpHome(tester, const DavinciHostScreen(hostSide: 0, flexible: true, gamePort: 46416, discoveryPort: 46417, seed: 5));
      final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
      final g1 = await joinAs(tester, 'davinci_code', '손님1', 46416, logs[0]);
      final g2 = await joinAs(tester, 'davinci_code', '손님2', 46416, logs[1]);
      await settle(tester, rounds: 6);
      expect(find.text('이대로 시작하기 (3명)'), findsOneWidget);
      expect(find.text('CPU 1명 넣고 시작하기 (4명)'), findsOneWidget);
      expect(startBtn(2), findsNothing);
      // 손님 한 명이 나가면 목록과 단추가 바뀐다
      await tester.runAsync(g2.close);
      await settle(tester, rounds: 6);
      expect(find.text('이대로 시작하기 (2명)'), findsOneWidget);
      expect(startBtn(2), findsOneWidget);
      // 다시 들어오고 한 명이 더 들어와 네 명이 되면 저절로 시작
      final g3 = await joinAs(tester, 'davinci_code', '손님3', 46416, logs[2]);
      final g4 = await joinAs(tester, 'davinci_code', '손님4', 46416, <Map<String, dynamic>>[]);
      await settle(tester, rounds: 8);
      expect(find.byType(DavinciScreen), findsOneWidget);
      expect(tester.widget<DavinciScreen>(find.byType(DavinciScreen)).players, 4);
      expect(tester.widget<DavinciScreen>(find.byType(DavinciScreen)).cpuSeats, isEmpty);
      await tester.pumpWidget(const SizedBox());
      for (final g in [g1, g3, g4]) {
        await tester.runAsync(g.close);
      }
      await settle(tester, rounds: 4);
    });
  });

  group('쿼리도 (2명 또는 4명)', () {
    testWidgets('한 명이 들어오면 "이대로(2명)"와 "CPU 2명(4명)"만, 둘이 들어오면 "CPU 1명(4명)"만 보인다', (tester) async {
      await pumpHome(tester, const QuoridorHostScreen(hostSide: 0, flexible: true, gamePort: 46420, discoveryPort: 46421));
      final g1 = await joinAs(tester, 'quoridor', '손님1', 46420, <Map<String, dynamic>>[]);
      await settle(tester, rounds: 5);
      expect(find.text('이대로 시작하기 (2명)'), findsOneWidget);
      expect(startBtn(1), findsNothing); // 3명은 할 수 없다
      expect(find.text('CPU 2명 넣고 시작하기 (4명)'), findsOneWidget);
      final g2 = await joinAs(tester, 'quoridor', '손님2', 46420, <Map<String, dynamic>>[]);
      await settle(tester, rounds: 5);
      expect(startBtn(0), findsNothing); // 사람 셋으로는 시작할 수 없다
      expect(find.text('CPU 1명 넣고 시작하기 (4명)'), findsOneWidget);
      expect(startBtn(2), findsNothing);
      await tester.pumpWidget(const SizedBox());
      for (final g in [g1, g2]) {
        await tester.runAsync(g.close);
      }
      await settle(tester, rounds: 4);
    });

    testWidgets('사람 셋 + CPU 1명으로 시작하면 4명 판이 된다', (tester) async {
      await pumpHome(tester, const QuoridorHostScreen(hostSide: 0, flexible: true, gamePort: 46422, discoveryPort: 46423));
      final logs = [<Map<String, dynamic>>[], <Map<String, dynamic>>[]];
      final g1 = await joinAs(tester, 'quoridor', '손님1', 46422, logs[0]);
      final g2 = await joinAs(tester, 'quoridor', '손님2', 46422, logs[1]);
      await settle(tester, rounds: 6);
      await tester.tap(startBtn(1));
      await settle(tester, rounds: 6);
      final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
      expect(starts.every((s) => s['players'] == 4 && (s['cpus'] as List).length == 1), isTrue);
      expect({for (final s in starts) s['side']}.length, 2);
      final screen = tester.widget<QuoridorScreen>(find.byType(QuoridorScreen));
      expect(screen.players, 4);
      expect(screen.cpuSeats!.length, 1);
      await tester.pumpWidget(const SizedBox());
      for (final g in [g1, g2]) {
        await tester.runAsync(g.close);
      }
      await settle(tester, rounds: 4);
    });

    testWidgets('사람 둘 + CPU 2명으로 시작하면 4명 판', (tester) async {
      await pumpHome(tester, const QuoridorHostScreen(hostSide: 0, flexible: true, gamePort: 46424, discoveryPort: 46425));
      final log = <Map<String, dynamic>>[];
      final g1 = await joinAs(tester, 'quoridor', '손님', 46424, log);
      await settle(tester, rounds: 5);
      await tester.tap(startBtn(2));
      await settle(tester, rounds: 6);
      final start = log.firstWhere((m) => m['t'] == 'start');
      expect(start['players'], 4);
      expect((start['cpus'] as List).length, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(g1.close);
      await settle(tester, rounds: 4);
    });
  });

  group('루미큐브', () {
    testWidgets('사람 셋 + CPU 1명으로 시작하면 4명 판 (시작 메시지에 씨앗과 CPU 자리가 있다)', (tester) async {
      await pumpHome(tester, const RummikubHostScreen(hostSide: 0, flexible: true, gamePort: 46426, discoveryPort: 46427, seed: 9));
      final logs = [<Map<String, dynamic>>[], <Map<String, dynamic>>[]];
      final g1 = await joinAs(tester, 'rummikub', '손님1', 46426, logs[0]);
      final g2 = await joinAs(tester, 'rummikub', '손님2', 46426, logs[1]);
      await settle(tester, rounds: 6);
      expect(find.text('이대로 시작하기 (3명)'), findsOneWidget);
      await tester.tap(startBtn(1));
      await settle(tester, rounds: 6);
      for (final l in logs) {
        final start = l.firstWhere((m) => m['t'] == 'start');
        expect(start['players'], 4);
        expect(start['seed'], 9);
        expect((start['cpus'] as List).length, 1);
      }
      expect(tester.widget<RummikubScreen>(find.byType(RummikubScreen)).players, 4);
      await tester.pumpWidget(const SizedBox());
      for (final g in [g1, g2]) {
        await tester.runAsync(g.close);
      }
      await settle(tester, rounds: 4);
    });
  });
}

LanLobbyPlan _never(List<LanConnection> guests, int cpus) => throw UnimplementedError();
