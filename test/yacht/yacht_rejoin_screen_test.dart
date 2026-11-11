import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';
import 'package:tabgame/games/yacht/ui/yacht_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';
import 'package:tabgame/net/lan_stall_overlay.dart';

import '../support/preview_kit.dart';

/// 진짜 연결(소켓 · CPU 계산)이 돌 시간을 주면서 화면의 시계도 [pump]밀리초씩 돌린다.
Future<void> settle(WidgetTester tester, {int rounds = 6, int ms = 40, int pump = 60}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(Duration(milliseconds: pump));
  }
}

Future<LanConnection> joinAs(WidgetTester tester, String nick, int port, List<Map<String, dynamic>> log) async {
  final conn = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
  conn.messages.listen(log.add);
  conn.send({'t': 'hello', 'game': 'yacht', 'nick': nick});
  return conn;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('3명 방: 소식이 방장을 거쳐 모두에게 가고, 나간 손님 자리는 CPU가 맡았다가 돌아오면 같은 판의 자리로 돌아온다', (tester) async {
    const port = 46490, discovery = 46491;
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
        home: YachtHostScreen(gamePort: port, discoveryPort: discovery, rng: Random(5)),
      ),
    ));
    await settle(tester, rounds: 4);

    final logs = [for (var i = 0; i < 2; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 2; i++) await joinAs(tester, '손님${i + 1}', port, logs[i])];
    await settle(tester, rounds: 6);
    await tester.tap(find.text('이대로 시작하기 (3명)'));
    await settle(tester, rounds: 8);
    final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
    final seats = [for (final s in starts) s['side'] as int];
    expect(starts.every((s) => s['rejoin'] is Map), isTrue, reason: '시작할 때 손님마다 다시 들어오기 표를 받아야 해요');
    expect(starts.every((s) => s['players'] == 3 && (s['names'] as List).length == 3), isTrue);

    final YachtController c = (tester.state(find.byType(YachtScreen)) as dynamic).c as YachtController;
    expect(c.online, isTrue);
    expect({c.humanSeat, ...seats}, {0, 1, 2}, reason: '자리가 겹치면 안 돼요');

    // [seat] 자리의 사람이 한 번 굴리고 초이스에 적는다 (방장이면 화면에서, 손님이면 소식으로)
    Future<void> playTurn(int seat) async {
      expect(c.game.turn, seat);
      if (seat == c.humanSeat) {
        c.roll();
        await settle(tester, rounds: 8, pump: 200);
        c.choose(YachtCategory.values.firstWhere(c.game.canScore));
        c.confirm();
      } else {
        final g = guests[seats.indexOf(seat)];
        g.send({'t': 'roll', 'd': [1, 2, 3, 4, 5], 'i': c.actions});
        await settle(tester, rounds: 8, pump: 200);
        expect(c.game.dice, [1, 2, 3, 4, 5]);
        g.send({'t': 'score', 'c': YachtCategory.values.firstWhere(c.game.canScore).index, 'i': c.actions});
      }
      await settle(tester, rounds: 4);
      expect(c.game.turn, (seat + 1) % 3, reason: '$seat번 자리의 차례가 끝나지 않았어요');
    }

    // 첫 손님(손님1)의 차례가 올 때까지 앞사람들이 한 차례씩 한다
    final awaySeat = seats[0];
    for (var s = 0; s < awaySeat; s++) {
      await playTurn(s);
    }
    final before = c.actions;
    for (var k = 0; k < 2; k++) {
      final others = logs[k].where((m) => m['t'] == 'roll' || m['t'] == 'score').length;
      // 내가 보낸 소식은 되돌아오지 않고, 남의 소식만 온다
      final mine = seats[k] < awaySeat ? 2 : 0;
      expect(others, before - mine, reason: '손님${k + 1}이 받은 소식 수');
    }

    // 손님1이 자기 차례에 앱을 껐다
    await tester.runAsync(guests[0].close);
    await settle(tester, rounds: 5);
    expect(find.textContaining('손님1 님이 나갔어요'), findsOneWidget);
    expect(c.cpuSeats, isEmpty, reason: '누르기 전에는 CPU가 맡지 않아요');
    await tester.tap(find.text('CPU가 대신하기'));
    await settle(tester, rounds: 2);
    expect(c.cpuSeats, {awaySeat});
    expect(logs[1].where((m) => m['t'] == 'cpu').map((m) => m['seat']), [awaySeat], reason: '다른 손님도 알아야 해요');

    // CPU가 그 자리의 차례를 끝내고, 그 소식이 남은 손님에게 간다
    for (var i = 0; i < 20 && c.game.turn == awaySeat; i++) {
      await settle(tester, rounds: 10, pump: 200);
    }
    expect(c.game.turn, (awaySeat + 1) % 3, reason: 'CPU가 나간 사람의 차례를 끝내지 않았어요');
    expect(logs[1].last['t'], 'score');

    // 나갔던 손님이 표를 들고 돌아온다
    final ticketJson = starts[0]['rejoin'] as Map;
    final ticket = RejoinTicket(
      game: 'yacht',
      roomId: ticketJson['room'] as String,
      token: ticketJson['token'] as String,
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
    expect(result.resume!['seat'], awaySeat);
    expect(c.cpuSeats, isEmpty, reason: '돌아오면 자리를 사람에게 돌려줘야 해요');
    expect(logs[1].where((m) => m['t'] == 'back').map((m) => m['seat']), [awaySeat]);

    // 받은 판의 모습으로 이 기기의 화면을 만들 수 있고, 판이 방장과 같다
    expect(yachtResume(result.resume!, result.conn!), isNotNull);
    final back = YachtControllerRejoin.fromWifiSnapshot(result.resume!['snap'] as Map<String, dynamic>, humanSeat: awaySeat)!;
    expect(back.actions, c.actions);
    expect(back.game.turn, c.game.turn);
    expect([for (final card in back.game.cards) card.total], [for (final card in c.game.cards) card.total]);
    expect(back.name(c.humanSeat), isNot('상대'), reason: '이름표도 함께 받아야 해요');
    back.dispose();

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(result.conn!.close);
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4);
  });
}
