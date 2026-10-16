
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/quoridor/core/quoridor_rules.dart';
import 'package:tabgame/games/quoridor/data/quoridor_history.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

int cell(int r, int c) => r * kBoard + c;

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 방(호스트)에 손님 기기처럼 들어가는 연결 하나. 받은 메시지를 [log]에 모은다.
Future<LanConnection> joinAs(WidgetTester tester, String nick, int port, List<Map<String, dynamic>> log) async {
  final conn = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
  conn.messages.listen(log.add);
  conn.send({'t': 'hello', 'game': 'quoridor', 'nick': nick});
  return conn;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  });

  Future<void> pumpHost(WidgetTester tester, {required int hostSide, required int port, required int discovery}) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
        home: QuoridorHostScreen(hostSide: hostSide, players: 4, gamePort: port, discoveryPort: discovery),
      ),
    ));
    await settle(tester, rounds: 4);
  }

  testWidgets('4명 방: 모인 사람이 보이고, 네 명이 모두 모이면 저절로 시작하며 손님마다 다른 자리와 이름 목록을 받는다', (tester) async {
    await pumpHost(tester, hostSide: 0, port: 46070, discovery: 46061);
    expect(find.text('방이 열렸어요'), findsOneWidget);
    expect(find.text('모인 사람 (1/4명)'), findsOneWidget);

    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = <LanConnection>[];
    for (var i = 0; i < 3; i++) {
      guests.add(await joinAs(tester, '손님${i + 1}', 46070, logs[i]));
      await settle(tester, rounds: 4);
      if (i < 2) {
        expect(find.text('모인 사람 (${i + 2}/4명)'), findsOneWidget);
        // 모인 동안 손님에게 사람 목록이 간다
        expect(logs[i].where((m) => m['t'] == 'lobby').last['need'], 4);
      }
    }
    expect(logs[0].where((m) => m['t'] == 'lobby').last['names'], [SettingsScopeNick.of(tester), '손님1', '손님2', '손님3']);

    // 모두 모이면 시작: 손님마다 start 메시지
    final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
    expect({for (final s in starts) s['side']}.length, 3);
    expect(starts.every((s) => s['players'] == 4 && (s['side'] as int) > 0), isTrue); // 방장이 0번을 골랐다
    final names = (starts.first['names'] as List).cast<String>();
    expect(names.length, 4);
    expect(names[0], SettingsScopeNick.of(tester));
    expect(names[starts[1]['side'] as int], '손님2');
    expect(find.byType(QuoridorScreen), findsOneWidget);
    final host = tester.widget<QuoridorScreen>(find.byType(QuoridorScreen));
    expect(host.players, 4);
    expect(host.humanSeat, 0);
    expect(host.links!.length, 3);
    expect(host.linkSeats, [for (final s in starts) s['side']]);

    await tester.pumpWidget(const SizedBox());
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4); // 방장 쪽 연결이 닫히는 동안
  });

  testWidgets('4명 판: 방장이 손님의 수를 확인해 다른 손님들에게 전해 주고, 차례가 아닌 손님의 수는 어긋남으로 본다', (tester) async {
    await pumpHost(tester, hostSide: 0, port: 46071, discovery: 46062);
    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 3; i++) await joinAs(tester, '손님${i + 1}', 46071, logs[i])];
    await settle(tester, rounds: 6);
    final seats = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')['side'] as int];
    // 자리 → 손님 번호
    final guestOfSeat = {for (var i = 0; i < 3; i++) seats[i]: i};
    final host = tester.widget<QuoridorScreen>(find.byType(QuoridorScreen));
    expect(host.humanSeat, 0);

    // 0번(방장)이 먼저: 칸을 눌러야 하지만 여기서는 방장 컨트롤러를 거치지 않고 손님들 쪽 수만 시험한다.
    // 방장 차례를 건너뛸 수 없으니, 방장이 한 수 두는 것은 화면 조작으로 한다.
    final state = tester.state(find.byType(QuoridorScreen));
    expect(state, isNotNull);
    final c = (state as dynamic).c;
    expect(c.tapCell(cell(7, 4)), isTrue);
    await settle(tester, rounds: 3);
    // 방장의 수가 모든 손님에게 간다
    for (final l in logs) {
      expect(l.where((m) => m['t'] == 'move').single, {'t': 'move', 'i': 0, 'm': cell(7, 4)});
    }

    // 1번 자리 손님의 수 → 방장이 받아 나머지 손님들에게 전한다
    final g1 = guestOfSeat[1]!;
    guests[g1].send({'t': 'move', 'i': 1, 'm': cell(4, 1)});
    await settle(tester, rounds: 4);
    expect(c.moveCount, 2);
    for (var i = 0; i < 3; i++) {
      final moves = logs[i].where((m) => m['t'] == 'move').toList();
      if (i == g1) {
        expect(moves.length, 1); // 보낸 사람에게는 되돌려 주지 않는다
      } else {
        expect(moves.last, {'t': 'move', 'i': 1, 'm': cell(4, 1)});
      }
    }

    // 2번 차례인데 3번 자리 손님이 수를 보내면 어긋남
    final g3 = guestOfSeat[3]!;
    guests[g3].send({'t': 'move', 'i': 2, 'm': cell(4, 7)});
    await settle(tester, rounds: 4);
    expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await settle(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(QuoridorScreen), findsNothing);
    // 어긋나서 끝나면 다른 손님들에게도 연결이 끊긴다
    for (final g in guests) {
      await tester.runAsync(() => g.closed.timeout(const Duration(seconds: 3)));
      expect(g.isClosed, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('4명 판이 끝까지 가면 결과가 한 번 기록되고, 모두 "한 판 더"를 눌러야 새 판이 시작되며 자리가 돈다', (tester) async {
    await pumpHost(tester, hostSide: 0, port: 46072, discovery: 46063);
    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 3; i++) await joinAs(tester, '손님${i + 1}', 46072, logs[i])];
    await settle(tester, rounds: 6);
    final seats = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')['side'] as int];
    final guestOfSeat = {for (var i = 0; i < 3; i++) seats[i]: i};
    final c = (tester.state(find.byType(QuoridorScreen)) as dynamic).c;

    // 방장(0번)이 곧장 위로 달리고, 나머지는 옆으로 한 칸씩 움직이며 차례를 넘긴다
    var i = 0;
    final path0 = [cell(7, 4), cell(6, 4), cell(5, 4), cell(4, 4), cell(3, 4), cell(2, 4), cell(1, 4), cell(0, 4)];
    final others = {
      1: [cell(3, 0), cell(3, 1), cell(2, 1), cell(1, 1), cell(1, 2), cell(1, 3), cell(2, 3), cell(2, 2)],
      2: [cell(1, 4)], // 위 말은 방장과 겹치니 아래로 먼저 간다 (아래 두 줄)
    };
    expect(others, isNotEmpty);
    // 말이 서로 안 겹치도록 단순하게: 1번은 위아래로, 2번은 좌우로, 3번은 위아래로 왔다 갔다 한다
    final shuffle = {
      1: [cell(3, 0), cell(4, 0)],
      2: [cell(0, 3), cell(0, 2)],
      3: [cell(3, 8), cell(4, 8)],
    };
    final used = {1: 0, 2: 0, 3: 0};
    var step = 0;
    while (!c.isOver && step < 40) {
      final seat = c.turn as int;
      if (seat == 0) {
        expect(c.tapCell(path0[i++]), isTrue);
      } else {
        final list = shuffle[seat]!;
        final to = list[used[seat]! % 2];
        used[seat] = used[seat]! + 1;
        guests[guestOfSeat[seat]!].send({'t': 'move', 'i': c.moveCount, 'm': to});
      }
      await settle(tester, rounds: 2);
      step++;
    }
    expect(c.isOver, isTrue);
    expect(c.state.winner, 0);
    await settle(tester, rounds: 4);
    final h = (await tester.runAsync(QuoridorHistory.load))!;
    expect(h.length, 1);
    expect(h.single.online, isTrue);
    expect(h.single.players, 4);
    expect(h.single.humanWon, isTrue);
    expect(find.text('한 판 더'), findsOneWidget);

    // 방장이 먼저 누르면 나머지를 기다린다
    await tester.tap(find.text('한 판 더'));
    await settle(tester, rounds: 3);
    expect(find.text('상대를 기다려요…'), findsOneWidget);
    expect(c.isOver, isTrue);
    for (var k = 0; k < 3; k++) {
      guests[k].send({'t': 'again'});
      await settle(tester, rounds: 3);
      if (k < 2) expect(c.isOver, isTrue); // 아직 다 안 눌렀다
    }
    expect(c.isOver, isFalse);
    expect(c.humanSeat, 1); // 자리가 한 칸 돈다
    expect(c.moveCount, 0);
    // 다른 손님들에게 서로의 "한 판 더"가 전해졌다
    expect(logs[0].where((m) => m['t'] == 'again').length, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4); // 방장 쪽 연결이 닫히는 동안
  });
}

/// 시험에서 쓰는 별명 읽기.
class SettingsScopeNick {
  static String of(WidgetTester tester) => SettingsScope.of(tester.element(find.byType(Scaffold).first)).nickname;
}
