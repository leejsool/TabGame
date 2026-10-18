import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/hub_screen.dart';

Future<void> pumpHub(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: HubScreen(settings: settings))));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 지금 목록에 나온 게임 카드들의 게임 id (화면 밖이어도 만들어진 카드까지).
List<String> shownGames(WidgetTester tester) =>
    [for (final c in tester.widgetList<GameCard>(find.byType(GameCard, skipOffstage: false))) c.game.id];

void main() {
  test('같은 Wi‑Fi로 할 수 있는 게임은 Wi‑Fi 모드를 가진다', () {
    final wifi = {for (final g in allGames) if (g.hasWifi) g.id};
    expect(wifi, {'ultimate_tictactoe', 'sprouts', 'dandelion', 'prophecy', 'rummikub', 'quoridor', 'goblet_gobblers', 'davinci_code'});
    // 루미큐브는 남의 패가 보이면 안 되니 한 기기에서 둘이 하는 모드가 없다
    final rummikub = allGames.firstWhere((g) => g.id == 'rummikub');
    expect(rummikub.modes, [PlayMode.vsCpu, PlayMode.wifi]);
  });

  for (final size in const [Size(360, 780), Size(1000, 700)]) {
    testWidgets('Wi‑Fi로 할 수 있는 게임 카드에만 Wi‑Fi 표시가 붙는다 ($size)', (tester) async {
      await pumpHub(tester, size);
      for (final g in allGames.where((g) => g.isReady)) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: SizedBox(width: size.width < 600 ? 165 : 300, height: 220, child: GameCard(game: g, compact: size.width < 600, onTap: () {})))),
        ));
        // Wi‑Fi는 카드 아래 모드 칩으로 한 번만 보인다 (위쪽 동그라미 표시는 없앴다)
        final chip = find.descendant(of: find.byType(GameCard), matching: find.text('Wi‑Fi'));
        expect(chip, g.hasWifi ? findsOneWidget : findsNothing, reason: g.title);
        expect(tester.takeException(), isNull, reason: g.title);
      }
    });

    testWidgets('필터로 Wi‑Fi 게임만, 교과학습 게임만 모아 볼 수 있다 ($size)', (tester) async {
      await pumpHub(tester, size);
      expect(shownGames(tester).length, greaterThan(allGames.where((g) => g.hasWifi).length));

      await tester.tap(find.byTooltip('Wi‑Fi'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shownGames(tester).toSet(), {for (final g in allGames) if (g.hasWifi) g.id});
      expect(find.text('같은 Wi‑Fi로 함께'), findsOneWidget);

      await tester.tap(find.byTooltip('교과학습'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shownGames(tester).toSet(), {for (final g in allGames) if (g.hasLesson) g.id});
      expect(find.text('교과학습이 있는 게임'), findsOneWidget);

      await tester.tap(find.byTooltip('전체'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shownGames(tester), contains('sudoku')); // (목록은 보이는 만큼만 만들어진다)
      expect(find.text('혼자 놀기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
