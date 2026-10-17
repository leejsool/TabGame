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
import 'package:tabgame/games/rummikub/game/rummikub_layout.dart';
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
    RummikubScreen.showFirstHint = false; // (팝업은 아래 시험에서만 켠다)
    RummikubScreen.playSounds = false; // (시험에서는 소리를 내지 않는다)
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
      // (내 손의 타일을 고르고 순서를 바꾸는 것은 상대 차례에도 된다 — 판을 만지는 것만 안 된다)
      c.toggleSelect(id);
      expect(c.selected, {id});
      c.clearSelection();
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
      c.dropTiles([t(3, 10)], const Offset(3.3, 0));
      expect(c.work.length, 1);
      expect(c.work.first.length, 4);
      // 멀리 놓으면 그 자리에 새 묶음
      c.dropTiles([t(0, 1)], const Offset(0, 4));
      expect(c.work.length, 2);
      expect(c.layoutSets(10, 8)[1].dy, closeTo(4, 0.5));
      // 묶음이 바뀌어도 (타일 하나가 빠져도) 남은 묶음은 자리를 지킨다
      final before = c.layoutSets(10, 8).first;
      c.returnToHand([t(3, 10)]);
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
      c.dropTiles(c.work.firstWhere((s) => s.contains(t(0, 10))), Offset(anchor.dx + 3.2, anchor.dy));
      expect(c.work.length, 1);
      expect(c.work.first.length, 6);
    });

    test('내 타일: 끌어서 마음대로 순서를 바꾸고, 정렬 단추는 한 번 가지런히 늘어놓을 뿐이다', () {
      final c = fixedController(rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      c.sortHand(byColor: false);
      expect(c.rackTiles, [t(3, 1), t(0, 3), t(2, 5), t(1, 9)]);
      // 9를 맨 앞으로, 5를 맨 뒤로
      c.moveInHand([t(1, 9)], beforeId: t(3, 1));
      expect(c.rackTiles, [t(1, 9), t(3, 1), t(0, 3), t(2, 5)]);
      c.moveInHand([t(3, 1)]);
      expect(c.rackTiles, [t(1, 9), t(0, 3), t(2, 5), t(3, 1)]);
      // 여러 장을 한꺼번에: 순서를 지키며 한 타일 앞으로
      c.moveInHand([t(2, 5), t(3, 1)], beforeId: t(0, 3));
      expect(c.rackTiles, [t(1, 9), t(2, 5), t(3, 1), t(0, 3)]);
      // 제자리나 자기 앞으로는 아무 일도 없다
      c.moveInHand([t(2, 5)], beforeId: t(2, 5));
      expect(c.rackTiles, [t(1, 9), t(2, 5), t(3, 1), t(0, 3)]);
      // 정렬 단추를 누르면 한 번 가지런해진다
      c.sortHand(byColor: true);
      expect(c.rackTiles, [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
    });

    test('판에 올렸다가 손으로 돌려받으면 손의 원래 자리로 돌아오고, 손의 원하는 자리에 놓을 수도 있다', () {
      final c = fixedController(rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      c.moveTiles([t(1, 9)]);
      expect(c.rackTiles, [t(0, 3), t(2, 5), t(3, 1)]);
      c.returnToHand([t(1, 9)]);
      expect(c.rackTiles, [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      c.moveTiles([t(1, 9)]);
      c.moveInHand([t(1, 9)], beforeId: t(3, 1)); // 판에서 끌어내 손의 원하는 자리로
      expect(c.rackTiles, [t(0, 3), t(2, 5), t(1, 9), t(3, 1)]);
      expect(c.work, isEmpty);
    });

    test('판 위 타일(처음부터 있던 것)은 손으로 가져올 수 없다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      c.endTurn();
      c.state.applyDraw();
      c.moveInHand([t(0, 10)]);
      expect(c.rackTiles.contains(t(0, 10)), isFalse);
      expect(c.work.expand((x) => x).contains(t(0, 10)), isTrue);
    });

    test('한 단계 되돌리기: 방금 한 옮기기·합치기를 하나씩 되돌린다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 10), t(0, 1)]);
      c.layoutSets(10, 8);
      expect(c.canUndoStep, isFalse);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      c.moveTiles([t(3, 10)], at: const Offset(5, 3));
      expect(c.work.length, 2);
      // 낱개를 묶음에 합쳤다가
      c.moveTiles([t(3, 10)], to: c.work.first);
      expect(c.work.length, 1);
      expect(c.work.first.length, 4);
      // 되돌리면 낱개가 떨어져 제자리(5,3)로 간다
      expect(c.canUndoStep, isTrue);
      c.undoStep();
      expect(c.work.length, 2);
      expect(c.layoutSets(10, 8).last, const Offset(5, 3));
      c.undoStep();
      c.undoStep();
      expect(c.work, isEmpty);
      expect(c.rackTiles.length, 5);
      expect(c.canUndoStep, isFalse);
      // 끝내기·처음으로에서는 되돌릴 기록이 비워진다
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      c.reset();
      expect(c.canUndoStep, isFalse);
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

  group('녹색 판: 낱개 놓기·겹침 풀기·묶음 통째로 이동', () {
    test('겹치게 놓은 묶음은 자동으로 비켜서 겹치지 않는다 (방금 만진 묶음은 제자리를 지킨다)', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 5), t(0, 6), t(0, 7), t(3, 1)]);
      c.layoutSets(10, 8);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      // 같은 자리에 다른 묶음을 억지로 놓는다
      c.moveTiles([t(0, 5), t(0, 6), t(0, 7)], at: const Offset(0, 0));
      final spots = c.layoutSets(10, 8);
      final rects = [for (var i = 0; i < c.work.length; i++) setRect(spots[i], c.work[i].length, 8)];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i와 $j가 겹쳐요');
        }
      }
      // 방금 만진 묶음(5-6-7)이 제자리 (0,0)
      final moved = c.work.indexWhere((s) => s.contains(t(0, 5)));
      expect(spots[moved], const Offset(0, 0));
    });

    test('묶음에 타일이 붙어 길어져서 옆 묶음과 겹치면 옆 묶음이 비켜 준다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 10), t(0, 5), t(0, 6), t(0, 7), t(0, 8)]);
      c.layoutSets(12, 10);
      c.moveTiles([t(0, 5), t(0, 6), t(0, 7)], at: const Offset(0, 0));
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(4.2, 0)); // 바로 옆
      c.moveTiles([t(0, 8)], to: c.work.firstWhere((s) => s.contains(t(0, 5)))); // 앞 묶음이 한 칸 길어진다
      final spots = c.layoutSets(12, 10);
      final rects = [for (var i = 0; i < c.work.length; i++) setRect(spots[i], c.work[i].length, 10)];
      expect(rects[0].overlaps(rects[1]), isFalse);
    });

    test('낱개 한 장도 아무 빈자리에 놓을 수 있고, 아주 가까울 때만 자석처럼 붙는다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4), t(0, 1)]);
      c.layoutSets(10, 8);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      // 묶음 옆 1칸쯤 떨어진 곳에는 그냥 놓인다 (붙지 않는다)
      c.dropTiles([t(3, 4)], const Offset(4.6, 0));
      expect(c.work.length, 2);
      expect(c.work.any((s) => s.length == 1 && s.first == t(3, 4)), isTrue);
      // 바싹 붙이면 합쳐진다
      c.dropTiles([t(0, 1)], const Offset(3.2, 0));
      expect(c.work.length, 2);
      expect(c.work.first.length + c.work.last.length, 5);
      // 한 장짜리 묶음이 있어도 끝내기는 막히고 이유가 나온다
      expect(c.endTurn(), isFalse);
    });
  });

  group('Wi‑Fi: 상대 차례에도 손을 정리하고, 상대가 내려놓는 모습이 실시간으로 보인다', () {
    test('상대 차례에도 내 손의 타일 순서를 바꿀 수 있다 (판은 못 만진다)', () {
      final c = fixedController(mode: PlayMode.wifi, humanSeat: 1, rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      expect(c.myTurn, isFalse);
      expect(c.canArrange, isTrue);
      final before = c.rackTiles.toList();
      c.moveInHand([before.last], beforeId: before.first);
      expect(c.rackTiles, [before.last, ...before.take(3)]);
      c.sortHand(byColor: false);
      expect(c.rackTiles, [t(3, 1), t(0, 3), t(2, 5), t(1, 9)]);
      c.moveTiles([t(0, 3)]); // 판은 못 만진다
      expect(c.work, isEmpty);
      expect(c.rackTiles.length, 4);
    });

    test('상대가 판에 한 장씩 올릴 때마다 내 화면에 바로 보이고, 끝내면 다시 옮기지 않고 그대로 반영된다', () {
      final (a, b) = wiredPair(seed: 9);
      for (final x in [a, b]) {
        x.state.racks[0]
          ..clear()
          ..addAll([t(0, 10), t(1, 10), t(2, 10), t(3, 2), t(0, 1)]);
      }
      a.hand = [...a.state.racks[0]];
      final lives = <Map<String, dynamic>>[];
      a.onLocalLive = (m) {
        lives.add(m);
        b.receiveLive(m);
      };
      a.layoutSets(10, 8);
      b.layoutSets(10, 8);
      expect(a.myTurn, isTrue);
      expect(b.myTurn, isFalse);
      // 상대(a)가 한 장 올린다 → b의 화면(work)에 바로 나타난다
      a.moveTiles([t(0, 10)], at: const Offset(0, 0));
      expect(b.work.expand((x) => x), contains(t(0, 10)));
      expect(b.state.table, isEmpty); // (판의 진짜 상태는 끝낼 때까지 그대로)
      // 둘째·셋째 장을 같은 묶음에 올린다
      a.moveTiles([t(1, 10)], to: a.work.first);
      a.moveTiles([t(2, 10)], to: a.work.first);
      expect(b.work.length, 1);
      expect(b.work.first.toSet(), {t(0, 10), t(1, 10), t(2, 10)});
      expect(lives.length, greaterThanOrEqualTo(3));
      // b가 같은 자리에 보고 있다
      expect(b.anchorOf(b.work.first), a.anchorOf(a.work.first));
      // 끝내면 최종 수가 가서 진짜 판에 반영된다 (연출 없이 바로)
      expect(a.endTurn(), isTrue);
      expect(b.state.table.length, 1);
      expect(b.animating, isFalse);
      expect(b.myTurn, isTrue);
      // 실시간 내용이 틀리면 (판에 있던 타일이 사라진 경우) 조용히 버린다
      expect(b.receiveLive({'i': b.moveCount, 'sets': <List<int>>[]}), isFalse);
    });
  });

  group('정리: 묶음은 그대로 두고 자리만 가지런히', () {
    test('흩어진 묶음들이 위쪽부터 줄 맞춰 놓이고, 묶음의 구성은 그대로이며, 한 단계 되돌리기로 돌아간다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 3), t(0, 4), t(0, 5), t(1, 7), t(1, 8), t(1, 9)]);
      c.layoutSets(9, 10);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(5, 6));
      c.moveTiles([t(0, 3), t(0, 4), t(0, 5)], at: const Offset(0, 9));
      c.moveTiles([t(1, 7), t(1, 8), t(1, 9)], at: const Offset(5, 2));
      final before = [for (final s in c.work) ([...s]..sort()).join(',')]..sort();
      final spots = c.layoutSets(9, 10);
      expect(spots.map((o) => o.dy).reduce(max), greaterThan(3));
      c.tidySets();
      final after = c.layoutSets(9, 10);
      expect([for (final s in c.work) ([...s]..sort()).join(',')]..sort(), before); // 묶음은 그대로
      // 런(빨강 3-4-5, 파랑 7-8-9)이 먼저, 그룹(10)이 나중. 9칸 폭에 3.8칸짜리 둘이 한 줄 → 셋째는 다음 줄
      int at(List<int> tile) => c.work.indexWhere((s) => s.contains(tile.first));
      expect(after[at([t(0, 3)])], const Offset(0, 0));
      expect(after[at([t(1, 7)])].dy, 0);
      expect(after[at([t(0, 10)])].dy, 1);
      expect(after.map((o) => o.dy).reduce(max), lessThan(2));
      expect(c.canUndoStep, isTrue);
      c.undoStep();
      expect(c.layoutSets(9, 10)[at([t(0, 10)])], const Offset(5, 6));
    });
  });

  group('자석은 좁게: 빈 땅에 놓으면 새 묶음', () {
    test('묶음 옆 반 칸쯤 떨어진 빈 땅에 놓은 낱개는 붙지 않고 새 묶음이 된다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4), t(0, 1)]);
      c.layoutSets(10, 8);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      for (final x in [4.0, 4.4, 5.0]) {
        c.dropTiles([t(3, 4)], Offset(x, 0));
        expect(c.work.length, 2, reason: 'x=$x 에서 붙어 버렸어요');
        c.undoStep();
      }
      // 묶음 위에 놓으면 (겹치면) 붙는다
      c.dropTiles([t(3, 4)], const Offset(3.1, 0));
      expect(c.work.length, 1);
    });

    test('여러 장·묶음 통째로 끌 때는 서로 겹칠 때만 붙는다', () {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(0, 5), t(0, 6), t(0, 7)]);
      c.layoutSets(14, 10);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      c.moveTiles([t(0, 5), t(0, 6), t(0, 7)], at: const Offset(0, 4));
      final group = c.work.firstWhere((s) => s.contains(t(0, 5)));
      // 바로 옆(틈 0.5칸)에 놓아도 붙지 않는다
      expect(c.dropTargetFor(group, const Offset(4.3, 0)), isNull);
      // 겹치면 붙을 묶음이 미리 알려진다
      expect(c.dropTargetFor(group, const Offset(2.5, 0)), same(c.work.firstWhere((s) => s.contains(t(0, 10)))));
    });
  });

  group('끌기 방식: 그냥 끌면 낱개, 꾹 눌러 끌면 묶음 통째로', () {
    testWidgets('판 위 타일을 그냥 끌면 한 장만, 꾹 눌렀다가 끌면 그 묶음 전체가 옮겨진다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      c.layoutSets(c.layoutWidth, c.layoutPerRow);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)], at: const Offset(0, 0));
      await settle(tester, rounds: 3);
      final table = tester.getRect(find.byType(DragTarget<List<int>>).first);

      // 1) 그냥 끌기: 한 장만 떨어져 나와 새 묶음이 된다
      final g = await tester.startGesture(tester.getCenter(tileFinder(t(2, 10))));
      await g.moveBy(const Offset(0, 25));
      await g.moveTo(Offset(table.center.dx, table.bottom - 60));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 3);
      expect(c.work.length, 2);
      expect(c.work.where((s) => s.length == 1).single, [t(2, 10)]);

      // 2) 꾹 눌렀다가 끌기: 묶음(남은 두 장) 통째로 옮겨진다
      final pair = c.work.firstWhere((s) => s.length == 2);
      final before = c.anchorOf(pair)!;
      final g2 = await tester.startGesture(tester.getCenter(tileFinder(t(0, 10))));
      await tester.pump(const Duration(milliseconds: 600)); // 꾹
      await g2.moveBy(const Offset(0, 40));
      await g2.moveTo(Offset(table.center.dx, table.center.dy));
      await tester.pump(const Duration(milliseconds: 100));
      await g2.up();
      await settle(tester, rounds: 3);
      final movedPair = c.work.firstWhere((s) => s.contains(t(0, 10)));
      expect(movedPair.length, 2); // 둘이 함께 움직였다
      expect(movedPair.contains(t(1, 10)), isTrue);
      expect(c.anchorOf(movedPair), isNot(before));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('처음 내 차례에는 규칙 팝업이 한 번 뜨고, 그 뒤로는 화면에 긴 안내 글이 없다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      RummikubScreen.showFirstHint = true;
      addTearDown(() => RummikubScreen.showFirstHint = false);
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 3);
      expect(find.text('처음 내려놓을 때'), findsOneWidget);
      await tester.tap(find.text('알겠어요'));
      await settle(tester, rounds: 8);
      expect(find.text('처음 내려놓을 때'), findsNothing);
      expect(find.textContaining('끌어다 맞추거나'), findsNothing); // 예전의 긴 안내 문구는 없다
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
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
      expect(c.myTurn, isTrue);
      expect(find.text('내 타일 5장'), findsOneWidget);
      expect(find.byTooltip('끝내기'), findsOneWidget);

      for (final id in [t(0, 10), t(1, 10), t(2, 10)]) {
        await tester.tap(tileFinder(id));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(c.selected.length, 3);
      await tester.tap(find.text('고른 타일로 새 묶음'));
      await settle(tester, rounds: 2);
      expect(c.work.length, 1);
      expect(find.text('내 타일 2장'), findsOneWidget);

      await tester.tap(find.byTooltip('끝내기'));
      await settle(tester, rounds: 2);
      expect(c.turn, 1);
      expect(find.textContaining('CPU 1'), findsWidgets);

      // CPU가 차례를 마칠 때까지 기다린다
      for (var i = 0; i < 40 && c.turn != 0; i++) {
        await settle(tester, rounds: 2);
      }
      expect(c.turn, 0);
      expect(c.myTurn, isTrue);
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

    testWidgets('상대의 수가 다 보여진 뒤 내 차례가 되면 "내 차례예요!"가 잠깐 떴다가 저절로 사라진다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = RummikubController(animate: true, mode: PlayMode.vsCpu, seed: 3)..stepDelay = const Duration(milliseconds: 15);
      c.state.racks[1]
        ..clear()
        ..addAll([t(0, 11), t(1, 11), t(2, 11), t(3, 2)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.text('내 차례예요!'), findsNothing); // (처음 시작할 때는 알리지 않는다)
      c.draw(); // 내 차례를 넘기면 CPU가 두고 다시 내 차례가 된다
      for (var i = 0; i < 100 && !(c.turn == 0 && c.canAct); i++) {
        await settle(tester, rounds: 1);
      }
      expect(c.canAct, isTrue);
      await tester.pump();
      expect(find.text('내 차례예요!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('내 차례예요!'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('내가 이기면 색종이와 "승리!" 현판이 나타나고 몇 초 뒤 저절로 사라진다 (지면 나타나지 않는다)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = RummikubController(animate: true, mode: PlayMode.vsCpu, players: 2, seed: 3);
      final rack = [t(0, 10), t(1, 10), t(2, 10)];
      c.state.racks[0]
        ..clear()
        ..addAll(rack);
      c.hand = [...rack];
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.byKey(const ValueKey('celebration')), findsNothing);
      c.moveTiles(rack);
      expect(c.endTurn(), isTrue); // 손이 비었다
      expect(c.isOver, isTrue);
      expect(c.state.winner, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('celebration')), findsOneWidget);
      expect(find.text('승리!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 5500));
      expect(find.byKey(const ValueKey('celebration')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('내 타일 안에서 타일을 끌어 다른 타일 앞에 놓으면 순서가 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixedController(rack: [t(0, 3), t(1, 9), t(2, 5), t(3, 1)]);
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('내 정리판'), findsNothing); // 정리판은 없다
      final before = c.rackTiles.toList();
      // 마지막 타일을 맨 앞 타일 위로 끌어다 놓는다
      final g = await tester.startGesture(tester.getCenter(tileFinder(before.last)));
      await g.moveBy(const Offset(-20, 0));
      await g.moveTo(tester.getCenter(tileFinder(before.first)));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, rounds: 2);
      expect(c.rackTiles, [before.last, ...before.take(3)]);
      // 정렬 단추는 한 번 가지런히 해 준다
      await tester.tap(find.text('숫자 정렬'));
      await settle(tester, rounds: 1);
      expect(c.rackTiles, [t(3, 1), t(0, 3), t(2, 5), t(1, 9)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('바닥에서 타일을 뽑으면 바닥에서 내 손으로 날아오고, 도착하면 손에 나타난다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = RummikubController(mode: PlayMode.vsCpu, players: 2, humanSeat: 0, seed: 3);
      c.state.racks[0]
        ..clear()
        ..addAll([t(0, 3), t(1, 9)]);
      c.hand = [t(0, 3), t(1, 9)];
      await tester.pumpWidget(await app(RummikubScreen(controller: c)));
      await settle(tester, rounds: 2);
      await tester.tap(find.byType(RkTileBack).first);
      await tester.pump(); // (그린 뒤에 도착 자리를 재서 날려 보낸다)
      await tester.pump(const Duration(milliseconds: 50));
      final drawn = c.lastDrawn!;
      expect(find.byKey(const ValueKey('fly')), findsOneWidget); // 날아가는 타일
      // 날아오는 동안 손의 그 타일은 숨겨져 있다
      final hiddenWhileFlying = tester.widget<Opacity>(find.byKey(ValueKey('hand$drawn')));
      expect(hiddenWhileFlying.opacity, 0);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      final shown = tester.widget<Opacity>(find.byKey(ValueKey('hand$drawn')));
      expect(shown.opacity, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3)); // (CPU 차례의 남은 시간)
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
      // 안 되는 이유는 화면 자리를 쓰지 않고 짧은 알림으로 알려 준다
      await tester.tap(find.byTooltip('끝내기'));
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
      expect(c.myTurn, isTrue);
      expect(find.text('새 판'), findsNothing);

      await tester.tap(find.byType(RkTileBack).first);
      await settle(tester, rounds: 3);
      expect(received.single['t'], 'move');
      expect(received.single['i'], 0);
      expect(received.single['draw'], 1);
      expect(received.single['pick'], isA<int>()); // 고른 바닥 타일의 자리
      expect(c.turn, 1);
      expect(c.myTurn, isFalse); // 상대 차례

      // 상대가 판에 올리는 중간 모습이 오면 바로 내 화면의 판에 나타난다 (끝내기 전이라 판의 진짜 상태는 그대로)
      final theirTiles = mirror.state.racks[1].take(3).toList();
      theirs.send({'t': 'live', 'i': 1, 'sets': [theirTiles], 'a': [[0.0, 0.0]]});
      await settle(tester, rounds: 3);
      expect(c.work.expand((x) => x).toSet(), theirTiles.toSet());
      expect(c.state.table, isEmpty);
      for (final id in theirTiles) {
        expect(tileFinder(id), findsOneWidget);
      }
      expect(find.textContaining('내려놓았어요'), findsNothing); // (판을 좁히는 안내 글은 없다)
      // 손 순서는 상대 차례에도 바꿀 수 있다
      final mine0 = c.rackTiles.toList();
      c.moveInHand([mine0.last], beforeId: mine0.first);
      expect(c.rackTiles.first, mine0.last);

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
      expect(find.text('내가 두 번째로 시작'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const RummikubJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.textContaining('루미큐브 · 2명'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      for (var i = 0; i < 60 && find.byType(RummikubScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<RummikubScreen>(find.byType(RummikubScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.map((s) => s.humanSeat).toSet(), {0, 1});
      expect(screens.every((s) => s.seed == 777 && s.mode == PlayMode.wifi), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });

    testWidgets('사람 2명 + CPU 1명 방: 들어가면 두 화면이 시작하고, 남은 자리가 CPU로 정해진다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 46032;
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
        builder: (_) => const RummikubHostScreen(hostSide: 0, players: 3, cpus: 1, gamePort: 0, discoveryPort: discovery, seed: 778),
      )));
      await settle(tester, rounds: 4);
      expect(find.textContaining('3명 (사람 2 + CPU 1)'), findsWidgets);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const RummikubJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.textContaining('루미큐브 · 3명 (사람 2 + CPU 1)'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      for (var i = 0; i < 60 && find.byType(RummikubScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<RummikubScreen>(find.byType(RummikubScreen, skipOffstage: false)).toList();
      expect(screens.length, 2);
      expect(screens.every((s) => s.players == 3 && s.seed == 778 && s.cpuSeats!.length == 1), isTrue);
      final cpu = screens.first.cpuSeats!.single;
      expect(screens.every((s) => s.cpuSeats!.single == cpu && s.humanSeat != cpu), isTrue);
      expect(screens.map((s) => s.humanSeat).toSet().length, 2);
      expect(screens.first.names![cpu], 'CPU 1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 3);
    });
  });

  group('타일 소리 신호', () {
    test('손에서 순서를 바꾸거나 판에 놓거나 되돌리면 place, 뽑으면 draw, 상대가 한 장씩 옮기면 step', () async {
      final c = fixedController(rack: [t(0, 10), t(1, 10), t(2, 10), t(3, 4)]);
      final kinds = <String>[];
      c.onFeedback = kinds.add;
      c.moveInHand([t(3, 4)], beforeId: t(0, 10));
      expect(kinds, ['place']);
      c.moveTiles([t(0, 10), t(1, 10), t(2, 10)]);
      expect(kinds, ['place', 'place']);
      c.returnToHand([t(2, 10)]);
      expect(kinds, ['place', 'place', 'place']);
      c.reset();
      c.draw();
      expect(kinds.last, 'draw');
      c.dispose();

      // 상대가 바닥에서 타일을 고를 때 한 번 (판 위에서 한 장씩 옮길 때도 한 장마다 같은 신호가 나온다)
      final a = RummikubController(animate: true, mode: PlayMode.wifi, players: 3, humanSeat: 1, seed: 5, cpuSeats: [2])..stepDelay = const Duration(milliseconds: 3);
      final seen = <String>[];
      a.onFeedback = seen.add;
      expect(a.receiveMove({'t': 'move', 'i': 0, 'draw': 1, 'pick': 0}), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(seen.where((k) => k == 'step').length, 1);
      a.dispose();
    });
  });

  group('녹색 판 타일 크기', () {
    test('세로 화면의 판 위 타일은 34를 넘지 않고, 묶음 사이 여백을 줄여도 커지지 않아 더 많이 들어간다', () {
      // 폭 400 기기: 안쪽 392 → 예전 크기 34 (여백을 줄였다고 36으로 커지면 안 된다)
      expect(rkTableTileSize(392), 34);
      expect(rkTableTileSize(900), 34);
      expect(rkTableTileSize(352), 31); // 폭 360 기기
      expect(rkTableTileSize(100), 20);
      // 태블릿은 1.5배까지 (폭 800 → 51), 폰 크기의 폭에서는 배율이 있어도 한계 안에서 같다
      expect(rkTableTileSize(792, scale: kTabletTileScale), 51);
      expect(rkTableTileSize(392, scale: kTabletTileScale), 34);
      expect(rkTableTileSize(792), 34);
      // 같은 폭에서 한 줄에 들어가는 3장 묶음의 수: 여백이 좁아진 만큼 예전보다 더 많이 들어간다
      const inner = 392.0;
      final tile = rkTableTileSize(inner);
      final perRowNow = (inner / tile / (3 + kSetPad)).floor();
      final perRowBefore = (inner / tile / (3 + 0.6)).floor();
      expect(perRowNow, greaterThanOrEqualTo(perRowBefore));
      expect(perRowNow * (3 + kSetPad) * tile, lessThanOrEqualTo(inner));
    });

    test('태블릿 판 위 타일은 3장짜리 묶음이 한 줄에 꼭 맞는 크기라, 빈자리 찾기로 놓아도 오른쪽에 묶음 하나만큼의 빈자리가 남지 않는다', () {
      // 탭 세로(폭 800 → 안쪽 792): 예전 51이면 4묶음 뒤에 1.7칸이 남았다 → 57로 키워 4묶음이 꽉 찬다
      expect(rkTabletTableTileSize(792), 57);
      // 탭 가로(판 쪽 안쪽 약 703): 예전 51이면 4번째 묶음이 0.01칸 모자라 3묶음만 → 50으로 4묶음
      expect(rkTabletTableTileSize(703), 50);
      for (final inner in [530.0, 592.0, 640.0, 703.0, 792.0, 900.0, 1000.0]) {
        final tile = rkTabletTableTileSize(inner);
        expect(tile, greaterThanOrEqualTo(34.0 * kTabletTileScale * 0.95), reason: '안쪽 $inner');
        final units = inner / tile;
        // 실제로 빈자리 찾기로 3장 묶음을 계속 놓아 본다
        final placed = <Rect>[];
        final size = setRect(Offset.zero, 3, 13);
        while (placed.length < 30) {
          final a = findFreeSpot(placed, size, units);
          if (a.dy > 0) break;
          placed.add(setRect(a, 3, 13));
        }
        final left = units - placed.last.right;
        expect(left, lessThan(1.2), reason: '안쪽 $inner: 한 줄 ${placed.length}묶음, 남은 칸 $left');
      }
    });
  });

  group('상대 차례 소리', () {
    test('상대가 타일 3장을 내려놓으면 딸깍은 3번만 난다 (판 위에 이미 있던 묶음의 타일은 소리 없이 넘어간다)', () async {
      final a = RummikubController(animate: true, mode: PlayMode.wifi, players: 2, humanSeat: 0, seed: 5)..stepDelay = const Duration(milliseconds: 3);
      final old = [t(0, 1), t(0, 2), t(0, 3)];
      final fresh = [t(1, 5), t(1, 6), t(1, 7)];
      a.state.table.add([...old]);
      a.state.racks[1]
        ..clear()
        ..addAll([...fresh, t(2, 9)]);
      a.state.racks[0].removeWhere((x) => old.contains(x) || fresh.contains(x) || x == t(2, 9));
      a.state.melded[1] = true;
      a.state.turn = 1;
      a.work = [for (final s in a.state.table) [...s]];
      final kinds = <String>[];
      a.onFeedback = kinds.add;
      expect(a.receiveMove({'t': 'move', 'i': 0, 'table': [old, fresh]}), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(kinds.where((k) => k == 'step').length, 3);
      expect(a.state.table.length, 2);
      a.dispose();
    });
  });

  group('사람 + CPU 방 (컨트롤러)', () {
    test('사람 3명 + CPU 1명: 방장이 CPU의 수를 정해 알리고, 서로 수를 전해 주면 모든 기기가 같은 판이 된다', () async {
      final rng = Random(4);
      final host = RummikubController(animate: true, mode: PlayMode.wifi, players: 4, humanSeat: 0, seed: 31, cpuSeats: [3], cpuHost: true)..stepDelay = const Duration(milliseconds: 4);
      final g1 = RummikubController(animate: true, mode: PlayMode.wifi, players: 4, humanSeat: 1, seed: 31, cpuSeats: [3])..stepDelay = const Duration(milliseconds: 4);
      final g2 = RummikubController(animate: true, mode: PlayMode.wifi, players: 4, humanSeat: 2, seed: 31, cpuSeats: [3])..stepDelay = const Duration(milliseconds: 9);
      expect([host.runsCpu, g1.runsCpu, g2.runsCpu], [true, false, false]);
      var desync = false;
      for (final c in [host, g1, g2]) {
        c.onDesync = () => desync = true;
      }
      // 별 모양으로 잇는다: 방장은 모두에게, 손님은 방장에게 보내고 방장이 다른 손님에게 전해 준다
      var cpuMoved = false;
      host.onLocalMove = (m) {
        if (host.turn == 3) cpuMoved = true; // (방장 자신의 수는 둔 뒤라 차례가 1번으로 넘어가 있다. 3번은 CPU가 정한 수)
        final msg = {'t': 'move', ...m};
        expect(g1.receiveMove(msg), isTrue);
        expect(g2.receiveMove(msg), isTrue);
      };
      g1.onLocalMove = (m) {
        final msg = {'t': 'move', ...m};
        expect(host.receiveMove(msg, fromSeat: 1), isTrue);
        expect(g2.receiveMove(msg), isTrue);
      };
      g2.onLocalMove = (m) {
        final msg = {'t': 'move', ...m};
        expect(host.receiveMove(msg, fromSeat: 2), isTrue);
        expect(g1.receiveMove(msg), isTrue);
      };
      host.start();
      for (var i = 0; i < 1200 && host.moveCount < 9 && !host.isOver && !desync; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        for (final c in [host, g1, g2]) {
          if (!c.canAct) continue;
          final s = c.state;
          final plan = RkAi.plan(rack: [...s.currentRack], table: [for (final t in s.table) [...t]], melded: s.melded[s.turn], level: RkLevel.normal, rng: rng);
          if (plan != null && s.checkPlay(plan) == null) {
            c.work = [for (final set in plan) [...set]];
            expect(c.endTurn(), isTrue);
          } else {
            c.draw();
          }
        }
      }
      expect(desync, isFalse, reason: '기기들의 판이 어긋났어요');
      expect(host.moveCount, greaterThanOrEqualTo(6), reason: '판이 진행되지 않았어요 (${host.moveCount}수, 차례 ${host.turn})');
      expect(cpuMoved, isTrue, reason: 'CPU가 한 번도 안 뒀어요');
      // 마지막 수까지 다 보여 줄 때까지 기다린다
      for (var i = 0; i < 200 && [host, g1, g2].any((c) => c.animating || c.thinking); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      expect(desync, isFalse);
      expect(g1.moveCount, host.moveCount);
      expect(g2.moveCount, host.moveCount);
      for (final c in [g1, g2]) {
        expect(c.state.table, host.state.table);
        expect(c.state.turn, host.state.turn);
        for (var p = 0; p < 4; p++) {
          expect(c.state.racks[p].toSet(), host.state.racks[p].toSet());
        }
      }
      for (final c in [host, g1, g2]) {
        c.dispose();
      }
    });

    test('CPU가 낀 방은 기권이 없고(3명 이상), 한 판 더 하면 사람·CPU 자리가 함께 한 칸씩 돈다', () {
      final c = RummikubController(animate: false, mode: PlayMode.wifi, players: 3, humanSeat: 2, seed: 5, cpuSeats: [0]);
      expect(c.canResign, isFalse);
      expect(c.humans, 2);
      c.restart();
      expect([c.humanSeat, c.cpuSeats.toList(), c.rotation], [0, [1], 1]);
      c.restart();
      expect([c.humanSeat, c.cpuSeats.toList(), c.rotation], [1, [2], 2]);
      c.dispose();
    });
  });
}
