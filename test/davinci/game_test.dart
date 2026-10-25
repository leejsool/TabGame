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
import 'package:tabgame/games/davinci/core/davinci_ai.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/data/davinci_history.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_records_tab.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_setup_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_wifi_screen.dart';
import 'package:tabgame/net/lan_connection.dart';

import '../support/preview_kit.dart';

int b(int n) => dvTile(0, n);
int w(int n) => dvTile(1, n);

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

/// 정해 둔 줄·더미로 시작하는 컨트롤러 (내가 0번 자리, CPU는 바로바로 둔다).
DavinciController fixed(List<List<int>> rows, {List<int> black = const [], List<int> white = const [], PlayMode mode = PlayMode.vsCpu, int humanSeat = 0, int seed = 3, bool? animate}) {
  final c = DavinciController(mode: mode, players: rows.length, humanSeat: humanSeat, seed: seed, animate: animate)..cpuStepDelay = Duration.zero;
  for (var i = 0; i < rows.length; i++) {
    c.state.rows[i]
      ..clear()
      ..addAll(rows[i]);
  }
  c.state.blackPool
    ..clear()
    ..addAll(black);
  c.state.whitePool
    ..clear()
    ..addAll(white);
  c.state.revealed.clear();
  c.state.turn = 0;
  c.state.drawn = null;
  c.state.pendingJoker = null;
  c.state.phase = c.state.drawableColors.isEmpty ? DvPhase.guess : DvPhase.draw;
  return c;
}

/// AI가 고른 수를 컨트롤러 조작으로 그대로 해 본다 (사람이 누르는 것과 같은 길).
void playAi(DavinciController c, Random rng) {
  final m = DvAi.choose(c.state, DvLevel.normal, rng);
  switch (m[0]) {
    case 0:
      expect(c.draw(m[1]), isTrue);
    case 1:
      expect(c.placeJoker(m[1]), isTrue);
    case 2:
      c.selectTarget(m[1], m[2]);
      expect(c.guess(m[3]), isTrue);
    case 3:
      expect(c.stop(), isTrue);
    case 4:
      expect(c.revealOwn(m[1]), isTrue);
  }
}

