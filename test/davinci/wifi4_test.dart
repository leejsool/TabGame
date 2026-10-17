import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

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
  conn.send({'t': 'hello', 'game': 'davinci_code', 'nick': nick});
  return conn;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DavinciController.animateByDefault = false; // (상대 수 연출은 아래 시험에서만 켠다)
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  });

  Future<void> pumpHost(WidgetTester tester, {required int players, required int port, required int discovery, int hostSide = 0}) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
        home: DavinciHostScreen(hostSide: hostSide, players: players, gamePort: port, discoveryPort: discovery, seed: 4242),
      ),
    ));
    await settle(tester, rounds: 4);
  }

  testWidgets('3명 방: 모두 모이면 저절로 시작하고, 손님마다 다른 자리·같은 씨앗과 이름 목록을 받는다', (tester) async {
    await pumpHost(tester, players: 3, port: 46170, discovery: 46181);
    expect(find.text('모인 사람 (1/3명)'), findsOneWidget);
    final logs = [for (var i = 0; i < 2; i++) <Map<String, dynamic>>[]];
    final guests = <LanConnection>[];
    for (var i = 0; i < 2; i++) {
      guests.add(await joinAs(tester, '손님${i + 1}', 46170, logs[i]));
      await settle(tester, rounds: 4);
    }
    final starts = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')];
    expect({for (final s in starts) s['side']}.length, 2);
    expect(starts.every((s) => s['players'] == 3 && s['seed'] == 4242 && (s['side'] as int) > 0), isTrue); // 방장이 0번
    expect((starts.first['names'] as List).length, 3);
    final host = tester.widget<DavinciScreen>(find.byType(DavinciScreen));
    expect(host.players, 3);
    expect(host.humanSeat, 0);
    expect(host.seed, 4242);
    expect(host.links!.length, 2);
    await tester.pumpWidget(const SizedBox());
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4);
  });

  testWidgets('4명 판: 방장이 손님의 수를 확인해 다른 손님들에게 전해 주고, 차례가 아닌 손님의 수는 어긋남으로 본다', (tester) async {
    await pumpHost(tester, players: 4, port: 46171, discovery: 46182);
    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 3; i++) await joinAs(tester, '손님${i + 1}', 46171, logs[i])];
    await settle(tester, rounds: 6);
    final seats = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')['side'] as int];
    final guestOfSeat = {for (var i = 0; i < 3; i++) seats[i]: i};
    final c = (tester.state(find.byType(DavinciScreen)) as dynamic).c;
    expect(c.turn, 0);

    // 방장(0번)의 수 → 모든 손님에게
    expect(c.draw(0), isTrue);
    await settle(tester, rounds: 3);
    for (final l in logs) {
      expect(l.where((m) => m['t'] == 'move').single, {'t': 'move', 'i': 0, 'mv': [0, 0]});
    }
    // 방장이 틀리게 맞혀서 차례를 1번 자리로 넘긴다
    final target = c.state.rows[1] as List<int>;
    final actual = dvNumber(target[0]);
    c.selectTarget(1, 0);
    expect(c.guess(dvIsJoker(target[0]) ? 0 : (actual == 11 ? 10 : actual + 1)), isTrue);
    await settle(tester, rounds: 3);
    expect(c.turn, 1);

    // 1번 자리 손님이 흰색 더미에서 뽑는다 → 방장이 받아 나머지 손님들에게 전한다
    final g1 = guestOfSeat[1]!;
    guests[g1].send({'t': 'move', 'i': 2, 'mv': [0, 1]});
    await settle(tester, rounds: 4);
    expect(c.moveCount, 3);
    for (var i = 0; i < 3; i++) {
      final moves = logs[i].where((m) => m['t'] == 'move').toList();
      if (i == g1) {
        expect(moves.length, 2); // 보낸 사람에게는 되돌려 주지 않는다 (방장이 보낸 두 수만)
      } else {
        expect(moves.last, {'t': 'move', 'i': 2, 'mv': [0, 1]});
      }
    }

    // 지금은 1번 차례인데 2번 자리 손님이 수를 보내면 어긋남
    final g2 = guestOfSeat[2]!;
    guests[g2].send({'t': 'move', 'i': 3, 'mv': [0, 0]});
    await settle(tester, rounds: 4);
    expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await settle(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DavinciScreen), findsNothing);
    for (final g in guests) {
      await tester.runAsync(() => g.closed.timeout(const Duration(seconds: 3)));
      expect(g.isClosed, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('4명 판: 맞히려고 고른 타일이 다른 기기에도 알려지고, 방장은 손님의 선택을 확인해 나머지 손님들에게 전한다', (tester) async {
    await pumpHost(tester, players: 4, port: 46173, discovery: 46184);
    final logs = [for (var i = 0; i < 3; i++) <Map<String, dynamic>>[]];
    final guests = [for (var i = 0; i < 3; i++) await joinAs(tester, '손님${i + 1}', 46173, logs[i])];
    await settle(tester, rounds: 6);
    final seats = [for (final l in logs) l.firstWhere((m) => m['t'] == 'start')['side'] as int];
    final guestOfSeat = {for (var i = 0; i < 3; i++) seats[i]: i};
    final c = (tester.state(find.byType(DavinciScreen)) as dynamic).c;

    // 방장(0번)이 뽑은 뒤 상대 타일을 고르면 모든 손님에게 간다
    expect(c.draw(0), isTrue);
    await settle(tester, rounds: 3);
    c.selectTarget(1, 0);
    await settle(tester, rounds: 3);
    for (final l in logs) {
      expect(l.where((m) => m['t'] == 'sel').single, {'t': 'sel', 'a': 0, 's': 1, 'n': 0});
    }
    c.selectTarget(1, 0); // 같은 타일을 다시 눌러 고름을 푼다
    await settle(tester, rounds: 3);
    for (final l in logs) {
      expect(l.where((m) => m['t'] == 'sel').last, {'t': 'sel', 'a': 0, 's': -1, 'n': -1});
    }

    // 방장이 틀리게 맞혀 차례가 1번 자리로 넘어간 뒤, 그 손님의 선택은 방장 화면에 보이고 나머지 손님들에게 전해진다
    final target = c.state.rows[1] as List<int>;
    final actual = dvNumber(target[0]);
    c.selectTarget(1, 0);
    expect(c.guess(dvIsJoker(target[0]) ? 0 : (actual == 11 ? 10 : actual + 1)), isTrue);
    await settle(tester, rounds: 3);
    expect(c.turn, 1);
    final g1 = guestOfSeat[1]!;
    final mine = c.state.rows[0] as List<int>;
    final hiddenIdx = [for (var i = 0; i < mine.length; i++) if (!c.state.isRevealed(mine[i])) i].first;
    guests[g1].send({'t': 'sel', 'a': 1, 's': 0, 'n': hiddenIdx});
    await settle(tester, rounds: 4);
    expect(c.remoteSel, (actor: 1, seat: 0, index: hiddenIdx));
    expect(find.text('고민 중…'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      final sels = logs[i].where((m) => m['t'] == 'sel' && m['a'] == 1).toList();
      expect(sels.length, i == g1 ? 0 : 1, reason: '보낸 사람에게는 되돌려 주지 않고 나머지에게는 전해요');
    }

    // 차례가 아닌 손님(2번 자리)이 1번 사람인 척 보내도 무시한다
    final g2 = guestOfSeat[2]!;
    guests[g2].send({'t': 'sel', 'a': 1, 's': 0, 'n': hiddenIdx});
    await settle(tester, rounds: 4);
    expect(find.text('판이 서로 어긋났어요'), findsNothing); // (선택 소식은 잘못돼도 판을 깨지 않는다)
    expect(logs[g1].where((m) => m['t'] == 'sel' && m['a'] == 1), isEmpty);

    await tester.pumpWidget(const SizedBox());
    for (final g in guests) {
      await tester.runAsync(g.close);
    }
    await settle(tester, rounds: 4);
  });
}
