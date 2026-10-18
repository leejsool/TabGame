import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';
import 'package:tabgame/games/goblet/data/goblet_history.dart';
import 'package:tabgame/games/goblet/game/goblet_controller.dart';
import 'package:tabgame/games/goblet/goblet_entry.dart';
import 'package:tabgame/games/goblet/ui/goblet_records_tab.dart';
import 'package:tabgame/games/goblet/ui/goblet_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_setup_screen.dart';
import 'package:tabgame/games/goblet/ui/goblet_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

import '../support/preview_kit.dart';

Future<Widget> app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<(LanConnection, LanConnection)> connectionPair() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final accepted = server.first;
  final client = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
  final srv = await accepted;
  await server.close();
  return (LanConnection(client), LanConnection(srv));
}

/// 컨트롤러로 한 수 둔다. place: from = -1.
bool mv(GobbletController c, int from, int to, int size) {
  final id = from < 0 ? c.reserveFront(c.turn, size) : c.topAt(from);
  if (id == null) return false;
  c.select(id);
  return c.dropPiece(id, to);
}

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접). a가 빨강(먼저), b가 파랑.
(GobbletController, GobbletController) wiredPair() {
  final a = GobbletController(mode: PlayMode.wifi, humanTeam: Team.red);
  final b = GobbletController(mode: PlayMode.wifi, humanTeam: Team.blue);
  a.onLocalMove = (m) => expect(b.receiveMove(m, index: a.moveCount - 1), isTrue);
  b.onLocalMove = (m) => expect(a.receiveMove(m, index: b.moveCount - 1), isTrue);
  return (a, b);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('Wi‑Fi 대결 판 진행', () {
    test('두 기기가 번갈아 수를 주고받아 끝까지 두면 판과 결과가 똑같다', () {
      for (var seed = 0; seed < 5; seed++) {
        final (a, b) = wiredPair();
        final rng = Random(seed);
        var n = 0;
        while (!a.isOver && n++ < 300) {
          final mine = a.turn == a.humanTeam ? a : b;
          expect(mine.humanCanAct, isTrue);
          expect((identical(mine, a) ? b : a).humanCanAct, isFalse); // 상대 차례에는 못 둔다
          final ms = mine.board.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          expect(mv(mine, m.from, m.to, m.size), isTrue);
        }
        expect(b.isOver, a.isOver);
        expect(a.board.owners, b.board.owners);
        expect(a.loc, b.loc);
        expect(a.result?.winner, b.result?.winner);
        expect(a.result?.kind, b.result?.kind);
      }
    });

    test('상대 차례가 아니거나 둘 수 없는 수는 받지 않는다', () {
      final a = GobbletController(mode: PlayMode.wifi, humanTeam: Team.red);
      // 내 차례(빨강 먼저)에 상대의 수가 오면 어긋난 것
      expect(a.receiveMove(GobbletMove.place(1, 0)), isFalse);
      expect(mv(a, -1, 4, 2), isTrue);
      // 상대 차례: 번호가 어긋나거나, 둘 수 없는 수(가운데의 더 큰 말 위에 작은 말)는 안 된다
      expect(a.receiveMove(GobbletMove.place(1, 0), index: 5), isFalse);
      expect(a.receiveMove(GobbletMove.place(1, 4)), isFalse);
      expect(a.receiveMove(GobbletMove.place(3, 4), index: 1), isTrue);
      expect(a.moveCount, 2);
      // CPU·둘이서 판은 수를 받지 않는다
      final local = GobbletController(mode: PlayMode.local2p);
      expect(local.receiveMove(GobbletMove.place(1, 0)), isFalse);
    });

    test('되돌리기는 없고, 기권하면 판이 끝난다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      expect(mv(a, -1, 0, 1), isTrue);
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(a.resigningTeam, Team.red);
      expect(b.resigningTeam, Team.blue);
      expect(b.resign(), isTrue);
      expect(b.result!.winner, Team.red);
      expect(b.result!.resigned, isTrue);
      a.opponentResigned();
      expect(a.result!.winner, Team.red);
      expect(a.result!.resigned, isTrue);
      expect(a.humanCanAct, isFalse);
    });

    test('한 판 더: 먼저 시작하는 팀이 서로 바뀌고 판이 비워진다 (내 팀은 그대로)', () {
      final (a, b) = wiredPair();
      expect(mv(a, -1, 0, 1), isTrue);
      a.restart();
      b.restart();
      expect([a.humanTeam, b.humanTeam], [Team.red, Team.blue]);
      expect(a.moveCount, 0);
      expect(b.humanCanAct, isTrue); // 이번에는 파랑이 먼저
      expect(a.humanCanAct, isFalse);
    });
  });

  group('Wi‑Fi 대결 기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Wi‑Fi 대결 표시와 내 팀이 저장되고, 이겼는지는 내 팀으로 판단한다', () async {
      await GobbletHistory.add(const GobbletRecord(at: 1, vsCpu: false, online: true, winner: Team.red, moves: 12, human: Team.blue));
      await GobbletHistory.add(const GobbletRecord(at: 2, vsCpu: false, online: true, winner: null, moves: 20, human: Team.red));
      final list = await GobbletHistory.load();
      expect(list.length, 2);
      expect(list[1].online, isTrue);
      expect(list[1].onlineWon, isFalse);
      expect(list[0].onlineWon, isNull);
      expect(list[1].humanWon, isNull); // (CPU 대결이 아니다)
      expect(const GobbletRecord(at: 3, vsCpu: false, winner: Team.red, moves: 3).online, isFalse);
    });

    testWidgets('기록 보드에 Wi‑Fi 대결 결과가 이겼어요/졌어요로 보이고, 팀 승 요약은 따로 센다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const GobbletRecord(at: 1760000000000, vsCpu: false, online: true, winner: Team.red, moves: 10, human: Team.red),
        const GobbletRecord(at: 1760000100000, vsCpu: false, online: true, winner: Team.red, moves: 14, human: Team.blue),
        const GobbletRecord(at: 1760000200000, vsCpu: false, winner: Team.blue, moves: 9),
      ];
      SharedPreferences.setMockInitialValues({'goblet.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: GobbletRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
      expect(find.text('파랑팀 승'), findsOneWidget); // 한 기기에서 둘이서 한 판만 센다
      expect(tester.takeException(), isNull);
    });
  });

  group('Wi‑Fi 대결 화면', () {
    testWidgets('내 수가 상대에게 가고, 상대의 수가 판에 나타난다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final received = <Map<String, dynamic>>[];
      theirs.messages.listen(received.add);
      final c = GobbletController(mode: PlayMode.wifi, humanTeam: Team.red);
      await tester.pumpWidget(await app(GobbletScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsWidgets);

      expect(mv(c, -1, 4, 2), isTrue);
      await settle(tester, rounds: 3);
      expect(received.single, {'t': 'move', 'i': 0, 'f': -1, 'to': 4, 's': 2});
      expect(find.textContaining('상대가 두기를'), findsOneWidget);
      expect(c.humanCanAct, isFalse);

      theirs.send({'t': 'move', 'i': 1, 'f': -1, 'to': 0, 's': 3});
      await settle(tester, rounds: 4);
      expect(c.moveCount, 2);
      expect(c.board.owners[0 * 3 + 2], 2); // 파랑이 0번 칸에 큰 말을 놓았다
      expect(find.textContaining('내 차례'), findsWidgets);
      expect(find.text('되돌리기'), findsNothing); // Wi‑Fi 대결에는 되돌리기·새 판이 없다
      expect(find.text('새 판'), findsNothing);
      expect(find.text('기권'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대의 수가 어긋나면 알리고 나간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = GobbletController(mode: PlayMode.wifi, humanTeam: Team.red);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => GobbletScreen(mode: PlayMode.wifi, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'f': -1, 'to': 0, 's': 1}); // 내 차례인데 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(GobbletScreen), findsNothing);
      expect(c.moveCount, 0); // 어긋난 수는 두지 않았다
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = GobbletController(mode: PlayMode.wifi, humanTeam: Team.blue);
      await tester.pumpWidget(await app(GobbletScreen(mode: PlayMode.wifi, humanTeam: Team.blue, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      theirs.send({'t': 'move', 'i': 0, 'f': -1, 'to': 4, 's': 1});
      await settle(tester, rounds: 3);
      theirs.send(const {'t': 'resign'});
      await settle(tester, rounds: 4);
      await tester.pump(const Duration(milliseconds: 1500)); // 결과 창이 뜨는 시간
      expect(find.text('상대가 기권했어요'), findsOneWidget);
      final h = (await tester.runAsync(GobbletHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.resigned, isTrue);
      expect(h.single.winner, Team.blue); // 내가 이겼다
      expect(h.single.human, Team.blue);
      await tester.tap(find.text('메뉴로'));
      await settle(tester, rounds: 2);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대와 연결이 끊기면 알리고 기록하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = GobbletController(mode: PlayMode.wifi, humanTeam: Team.blue);
      await tester.pumpWidget(await app(GobbletScreen(mode: PlayMode.wifi, humanTeam: Team.blue, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      theirs.send({'t': 'move', 'i': 0, 'f': -1, 'to': 4, 's': 1});
      await settle(tester, rounds: 3);
      await tester.runAsync(theirs.close);
      await settle(tester, rounds: 6);
      expect(find.text('상대와 연결이 끊겼어요'), findsWidgets);
      expect(find.text('나가기'), findsOneWidget);
      final h = (await tester.runAsync(GobbletHistory.load))!;
      expect(h, isEmpty);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('끝까지 두면 결과가 기록되고, 서로 한 판 더를 누르면 먼저 시작하는 팀이 바뀌어 새 판이 시작된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = GobbletController(mode: PlayMode.wifi, humanTeam: Team.red);
      await tester.pumpWidget(await app(GobbletScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      // 상대 기기의 판 (같은 규칙으로 따라간다)
      final mirror = GobbletBoard();
      mirror.turn = Team.red.owner;
      // 빨강: 0,1,2 칸에 큰·중간·작은 말 / 파랑: 3,4 칸에 작은 말을 놓는다 → 빨강 가로 줄 완성
      final reds = [(-1, 0, 3), (-1, 1, 3), (-1, 2, 2)];
      final blues = [(-1, 3, 1), (-1, 4, 1)];
      for (var i = 0; i < 3; i++) {
        final r = reds[i];
        expect(mv(c, r.$1, r.$2, r.$3), isTrue);
        mirror.apply(GobbletMove.place(r.$3, r.$2));
        if (i < 2) {
          final b = blues[i];
          mirror.apply(GobbletMove.place(b.$3, b.$2));
          theirs.send({'t': 'move', 'i': c.moveCount, 'f': b.$1, 'to': b.$2, 's': b.$3});
          await settle(tester, rounds: 3);
          expect(c.moveCount, mirror.owners.where((o) => o != 0).length, reason: '상대의 수가 반영돼야 해요');
        }
      }
      expect(c.isOver, isTrue);
      expect(c.result!.winner, Team.red);
      await settle(tester, rounds: 2);
      await tester.pump(const Duration(milliseconds: 1600)); // 결과 창
      final h = (await tester.runAsync(GobbletHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.human, Team.red);
      expect(h.single.winner, Team.red);
      expect(find.text('이겼어요! 🎉'), findsWidgets);

      // 내가 먼저 누르면 상대를 기다린다
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '한 판 더')));
      await settle(tester, rounds: 3);
      expect(find.text('상대를 기다려요…'), findsOneWidget); // (아래 막대의 단추 글자)
      expect(c.isOver, isTrue);
      // 상대도 누르면 새 판: 파랑이 먼저
      theirs.send(const {'t': 'again'});
      await settle(tester, rounds: 3);
      expect(c.isOver, isFalse);
      expect(c.moveCount, 0);
      expect(c.humanTeam, Team.red); // 내 팀은 그대로
      expect(c.turn, Team.blue);
      expect(c.humanCanAct, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });
  });

  group('방 만들기·찾기 화면', () {
    test('등록: 고블렛에 Wi‑Fi 모드가 있고, 진입점이 첫 화면을 연다', () {
      final g = allGames.firstWhere((g) => g.id == 'goblet_gobblers');
      expect(g.modes, contains(PlayMode.wifi));
      expect(g.hasWifi, isTrue);
    });

    testWidgets('진입점: Wi‑Fi는 첫 화면, CPU는 설정 화면', (tester) async {
      await tester.pumpWidget(await app(Builder(builder: (context) => buildGoblet(context, PlayMode.wifi))));
      await settle(tester, rounds: 2);
      expect(find.byType(GobbletWifiScreen), findsOneWidget);
      await tester.pumpWidget(await app(Builder(builder: (context) => buildGoblet(context, PlayMode.vsCpu))));
      await settle(tester, rounds: 2);
      expect(find.byType(GobbletSetupScreen), findsOneWidget);
    });

    testWidgets('첫 화면에서 방 만들기를 누르면 내 팀을 고르고 "방 열기"로 진행한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const GobbletWifiScreen()));
      await settle(tester, rounds: 2);
      expect(find.text('방 만들기'), findsOneWidget);
      expect(find.text('방 찾기'), findsOneWidget);
      await tester.tap(find.text('방 만들기'));
      await settle(tester, rounds: 3);
      expect(find.byType(GobbletHostSetupScreen), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('빨강팀'), findsOneWidget);
      expect(find.text('파랑팀'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방을 열고 찾아 들어가면 두 화면이 서로 다른 팀으로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 46051;
      final navKey = GlobalKey<NavigatorState>();
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(
          navigatorKey: navKey,
          theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
          home: const Scaffold(body: SizedBox()),
        ),
      ));
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const GobbletHostScreen(hostTeam: 1, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('나는 파랑팀 (나중에 시작)'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const GobbletJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      // 방 목록에 방이 뜰 때까지 기다린다 (기기가 바쁠 때는 늦게 뜬다)
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.text('고블렛 고블러스'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      for (var i = 0; i < 60 && find.byType(GobbletScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<GobbletScreen>(find.byType(GobbletScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanTeam).toSet(), {Team.red, Team.blue});
      expect(screens.every((s) => s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
