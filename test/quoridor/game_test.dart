import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/quoridor/core/quoridor_ai.dart';
import 'package:tabgame/games/quoridor/core/quoridor_rules.dart';
import 'package:tabgame/games/quoridor/data/quoridor_history.dart';
import 'package:tabgame/games/quoridor/game/quoridor_controller.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_board.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_records_tab.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_setup_screen.dart';
import 'package:tabgame/games/quoridor/ui/quoridor_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

int cell(int r, int c) => r * kBoard + c;

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
(QuoridorController, QuoridorController) wiredPair() {
  final a = QuoridorController(mode: PlayMode.wifi, humanSeat: 0);
  final b = QuoridorController(mode: PlayMode.wifi, humanSeat: 1);
  a.onLocalMove = (m) => expect(b.receiveMove(m, index: a.moveCount - 1), isTrue);
  b.onLocalMove = (m) => expect(a.receiveMove(m, index: b.moveCount - 1), isTrue);
  return (a, b);
}

/// 판 위의 칸 [cellNo]의 화면 좌표 (QBoardView 안).
Offset cellPoint(WidgetTester tester, int cellNo) {
  final rect = tester.getRect(find.byType(QBoardView));
  final side = min(rect.width, rect.height);
  final left = rect.center.dx - side / 2, top = rect.center.dy - side / 2;
  final margin = side * 0.035;
  final unit = (side - margin * 2) / (kBoard + (kBoard - 1) * 0.24);
  final pitch = unit * 1.24;
  return Offset(left + margin + (cellNo % kBoard) * pitch + unit / 2, top + margin + (cellNo ~/ kBoard) * pitch + unit / 2);
}

