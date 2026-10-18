import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_wifi_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_wifi_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_wifi_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_wifi_screen.dart';
import 'package:tabgame/games/uttt/core/uttt_rules.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';
import 'package:tabgame/net/lan_rejoin_flow.dart';
import 'package:tabgame/net/lan_stall_overlay.dart';

import '../support/preview_kit.dart';

/// 2인용 같은 Wi‑Fi 게임 다섯 개가 모두 같은 방식으로: 상대가 앱을 끄면 방장이 CPU에게 맡기고, 상대가 표를 들고 돌아오면 자리를 되찾는다.
class _Game {
  const _Game(this.name, this.lanId, this.host, this.screen, this.resume);

  final String name;
  final String lanId;
  final Widget Function(int port, int discovery) host;
  final Type screen;
  final Widget? Function(Map<String, dynamic>, LanConnection) resume;
}

final _games = [
  _Game('궁극 틱택토', 'ultimate_tictactoe', (p, d) => UtttHostScreen(hostSide: kX, gamePort: p, discoveryPort: d), UtttScreen, utttResume),
  _Game('민들레', 'dandelion', (p, d) => DandelionHostScreen(hostRole: 0, gamePort: p, discoveryPort: d), DandelionScreen, dandelionResume),
  _Game('예언', 'prophecy', (p, d) => ProphecyHostScreen(rows: 5, cols: 5, hostSide: 0, gamePort: p, discoveryPort: d), ProphecyScreen, prophecyResume),
  _Game('고블렛 고블러스', 'goblet_gobblers', (p, d) => GobbletHostScreen(hostTeam: 0, gamePort: p, discoveryPort: d), GobbletScreen, gobbletResume),
  _Game('콩나물', 'sprouts', (p, d) => SproutsHostScreen(dots: 3, hostSide: 0, gamePort: p, discoveryPort: d), SproutsScreen, sproutsResume),
];

Future<void> settle(WidgetTester tester, {int rounds = 6, int ms = 40}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  for (var i = 0; i < _games.length; i++) {
    final g = _games[i];
    final port = 46100 + i * 2, discovery = 46101 + i * 2;

    testWidgets('${g.name}: 상대가 앱을 끄면 방장이 CPU에게 맡기고, 상대가 표를 들고 돌아오면 자리를 되찾아 같은 판이 열린다', (tester) async {
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
          home: g.host(port, discovery),
        ),
      ));
      await settle(tester, rounds: 4);

      final log = <Map<String, dynamic>>[];
      final guest = (await tester.runAsync(() => LanConnection.connect('127.0.0.1', port)))!;
      guest.messages.listen(log.add);
      guest.send({'t': 'hello', 'game': g.lanId, 'nick': '손님'});
      await settle(tester, rounds: 8);
      final start = log.firstWhere((m) => m['t'] == 'start');
      expect(start['rejoin'], isA<Map>(), reason: '시작할 때 다시 들어오기 표를 받아야 해요');
      final c = (tester.state(find.byType(g.screen)) as dynamic).c;
      expect(c.cpuCover, isFalse);

      // 손님이 앱을 껐다
      await tester.runAsync(guest.close);
      await settle(tester, rounds: 5);
      expect(find.textContaining('손님 님이 나갔어요'), findsOneWidget);
      expect(find.text('CPU가 대신하기'), findsOneWidget);
      expect(find.text('이 판 끝내기'), findsOneWidget);

      // 방장이 CPU에게 맡긴다
      await tester.tap(find.text('CPU가 대신하기'));
      await settle(tester, rounds: 3);
      expect(c.cpuCover, isTrue);
      expect(find.textContaining('CPU가 대신하고 있어요'), findsOneWidget);

      // 손님이 표를 들고 돌아온다 (방장 화면이 소식을 받도록 화면을 계속 돌리며 기다린다)
      final t = start['rejoin'] as Map;
      final ticket = RejoinTicket(
        game: g.lanId,
        roomId: t['room'] as String,
        token: t['token'] as String,
        host: '127.0.0.1',
        port: port,
        hostNick: '방장',
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );
      Future<LanRejoinResult>? pending;
      await tester.runAsync(() async {
        pending = lanRejoin(ticket, nick: '손님');
      });
      await settle(tester, rounds: 8);
      final result = (await tester.runAsync(() => pending!))!;
      expect(result.ok, isTrue, reason: '실패 까닭: ${result.fail}');
      await settle(tester, rounds: 3);
      expect(c.cpuCover, isFalse, reason: '돌아오면 CPU가 맡던 자리를 돌려줘야 해요');
      expect(find.textContaining('CPU가 대신하고 있어요'), findsNothing);
      expect(find.textContaining('나갔어요'), findsNothing);

      // 받은 판의 모습으로 이 기기의 화면이 열린다 (방장 화면을 닫기 전에 만든다)
      final restored = g.resume(result.resume!, result.conn!);
      expect(restored, isNotNull, reason: '받은 판의 모습으로 화면을 만들 수 없어요');
      await tester.pumpWidget(const SizedBox()); // 방장 화면을 닫는다 (곧 연결이 끊긴다는 소식이 온다)
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: restored!),
      ));
      await tester.pump();
      expect(find.byType(g.screen), findsOneWidget);
      final back = (tester.state(find.byType(g.screen)) as dynamic).c;
      expect(back.online, isTrue);
      expect(back.moveCount, c.moveCount);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(result.conn!.close);
      await settle(tester, rounds: 4);
    });
  }
}
