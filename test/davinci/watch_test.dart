import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/data/davinci_history.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';

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

/// 3명(나 + CPU 둘): 내 숨은 타일은 하나뿐이고, 더미는 비어 있어서 틀리면 내 타일을 공개해야 한다.
DavinciController threePlayers() {
  final c = DavinciController(mode: PlayMode.vsCpu, players: 3, humanSeat: 0, seed: 3, animate: false)..cpuStepDelay = Duration.zero;
  final tiles = [
    [b(1)],
    [b(2), w(7)],
    [b(3), w(8)],
  ];
  for (var i = 0; i < tiles.length; i++) {
    c.state.rows[i]
      ..clear()
      ..addAll(tiles[i]);
  }
  c.state.blackPool.clear();
  c.state.whitePool.clear();
  c.state.revealed.clear();
  c.state.turn = 0;
  c.state.drawn = null;
  c.state.pendingJoker = null;
  c.state.phase = DvPhase.guess;
  return c;
}

/// 내가 틀리게 맞혀서 내 마지막 타일을 직접 공개하고 탈락한다.
Future<void> eliminateHuman(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tile-1-0')));
  await settle(tester, rounds: 2);
  await tester.tap(find.byKey(const ValueKey('num5')));
  await settle(tester, rounds: 2);
  await tester.tap(find.byKey(const ValueKey('tile-0-0')));
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  test('사람이 모두 탈락하고 CPU가 둘 이상 남았을 때만 "사람 전원 탈락"이다', () {
    final c = threePlayers();
    expect(c.humansAllOut, isFalse);
    c.state.revealed.add(b(1)); // 내 타일이 모두 공개됐다
    expect(c.humansAllOut, isTrue);
    expect(c.endWatching(), isTrue);
    expect(c.halted, isTrue);
    expect(c.endedWatching, isTrue);
    expect(c.resignWinner, anyOf(1, 2)); // 이긴 쪽은 남은 CPU 중 하나
    expect(c.humansAllOut, isFalse); // 이미 끝낸 판
    c.dispose();
  });

  testWidgets('내가 탈락하면 계속 볼지 끝낼지 묻고, 묻는 동안 CPU는 기다린다', (tester) async {
    bigScreen(tester);
    final c = threePlayers();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await settle(tester, rounds: 2);
    await eliminateHuman(tester);
    await settle(tester, rounds: 3);
    expect(c.state.isOut(0), isTrue);
    expect(find.text('내 타일이 모두 공개됐어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('dv-end-game')), findsOneWidget);
    expect(find.byKey(const ValueKey('dv-keep-watching')), findsOneWidget);
    final movesWhileAsking = c.moveCount;
    await settle(tester, rounds: 6);
    expect(c.moveCount, movesWhileAsking, reason: '묻는 동안 CPU가 수를 뒀어요');

    // 계속 지켜보기: 창이 닫히고 CPU가 다시 두며, 같은 판에서 또 묻지 않는다
    await tester.tap(find.byKey(const ValueKey('dv-keep-watching')));
    await settle(tester, rounds: 8);
    expect(find.text('내 타일이 모두 공개됐어요'), findsNothing);
    expect(c.moveCount, greaterThan(movesWhileAsking));
    expect(c.halted, isFalse);
    expect(find.text('내 타일이 모두 공개됐어요'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 10);
  });

  testWidgets('끝내기를 고르면 진 것으로 기록하고 판이 멈추며, 새 판을 시작할 수 있다', (tester) async {
    bigScreen(tester);
    final c = threePlayers();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await settle(tester, rounds: 2);
    await eliminateHuman(tester);
    await settle(tester, rounds: 3);
    await tester.tap(find.byKey(const ValueKey('dv-end-game')));
    await settle(tester, rounds: 10); // (기록을 저장하는 동안 실제 시간이 필요하다)
    expect(c.halted, isTrue);
    expect(c.endedWatching, isTrue);
    expect(find.text('게임을 끝냈어요'), findsOneWidget);
    final records = await tester.runAsync(DvHistory.load);
    expect(records!.length, 1);
    expect(records.first.humanWon, isFalse);
    expect(records.first.players, 3);
    final moves = c.moveCount;
    await settle(tester, rounds: 6);
    expect(c.moveCount, moves, reason: '끝낸 뒤에도 CPU가 수를 뒀어요');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('새 판')));
    await settle(tester, rounds: 3);
    expect(c.halted, isFalse);
    expect(c.endedWatching, isFalse);
    expect(c.watchPrompted, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 10);
  });

  testWidgets('2명 판에서 내가 탈락하면 바로 끝난 판이라 묻지 않는다', (tester) async {
    bigScreen(tester);
    final c = DavinciController(mode: PlayMode.vsCpu, players: 2, humanSeat: 0, seed: 3, animate: false)..cpuStepDelay = Duration.zero;
    c.state.rows[0]
      ..clear()
      ..add(b(1));
    c.state.rows[1]
      ..clear()
      ..addAll([b(2), w(7)]);
    c.state.blackPool.clear();
    c.state.whitePool.clear();
    c.state.revealed.clear();
    c.state.turn = 0;
    c.state.drawn = null;
    c.state.phase = DvPhase.guess;
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await settle(tester, rounds: 2);
    await eliminateHuman(tester);
    await settle(tester, rounds: 4);
    expect(c.isOver, isTrue);
    expect(find.text('내 타일이 모두 공개됐어요'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 10);
  });
}
