import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/prophecy/core/prophecy_rules.dart';
import 'package:tabgame/games/prophecy/data/prophecy_history.dart';
import 'package:tabgame/games/prophecy/game/prophecy_controller.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_records_tab.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_setup_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_wifi_screen.dart';
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
(ProphecyController, ProphecyController) wiredPair({int rows = 4, int cols = 4}) {
  final a = ProphecyController(mode: PlayMode.wifi, rows: rows, cols: cols, humanSide: 0);
  final b = ProphecyController(mode: PlayMode.wifi, rows: rows, cols: cols, humanSide: 1);
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
    test('두 기기가 번갈아 수를 주고받아 끝까지 두면 판과 점수가 똑같다', () {
      final (a, b) = wiredPair(rows: 5, cols: 4);
      final rng = Random(7);
      while (!a.isOver) {
        final mine = a.state.turn == 0 ? a : b;
        expect(mine.humanCanAct, isTrue);
        expect((a.state.turn == 0 ? b : a).humanCanAct, isFalse); // 상대 차례에는 못 쓴다
        final ms = mine.state.legalMoves();
        final m = ms[rng.nextInt(ms.length)];
        mine.select(moveCell(m));
        expect(mine.write(moveValue(m)), isTrue);
      }
      expect(b.isOver, isTrue);
      expect(a.state.cells, b.state.cells);
      expect(a.state.owners, b.state.owners);
      expect(a.state.scores(), b.state.scores());
      expect(a.moves, b.moves);
    });

    test('상대 차례가 아닐 때나 둘 수 없는 수는 받지 않는다', () {
      final a = ProphecyController(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0);
      // 내 차례(먼저 쓰기)에 상대의 수가 오면 어긋난 것
      expect(a.receiveMove(encodeMove(0, 1)), isFalse);
      a.select(0);
      a.write(2);
      // 상대 차례: 이미 쓴 칸, 범위 밖의 숫자는 둘 수 없다
      expect(a.receiveMove(encodeMove(0, 1)), isFalse);
      expect(a.receiveMove(encodeMove(1, 2)), isFalse); // 같은 행에 2가 이미 있다
      expect(a.receiveMove(encodeMove(5, 3)), isTrue);
      expect(a.moveCount, 2);
      // CPU·둘이서 판은 수를 받지 않는다
      final local = ProphecyController(mode: PlayMode.local2p, rows: 4, cols: 4);
      expect(local.receiveMove(encodeMove(0, 1)), isFalse);
    });

    test('되돌리기는 없고, 기권하면 판이 멈춘다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      a.select(0);
      a.write(1);
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(a.resigningSide, 0);
      expect(b.resigningSide, 1);
      expect(a.resign(), isTrue);
      expect(a.halted, isTrue);
      expect(a.humanCanAct, isFalse);
      expect(a.canResign, isFalse);
      b.opponentResigned();
      expect(b.halted, isTrue);
      expect(b.humanCanAct, isFalse);
      expect(b.receiveMove(encodeMove(3, 2)), isFalse);
    });

    test('한 판 더: 먼저/나중이 서로 바뀌고 판이 비워진다', () {
      final (a, b) = wiredPair();
      a.select(0);
      a.write(1);
      a.restart(swapSides: true);
      b.restart(swapSides: true);
      expect([a.humanSide, b.humanSide], [1, 0]);
      expect(a.moveCount, 0);
      expect(b.humanCanAct, isTrue); // 이번에는 b가 먼저 쓴다
      expect(a.humanCanAct, isFalse);
      expect(a.halted, isFalse);
    });
  });

  group('Wi‑Fi 대결 기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Wi‑Fi 대결 표시와 내 쪽이 저장되고, 이겼는지는 내 쪽으로 판단한다', () async {
      await ProphHistory.add(const ProphRecord(at: 1, vsCpu: false, online: true, rows: 5, cols: 5, score0: 9, score1: 4, winner: 0, moves: 20, human: 1));
      await ProphHistory.add(const ProphRecord(at: 2, vsCpu: false, online: true, rows: 5, cols: 5, score0: 3, score1: 3, winner: null, moves: 20, human: 0));
      final list = await ProphHistory.load();
      expect(list.length, 2);
      expect(list[1].online, isTrue);
      expect(list[1].onlineWon, isFalse); // 먼저 쓴 쪽이 이겼는데 나는 나중 쪽
      expect(list[0].onlineWon, isNull);
      expect(list[1].humanWon, isNull); // (CPU 대결이 아니다)
      expect(const ProphRecord(at: 3, vsCpu: false, rows: 4, cols: 4, score0: 1, score1: 0, winner: 0, moves: 3).online, isFalse);
    });

    testWidgets('기록 보드에 Wi‑Fi 대결 결과가 이겼어요/졌어요로 보이고, 둘이서 요약은 따로 센다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const ProphRecord(at: 1760000000000, vsCpu: false, online: true, rows: 5, cols: 5, score0: 12, score1: 7, winner: 0, moves: 25, human: 0),
        const ProphRecord(at: 1760000100000, vsCpu: false, online: true, rows: 4, cols: 4, score0: 2, score1: 9, winner: 1, moves: 16, human: 0),
        const ProphRecord(at: 1760000200000, vsCpu: false, rows: 4, cols: 4, score0: 6, score1: 3, winner: 0, moves: 16),
      ];
      SharedPreferences.setMockInitialValues({'prophecy.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: ProphecyRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.textContaining('Wi‑Fi'), findsWidgets);
      expect(find.text('플레이어 1 승'), findsOneWidget); // 한 기기에서 둘이서 한 판만 센다
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
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
      final c = ProphecyController(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0);
      await tester.pumpWidget(await app(ProphecyScreen(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsOneWidget);

      c.select(5);
      expect(c.write(3), isTrue);
      await settle(tester, rounds: 3);
      expect(received.single, {'t': 'move', 'i': 0, 'm': encodeMove(5, 3)});
      expect(find.textContaining('상대 차례'), findsOneWidget);
      expect(find.textContaining('상대가 쓰기를 기다리고'), findsOneWidget);
      expect(c.humanCanAct, isFalse);

      theirs.send({'t': 'move', 'i': 1, 'm': encodeMove(0, 1)});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.state.cells[0], 1);
      expect(c.state.owners[0], 1);
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
      final c = ProphecyController(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProphecyScreen(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      // 내 차례인데 상대가 수를 보냈다
      theirs.send({'t': 'move', 'i': 0, 'm': encodeMove(0, 1)});
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600)); // 화면이 닫히는 동안
      expect(find.byType(ProphecyScreen), findsNothing);
      expect(c.moveCount, 0); // 어긋난 수는 두지 않았다
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록되고, 상대와 연결이 끊기면 알리고 기록하지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final resign in [true, false]) {
        final (mine, theirs) = (await tester.runAsync(connectionPair))!;
        final c = ProphecyController(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 1);
        await tester.pumpWidget(await app(ProphecyScreen(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 1, controller: c, link: mine)));
        await settle(tester, rounds: 2);
        theirs.send({'t': 'move', 'i': 0, 'm': encodeMove(0, 2)});
        await settle(tester, rounds: 3);
        expect(c.moveCount, 1);
        if (resign) {
          theirs.send(const {'t': 'resign'});
          await settle(tester, rounds: 4);
          expect(find.text('상대가 기권했어요'), findsOneWidget);
          expect(c.halted, isTrue);
          final h = (await tester.runAsync(ProphHistory.load))!;
          expect(h.length, 1);
          expect(h.single.online, isTrue);
          expect(h.single.resigned, isTrue);
          expect(h.single.winner, 1); // 내가(나중 쪽) 이겼다
          expect(h.single.human, 1);
          await tester.tap(find.text('메뉴로'));
          await settle(tester, rounds: 2);
        } else {
          await tester.runAsync(theirs.close);
          await settle(tester, rounds: 6);
          expect(find.text('상대와 연결이 끊겼어요'), findsWidgets);
          expect(find.text('나가기'), findsOneWidget);
          final h = (await tester.runAsync(ProphHistory.load))!;
          expect(h, isEmpty); // 끊긴 판은 기록되지 않는다 (app()이 저장소를 비우고 시작하니 앞 판의 기록도 없다)
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(theirs.close);
        await settle(tester, rounds: 1);
      }
    });

    testWidgets('끝까지 두면 결과가 기록되고, 서로 한 판 더를 누르면 먼저/나중이 바뀌어 새 판이 시작된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = ProphecyController(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0);
      await tester.pumpWidget(await app(ProphecyScreen(mode: PlayMode.wifi, rows: 4, cols: 4, humanSide: 0, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      // 상대 기기의 판 (같은 규칙으로 따라간다)
      final mirror = ProphState(4, 4);
      final rng = Random(11);
      while (!c.isOver) {
        if (c.state.turn == 0) {
          final ms = c.state.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          c.select(moveCell(m));
          expect(c.write(moveValue(m)), isTrue);
          mirror.play(moveCell(m), moveValue(m));
        } else {
          final ms = mirror.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          mirror.play(moveCell(m), moveValue(m));
          theirs.send({'t': 'move', 'i': c.moveCount, 'm': m});
          await settle(tester, rounds: 2);
          expect(c.moveCount, mirror.turns, reason: '상대의 수가 반영돼야 해요');
        }
      }
      await tester.pump(const Duration(milliseconds: 3000));
      expect(mirror.scores(), c.state.scores());
      final h = (await tester.runAsync(ProphHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.human, 0);
      expect(h.single.winner, c.state.winner);
      expect(find.text('한 판 더'), findsOneWidget);

      // 내가 먼저 누르면 상대를 기다린다
      await tester.tap(find.text('한 판 더'));
      await settle(tester, rounds: 2);
      expect(find.text('상대를 기다려요…'), findsOneWidget);
      expect(c.isOver, isTrue);
      // 상대도 누르면 새 판: 쪽이 바뀐다
      theirs.send(const {'t': 'again'});
      await settle(tester, rounds: 3);
      expect(c.isOver, isFalse);
      expect(c.moveCount, 0);
      expect(c.humanSide, 1);
      expect(find.textContaining('상대 차례'), findsOneWidget); // 이제 상대가 먼저
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });
  });

  group('방 만들기·찾기 화면', () {
    testWidgets('첫 화면에서 방 만들기를 누르면 표 크기와 내 쪽을 고르고 "방 열기"로 진행한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const ProphecyWifiScreen()));
      await settle(tester, rounds: 2);
      expect(find.text('방 만들기'), findsOneWidget);
      expect(find.text('방 찾기'), findsOneWidget);
      await tester.tap(find.text('방 만들기'));
      await settle(tester, rounds: 3);
      expect(find.byType(ProphecySetupScreen), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('먼저 쓰기'), findsOneWidget);
      expect(find.text('나중에 쓰기'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방을 열면 기다리는 화면이 뜨고, 방 찾기 화면에서 그 방이 보여 들어가면 두 화면이 같은 판으로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 45951;
      // 방 만든 기기 화면과 찾는 기기 화면을 한 앱 안에 차례로 올려 본다 (같은 기기 안에서 127.0.0.1로 이어진다)
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
        builder: (_) => const ProphecyHostScreen(rows: 4, cols: 5, hostSide: 1, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('표 4×5'), findsOneWidget);
      expect(find.text('내가 나중에 쓰기'), findsOneWidget);

      // 방 찾기: 같은 기기라 127.0.0.1로 물어본다
      final joined = Completer<void>();
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const ProphecyJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )).then((_) => joined.complete()));
      // 방 목록에 방이 뜰 때까지 기다린다 (기기가 바쁠 때는 늦게 뜬다)
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.text('표 4×5'), findsWidgets);
      expect(find.text('들어가기'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      // 두 화면이 모두 열릴 때까지 기다린다 (기기가 바쁠 때는 늦다)
      for (var i = 0; i < 60 && find.byType(ProphecyScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      // 들어간 쪽(손님)은 먼저 쓰는 쪽, 방을 연 쪽은 나중 쪽으로 시작한다 (hostSide: 1)
      final screens = tester.widgetList<ProphecyScreen>(find.byType(ProphecyScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSide).toSet(), {0, 1});
      expect(screens.every((s) => s.rows == 4 && s.cols == 5 && s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);

      // 화면을 모두 닫는다
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
