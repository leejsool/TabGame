import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';
import 'package:tabgame/games/davinci/game/davinci_controller.dart';
import 'package:tabgame/games/davinci/ui/davinci_screen.dart';
import 'package:tabgame/games/davinci/ui/davinci_tiles.dart';

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

/// 3명 Wi‑Fi 판: 내가 0번, 1번이 맞히는 중이고 더미는 비어 있다. 연출을 켠다.
DavinciController threeWifi() {
  final c = DavinciController(mode: PlayMode.wifi, players: 3, humanSeat: 0, seed: 3, animate: true)
    ..cpuStepDelay = const Duration(milliseconds: 100);
  final rows = [
    [b(1), b(6)],
    [b(2), w(7)],
    [w(3), b(4), b(5)],
  ];
  for (var i = 0; i < rows.length; i++) {
    c.state.rows[i]
      ..clear()
      ..addAll(rows[i]);
  }
  c.state.blackPool.clear();
  c.state.whitePool.clear();
  c.state.revealed.clear();
  c.state.turn = 1;
  c.state.drawn = null;
  c.state.pendingJoker = null;
  c.state.phase = DvPhase.guess;
  return c;
}

DvTile tile(WidgetTester tester, String key) => tester.widget<DvTile>(find.byKey(ValueKey(key)));

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('상대가 연달아 맞혀도, 앞의 추측 연출이 끝나기 전에는 뒤의 추측 결과가 판에 먼저 나타나지 않는다', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));

    // 한꺼번에 도착한 두 번의 추측: 3번 자리의 첫째(흰 3), 둘째(검정 4)
    expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 0), isTrue);
    expect(c.receiveMove(DvMove.guess(2, 1, 4), index: 1), isTrue); // 줄 서서 기다린다
    expect(c.state.isRevealed(b(4)), isFalse, reason: '둘째 추측이 첫째 연출보다 먼저 판에 반영됐어요');
    await tester.pump();
    expect(tile(tester, 'tile-2-1').lying, isFalse, reason: '둘째 타일이 먼저 공개돼 보였어요');
    expect(c.moveCount, 1);

    // 첫째 연출이 흘러가는 동안에도 둘째는 아직 안 보인다
    await tester.pump(const Duration(milliseconds: 150));
    expect(c.state.isRevealed(b(4)), isFalse);
    expect(tile(tester, 'tile-2-1').lying, isFalse);

    // 첫째 연출이 끝나면 둘째가 반영되고 그 연출이 시작된다
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.state.isRevealed(b(4)), isTrue);
    expect(c.moveCount, 2);
    expect(c.effect, isNotNull);
    expect(c.effect!.tile, b(4));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(c.effect, isNull);
    expect(tile(tester, 'tile-2-1').lying, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('줄 서 있는 수가 규칙에 안 맞으면 바로 거절한다 (줄 서 있는 수까지 둔 모습으로 확인)', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 0), isTrue);
    expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 1), isFalse, reason: '이미 맞혀서 공개된 타일을 또 맞혔는데 받아들여졌어요');
    expect(c.receiveMove(DvMove.guess(2, 1, 4), index: 5), isFalse, reason: '순서 번호가 어긋났는데 받아들여졌어요');
    expect(c.receiveMove(DvMove.guess(2, 1, 4), index: 1), isTrue);
    expect(c.receiveMove(DvMove.stop, index: 2), isTrue);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(c.moveCount, 3);
    expect(c.turn, 2); // 멈추고 차례가 넘어갔다
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('상대가 타일을 고르면 그 타일이 떠오르고 "고민 중…"이 보이며, 수를 두면 연출로 이어진다', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('고민 중…'), findsNothing);

    c.receiveSelection(1, 2, 0); // 1번 사람이 3번 자리의 첫째 타일을 골랐다
    await tester.pump();
    expect(c.remoteSel, (actor: 1, seat: 2, index: 0));
    expect(find.text('고민 중…'), findsOneWidget);
    expect(tile(tester, 'tile-2-0').lifted, isTrue);
    expect(tile(tester, 'tile-2-1').lifted, isFalse);

    // 다른 타일로 바꾸면 따라 바뀐다
    c.receiveSelection(1, 2, 2);
    await tester.pump();
    expect(tile(tester, 'tile-2-0').lifted, isFalse);
    expect(tile(tester, 'tile-2-2').lifted, isTrue);

    // 고름을 풀면 사라진다
    c.receiveSelection(1, -1, -1);
    await tester.pump();
    expect(find.text('고민 중…'), findsNothing);

    // 다시 골랐다가 실제로 맞히면 표시는 지워지고 맞히는 연출이 이어진다
    c.receiveSelection(1, 2, 0);
    await tester.pump();
    expect(find.text('고민 중…'), findsOneWidget);
    expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 0), isTrue);
    await tester.pump();
    expect(c.remoteSel, isNull);
    expect(find.text('고민 중…'), findsNothing);
    expect(c.effect!.kind, 2);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앞의 수를 보여 주는 동안 도착한 "고르는 중" 소식은 연출이 끝난 뒤에 보인다', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    expect(c.receiveMove(DvMove.guess(2, 0, 3), index: 0), isTrue);
    await tester.pump();
    c.receiveSelection(1, 2, 1); // 첫째 추측을 보여 주는 중에 다음 타일을 골랐다
    await tester.pump(const Duration(milliseconds: 150));
    expect(c.remoteSel, isNull, reason: '앞의 연출이 끝나기 전에 다음 선택이 보였어요');
    await tester.pump(const Duration(seconds: 6));
    expect(c.remoteSel, (actor: 1, seat: 2, index: 1));
    expect(find.text('고민 중…'), findsOneWidget);
    expect(tile(tester, 'tile-2-1').lifted, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('차례가 아닌 사람이나 이미 공개된 타일을 고른다는 소식은 무시한다', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    c.receiveSelection(2, 0, 0); // 2번 사람은 지금 차례가 아니다
    await tester.pump();
    expect(c.remoteSel, isNull);
    c.receiveSelection(1, 1, 0); // 자기 줄은 고를 수 없다
    expect(c.remoteSel, isNull);
    c.receiveSelection(1, 2, 9); // 없는 순서
    expect(c.remoteSel, isNull);
    c.state.revealed.add(w(3));
    c.receiveSelection(1, 2, 0); // 이미 공개된 타일
    expect(c.remoteSel, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('내가 상대 타일을 고르거나 풀면 다른 기기에 알릴 수 있다', (tester) async {
    bigScreen(tester);
    final c = threeWifi();
    c.state.turn = 0; // 내 차례
    final sent = <(int, int)>[];
    c.onLocalSelect = (seat, index) => sent.add((seat, index));
    await tester.pumpWidget(await app(DavinciScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    c.selectTarget(2, 1);
    expect(sent, [(2, 1)]);
    c.selectTarget(2, 2); // 다른 타일로 바꿈
    expect(sent.last, (2, 2));
    c.selectTarget(2, 2); // 같은 타일을 다시 누르면 고름이 풀린다
    expect(sent.last, (-1, -1));
    c.selectTarget(1, 0);
    c.clearSelection();
    expect(sent.last, (-1, -1));
    await tester.pumpWidget(const SizedBox());
  });
}
