import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/game_visibility_screen.dart';
import 'package:tabgame/hub/hub_screen.dart';
import 'package:tabgame/hub/settings_screen.dart';

List<String> shownGames(WidgetTester tester) =>
    [for (final c in tester.widgetList<GameCard>(find.byType(GameCard, skipOffstage: false))) c.game.id];

Future<Settings> pumpHub(WidgetTester tester, {Map<String, Object> prefs = const {}, Size size = const Size(1000, 6000)}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await Settings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: HubScreen(settings: settings))));
  await tester.pump(const Duration(milliseconds: 300));
  return settings;
}

void main() {
  test('처음에는 모든 게임이 보이고, 끄고 켠 것이 기기에 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    var settings = await Settings.load();
    expect(settings.hiddenGames, isEmpty);
    expect(allGames.every((g) => settings.isGameVisible(g.id)), isTrue);

    settings.setGameVisible('sudoku', false);
    settings.setGameVisible('rummikub', false);
    settings.setGameVisible('sudoku', false); // (같은 값이면 아무 일도 없다)
    expect(settings.isGameVisible('sudoku'), isFalse);
    expect(settings.hiddenGames, {'sudoku', 'rummikub'});

    // 앱을 다시 켜도 그대로
    settings = await Settings.load();
    expect(settings.hiddenGames, {'sudoku', 'rummikub'});
    settings.setGameVisible('sudoku', true);
    expect(settings.hiddenGames, {'rummikub'});
    settings.showAllGames();
    expect(settings.hiddenGames, isEmpty);
    settings = await Settings.load();
    expect(settings.hiddenGames, isEmpty);
  });

  test('바뀔 때만 화면에 알린다', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    var n = 0;
    settings.addListener(() => n++);
    settings.setGameVisible('sudoku', true); // 이미 보임: 변화 없음
    settings.showAllGames(); // 숨긴 게 없음: 변화 없음
    expect(n, 0);
    settings.setGameVisible('sudoku', false);
    expect(n, 1);
  });

  testWidgets('메인 화면: 기본은 모든 게임, 숨긴 게임은 빠지고 다시 켜면 돌아온다', (tester) async {
    final settings = await pumpHub(tester);
    expect(shownGames(tester).toSet(), {for (final g in allGames) g.id});

    settings.setGameVisible('sudoku', false);
    settings.setGameVisible('dot_cannon', false);
    await tester.pump();
    final shown = shownGames(tester);
    expect(shown.contains('sudoku'), isFalse);
    expect(shown.contains('dot_cannon'), isFalse);
    expect(shown.contains('minesweeper'), isTrue);

    settings.showAllGames();
    await tester.pump();
    expect(shownGames(tester).toSet(), {for (final g in allGames) g.id});
  });

  testWidgets('저장해 둔 숨김이 앱을 켜면 바로 반영된다 (필터를 바꿔도 숨긴 게임은 안 나온다)', (tester) async {
    await pumpHub(tester, prefs: {
      'hiddenGames': ['goblet_gobblers', 'quoridor'],
    });
    expect(shownGames(tester).contains('goblet_gobblers'), isFalse);
    expect(shownGames(tester).contains('quoridor'), isFalse);
    // Wi‑Fi 분류로 모아 봐도 숨긴 게임은 빠진다
    await tester.tap(find.byTooltip('Wi‑Fi'));
    await tester.pump(const Duration(milliseconds: 300));
    final wifi = shownGames(tester);
    expect(wifi.contains('rummikub'), isTrue);
    expect(wifi.contains('quoridor'), isFalse);
  });

  testWidgets('한 묶음의 게임을 모두 숨기면 그 묶음 제목도 사라진다', (tester) async {
    final settings = await pumpHub(tester);
    expect(find.text('함께 놀기'), findsOneWidget);
    for (final g in allGames.where((g) => g.hasMulti)) {
      settings.setGameVisible(g.id, false);
    }
    await tester.pump();
    expect(find.text('함께 놀기'), findsNothing);
    expect(find.text('혼자 놀기'), findsOneWidget);
  });

  testWidgets('게임을 전부 숨기면 안내와 "모든 게임 다시 보이기" 단추가 나온다', (tester) async {
    final settings = await pumpHub(tester);
    for (final g in allGames) {
      settings.setGameVisible(g.id, false);
    }
    await tester.pump();
    expect(shownGames(tester), isEmpty);
    expect(find.byKey(const ValueKey('hub-all-hidden')), findsOneWidget);
    await tester.tap(find.text('모든 게임 다시 보이기'));
    await tester.pump();
    expect(find.byKey(const ValueKey('hub-all-hidden')), findsNothing);
    expect(shownGames(tester).toSet(), {for (final g in allGames) g.id});
  });

  testWidgets('설정 화면 → 메인 화면에 보일 게임: 스위치로 끄고 켜고, "모두 켜기"로 되돌린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: SettingsScreen(settings: settings))));
    await tester.pump();
    expect(find.text('메인 화면에 보일 게임'), findsOneWidget);
    expect(find.textContaining('모든 게임이 보여요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-visible-games')));
    await tester.pumpAndSettle();
    expect(find.byType(GameVisibilityScreen), findsOneWidget);
    expect(find.byType(SwitchListTile), findsWidgets);
    // 모두 켜져 있다
    final first = tester.widget<SwitchListTile>(find.byKey(ValueKey('visible-${allGames.first.id}')));
    expect(first.value, isTrue);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('visibility-show-all'))).onPressed, isNull);

    // 하나 끄기
    final tile = find.byKey(const ValueKey('visible-sudoku'));
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.pump();
    expect(settings.isGameVisible('sudoku'), isFalse);
    expect(find.textContaining('개 중 ${allGames.length - 1}개가 보여요'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('visibility-show-all'))).onPressed, isNotNull);

    // 모두 켜기
    await tester.tap(find.byKey(const ValueKey('visibility-show-all')));
    await tester.pump();
    expect(settings.hiddenGames, isEmpty);

    // 설정 화면에는 몇 개가 보이는지 나온다
    settings.setGameVisible('sudoku', false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('${allGames.length}개 중 ${allGames.length - 1}개가 보여요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('게임 목록 화면의 모든 게임 줄이 폰 크기에서도 오류 없이 그려진다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: GameVisibilityScreen(settings: settings))));
    await tester.pump();
    for (final g in allGames) {
      // (화면 바로 밖에 미리 만들어 둔 줄도 찾아서 화면 안으로 끌어온다)
      final tile = find.byKey(ValueKey('visible-${g.id}'), skipOffstage: false);
      await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(tile);
      await tester.pump();
      expect(find.byKey(ValueKey('visible-${g.id}')), findsOneWidget, reason: g.title);
    }
    expect(tester.takeException(), isNull);
  });
}