/// 격자점 (r, c)의 화면 좌표.
Offset anchorPoint(WidgetTester tester, int r, int c) {
  final rect = tester.getRect(find.byType(QBoardView));
  final side = min(rect.width, rect.height);
  final left = rect.center.dx - side / 2, top = rect.center.dy - side / 2;
  final margin = side * 0.035;
  final unit = (side - margin * 2) / (kBoard + (kBoard - 1) * 0.24);
  final gap = unit * 0.24;
  return Offset(left + margin + (c + 1) * unit + c * gap + gap / 2, top + margin + (r + 1) * unit + r * gap + gap / 2);
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

  group('컨트롤러', () {
    test('한 기기: 칸을 눌러 말을 옮기면 차례가 넘어가고, 되돌릴 수 있다', () {
      final c = QuoridorController(mode: PlayMode.local2p);
      expect(c.targets..sort(), [cell(7, 4), cell(8, 3), cell(8, 5)]);
      expect(c.tapCell(cell(5, 5)), isFalse); // 갈 수 없는 칸
      expect(c.tapCell(cell(7, 4)), isTrue);
      expect(c.turn, 1);
      expect(c.state.pawn[0], cell(7, 4));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.turn, 0);
      expect(c.state.pawn[0], cell(8, 4));
      expect(c.canUndo, isFalse);
    });

    test('벽 세우기: 모드를 켜고 자리를 골라 확정하면 세워진다', () {
      final c = QuoridorController(mode: PlayMode.local2p);
      expect(c.targets, isNotEmpty);
      c.setWallMode(true);
      expect(c.targets, isEmpty); // 벽 고르는 중에는 말 이동 점이 없다
      expect(c.canConfirmWall, isFalse);
      c.pickWall(3, 3);
      expect(c.canConfirmWall, isTrue);
      c.toggleWallOrient();
      expect(c.wallOrientPick, 1);
      expect(c.confirmWall(), isTrue);
      expect(c.state.vWallAt(3, 3), isTrue);
      expect(c.state.wallsLeft[0], 9);
      expect(c.wallMode, isFalse);
      expect(c.turn, 1);
      // 겹치는 자리는 확정할 수 없다
      c.setWallMode(true);
      c.pickWall(4, 3);
      expect(c.canConfirmWall, isFalse);
      expect(c.confirmWall(), isFalse);
      expect(c.turn, 1);
    });

    test('벽이 떨어지면 벽 모드를 켤 수 없다', () {
      final c = QuoridorController(mode: PlayMode.local2p, players: 4);
      c.state.wallsLeft[0] = 0;
      c.setWallMode(true);
      expect(c.wallMode, isFalse);
    });

    test('4명 한 기기: 차례가 4명을 돌고 기권은 없다', () {
      final c = QuoridorController(mode: PlayMode.local2p, players: 4);
      c.tapCell(cell(7, 4));
      c.tapCell(cell(4, 1));
      c.tapCell(cell(1, 4));
      c.tapCell(cell(4, 7));
      expect(c.turn, 0);
      expect(c.moveCount, 4);
      expect(c.canResign, isFalse);
      expect(QuoridorController(mode: PlayMode.local2p).canResign, isFalse); // (한 수도 안 뒀다)
    });

    test('CPU 대결: 내 차례가 아니면 못 둔다, 되돌리면 내 마지막 수까지 돌아간다', () async {
      final c = QuoridorController(mode: PlayMode.vsCpu, players: 4, humanSeat: 1, level: QLevel.easy);
      c.start();
      expect(c.humanCanAct, isFalse); // 0번(CPU)이 먼저
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(c.turn, 1);
      expect(c.humanCanAct, isTrue);
      expect(c.tapCell(c.targets.first), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 3000)); // CPU 2, 3, 0번이 차례로
      expect(c.turn, 1);
      expect(c.moveCount, 5);
      c.undo();
      expect(c.moveCount, 1);
      expect(c.turn, 1);
      c.dispose();
    });
  });

  group('Wi‑Fi 대결 판 진행', () {
    test('두 기기가 번갈아 수를 주고받아 끝까지 두면 판이 똑같다', () {
      final (a, b) = wiredPair();
      final rng = Random(3);
      var turns = 0;
      while (!a.isOver && turns < 400) {
        turns++;
        final mine = a.humanCanAct ? a : b;
        expect((a.humanCanAct ? b : a).humanCanAct, isFalse); // 상대 차례에는 못 둔다
        final m = QAi.choose(mine.state, QLevel.normal, rng);
        if (isWallMove(m)) {
          mine.setWallMode(true);
          mine.wallOrientPick = wallOrient(m);
          mine.pickWall(wallRow(m), wallCol(m));
          expect(mine.confirmWall(), isTrue);
        } else {
          expect(mine.tapCell(m), isTrue);
        }
      }
      expect(a.isOver, isTrue);
      expect(b.isOver, isTrue);
      expect(a.state.winner, b.state.winner);
      expect(a.state.pawn, b.state.pawn);
      expect(a.state.h, b.state.h);
      expect(a.state.v, b.state.v);
      expect(a.moves, b.moves);
    });

    test('상대 차례가 아니거나 둘 수 없는 수는 받지 않는다', () {
      final a = QuoridorController(mode: PlayMode.wifi, humanSeat: 0);
      expect(a.receiveMove(cell(1, 4)), isFalse); // 내 차례에 상대의 수
      a.tapCell(cell(7, 4));
      expect(a.receiveMove(cell(5, 5)), isFalse); // 갈 수 없는 칸
      expect(a.receiveMove(cell(1, 4), index: 5), isFalse); // 번호가 어긋남
      expect(a.receiveMove(wallMove(0, 7, 4), index: 1), isTrue);
      final local = QuoridorController(mode: PlayMode.local2p);
      expect(local.receiveMove(cell(7, 4)), isFalse);
    });

    test('되돌리기는 없고, 기권하면 판이 멈춘다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      a.tapCell(cell(7, 4));
      expect(a.canUndo, isFalse);
      expect(b.canUndo, isFalse);
      expect(b.resigningSeat, 1);
      expect(b.resign(), isTrue);
      expect(b.halted, isTrue);
      expect(b.humanCanAct, isFalse);
      a.opponentResigned();
      expect(a.halted, isTrue);
      expect(a.humanCanAct, isFalse);
    });

    test('한 판 더: 자리가 서로 바뀌고 판이 비워진다', () {
      final (a, b) = wiredPair();
      a.tapCell(cell(7, 4));
      a.restart(rotate: true);
      b.restart(rotate: true);
      expect([a.humanSeat, b.humanSeat], [1, 0]);
      expect(a.moveCount, 0);
      expect(b.humanCanAct, isTrue);
      expect(a.humanCanAct, isFalse);
    });
  });

  group('기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장하고 불러온다', () async {
      await QuoridorHistory.add(const QuoridorRecord(at: 1, vsCpu: true, players: 4, winner: 0, moves: 50, human: 0, level: QLevel.hard));
      await QuoridorHistory.add(const QuoridorRecord(at: 2, vsCpu: false, online: true, players: 2, winner: 0, moves: 30, human: 1, resigned: true));
      await QuoridorHistory.add(const QuoridorRecord(at: 3, vsCpu: false, players: 4, winner: 2, moves: 60));
      final list = await QuoridorHistory.load();
      expect(list.length, 3);
      expect(list[0].humanWon, isNull); // 한 기기
      expect(list[1].humanWon, isFalse);
      expect(list[1].resigned, isTrue);
      expect(list[2].level, QLevel.hard);
      expect(list[2].humanWon, isTrue);
    });

    testWidgets('기록 보드에 CPU 전적과 한 기기·Wi‑Fi 결과가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const QuoridorRecord(at: 1760000000000, vsCpu: true, players: 2, winner: 0, moves: 40, human: 0, level: QLevel.normal),
        const QuoridorRecord(at: 1760000100000, vsCpu: false, online: true, players: 2, winner: 1, moves: 50, human: 0),
        const QuoridorRecord(at: 1760000200000, vsCpu: false, players: 4, winner: 3, moves: 70),
      ];
      SharedPreferences.setMockInitialValues({'quoridor.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: QuoridorRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · CPU 보통'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(find.text('플레이어 4 승리'), findsOneWidget);
      expect(find.text('플레이어 4 승'), findsOneWidget); // 4명이 한 판이 있어서 네 칸
      expect(find.text('Wi‑Fi 대결 승'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('화면', () {
    testWidgets('한 기기: 칸을 눌러 말을 옮기고, 내 앞의 나무막대를 끌어다 놓아 돌린 뒤 체크로 벽을 세운다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = QuoridorController(mode: PlayMode.local2p);
      await tester.pumpWidget(await app(QuoridorScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('플레이어 1 차례'), findsWidgets);
      await tester.tapAt(cellPoint(tester, cell(7, 4)));
      await settle(tester, rounds: 2);
      expect(c.state.pawn[0], cell(7, 4));
      expect(find.textContaining('플레이어 2 차례'), findsWidgets);

      // 각자 앞에 막대 더미가 있고, 지금 차례인 사람(2번 = 위쪽)의 더미만 끌 수 있다
      expect(find.byKey(const ValueKey('wall-stock-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('wall-stock-1')), findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('wall-stock-1'))));
      await g.moveBy(const Offset(0, 30));
      await g.moveTo(anchorPoint(tester, 5, 4));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect(c.wallMode, isTrue);
      expect(c.wallRowPick, 5);
      expect(c.wallColPick, 4);
      expect(c.wallOrientPick, 0);
      expect(find.byIcon(Icons.rotate_90_degrees_cw_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.textContaining('벽을 세울까요'), findsOneWidget);

      // 돌린 뒤 체크로 확정
      await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw_rounded));
      await settle(tester, rounds: 1);
      expect(c.wallOrientPick, 1);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await settle(tester, rounds: 2);
      expect(c.state.vWallAt(5, 4), isTrue);
      expect(c.state.wallsLeft[1], 9);
      expect(c.wallMode, isFalse);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.textContaining('플레이어 1 차례'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('놓아 둔 막대는 끌어서 옮길 수 있고, 판 밖으로 끌어내거나 X를 누르면 취소된다 (막대는 줄지 않는다)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = QuoridorController(mode: PlayMode.local2p);
      await tester.pumpWidget(await app(QuoridorScreen(controller: c)));
      await settle(tester, rounds: 2);
      final stock = tester.getCenter(find.byKey(const ValueKey('wall-stock-0')));
      final g = await tester.startGesture(stock);
      await g.moveBy(const Offset(0, -30));
      await g.moveTo(anchorPoint(tester, 3, 3));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect([c.wallRowPick, c.wallColPick], [3, 3]);
      // 판 위에서 다른 자리로 끌어 옮긴다
      final g2 = await tester.startGesture(anchorPoint(tester, 3, 3));
      await g2.moveBy(const Offset(10, 10));
      await g2.moveTo(anchorPoint(tester, 6, 2));
      await tester.pump(const Duration(milliseconds: 100));
      await g2.up();
      await settle(tester, rounds: 2);
      expect([c.wallRowPick, c.wallColPick], [6, 2]);
      expect(c.wallMode, isTrue);
      // 판 밖으로 끌어내면 취소
      final g3 = await tester.startGesture(anchorPoint(tester, 6, 2));
      await g3.moveBy(const Offset(10, 10));
      await g3.moveTo(const Offset(790, 20));
      await tester.pump(const Duration(milliseconds: 100));
      await g3.up();
      await settle(tester, rounds: 2);
      expect(c.wallMode, isFalse);
      expect(c.state.wallsLeft[0], 10);
      // 다시 놓고 X로 취소
      final g4 = await tester.startGesture(stock);
      await g4.moveBy(const Offset(0, -30));
      await g4.moveTo(anchorPoint(tester, 2, 2));
      await tester.pump(const Duration(milliseconds: 100));
      await g4.up();
      await settle(tester, rounds: 2);
      expect(c.wallMode, isTrue);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, rounds: 2);
      expect(c.wallMode, isFalse);
      expect(c.state.wallsLeft[0], 10);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('세울 수 없는 자리에서는 체크가 눌리지 않고, 막대가 다 떨어진 더미는 끌 수 없다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = QuoridorController(mode: PlayMode.local2p);
      c.state.apply(wallMove(0, 3, 3)); // 이미 있는 벽 (0번이 세웠다고 치자)
      await tester.pumpWidget(await app(QuoridorScreen(controller: c)));
      await settle(tester, rounds: 2);
      // 1번(위쪽) 차례: 같은 자리에 겹치는 막대를 놓아 본다
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('wall-stock-1'))));
      await g.moveBy(const Offset(0, 30));
      await g.moveTo(anchorPoint(tester, 3, 3));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect(c.wallMode, isTrue);
      expect(c.canConfirmWall, isFalse);
      await tester.tap(find.byIcon(Icons.check_rounded));
      await settle(tester, rounds: 1);
      expect(c.state.wallsLeft[1], 10); // 세워지지 않았다
      expect(c.wallMode, isTrue);
      expect(find.textContaining('겹치거나 엇갈려요'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, rounds: 1);
      // 막대가 없는 더미는 끌 수 없다
      c.state.wallsLeft[1] = 0;
      c.setWallMode(false);
      c.notifyListeners();
      await settle(tester, rounds: 1);
      final g2 = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('wall-stock-1'))));
      await g2.moveBy(const Offset(0, 30));
      await g2.moveTo(anchorPoint(tester, 5, 5));
      await tester.pump(const Duration(milliseconds: 100));
      await g2.up();
      await settle(tester, rounds: 1);
      expect(c.wallMode, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4명 판이 좁은 폰에서도 넘치지 않고, 칩이 네 개 보인다', (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = QuoridorController(mode: PlayMode.local2p, players: 4);
      await tester.pumpWidget(await app(QuoridorScreen(controller: c)));
      await settle(tester, rounds: 2);
      for (var i = 1; i <= 4; i++) {
        expect(find.text('플레이어 $i'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('설정 화면: 인원(2/4)과 난이도를 고르고 시작하면 판이 열린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const QuoridorSetupScreen(mode: PlayMode.vsCpu)));
      await settle(tester, rounds: 2);
      expect(find.text('몇 명이 할까요?'), findsOneWidget);
      await tester.tap(find.text('4명'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await settle(tester, rounds: 3);
      final screen = tester.widget<QuoridorScreen>(find.byType(QuoridorScreen));
      expect(screen.players, 4);
      expect(screen.mode, PlayMode.vsCpu);
      expect(find.text('CPU 3'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 20); // CPU가 두는 동안
    });

    testWidgets('Wi‑Fi 방 설정 화면에는 인원(2/4)과 내 순서 선택이 있고 "방 열기"가 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const QuoridorSetupScreen(mode: PlayMode.wifi)));
      await settle(tester, rounds: 2);
      expect(find.text('몇 명이 할까요?'), findsOneWidget);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('4번째'), findsNothing); // 2명이면 순서는 둘뿐
      await tester.tap(find.text('4명'));
      await settle(tester, rounds: 2);
      expect(find.text('4번째'), findsOneWidget);
      await tester.tap(find.text('4번째'));
      await settle(tester, rounds: 1);
      await tester.tap(find.text('2명'));
      await settle(tester, rounds: 1);
      expect(find.text('4번째'), findsNothing);
    });
  });

  group('Wi‑Fi 화면', () {
    testWidgets('내 수가 상대에게 가고, 상대의 수가 판에 나타난다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final received = <Map<String, dynamic>>[];
      theirs.messages.listen(received.add);
      final c = QuoridorController(mode: PlayMode.wifi, humanSeat: 0);
      await tester.pumpWidget(await app(QuoridorScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsWidgets);

      await tester.tapAt(cellPoint(tester, cell(7, 4)));
      await settle(tester, rounds: 3);
      expect(received.single, {'t': 'move', 'i': 0, 'm': cell(7, 4)});
      expect(find.textContaining('기다리는 중'), findsOneWidget);
      expect(c.humanCanAct, isFalse);

      theirs.send({'t': 'move', 'i': 1, 'm': cell(1, 4)});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.state.pawn[1], cell(1, 4));
      expect(find.textContaining('내 차례'), findsWidgets);
      expect(find.text('새 판'), findsNothing); // Wi‑Fi 대결에는 되돌리기·새 판이 없다
      expect(find.text('되돌리기'), findsNothing);
      expect(find.text('기권'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = QuoridorController(mode: PlayMode.wifi, humanSeat: 1);
      await tester.pumpWidget(await app(QuoridorScreen(mode: PlayMode.wifi, humanSeat: 1, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      theirs.send({'t': 'move', 'i': 0, 'm': cell(7, 4)});
      await settle(tester, rounds: 3);
      theirs.send(const {'t': 'resign'});
      await settle(tester, rounds: 4);
      expect(find.text('상대가 기권했어요'), findsOneWidget);
      final h = (await tester.runAsync(QuoridorHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.resigned, isTrue);
      expect(h.single.humanWon, isTrue);
      await tester.tap(find.text('메뉴로'));
      await settle(tester, rounds: 2);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('규칙에 안 맞는 상대의 수가 오면 알리고 나간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = QuoridorController(mode: PlayMode.wifi, humanSeat: 0);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => QuoridorScreen(mode: PlayMode.wifi, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'm': cell(1, 4)}); // 내 차례에 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(QuoridorScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('방을 열고 찾아 들어가면 두 화면이 반대 자리로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 46041;
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
        builder: (_) => const QuoridorHostScreen(hostSide: 1, gamePort: 0, discoveryPort: discovery),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('내가 두 번째로 시작'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const QuoridorJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      // 방 목록에 방이 뜰 때까지 기다린다 (기기가 바쁠 때는 늦게 뜬다)
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.text('쿼리도 · 2명'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      // 두 화면이 모두 열릴 때까지 기다린다 (기기가 바쁠 때는 늦다)
      for (var i = 0; i < 60 && find.byType(QuoridorScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<QuoridorScreen>(find.byType(QuoridorScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSeat).toSet(), {0, 1});
      expect(screens.every((s) => s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
