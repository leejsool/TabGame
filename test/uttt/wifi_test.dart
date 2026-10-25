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
import 'package:tabgame/games/uttt/core/uttt_rules.dart';
import 'package:tabgame/games/uttt/data/uttt_history.dart';
import 'package:tabgame/games/uttt/game/uttt_controller.dart';
import 'package:tabgame/games/uttt/ui/uttt_records_tab.dart';
import 'package:tabgame/games/uttt/ui/uttt_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_setup_screen.dart';
import 'package:tabgame/games/uttt/ui/uttt_wifi_screen.dart';
import 'package:tabgame/games/uttt/uttt_entry.dart';
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

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접).
(UtttController, UtttController) wiredPair() {
  final a = UtttController(mode: PlayMode.wifi, humanSide: kX);
  final b = UtttController(mode: PlayMode.wifi, humanSide: kO);
  a.onLocalMove = (m) => expect(b.receiveMove(m), isTrue);
  b.onLocalMove = (m) => expect(a.receiveMove(m), isTrue);
  return (a, b);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('Wi‑Fi 대결 판 진행', () {
    test('두 기기가 번갈아 수를 주고받아 끝까지 두면 판이 똑같고 결과도 같다', () {
      for (var seed = 1; seed <= 5; seed++) {
        final (a, b) = wiredPair();
        final rng = Random(seed);
        while (!a.isOver) {
          final mine = a.state.turn == kX ? a : b;
          final other = identical(mine, a) ? b : a;
          expect(mine.humanCanAct, isTrue);
          expect(other.humanCanAct, isFalse); // 상대 차례에는 못 둔다
          final ms = mine.state.legalMoves();
          expect(mine.play(ms[rng.nextInt(ms.length)]), isTrue);
        }
        expect(b.isOver, isTrue);
        expect(a.moves, b.moves);
        expect(a.outcome, b.outcome);
        expect(a.state.bigX, b.state.bigX);
        expect(a.state.bigO, b.state.bigO);
      }
    });

    test('상대 차례가 아닐 때나 둘 수 없는 수는 받지 않는다', () {
      final a = UtttController(mode: PlayMode.wifi, humanSide: kX);
      expect(a.receiveMove(40), isFalse); // 내 차례에 상대의 수가 오면 어긋난 것
      expect(a.play(40), isTrue); // 한가운데 판의 한가운데 칸
      expect(a.receiveMove(40), isFalse); // 이미 둔 칸
      expect(a.receiveMove(0), isFalse); // 한가운데 판에서 둬야 하는데 다른 판
      expect(a.receiveMove(36), isTrue); // 한가운데 판 (40 → 4번 판) 의 다른 칸
      expect(a.moveCount, 2);
      // CPU·둘이서 판은 수를 받지 않는다
      expect(UtttController(mode: PlayMode.local2p).receiveMove(0), isFalse);
    });

    test('되돌리기는 없고, 기권하면 판이 멈춘다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      expect(a.play(40), isTrue);
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(a.resigningSide, kX);
      expect(b.resigningSide, kO);
      expect(a.resign(), isTrue);
      expect(a.halted, isTrue);
      expect(a.humanCanAct, isFalse);
      expect(a.canResign, isFalse);
      b.opponentResigned();
      expect(b.halted, isTrue);
      expect(b.humanCanAct, isFalse);
      expect(b.receiveMove(36), isFalse);
    });

    test('한 판 더: 먼저 시작하는 쪽이 서로 바뀌고 판이 비워진다 (내 표시는 그대로)', () {
      final (a, b) = wiredPair();
      a.play(40);
      a.restart();
      b.restart();
      expect([a.humanSide, b.humanSide], [kX, kO]);
      expect(a.moveCount, 0);
      expect(b.humanCanAct, isTrue); // 이번에는 O가 먼저 둔다
      expect(a.humanCanAct, isFalse);
      expect(a.halted, isFalse);
    });
  });

  group('Wi‑Fi 대결 기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Wi‑Fi 대결 표시와 내 표시가 저장되고, 이겼는지는 내 표시로 판단한다', () async {
      await UtttHistory.add(const UtttRecord(at: 1, vsCpu: false, online: true, winner: kX, moves: 40, human: kO));
      await UtttHistory.add(const UtttRecord(at: 2, vsCpu: false, online: true, winner: null, moves: 81, human: kX));
      final list = await UtttHistory.load();
      expect(list.length, 2);
      expect(list[1].online, isTrue);
      expect(list[1].onlineWon, isFalse);
      expect(list[0].onlineWon, isNull);
      expect(list[1].humanWon, isNull);
      expect(const UtttRecord(at: 3, vsCpu: false, winner: kX, moves: 3).online, isFalse);
    });

    testWidgets('기록 보드에 Wi‑Fi 대결 결과가 이겼어요/졌어요로 보이고, X/O 승 요약은 따로 센다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const UtttRecord(at: 1760000000000, vsCpu: false, online: true, winner: kX, moves: 33, human: kX),
        const UtttRecord(at: 1760000100000, vsCpu: false, online: true, winner: kX, moves: 41, human: kO),
        const UtttRecord(at: 1760000200000, vsCpu: false, winner: kO, moves: 25),
      ];
      SharedPreferences.setMockInitialValues({'uttt.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: UtttRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
      expect(find.text('O 승'), findsOneWidget);
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
      final c = UtttController(mode: PlayMode.wifi, humanSide: kX);
      await tester.pumpWidget(await app(UtttScreen(mode: PlayMode.wifi, humanSide: kX, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsOneWidget);

      expect(c.play(40), isTrue);
      await settle(tester, rounds: 3);
      expect(received.single, {'t': 'move', 'i': 0, 'm': 40});
      expect(find.textContaining('상대 차례'), findsOneWidget);
      expect(c.humanCanAct, isFalse);
      expect(c.play(36), isFalse); // 상대 차례에는 못 둔다

      theirs.send({'t': 'move', 'i': 1, 'm': 36});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.state.turn, kX);
      expect(find.textContaining('내 차례'), findsOneWidget);
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
      final c = UtttController(mode: PlayMode.wifi, humanSide: kX);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => UtttScreen(mode: PlayMode.wifi, humanSide: kX, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'm': 40}); // 내 차례인데 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(UtttScreen), findsNothing);
      expect(c.moveCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록되고, 상대와 연결이 끊기면 알리고 기록하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final resign in [true, false]) {
        final (mine, theirs) = (await tester.runAsync(connectionPair))!;
        final c = UtttController(mode: PlayMode.wifi, humanSide: kO);
        await tester.pumpWidget(await app(UtttScreen(mode: PlayMode.wifi, humanSide: kO, controller: c, link: mine)));
        await settle(tester, rounds: 2);
        theirs.send({'t': 'move', 'i': 0, 'm': 40});
        await settle(tester, rounds: 3);
        expect(c.moveCount, 1);
        if (resign) {
          theirs.send(const {'t': 'resign'});
          await settle(tester, rounds: 4);
          expect(find.text('상대가 기권했어요'), findsOneWidget);
          expect(c.halted, isTrue);
          final h = (await tester.runAsync(UtttHistory.load))!;
          expect(h.length, 1);
          expect(h.single.online, isTrue);
          expect(h.single.resigned, isTrue);
          expect(h.single.winner, kO); // 내가(O) 이겼다
          expect(h.single.human, kO);
          await tester.tap(find.text('메뉴로'));
          await settle(tester, rounds: 2);
        } else {
          await tester.runAsync(theirs.close);
          await settle(tester, rounds: 6);
          expect(find.text('상대와 연결이 끊겼어요'), findsWidgets);
          expect(find.text('나가기'), findsOneWidget);
          final h = (await tester.runAsync(UtttHistory.load))!;
          expect(h, isEmpty); // 끊긴 판은 기록되지 않는다 (app()이 저장소를 비우고 시작한다)
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(theirs.close);
        await settle(tester, rounds: 1);
      }
    });

    testWidgets('끝까지 두면 결과가 기록되고, 서로 한 판 더를 누르면 먼저 시작하는 쪽이 바뀌어 새 판이 시작된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = UtttController(mode: PlayMode.wifi, humanSide: kX);
      await tester.pumpWidget(await app(UtttScreen(mode: PlayMode.wifi, humanSide: kX, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      // 상대 기기의 판 (같은 규칙으로 따라간다)
      final mirror = UttState();
      var played = 0;
      final rng = Random(5);
      while (!c.isOver) {
        if (c.state.turn == kX) {
          final ms = c.state.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          expect(c.play(m), isTrue);
          mirror.apply(m);
          played++;
        } else {
          final ms = mirror.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          mirror.apply(m);
          theirs.send({'t': 'move', 'i': c.moveCount, 'm': m});
          played++;
          await settle(tester, rounds: 2);
          expect(c.moveCount, played, reason: '상대의 수가 반영돼야 해요');
        }
      }
      expect(mirror.outcome, c.outcome);
      final h = (await tester.runAsync(UtttHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.human, kX);
      // 잠시 뒤 결과 창이 뜬다
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('한 판 더'), findsWidgets);

      // 내가 먼저 누르면 상대를 기다린다
      await tester.tap(find.widgetWithText(FilledButton, '한 판 더').last); // 결과 창의 단추 (맨 위)
      await settle(tester, rounds: 3);
      expect(find.text('상대를 기다려요…'), findsOneWidget);
      expect(c.isOver, isTrue);
      // 상대도 누르면 새 판: 먼저 시작하는 쪽이 바뀐다 (이번에는 O가 먼저)
      theirs.send(const {'t': 'again'});
      await settle(tester, rounds: 3);
      expect(c.isOver, isFalse);
      expect(c.moveCount, 0);
      expect(c.humanSide, kX);
      expect(c.state.turn, kO);
      expect(find.textContaining('상대 차례'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });
  });

  group('방 만들기·찾기 화면', () {
    test('등록: 궁극 틱택토에 Wi‑Fi 모드가 있고, 진입점이 첫 화면을 연다', () {
      final g = allGames.firstWhere((g) => g.id == 'ultimate_tictactoe');
      expect(g.modes, contains(PlayMode.wifi));
      expect(PlayMode.wifi.label, contains('Wi‑Fi'));
    });

    testWidgets('첫 화면에서 방 만들기를 누르면 내 표시를 고르고 "방 열기"로 진행한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(Builder(builder: (context) => buildUttt(context, PlayMode.wifi))));
      await settle(tester, rounds: 2);
      expect(find.byType(UtttWifiScreen), findsOneWidget);
      expect(find.text('방 만들기'), findsOneWidget);
      expect(find.text('열려 있는 방'), findsOneWidget); // (첫 화면이 곧 방 찾기 화면)
      await tester.tap(find.text('방 만들기'));
      await settle(tester, rounds: 3);
      expect(find.byType(UtttHostSetupScreen), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방을 열면 기다리는 화면이 뜨고, 방 찾기 화면에서 그 방이 보여 들어가면 두 화면이 서로 다른 표시로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 45961;
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
        builder: (_) => const UtttHostScreen(hostSide: kO, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('내가 O (나중에 시작)'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const UtttJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester, rounds: 6);
      expect(find.text('궁극 틱택토'), findsWidgets);
      expect(find.text('들어가기'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      await settle(tester, rounds: 12);
      final screens = tester.widgetList<UtttScreen>(find.byType(UtttScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSide).toSet(), {kX, kO});
      expect(screens.every((s) => s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
