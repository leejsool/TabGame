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
import 'package:tabgame/games/dandelion/core/dandelion_rules.dart';
import 'package:tabgame/games/dandelion/dandelion_entry.dart';
import 'package:tabgame/games/dandelion/data/dandelion_history.dart';
import 'package:tabgame/games/dandelion/game/dandelion_controller.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_records_tab.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_setup_screen.dart';
import 'package:tabgame/games/dandelion/ui/dandelion_wifi_screen.dart';
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

/// 지금 차례인 쪽이 [m]을 둔다 (민들레면 꽃 심기, 바람이면 방향).
bool play(DandelionController c, int m) => c.state.turn == Role.dandelion ? c.plant(m) : c.blow(WindDir.values[m]);

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접).
(DandelionController, DandelionController) wiredPair() {
  final a = DandelionController(mode: PlayMode.wifi, humanRole: Role.dandelion);
  final b = DandelionController(mode: PlayMode.wifi, humanRole: Role.wind);
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
    test('두 기기가 번갈아 꽃을 심고 바람을 불며 끝까지 가면 초원과 결과가 똑같다', () {
      for (var seed = 1; seed <= 6; seed++) {
        final (a, b) = wiredPair();
        final rng = Random(seed);
        while (!a.isOver) {
          final mine = a.state.turn == a.humanRole ? a : b;
          final other = identical(mine, a) ? b : a;
          expect(mine.humanCanAct, isTrue);
          expect(other.humanCanAct, isFalse); // 상대 차례에는 못 둔다
          final ms = mine.state.legalMoves();
          expect(play(mine, ms[rng.nextInt(ms.length)]), isTrue);
        }
        expect(b.isOver, isTrue);
        expect(a.moves, b.moves);
        expect(a.state.cells, b.state.cells);
        expect(a.winner, b.winner);
      }
    });

    test('상대 차례가 아닐 때나 둘 수 없는 수는 받지 않는다', () {
      final a = DandelionController(mode: PlayMode.wifi, humanRole: Role.dandelion);
      expect(a.receiveMove(3), isFalse); // 내 차례(민들레)에 상대의 수가 오면 어긋난 것
      expect(a.plant(12), isTrue);
      // 이제 바람 차례: 범위 밖 번호는 둘 수 없다
      expect(a.receiveMove(-1), isFalse);
      expect(a.receiveMove(8), isFalse);
      expect(a.receiveMove(0), isTrue); // 위쪽 바람
      expect(a.moveCount, 2);
      // 다시 내 차례에 오는 수는 어긋난 것
      expect(a.receiveMove(1), isFalse);
      expect(a.plant(3), isTrue);
      // 이미 분 방향(위)은 다시 못 분다
      expect(a.receiveMove(0), isFalse);
      expect(a.receiveMove(2), isTrue);
      // 둘이서·CPU 판은 수를 받지 않는다
      expect(DandelionController(mode: PlayMode.local2p).receiveMove(0), isFalse);
    });

    test('바람 쪽도 상대(민들레)의 꽃을 받는다. 이미 꽃이 있는 칸의 꽃은 받지 않는다', () {
      final b = DandelionController(mode: PlayMode.wifi, humanRole: Role.wind);
      expect(b.receiveMove(12), isTrue);
      expect(b.humanCanAct, isTrue);
      expect(b.blow(WindDir.right), isTrue);
      expect(b.receiveMove(12), isFalse, reason: '이미 꽃이 핀 칸');
      expect(b.receiveMove(25), isFalse, reason: '초원 밖');
      expect(b.receiveMove(11), isTrue); // 씨앗이 앉은 칸에는 꽃을 심을 수 있다
    });

    test('되돌리기는 없고, 기권하면 판이 멈춘다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      expect(a.plant(12), isTrue);
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(a.resigningRole, Role.dandelion);
      expect(b.resigningRole, Role.wind);
      expect(a.resign(), isTrue);
      expect(a.halted, isTrue);
      expect(a.humanCanAct, isFalse);
      expect(a.canResign, isFalse);
      b.opponentResigned();
      expect(b.halted, isTrue);
      expect(b.humanCanAct, isFalse);
      expect(b.receiveMove(0), isFalse);
    });

    test('한 판 더: 민들레와 바람이 서로 바뀌고 초원이 비워진다', () {
      final (a, b) = wiredPair();
      a.plant(12);
      a.restart(swapRoles: true);
      b.restart(swapRoles: true);
      expect([a.humanRole, b.humanRole], [Role.wind, Role.dandelion]);
      expect(a.moveCount, 0);
      expect(b.humanCanAct, isTrue); // 이번에는 b가 민들레라 먼저 심는다
      expect(a.humanCanAct, isFalse);
      expect(a.halted, isFalse);
      expect(b.plant(7), isTrue);
      expect(a.moveCount, 1);
    });
  });

  group('Wi‑Fi 대결 기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Wi‑Fi 대결 표시와 내 쪽이 저장되고, 이겼는지는 내 쪽으로 판단한다', () async {
      await DandelionHistory.add(const DandelionRecord(at: 1, vsCpu: false, online: true, winner: Role.wind, moves: 14, empties: 2, human: Role.dandelion));
      final list = await DandelionHistory.load();
      expect(list.single.online, isTrue);
      expect(list.single.onlineWon, isFalse);
      expect(list.single.humanWon, isNull);
      expect(list.single.human, Role.dandelion);
      expect(const DandelionRecord(at: 2, vsCpu: false, winner: Role.wind, moves: 3, empties: 1).online, isFalse);
    });

    testWidgets('기록 보드에 Wi‑Fi 대결 결과가 이겼어요/졌어요로 보이고, 민들레·바람 승 요약과 따로 센다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const DandelionRecord(at: 1760000000000, vsCpu: false, online: true, winner: Role.dandelion, moves: 13, empties: 0, human: Role.dandelion),
        const DandelionRecord(at: 1760000100000, vsCpu: false, online: true, winner: Role.wind, moves: 14, empties: 2, human: Role.dandelion),
        const DandelionRecord(at: 1760000200000, vsCpu: false, winner: Role.wind, moves: 14, empties: 3),
      ];
      SharedPreferences.setMockInitialValues({'dandelion.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: DandelionRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
      expect(find.text('바람 승'), findsOneWidget);
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
      final c = DandelionController(mode: PlayMode.wifi, humanRole: Role.dandelion);
      await tester.pumpWidget(await app(DandelionScreen(mode: PlayMode.wifi, humanRole: Role.dandelion, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsOneWidget);

      expect(c.plant(12), isTrue);
      await settle(tester, rounds: 3);
      expect(received.single, {'t': 'move', 'i': 0, 'm': 12});
      expect(find.textContaining('상대 차례'), findsOneWidget);
      expect(find.textContaining('상대가 바람을 고르고'), findsOneWidget);
      expect(c.humanCanAct, isFalse);
      expect(c.plant(3), isFalse); // 상대 차례에는 못 둔다

      theirs.send({'t': 'move', 'i': 1, 'm': WindDir.right.index});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.state.turn, Role.dandelion);
      expect(c.state.cells[13], kSeed); // 꽃의 오른쪽으로 씨앗이 날아갔다
      expect(find.textContaining('내 차례'), findsOneWidget);
      expect(find.text('되돌리기'), findsNothing); // Wi‑Fi 대결에는 되돌리기·새 판이 없다
      expect(find.text('새 판'), findsNothing);
      expect(find.text('기권'), findsOneWidget);
      expect(find.textContaining('· 나'), findsOneWidget); // 내 칩
      expect(find.textContaining('· 상대'), findsOneWidget); // 상대 칩 (별명을 모르면 "상대")
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대의 수가 어긋나면 알리고 나간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = DandelionController(mode: PlayMode.wifi, humanRole: Role.dandelion);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DandelionScreen(mode: PlayMode.wifi, humanRole: Role.dandelion, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'm': 3}); // 내 차례인데 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DandelionScreen), findsNothing);
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
        final c = DandelionController(mode: PlayMode.wifi, humanRole: Role.wind);
        await tester.pumpWidget(await app(DandelionScreen(mode: PlayMode.wifi, humanRole: Role.wind, controller: c, link: mine)));
        await settle(tester, rounds: 2);
        theirs.send({'t': 'move', 'i': 0, 'm': 12});
        await settle(tester, rounds: 3);
        expect(c.moveCount, 1);
        if (resign) {
          theirs.send(const {'t': 'resign'});
          await settle(tester, rounds: 4);
          expect(find.text('상대가 기권했어요'), findsOneWidget);
          expect(c.halted, isTrue);
          final h = (await tester.runAsync(DandelionHistory.load))!;
          expect(h.length, 1);
          expect((h.single.online, h.single.resigned, h.single.winner, h.single.human), (true, true, Role.wind, Role.wind));
          await tester.tap(find.text('메뉴로'));
          await settle(tester, rounds: 2);
        } else {
          await tester.runAsync(theirs.close);
          await settle(tester, rounds: 6);
          expect(find.text('상대와 연결이 끊겼어요'), findsWidgets);
          expect(find.text('나가기'), findsOneWidget);
          expect((await tester.runAsync(DandelionHistory.load))!, isEmpty);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(theirs.close);
        await settle(tester, rounds: 1);
      }
    });

    testWidgets('끝까지 두면 결과가 기록되고, 서로 한 판 더를 누르면 민들레와 바람이 바뀌어 새 판이 시작된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = DandelionController(mode: PlayMode.wifi, humanRole: Role.dandelion);
      await tester.pumpWidget(await app(DandelionScreen(mode: PlayMode.wifi, humanRole: Role.dandelion, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      // 상대 기기의 판 (같은 규칙으로 따라간다)
      final mirror = DandState();
      var played = 0;
      final rng = Random(9);
      while (!c.isOver) {
        if (c.state.turn == Role.dandelion) {
          final ms = c.state.legalMoves();
          final m = ms[rng.nextInt(ms.length)];
          expect(c.plant(m), isTrue);
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
      expect(mirror.winner, c.winner);
      final h = (await tester.runAsync(DandelionHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.human, Role.dandelion);
      // 잠시 뒤 결과 창이 뜬다
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('한 판 더'), findsWidgets);

      // 내가 먼저 누르면 상대를 기다린다
      await tester.tap(find.widgetWithText(FilledButton, '한 판 더').last); // 결과 창의 단추 (맨 위)
      await settle(tester, rounds: 3);
      expect(find.text('상대를 기다려요…'), findsOneWidget);
      expect(c.isOver, isTrue);
      // 상대도 누르면 새 판: 민들레와 바람이 바뀐다 (이번에는 내가 바람)
      theirs.send(const {'t': 'again'});
      await settle(tester, rounds: 3);
      expect(c.isOver, isFalse);
      expect(c.moveCount, 0);
      expect(c.humanRole, Role.wind);
      expect(find.textContaining('상대 차례'), findsOneWidget); // 이번에는 상대가 먼저 꽃을 심는다
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });
  });

  group('방 만들기·찾기 화면', () {
    test('등록: 민들레에 Wi‑Fi 모드가 있고, 학사모와 함께 이제 모든 교과학습 게임이 Wi‑Fi를 쓴다', () {
      final g = allGames.firstWhere((g) => g.id == 'dandelion');
      expect(g.modes, contains(PlayMode.wifi));
      // (바둑돌 옮기기·공원 길찾기는 멘토링 교재용 게임이라 Wi‑Fi 없이 교과학습만 있다)
      for (final lesson in allGames.where((g) => g.hasLesson && !{'stones', 'park'}.contains(g.id))) {
        expect(lesson.modes, contains(PlayMode.wifi), reason: '${lesson.title}에 Wi‑Fi 모드가 없어요');
      }
    });

    testWidgets('첫 화면에서 방 만들기를 누르면 내 쪽을 고르고 "방 열기"로 진행한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(Builder(builder: (context) => buildDandelion(context, PlayMode.wifi))));
      await settle(tester, rounds: 2);
      expect(find.byType(DandelionWifiScreen), findsOneWidget);
      await tester.tap(find.text('방 만들기'));
      await settle(tester, rounds: 3);
      expect(find.byType(DandelionHostSetupScreen), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('민들레'), findsWidgets);
      expect(find.text('바람'), findsWidgets);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('방을 열면 기다리는 화면이 뜨고, 방 찾기에서 들어가면 두 화면이 서로 다른 쪽(민들레/바람)으로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 45981;
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
        builder: (_) => DandelionHostScreen(hostRole: Role.wind.index, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('내가 바람 (씨앗을 날려요)'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const DandelionJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester, rounds: 6);
      expect(find.text('들어가기'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      await settle(tester, rounds: 12);
      final screens = tester.widgetList<DandelionScreen>(find.byType(DandelionScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanRole).toSet(), {Role.dandelion, Role.wind});
      expect(screens.every((s) => s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