/// 두 기기의 컨트롤러를 서로 이어 준다 (네트워크 대신 직접).
(DavinciController, DavinciController) wiredPair({int seed = 11}) {
  final a = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: seed);
  final bb = DavinciController(mode: PlayMode.wifi, humanSeat: 1, seed: seed);
  a.onLocalMove = (m) => expect(bb.receiveMove(m, index: a.moveCount - 1), isTrue);
  bb.onLocalMove = (m) => expect(a.receiveMove(m, index: bb.moveCount - 1), isTrue);
  return (a, bb);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DavinciController.animateByDefault = false; // (상대 수 연출은 아래 시험에서만 켠다)
    await loadAppFonts();
  });

  group('컨트롤러', () {
    test('상대 타일을 누르면 "고민"(think) 소리가 한 번 나고, 다시 눌러 고름을 풀 때는 나지 않는다', () {
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], black: [b(4)], white: [w(3)]);
      final sounds = <String>[];
      c.onFeedback = sounds.add;
      expect(c.draw(0), isTrue);
      sounds.clear(); // (뽑기 소리는 빼고)
      c.selectTarget(1, 1);
      expect(sounds.where((k) => k.startsWith('think')).length, 1);
      c.selectTarget(1, 1); // 고름을 푼다
      expect(sounds.where((k) => k.startsWith('think')).length, 1);
      c.selectTarget(0, 0); // 내 타일은 못 고른다
      expect(sounds.where((k) => k.startsWith('think')).length, 1);
    });

    test('다른 기기의 사람이 타일을 고르면 고민 소리가 나고, 이어 그 타일을 맞히는 연출에서는 또 나지 않는다', () async {
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], mode: PlayMode.wifi, animate: true)
        ..cpuStepDelay = const Duration(milliseconds: 10);
      c.state.turn = 1;
      c.state.phase = DvPhase.guess;
      final sounds = <String>[];
      c.onFeedback = sounds.add;
      c.receiveSelection(1, 0, 1); // 상대가 내 1번 타일을 누른다
      expect(sounds.where((k) => k.startsWith('think')).length, 1);
      expect(c.receiveMove(DvMove.guess(0, 1, 6)), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sounds.where((k) => k.startsWith('think')).length, 1, reason: sounds.join(','));
      expect(sounds, contains('right'));
      c.dispose();
    });

    test('고름 소식 없이 상대가 맞히면(CPU 등) 타일을 고르는 순간 고민 소리가 한 번 난다', () async {
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], mode: PlayMode.wifi, animate: true)
        ..cpuStepDelay = const Duration(milliseconds: 10);
      c.state.turn = 1;
      c.state.phase = DvPhase.guess;
      final sounds = <String>[];
      c.onFeedback = sounds.add;
      expect(c.receiveMove(DvMove.guess(0, 1, 6)), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sounds.where((k) => k.startsWith('think')).length, 1, reason: sounds.join(','));
      c.dispose();
    });

    test('뽑고, 상대 타일을 골라 맞히면 공개되고, 멈추면 차례가 넘어간다 (CPU가 이어서 둔다)', () async {
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], black: [b(4)], white: [w(3)]);
      expect(c.humanCanAct, isTrue);
      expect(c.draw(0), isTrue);
      expect(c.state.rows[0], [b(1), b(4), b(6), w(9)]);
      c.selectTarget(1, 1);
      expect([c.selSeat, c.selIndex], [1, 1]);
      c.selectTarget(1, 1); // 다시 누르면 고름이 풀린다
      expect(c.selSeat, -1);
      c.selectTarget(1, 1);
      expect(c.guess(7), isTrue);
      expect(c.state.isRevealed(w(7)), isTrue);
      expect(c.phase, DvPhase.decide);
      expect(c.stop(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.turn, 0); // CPU(1번)가 차례를 마치고 돌아왔다
      expect(c.state.turnCount, greaterThanOrEqualTo(2));
      c.dispose();
    });

    test('규칙에 안 맞는 조작이나 내 차례가 아닌 때의 조작은 안 된다', () {
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [b(4)]);
      expect(c.guess(5), isFalse); // 고른 타일이 없다
      expect(c.stop(), isFalse);
      expect(c.placeJoker(0), isFalse);
      c.selectTarget(1, 0); // (뽑기 전에는 고를 수 없다)
      expect(c.selSeat, -1);
      expect(c.draw(1), isFalse); // 흰색 더미가 비었다
      expect(c.draw(0), isTrue);
      c.selectTarget(0, 0); // 내 타일은 고를 수 없다
      expect(c.selSeat, -1);
      final other = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [b(4)], humanSeat: 1);
      expect(other.humanCanAct, isFalse);
      expect(other.draw(0), isFalse);
    });

    test('기권하면 상대(여럿이면 숨은 타일이 많은 쪽)가 이긴다', () {
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
        [b(3), w(8), b(9)],
      ], black: [b(4)]);
      c.draw(0);
      expect(c.canResign, isTrue);
      expect(c.resign(), isTrue);
      expect(c.halted, isTrue);
      expect(c.resignWinner, 2);
      expect(c.humanCanAct, isFalse);
    });
  });

  group('Wi‑Fi 대결 판 진행', () {
    test('두 기기가 같은 씨앗으로 시작해 수를 주고받으면 끝까지 똑같은 판이다', () {
      for (var seed = 0; seed < 4; seed++) {
        final (a, bb) = wiredPair(seed: seed);
        expect(a.state.rows, bb.state.rows);
        final rng = Random(seed);
        var n = 0;
        while (!a.isOver && n++ < 1500) {
          final mine = a.humanCanAct ? a : bb;
          expect((identical(mine, a) ? bb : a).humanCanAct, isFalse); // 상대 차례에는 못 둔다
          playAi(mine, rng);
        }
        expect(a.isOver, isTrue);
        expect(bb.isOver, isTrue);
        expect(a.state.winner, bb.state.winner);
        expect(a.state.rows, bb.state.rows);
        expect(a.state.revealed, bb.state.revealed);
        expect(a.moves, bb.moves);
      }
    });

    test('순서가 어긋났거나 규칙에 안 맞는 수는 받지 않는다', () {
      final a = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: 4);
      expect(a.receiveMove(DvMove.drawMove(0)), isFalse); // 내 차례에 상대의 수
      expect(a.draw(0), isTrue);
      expect(a.receiveMove(DvMove.drawMove(0), index: 7), isFalse); // 번호가 어긋남
      final local = DavinciController(mode: PlayMode.vsCpu, seed: 4);
      expect(local.receiveMove(DvMove.drawMove(0)), isFalse);
    });

    test('한 판 더: 자리가 돌고 모두 같은 새 패를 받는다. 기권하면 판이 멈춘다', () {
      final (a, bb) = wiredPair();
      a.draw(0);
      a.restart();
      bb.restart();
      expect([a.humanSeat, bb.humanSeat], [1, 0]);
      expect(a.seed, bb.seed);
      expect(a.state.rows, bb.state.rows);
      expect(bb.humanCanAct, isTrue);
      expect(a.humanCanAct, isFalse);
      bb.draw(0);
      expect(bb.resign(), isTrue);
      a.opponentResigned();
      expect(a.halted, isTrue);
      expect(a.resignWinner, a.humanSeat);
    });
  });

  group('상대가 둔 수 보여 주기 (연출)', () {
    /// 내가 0번, 상대(1번)가 맞히는 판. 상대 차례로 맞춰 둔다.
    DavinciController opponentTurn({int seed = 5}) {
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: seed, animate: true)..cpuStepDelay = const Duration(milliseconds: 40);
      c.state.rows[0]
        ..clear()
        ..addAll([b(1), w(4), b(6)]);
      c.state.rows[1]
        ..clear()
        ..addAll([b(2), w(7), b(10)]);
      c.state.revealed.clear();
      c.state.turn = 1;
      c.state.phase = DvPhase.guess;
      c.state.drawn = w(7); // 상대가 방금 뽑은 타일 (틀리면 공개된다)
      return c;
    }

    test('맞히는 수: 추측 중에는 고른 타일이 떠오르고 아직 숨은 것으로 보이다가, 결과가 나오면 공개(눕힘)된다', () async {
      final c = opponentTurn();
      final seen = <String>[];
      c.addListener(() {
        final e = c.effect;
        if (e != null) seen.add('${e.stage.name}:${c.liftedTile != null}:${c.hiddenOverride.contains(w(4))}');
      });
      // 상대가 내 두 번째 타일(흰색 4)을 4라고 맞힌다
      expect(c.receiveMove(DvMove.guess(0, 1, 4), index: 0), isTrue);
      expect(c.state.isRevealed(w(4)), isTrue); // (판 자체는 바로 반영된다)
      expect(c.effect, isNotNull);
      // 먼저 타일을 고르고(떠오른다) → 잠깐 뒤에 말풍선으로 숫자를 말하고 → 결과. (동시에 보이지 않는다)
      expect(c.effect!.stage, DvEffectStage.pick);
      expect(c.liftedTile, w(4));
      expect(c.hiddenOverride, contains(w(4))); // 연출 동안은 아직 세워진 숨은 타일로 보인다
      expect(c.effectBusy, isTrue);
      expect(c.humanCanAct, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(c.effect!.stage, DvEffectStage.ask);
      expect(c.liftedTile, w(4)); // 고른 타일은 말하는 동안에도 떠 있다
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.effect?.stage, DvEffectStage.result);
      expect(c.effect!.correct, isTrue);
      expect(c.liftedTile, isNull);
      expect(c.hiddenOverride, isEmpty); // 맞혔으니 이제 눕는다
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.effect, isNull);
      expect(c.effectBusy, isFalse);
      expect(seen.first, startsWith('pick:true:true'));
      expect(seen.any((x) => x.startsWith('ask:true:true')), isTrue);
      c.dispose();
    });

    test('틀리면 ✕가 뜨고 고른 타일은 제자리로 돌아가며, 상대가 뽑았던 타일은 결과 뒤에 공개된다', () async {
      final c = opponentTurn();
      expect(c.receiveMove(DvMove.guess(0, 1, 9), index: 0), isTrue); // 틀림
      expect(c.effect!.guesserTile, w(7));
      expect(c.hiddenOverride, contains(w(7))); // 상대의 뽑은 타일은 아직 숨은 채
      expect(c.state.isRevealed(w(7)), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(c.effect!.stage, DvEffectStage.result);
      expect(c.effect!.correct, isFalse);
      expect(c.liftedTile, isNull); // 떠 있던 타일이 내려왔다
      expect(c.hiddenOverride, contains(w(7))); // 아직 눕지 않았다
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.hiddenOverride, isEmpty); // 연출이 끝나면 공개(눕힘)
      expect(c.turn, 0);
      c.dispose();
    });

    test('CPU도 수마다 연출을 보이고, 연출이 끝나야 다음 수를 둔다', () async {
      final c = DavinciController(mode: PlayMode.vsCpu, humanSeat: 0, seed: 3, animate: true)..cpuStepDelay = const Duration(milliseconds: 20);
      c.state.blackPool
        ..clear()
        ..add(b(5));
      c.state.whitePool.clear();
      expect(c.draw(0), isTrue);
      c.selectTarget(1, 0);
      final actual = dvNumber(c.state.rows[1][0]);
      // 일부러 틀리게 맞혀서 CPU 차례로 넘긴다
      c.guess(dvIsJoker(c.state.rows[1][0]) ? 0 : (actual == 11 ? 10 : actual + 1));
      final kinds = <int>[];
      c.addListener(() {
        final e = c.effect;
        if (e != null && e.actor == 1 && (kinds.isEmpty || kinds.last != e.kind)) kinds.add(e.kind);
      });
      for (var i = 0; i < 200 && c.turn != 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(kinds, isNotEmpty);
      expect(kinds.contains(2), isTrue); // 맞히는 수를 보여 줬다
      c.dispose();
    });

    test('연출을 끄면 (시험용) 막지 않고 바로 반영된다', () {
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: 5, animate: false);
      expect(c.effectBusy, isFalse);
      c.state.turn = 1;
      c.state.phase = DvPhase.draw;
      expect(c.receiveMove(DvMove.drawMove(0), index: 0), isTrue);
      expect(c.effect, isNull);
      c.dispose();
    });
  });

  group('기록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('저장하고 불러온다', () async {
      await DvHistory.add(const DvRecord(at: 1, vsCpu: true, players: 3, winner: 0, human: 0, turns: 40, level: DvLevel.hard));
      await DvHistory.add(const DvRecord(at: 2, vsCpu: false, online: true, players: 4, winner: 2, human: 1, turns: 30, resigned: true));
      final list = await DvHistory.load();
      expect(list.length, 2);
      expect(list[0].humanWon, isFalse);
      expect(list[0].resigned, isTrue);
      expect(list[1].level, DvLevel.hard);
      expect(list[1].humanWon, isTrue);
    });

    testWidgets('기록 보드에 CPU 전적과 Wi‑Fi 결과가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recs = [
        const DvRecord(at: 1760000000000, vsCpu: true, players: 2, winner: 0, human: 0, turns: 30, level: DvLevel.normal),
        const DvRecord(at: 1760000100000, vsCpu: false, online: true, players: 3, winner: 1, human: 0, turns: 40),
      ];
      SharedPreferences.setMockInitialValues({'davinci.history': jsonEncode([for (final r in recs.reversed) r.toJson()])});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: const Scaffold(body: DavinciRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이겼어요 · CPU 보통'), findsOneWidget);
      expect(find.text('졌어요 · Wi‑Fi 대결'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('화면', () {
    testWidgets('CPU 대결: 더미를 눌러 뽑고, 상대 타일을 골라 숫자를 맞힌다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], black: [b(4)], white: [w(3)]);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('더미에서 타일을 한 장 뽑아요'), findsWidgets);
      expect(find.byKey(const ValueKey('pile0')), findsOneWidget);
      // 상대의 숨은 타일은 숫자가 안 보이고, 내 타일은 숫자가 보인다
      expect(find.text('9'), findsOneWidget); // 내 흰색 9 (상대 줄에는 숫자가 없다)
      expect(find.text('7'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await settle(tester, rounds: 2);
      expect(c.phase, DvPhase.guess);
      expect(find.byKey(const ValueKey('tile-0-1')), findsOneWidget);
      // 맞힐 타일 고르기 → 숫자 판
      await tester.tap(find.byKey(const ValueKey('tile-1-1')));
      await settle(tester, rounds: 2);
      expect(c.selSeat, 1);
      expect(find.byKey(const ValueKey('num7')), findsOneWidget);
      // 내가 가진 흰색 9는 흰색 타일의 후보가 아니라서 눌리지 않는다
      final nine = tester.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('num9')), matching: find.byType(FilledButton)));
      expect(nine.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('num7')));
      await settle(tester, rounds: 2);
      expect(c.state.isRevealed(w(7)), isTrue);
      expect(find.textContaining('맞혔어요'), findsWidgets);
      expect(find.text('7'), findsOneWidget); // 공개된 타일은 숫자가 보인다
      await tester.tap(find.textContaining('멈추기'));
      await settle(tester, rounds: 6);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('내가 더미에서 뽑으면 타일이 더미에서 내 손패 한가운데를 거쳐 제 자리로 날아오고, 도착하면 줄에 나타난다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], black: [b(4)], white: [w(3)], animate: true);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('fly')), findsOneWidget);
      Opacity wrap() => tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('tile-0-1')), matching: find.byType(Opacity)).first);
      expect(wrap().opacity, 0); // 날아오는 동안 줄에서는 숨겨져 있다
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const ValueKey('fly')), findsOneWidget); // 아직 날아가는 중 (한가운데를 거쳐 가느라 오래 걸린다)
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      expect(wrap().opacity, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('상대가 더미에서 뽑으면 그 더미에서 상대 줄로 타일이 날아간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6), w(9)],
        [b(2), w(7), b(10)],
      ], black: [b(4)], white: [w(3)], mode: PlayMode.wifi, animate: true)
        ..cpuStepDelay = const Duration(milliseconds: 500);
      c.state.turn = 1;
      c.state.phase = DvPhase.draw;
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(c.receiveMove(DvMove.drawMove(0), index: 0), isTrue);
      expect(c.effect?.kind, 0);
      expect(c.effect?.tile, b(4));
      expect(c.effect?.number, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('fly')), findsOneWidget);
      final hidden = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('tile-1-1')), matching: find.byType(Opacity)).first);
      expect(hidden.opacity, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      final shown = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('tile-1-1')), matching: find.byType(Opacity)).first);
      expect(shown.opacity, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('상대가 조커를 뽑아도 자리를 정하기 전에는 아무것도 안 보이고, 정하면 일반 뽑기와 똑같이 한 번에 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [24], mode: PlayMode.wifi, animate: true)
        ..cpuStepDelay = const Duration(milliseconds: 200);
      final sounds = <String>[];
      c.onFeedback = sounds.add;
      c.state.turn = 1;
      c.state.phase = DvPhase.draw;
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      c.onFeedback = sounds.add;
      expect(c.receiveMove(DvMove.drawMove(0), index: 0), isTrue); // 상대가 조커를 뽑는다
      // 아직 자리를 안 정했다: 효과도, 날아가는 타일도, 소리도 없다
      expect(c.effect, isNull);
      expect(sounds, isEmpty);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      expect(c.effect, isNull);
      // 자리를 정하면 뽑기 하나로 보인다 (손패 한가운데를 거쳐 제 자리로 날아간다)
      expect(c.receiveMove(DvMove.placeJoker(1), index: 1), isTrue);
      expect(c.effect?.kind, 0);
      expect(c.effect?.number, 0);
      expect(c.effect?.tile, 24);
      expect(sounds, ['draw']);
      final seenTexts = <String>{};
      var flew = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        flew = flew || find.byKey(const ValueKey('fly')).evaluate().isNotEmpty;
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          final d = t.data ?? '';
          if (d.contains('조커') || d.contains('타일 놓기') || d.contains('뽑기')) seenTexts.add(d);
        }
      }
      expect(flew, isTrue);
      expect(seenTexts.any((x) => x.contains('조커')), isFalse, reason: '상대의 조커가 드러났어요: $seenTexts');
      expect(seenTexts.any((x) => x.contains('타일 놓기')), isFalse, reason: '조커를 뽑으면 놓기 단계가 따로 보여요: $seenTexts');
      expect(seenTexts, contains('검정 뽑기'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CPU가 조커를 뽑아도 일반 타일처럼 뽑기 하나로 보이고 날아가는 모양도 같다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Future<List<String>> run(int tile) async {
        final c = fixed([
          [b(1), b(6)],
          [b(2), w(7)],
        ], black: [tile], animate: true)
          ..cpuStepDelay = const Duration(milliseconds: 200);
        c.state.turn = 1;
        c.state.phase = DvPhase.draw;
        await tester.pumpWidget(await app(DavinciScreen(controller: c)));
        await settle(tester, rounds: 2);
        c.start();
        final log = <String>[];
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          final fly = find.byKey(const ValueKey('fly')).evaluate().isNotEmpty;
          final e = c.effect;
          log.add('${e == null ? '-' : 'k${e.kind}'}${fly ? 'F' : ''}');
        }
        await tester.pumpWidget(const SizedBox());
        return log;
      }

      final normal = await run(b(4));
      final joker = await run(24);
      expect(joker.any((x) => x.startsWith('k1')), isFalse, reason: '조커를 놓는 단계가 따로 보여요: $joker');
      expect(joker.take(10), normal.take(10), reason: '조커 뽑기와 일반 뽑기가 달라 보여요');
      expect(tester.takeException(), isNull);
    });

    testWidgets('상대가 맞혀서 누군가 탈락해도, ○ / ✕ 연출이 끝난 뒤에야 "탈락"이 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
        [w(3)],
      ], mode: PlayMode.wifi, animate: true)
        ..cpuStepDelay = const Duration(milliseconds: 100);
      c.state.turn = 1;
      c.state.phase = DvPhase.guess;
      c.state.drawn = w(7);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 0), isTrue); // 3번 자리의 마지막 숨은 타일을 맞힌다
      expect(c.state.isOut(2), isTrue); // (판 자체는 바로 반영된다)
      await tester.pump();
      expect(find.text('탈락'), findsNothing, reason: '고르는 중에 탈락이 떴어요');
      await tester.pump(const Duration(milliseconds: 150)); // 숫자를 말하는 중
      expect(c.effect!.stage, DvEffectStage.ask);
      expect(find.text('탈락'), findsNothing, reason: '말하는 중에 탈락이 떴어요');
      await tester.pump(const Duration(milliseconds: 150)); // 결과(○)가 보이는 중
      expect(c.effect!.stage, DvEffectStage.result);
      expect(find.text('탈락'), findsNothing, reason: '○가 뜨기도 전에 탈락이 떴어요');
      await tester.pump(const Duration(milliseconds: 400)); // 연출이 끝났다
      expect(c.effect, isNull);
      expect(find.text('탈락'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('조커를 뽑으면 내 줄의 자리 칸이 나타나고, 눌러서 놓는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [24]);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await settle(tester, rounds: 2);
      expect(c.phase, DvPhase.placeJoker);
      expect(find.byKey(const ValueKey('slot0')), findsOneWidget);
      expect(find.byKey(const ValueKey('slot2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('slot1')));
      await settle(tester, rounds: 2);
      expect(c.state.rows[0], [b(1), 24, b(6)]);
      expect(c.phase, DvPhase.guess);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('내가 조커를 뽑으면 손패 한가운데로 날아가 떠 있다가, 자리를 정하면 그 자리로 날아간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [24], animate: true);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('fly')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      expect(find.byKey(const ValueKey('hover')), findsOneWidget); // 자리를 정할 때까지 떠 있다
      await tester.tap(find.byKey(const ValueKey('slot1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('hover')), findsNothing);
      expect(find.byKey(const ValueKey('fly')), findsOneWidget);
      Opacity wrap() => tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('tile-0-1')), matching: find.byType(Opacity)).first);
      expect(wrap().opacity, 0);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('fly')), findsNothing);
      expect(wrap().opacity, 1);
      expect(c.state.rows[0], [b(1), 24, b(6)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('더미가 비어서 틀리면 내 숨은 타일을 눌러 공개한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ]);
      await tester.pumpWidget(await app(DavinciScreen(controller: c)));
      await tester.tap(find.byKey(const ValueKey('tile-1-0')));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const ValueKey('num5')));
      await settle(tester, rounds: 2);
      expect(c.phase, DvPhase.reveal);
      expect(find.textContaining('내 숨은 타일 하나를 눌러 공개'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('tile-0-1')));
      await settle(tester, rounds: 2);
      expect(c.state.isRevealed(b(6)), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('설정 화면: CPU 수와 난이도를 고르고 시작하면 판이 열리고, Wi‑Fi 방 설정에는 인원 선택 없이 내 순서가 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const DavinciSetupScreen(mode: PlayMode.vsCpu)));
      await settle(tester, rounds: 2);
      await tester.tap(find.text('3명'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await settle(tester, rounds: 3);
      final screen = tester.widget<DavinciScreen>(find.byType(DavinciScreen));
      expect(screen.players, 4);
      expect(find.text('CPU 1'), findsWidgets);
      expect(find.text('CPU 3'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, rounds: 20);

      await tester.pumpWidget(await app(const DavinciSetupScreen(mode: PlayMode.wifi)));
      await settle(tester, rounds: 2);
      // Wi‑Fi 방은 인원수를 미리 정하지 않는다 (모이는 대로 방장이 시작 단추로 정한다)
      expect(find.text('몇 명이 할까요?'), findsNothing);
      expect(find.text('방 열기'), findsOneWidget);
      expect(find.text('내 순서'), findsOneWidget);
      expect(find.text('무작위'), findsOneWidget);
      expect(find.text('두 번째'), findsOneWidget);
      expect(find.text('3번째'), findsNothing);
      expect(tester.takeException(), isNull);
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
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: 21);
      await tester.pumpWidget(await app(DavinciScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await settle(tester, rounds: 3);
      expect(received.single['t'], 'move');
      expect(received.single['i'], 0);
      expect(received.single['mv'], [0, 0]);
      expect(c.humanCanAct, isTrue); // 뽑은 뒤에도 내 차례 (이제 맞힌다)
      // 일부러 틀리게 맞혀서 차례를 넘긴다
      final actual = dvNumber(c.state.rows[1][0]);
      c.selectTarget(1, 0);
      expect(c.guess(actual == 11 ? 10 : actual + 1), isTrue);
      await settle(tester, rounds: 3);
      expect(received.last['mv'], [2, 1, 0, actual == 11 ? 10 : actual + 1]);
      expect(c.humanCanAct, isFalse);
      // 상대의 수: 상대는 흰색 더미에서 뽑는다
      theirs.send({'t': 'move', 'i': 2, 'mv': [0, 1]});
      await settle(tester, rounds: 3);
      expect(c.moveCount, 3);
      expect(c.state.rows[1].length, greaterThan(4));
      expect(find.text('새 판'), findsNothing); // Wi‑Fi 대결에는 새 판이 없다
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('내가 조커를 뽑으면 자리를 정할 때까지 상대에게 아무것도 보내지 않고, 정하면 두 수를 이어서 보낸다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final received = <Map<String, dynamic>>[];
      theirs.messages.listen(received.add);
      final c = fixed([
        [b(1), b(6)],
        [b(2), w(7)],
      ], black: [24], mode: PlayMode.wifi);
      await tester.pumpWidget(await app(DavinciScreen(mode: PlayMode.wifi, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const ValueKey('pile0')));
      await settle(tester, rounds: 3);
      expect(c.phase, DvPhase.placeJoker);
      expect(received, isEmpty, reason: '조커를 뽑은 걸 상대가 알아요');
      await tester.tap(find.byKey(const ValueKey('slot1')));
      await settle(tester, rounds: 3);
      expect(received.map((m) => m['mv']).toList(), [
        [0, 0],
        [1, 1],
      ]);
      expect(received.map((m) => m['i']).toList(), [0, 1]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('상대가 기권하면 내 승리로 기록된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 1, seed: 21);
      await tester.pumpWidget(await app(DavinciScreen(mode: PlayMode.wifi, humanSeat: 1, controller: c, link: mine)));
      await settle(tester, rounds: 2);
      theirs.send({'t': 'move', 'i': 0, 'mv': [0, 0]});
      await settle(tester, rounds: 3);
      theirs.send(const {'t': 'resign'});
      await settle(tester, rounds: 4);
      expect(c.halted, isTrue);
      final h = (await tester.runAsync(DvHistory.load))!;
      expect(h.length, 1);
      expect(h.single.online, isTrue);
      expect(h.single.resigned, isTrue);
      expect(h.single.humanWon, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('규칙에 안 맞는 상대의 수가 오면 알리고 나간다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final (mine, theirs) = (await tester.runAsync(connectionPair))!;
      final c = DavinciController(mode: PlayMode.wifi, humanSeat: 0, seed: 21);
      await tester.pumpWidget(await app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DavinciScreen(mode: PlayMode.wifi, controller: c, link: mine),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('열기'));
      await settle(tester, rounds: 3);
      theirs.send({'t': 'move', 'i': 0, 'mv': [0, 0]}); // 내 차례에 상대가 수를 보냈다
      await settle(tester, rounds: 4);
      expect(find.text('판이 서로 어긋났어요'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await settle(tester, rounds: 3);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DavinciScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(theirs.close);
    });

    testWidgets('방을 열고 찾아 들어가면 두 화면이 같은 씨앗·반대 자리로 시작한다 (2명)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      const discovery = 46101;
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
        builder: (_) => const DavinciHostScreen(hostSide: 1, gamePort: 0, discoveryPort: discovery, seed: 777),
      )));
      await settle(tester, rounds: 4);
      expect(find.text('방이 열렸어요'), findsOneWidget);
      expect(find.text('내가 두 번째로 시작'), findsOneWidget);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const DavinciJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.textContaining('다빈치 코드 · 2명'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      for (var i = 0; i < 60 && find.byType(DavinciScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<DavinciScreen>(find.byType(DavinciScreen, skipOffstage: false)).toList();
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
      const discovery = 46102;
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
        builder: (_) => const DavinciHostScreen(hostSide: 0, players: 3, cpus: 1, gamePort: 0, discoveryPort: discovery, seed: 778),
      )));
      await settle(tester, rounds: 4);
      expect(find.textContaining('3명 (사람 2 + CPU 1)'), findsWidgets);

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const DavinciJoinScreen(discoveryPort: discovery, extraTargets: ['127.0.0.1']),
      )));
      for (var i = 0; i < 40 && find.widgetWithText(FilledButton, '들어가기').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle(tester, rounds: 2);
      expect(find.textContaining('다빈치 코드 · 3명 (사람 2 + CPU 1)'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '들어가기').first);
      for (var i = 0; i < 60 && find.byType(DavinciScreen, skipOffstage: false).evaluate().length < 2; i++) {
        await settle(tester, rounds: 1);
      }
      await settle(tester, rounds: 2);
      final screens = tester.widgetList<DavinciScreen>(find.byType(DavinciScreen, skipOffstage: false)).toList();
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

  group('사람 + CPU 방 (컨트롤러)', () {
    test('사람 3명 + CPU 1명: 방장이 CPU의 수를 정해 알리고, 모든 기기가 같은 판으로 끝난다 (한 판 더도)', () async {
      final rng = Random(8);
      DavinciController make(int seat, {bool host = false}) =>
          DavinciController(mode: PlayMode.wifi, players: 4, humanSeat: seat, seed: 21, cpuSeats: [3], cpuHost: host)..cpuStepDelay = Duration.zero;
      final hostC = make(0, host: true), g1 = make(1), g2 = make(2);
      expect([hostC.runsCpu, g1.runsCpu, g2.runsCpu], [true, false, false]);
      var cpuMoves = 0;
      // 별 모양으로 잇는다: 방장은 모두에게, 손님은 방장에게 보내고 방장이 다른 손님에게 전해 준다
      hostC.onLocalMove = (m) {
        if (hostC.turn == 3 || hostC.state.lastGuess?.guesser == 3) cpuMoves++;
        final i = hostC.moveCount - 1;
        expect(g1.receiveMove(m, index: i), isTrue);
        expect(g2.receiveMove(m, index: i), isTrue);
      };
      g1.onLocalMove = (m) {
        final i = g1.moveCount - 1;
        expect(hostC.receiveMove(m, index: i), isTrue);
        expect(g2.receiveMove(m, index: i), isTrue);
      };
      g2.onLocalMove = (m) {
        final i = g2.moveCount - 1;
        expect(hostC.receiveMove(m, index: i), isTrue);
        expect(g1.receiveMove(m, index: i), isTrue);
      };

      Future<void> playOut() async {
        for (var i = 0; i < 4000 && !hostC.isOver; i++) {
          await Future<void>.delayed(Duration.zero);
          for (final c in [hostC, g1, g2]) {
            if (c.humanCanAct) playAi(c, rng);
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(hostC.isOver, isTrue, reason: '판이 끝나지 않았어요');
        for (final c in [g1, g2]) {
          expect(c.isOver, isTrue);
          expect(c.moves, hostC.moves);
          expect(c.state.winner, hostC.state.winner);
          expect(c.state.rows, hostC.state.rows);
        }
      }

      hostC.start();
      await playOut();
      expect(cpuMoves, greaterThan(0), reason: 'CPU가 한 번도 안 뒀어요');

      // 한 판 더: 사람과 CPU 자리가 함께 한 칸씩 돌고, 이번엔 0번 자리의 CPU가 먼저 둔다
      for (final c in [hostC, g1, g2]) {
        c.restart();
      }
      expect(hostC.cpuSeats, {0});
      expect([hostC.humanSeat, g1.humanSeat, g2.humanSeat], [1, 2, 3]);
      cpuMoves = 0;
      await playOut();
      expect(cpuMoves, greaterThan(0));
      for (final c in [hostC, g1, g2]) {
        c.dispose();
      }
    });
  });
}
