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
import 'package:tabgame/games/rummikub/core/rummikub_ai.dart';
import 'package:tabgame/games/rummikub/core/rummikub_rules.dart';
import 'package:tabgame/games/rummikub/data/rummikub_history.dart';
import 'package:tabgame/games/rummikub/game/rummikub_controller.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_records_tab.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_screen.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_setup_screen.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_tiles.dart';
import 'package:tabgame/games/rummikub/ui/rummikub_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

int t(int color, int number) => tileId(color, number);

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

/// 정해 둔 손으로 시작하는 컨트롤러 (내가 0번 자리).
RummikubController fixedController({PlayMode mode = PlayMode.vsCpu, List<int>? rack, int humanSeat = 0}) {
  final c = RummikubController(animate: false, mode: mode, players: 2, humanSeat: humanSeat, seed: 3);
  if (rack != null) {
    c.state.racks[humanSeat]
      ..clear()
      ..addAll(rack);
    c.hand = [...rack];
    c.sortHand(byColor: true);
  }
  return c;
}

Finder tileFinder(int id) => find.byWidgetPredicate((w) => w is RkTile && w.id == id);

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접).
(RummikubController, RummikubController) wiredPair({int seed = 9}) {
  final a = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 0, seed: seed);
  final b = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 1, seed: seed);
  a.onLocalMove = (m) => expect(b.receiveMove({'t': 'move', ...m}), isTrue);
  b.onLocalMove = (m) => expect(a.receiveMove({'t': 'move', ...m}), isTrue);
  return (a, b);
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
    test('타일을 골라 새 묶음으로 옮기고 끝내면 판에 올라간다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4), t(0, 1)]);
      for (final id in [t(0, 10), t(1, 10), t(2, 10)]) {
        c.toggleSelect(id);
      }
      expect(c.selected.length, 3);
      c.moveTiles(c.selected.toList());
      expect(c.work.length, 1);
      expect(c.rackTiles.length, 2);
      expect(c.changed, isTrue);
      expect(c.error, isNull);
      expect(c.canEnd, isTrue);
      expect(c.endTurn(), isTrue);
      expect(c.state.table.length, 1);
      expect(c.state.racks[0].length, 2);
      expect(c.turn, 1);
      expect(c.hand.length, 2);
    });

    test('30점이 안 되면 끝낼 수 없고 이유가 나온다', () {
      final c = fixedController(rack: [t(0, 2), t(1, 2), t(2, 2), t(3, 4)]);
      c.moveTiles([t(0, 2), t(1, 2), t(2, 2)]);
      expect(c.error, PlayError.needPoints);
      expect(c.endTurn(), isFalse);
      expect(c.notice, PlayError.needPoints.message);
      expect(c.turn, 0);
    });

    test('올바르지 않은 묶음은 안 되고, "처음으로"로 되돌린다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      c.moveTiles([t(0, 10), t(1, 10), t(3, 4)]);
      expect(c.error, PlayError.badSet);
      c.reset();
      expect(c.work, isEmpty);
      expect(c.rackTiles.length, 4);
    });

    test('같은 묶음에 타일을 더하고, 이번 차례에 올린 타일만 손으로 돌려받는다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 10), t(0, 1)]);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      c.moveTiles([t(3, 10)], to: c.work.first);
      expect(c.work.length, 1);
      expect(c.work.first.length, 4);
      c.returnToHand([t(3, 10)]);
      expect(c.work.first.length, 3);
      expect(c.rackTiles.contains(t(3, 10)), isTrue);
      c.endTurn();
      // 상대 차례를 넘기고 내 차례: 이미 판에 있던 타일은 손으로 돌릴 수 없다
      c.state.applyDraw();
      c.sortHand(byColor: true);
      c.moveTiles([t(0, 1)]);
      c.returnToHand([t(0, 10)]);
      expect(c.work.expand((s) => s).contains(t(0, 10)), isTrue);
    });

    test('타일 뽑기: 만진 것은 버려지고 한 장이 손에 들어오고 차례가 넘어간다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10)]);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      final before = c.state.poolCount;
      var sent = <String, dynamic>{};
      c.onLocalMove = (m) => sent = m;
      c.draw();
      expect(c.state.poolCount, before - 1);
      expect(c.hand.length, 4);
      expect(c.lastDrawn, isNotNull);
      expect(c.work, isEmpty);
      expect(c.turn, 1);
      expect(sent, {'i': 0, 'draw': 1, 'pick': before - 1}); // 고르지 않으면 맨 뒤 한 장
    });

    test('내 차례가 아니면 만질 수 없다', () {
      final c = fixedController(humanSeat: 1);
      final id = c.rackTiles.first;
      c.toggleSelect(id);
      expect(c.selected, isEmpty);
      c.moveTiles([id]);
      expect(c.work, isEmpty);
      c.draw();
      expect(c.moveCount, 0);
    });
  });

  group('녹색 판 자리와 자석', () {
    test('끌어다 놓은 자리가 유지되고, 가까운 묶음에는 자석처럼 붙고, 먼 곳에는 새 묶음이 된다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 10), t(0, 1), t(1, 2)]);
      c.layoutSets(10, 8);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      expect(c.layoutSets(10, 8).first, const Offset(0, 0));
      // 묶음 바로 옆에 놓으면 붙는다 (틈이 0.9칸 이내)
      c.dropTiles([t(3, 10)], const Offset(4.0, 0));
      expect(c.work.length, 1);
      expect(c.work.first.length, 4);
      // 멀리 놓으면 그 자리에 새 묶음
      c.dropTiles([t(0, 1)], const Offset(0, 4));
      expect(c.work.length, 2);
      expect(c.layoutSets(10, 8)[1].dy, closeTo(4, 0.5));
      // 묶음이 바뀌어도 (타일 하나가 빠져도) 남은 묶음은 자리를 지킨다
      final before = c.layoutSets(10, 8).first;
      c.moveToAuto([t(3, 10)]);
      expect(c.layoutSets(10, 8).first, before);
    });

    test('묶음 통째로 끌어다 놓으면 새 자리로 옮겨지고, 다른 묶음 옆이면 합쳐진다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 5), t(0, 6), t(0, 7)]);
      c.layoutSets(12, 10);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      c.moveTiles([t(0, 5), t(0, 6), t(0, 7)], at: const Offset(0, 3));
      final set = [...c.work.first];
      c.dropTiles(set, const Offset(6, 6));
      expect(c.work.length, 2);
      expect(c.layoutSets(12, 10).any((a) => a.dy >= 5.5), isTrue);
      // 다른 묶음 바로 옆으로 끌면 합쳐진다
      final other = c.work.firstWhere((s) => s.contains(t(0, 5)));
      final anchor = c.anchorOf(other)!;
      c.dropTiles(c.work.firstWhere((s) => s.contains(t(0, 10))), Offset(anchor.dx + 4, anchor.dy));
      expect(c.work.length, 1);
      expect(c.work.first.length, 6);
    });

    test('내 정리판: 정렬 단추와 상관없고, 순서를 끼워 넣을 수 있고, 판에 올렸다 돌아오면 제자리로 온다', () {
      final c = fixedController(rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      c.moveToCustom([t(1, 9)]);
      c.moveToCustom([t(3, 1)]);
      expect(c.customTiles, [t(1, 9), t(3, 1)]);
      c.moveToCustom([t(2, 5)], beforeId: t(1, 9));
      expect(c.customTiles, [t(2, 5), t(1, 9), t(3, 1)]);
      c.sortHand(byColor: false);
      expect(c.customTiles, [t(2, 5), t(1, 9), t(3, 1)]); // 단추를 눌러도 그대로
      expect(c.autoTiles, [t(0, 3)]);
      // 판에 올리면 손에서 빠지고, 돌려받으면 정리판의 제자리로
      c.moveTiles([t(1, 9)]);
      expect(c.customTiles, [t(2, 5), t(3, 1)]);
      c.returnToHand([t(1, 9)]);
      expect(c.customTiles, [t(2, 5), t(1, 9), t(3, 1)]);
      // 정렬 칸으로 돌려보내면 정리판에서 빠진다
      c.moveToAuto([t(1, 9)]);
      expect(c.customTiles, [t(2, 5), t(3, 1)]);
      expect(c.autoTiles.contains(t(1, 9)), isTrue);
    });

    test('판 위 타일(처음부터 있던 것)은 정리판이나 손으로 가져올 수 없다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      c.endTurn();
      c.state.applyDraw();
      c.sortHand(byColor: true);
      c.moveToCustom([t(0, 10)]);
      expect(c.customTiles, isEmpty);
      expect(c.work.expand((x) => x).contains(t(0, 10)), isTrue);
    });
  });

  group('상대의 수 보여 주기', () {
    test('상대 기기의 수는 타일을 한 장씩 옮기는 모습을 거쳐 반영된다 (손에서 꺼낸 타일은 위에서 날아온다)', () async {
      final a = RummikubController(mode: PlayMode.wifi, humanSeat: 0, seed: 5)..stepDelay = const Duration(milliseconds: 20);
      // 상대(1번)가 낼 수 있게: 30점 그룹을 손에 쥐여 주고, 내 차례는 넘긴다
      a.state.racks[1]
        ..clear()
        ..addAll([t(0, 10), t(1, 10), t(2, 10), t(3, 3)]);
      a.draw();
      final counts = <int>[];
      final flyingSeen = <int>{};
      a.addListener(() {
        counts.add(a.work.fold<int>(0, (n, s) => n + s.length));
        flyingSeen.addAll(a.flying);
      });
      final move = {'i': a.moveCount, 'table': [[t(0, 10), t(1, 10), t(2, 10)]]};
      expect(a.receiveMove(move), isTrue);
      expect(a.animating, isTrue);
      expect(a.moveCount, 1); // 아직 반영 전
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(a.animating, isFalse);
      expect(a.moveCount, 2);
      expect(a.state.table.length, 1);
      expect(counts.toSet().length, greaterThan(1)); // 한 번에 반영되지 않고 한 장씩 늘었다
      expect(flyingSeen, {t(0, 10), t(1, 10), t(2, 10)});
      expect(a.flying, isEmpty);
      expect(a.myTurn, isTrue);
      a.dispose();
    });

    test('CPU가 둘 때도 같다: 생각이 끝나면 한 장씩 옮기는 모습을 보인 뒤 내 차례가 된다', () async {
      final c = RummikubController(mode: PlayMode.vsCpu, seed: 3)..stepDelay = const Duration(milliseconds: 15);
      // CPU(1번)가 낼 수 있는 30점 그룹을 손에 쥐여 주고, 사람 차례는 넘긴다
      c.state.racks[1]
        ..clear()
        ..addAll([t(0, 11), t(1, 11), t(2, 11), t(3, 2)]);
      c.draw();
      var sawAnimating = false;
      c.addListener(() => sawAnimating = sawAnimating || c.animating);
      for (var i = 0; i < 200 && c.turn != 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(c.turn, 0);
      expect(sawAnimating, isTrue);
      expect(c.state.table.length, 1);
      expect(c.lastActor, 1);
      c.dispose();
    });

    test('애니메이션을 끄면 (시험용) 바로 반영된다', () {
      final a = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 0, seed: 5);
      a.state.racks[1]
        ..clear()
        ..addAll([t(0, 10), t(1, 10), t(2, 10), t(3, 3)]);
      a.draw();
      expect(a.receiveMove({'i': 1, 'table': [[t(0, 10), t(1, 10), t(2, 10)]]}), isTrue);
      expect(a.moveCount, 2);
      expect(a.animating, isFalse);
      a.dispose();
    });
  });

  group('Wi‑Fi 대결 판 진행', () {
    test('두 기기가 같은 씨앗으로 시작해 수를 주고받으면 끝까지 똑같은 판이다', () {
      final (a, b) = wiredPair();
      expect(a.state.racks, b.state.racks);
      final rng = Random(5);
      var turns = 0;
      while (!a.isOver && turns < 300) {
        turns++;
        final mine = a.myTurn ? a : b;
        expect((a.myTurn ? b : a).canAct, isFalse); // 상대 차례에는 못 한다
        final plan = RkAi.plan(rack: mine.state.currentRack, table: mine.state.table, melded: mine.state.melded[mine.turn], level: RkLevel.normal, rng: rng);
        if (plan == null) {
          mine.draw();
        } else {
          mine.work = plan;
          expect(mine.endTurn(), isTrue);
        }
      }
      expect(a.isOver, isTrue);
      expect(b.isOver, isTrue);
      expect(a.state.winner, b.state.winner);
      expect(a.state.racks, b.state.racks);
      expect(a.state.table, b.state.table);
      expect(a.state.pool, b.state.pool);
      expect(a.moveCount, b.moveCount);
    });

    test('순서가 어긋났거나 규칙에 안 맞는 수는 받지 않는다', () {
      final a = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 0, seed: 4);
      expect(a.receiveMove({'i': 0, 'draw': 1}), isFalse); // 내 차례에 상대의 수
      a.draw();
      expect(a.receiveMove({'i': 0, 'draw': 1}), isFalse); // 번호가 어긋남
      expect(a.receiveMove({'i': 1, 'table': [[1, 2, 3]]}), isFalse); // 상대가 갖지 않은 타일
      expect(a.receiveMove({'i': 1, 'table': 'x'}), isFalse);
      expect(a.receiveMove({'i': 1, 'table': [[999, 998, 997]]}), isFalse);
      expect(a.receiveMove({'i': 1, 'draw': 1}), isTrue);
      final local = RummikubController(animate: false, mode: PlayMode.vsCpu, seed: 4);
      expect(local.receiveMove({'i': 0, 'draw': 1}), isFalse);
    });

    test('한 판 더: 자리가 바뀌고 두 기기가 같은 새 패를 받는다', () {
      final (a, b) = wiredPair();
      a.restart();
      b.restart();
      expect([a.humanSeat, b.humanSeat], [1, 0]);
      expect(a.seed, b.seed);
      expect(a.state.racks, b.state.racks);
      expect(b.myTurn, isTrue);
      expect(a.canAct, isFalse);
    });

    test('기권하면 판이 멈춘다 (상대가 기권해도 마찬가지)', () {
      final (a, b) = wiredPair();
      a.draw();
      expect(a.resign(), isTrue);
      expect(a.halted, isTrue);
      expect(a.canAct, isFalse);
      b.opponentResigned();
      expect(b.halted, isTrue);
      expect(b.canAct, isFalse);
    });
  });

  group('CPU 대결', () {
    test('사람이 낸 뒤 CPU가 차례를 마치고 내 차례로 돌아온다', () async {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      c.endTurn();
      expect(c.turn, 1);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(c.turn, 0);
      expect(c.lastActor, 1);
      c.dispose();
    });
  });

  group('기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장하고 불러온다', () async {
      await RkHistory.add(const RkRecord(at: 1, vsCpu: true, players: 3, winner: 0, human: 0, turns: 40, level: RkLevel.hard));
      await RkHistory.add(const RkRecord(at: 2, vsCpu: false, online: true, players: 2, winner: 0, human: 1, turns: 30, resigned: true));
      final list = await RkHistory.load();
      expect(list.length, 2);
      expect(list[0].online, isTrue);
      expect(list[0].humanWon, isFalse);
      expect(list[0].resigned, isTrue);
      expect(list[1].level, RkLevel.hard);
      expect(list[1].humanWon, isTrue);
    });

    testWidgets('기록 보드에 CPU 전적과 Wi‑Fi 결과가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const RkRecord(at: 1760000000000, vsCpu: true, players: 2, winner: 0, human: 0, turns: 30, level: RkLevel.normal),
        const RkRecord(at: 1760000100000, vsCpu: false, online: true, players: 2, winner: 1, human: 0, turns: 40),
      ];
      SharedPreferences.setMockInitialValues({'rummikub.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: RummikubRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · CPU 보통'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('화면', () {
    testWidgets('CPU 대결: 타일을 골라 새 묶음을 만들어 끝내면 CPU 차례가 되고, 이후 내 차례로 돌아온다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4), t(0, 1)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsOneWidget);
      expect(find.text('내 타일 5장'), findsOneWidget);
      expect(find.text('끝내기'), findsOneWidget);

      for (final id in [t(0, 10), t(1, 10), t(2, 10)]) {
        await tester.tap(tileFinder(id));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(c.selected.length, 3);
      await tester.tap(find.text('고른 타일로 새 묶음'));
      await settle(tester, rounds: 2);
      expect(c.work.length, 1);
      expect(find.text('내 타일 2장'), findsOneWidget);

      await tester.tap(find.text('끝내기'));
      await settle(tester, rounds: 2);
      expect(c.turn, 1);
      expect(find.textContaining('CPU 1'), findsWidgets);

      // CPU가 차례를 마칠 때까지 기다린다
      for (var i = 0; i < 40 && c.turn != 0; i++) {
        await settle(tester, rounds: 2);
      }
      expect(c.turn, 0);
      expect(find.textContaining('내 차례'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('타일을 끌어서 녹색 판 아무 데나 놓으면 그 자리에 새 묶음이 되고, 내 타일 칸으로 끌어 되돌릴 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      final table = tester.getRect(find.byType(DragTarget<List<int>>).first); // 녹색 판
      final g = await tester.startGesture(tester.getCenter(tileFinder(t(3, 4))));
      await g.moveBy(const Offset(0, -30));
      await g.moveTo(table.center);
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect(c.work.length, 1);
      expect(c.work.first, [t(3, 4)]);
      expect(c.rackTiles.length, 3);
      // 이번 차례에 올린 타일은 손(내 타일 칸)으로 끌어 되돌릴 수 있다
      final g2 = await tester.startGesture(tester.getCenter(tileFinder(t(3, 4))));
      await g2.moveBy(const Offset(0, 30));
      await g2.moveTo(tester.getCenter(find.text('내 타일 3장')));
      await tester.pump(const Duration(milliseconds: 100));
      await g2.up();
      await settle(tester, rounds: 2);
      expect(c.work, isEmpty);
      expect(c.rackTiles.length, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"내 정리판"으로 끌어 놓으면 정렬 단추와 상관없이 그 순서를 유지한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 정리판'), findsOneWidget);
      final zone = tester.getCenter(find.textContaining('내 정리판'));
      // 9를 정리판으로, 이어서 3을 9 앞으로
      final g = await tester.startGesture(tester.getCenter(tileFinder(t(1, 9))));
      await g.moveBy(const Offset(0, 20));
      await g.moveTo(zone + const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect(c.customTiles, [t(1, 9)]);
      expect(c.autoTiles.contains(t(1, 9)), isFalse);
      // 숫자 순서 단추를 눌러도 정리판의 타일은 그대로
      await tester.tap(find.text('숫자 순서'));
      await settle(tester, rounds: 1);
      expect(c.customTiles, [t(1, 9)]);
      expect(c.autoTiles, [t(3, 1), t(0, 3), t(2, 5)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('규칙이 안 맞으면 안내가 보이고, 타일 뽑기는 손을 한 장 늘린다', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 2), t(1, 2), t(2, 2), t(3, 4)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      c.moveTiles([t(0, 2), t(1, 2), t(2, 2)]);
      await settle(tester, rounds: 1);
      expect(find.text(PlayError.needPoints.message), findsOneWidget);
      await tester.tap(find.byType(RkTileBack).first); // 바닥의 타일을 한 장 고른다
      await settle(tester, rounds: 2);
      expect(find.text('타일을 뽑을까요?'), findsOneWidget); // 만져 둔 게 있어서 먼저 물어본다
      await tester.tap(find.text('뽑기'));
      await settle(tester, rounds: 2);
      expect(c.hand.length, 5);
      expect(c.turn, 1);
      for (var i = 0; i < 40 && c.turn != 0; i++) {
        await settle(tester, rounds: 2); // CPU가 차례를 마칠 때까지
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('설정 화면: CPU 수와 난이도를 고르고 시작하면 판이 열린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const RummikubSetupScreen(mode: PlayMode.vsCpu)));
      await settle(tester, rounds: 2);
      expect(find.text('CPU 몇 명과 할까요?'), findsOneWidget);
      await tester.tap(find.text('3명'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await settle(tester, rounds: 3);
      final screen = tester.widget<RummikubScreen>(find.byType(RummikubScreen));
      expect(screen.players, 4);
      expect(find.text('CPU 1'), findsWidgets);
      expect(find.text('CPU 3'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Wi‑Fi 화면', () {
    testWidgets('내 차례 결과가 상대에게 가고, 상대의 수가 판에 나타난다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final received = <Map<String, dynamic>>[];
      theirs.messages.listen(received.add);
      final c = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 0, seed: 21);
      final mirror = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 1, seed: 21);
      await tester.pumpWidget(await app(RummikubScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 차례'), findsOneWidget);
      expect(find.text('새 판'), findsNothing);

      await tester.tap(find.byType(RkTileBack).first);
      await settle(tester, rounds: 3);
      expect(received.single['t'], 'move');
      expect(received.single['i'], 0);
      expect(received.single['draw'], 1);
      expect(received.single['pick'], isA<int>()); // 고른 바닥 타일의 자리
      expect(c.turn, 1);
      expect(find.textContaining('기다리는 중'), findsOneWidget);

      // 상대(미러)가 뽑는다
      theirs.send({'t': 'move', 'i': 1, 'draw': 1});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 2);
      expect(c.myTurn, isTrue);
      expect(mirror.state.racks[0].length, 14); // (미러는 처음 모습)
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 1, seed: 21);
      await tester.pumpWidget(await app(RummikubScreen(mode: PlayMode.wifi, humanSeat: 1, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      theirs.send({'t': 'move', 'i': 0, 'draw': 1});
      await settle(tester, rounds: 3);
      theirs.send(const {'t': 'resign'});
      await settle(tester, rounds: 4);
      expect(find.text('상대가 기권했어요'), findsOneWidget);
      final h = (await tester.runAsync(RkHistory.load))!;
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
      final c = RummikubController(animate: false, mode: PlayMode.wifi, humanSeat: 0, seed: 21);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => RummikubScreen(mode: PlayMode.wifi, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'draw': 1}); // 내 차례에 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(RummikubScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('방을 열고 찾아 들어가면 두 화면이 같은 씨앗·반대 자리로 시작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 46031;
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
        builder: (_) => const RummikubHostScreen(hostSide: 1, gamePort: 0, discoveryPort: discovery, seed: 777),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('내가 나중에 시작'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const RummikubJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester, rounds: 6);
      expect(find.text('루미큐브'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      await settle(tester, rounds: 12);
      final screens = tester.widgetList<RummikubScreen>(find.byType(RummikubScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSeat).toSet(), {0, 1});
      expect(screens.every((s) => s.seed == 777 && s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });
}
