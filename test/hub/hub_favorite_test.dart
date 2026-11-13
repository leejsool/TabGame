import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/hub_screen.dart';

/// 허브의 즐겨찾기(별표)와 꾹 눌러 끌어서 순서 바꾸기.
void main() {
  Future<Settings> pumpHub(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final settings = await Settings.load();
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: HubScreen(settings: settings))));
    await tester.pump(const Duration(milliseconds: 300));
    return settings;
  }

  final allIds = [for (final g in allGames) g.id];

  testWidgets('카드에는 이름만 있고(작은 설명 글 없음), 빈 별을 누르면 채워지면서 맨 위 "즐겨찾기" 묶음으로 올라간다', (tester) async {
    final settings = await pumpHub(tester);
    final sudoku = allGames.firstWhere((g) => g.id == 'sudoku');
    expect(find.text(sudoku.tagline), findsNothing);
    expect(find.text('즐겨찾기'), findsNothing);

    final card = find.byKey(const ValueKey('hub-solo-sudoku'));
    await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.star_border_rounded)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.favoriteGames, ['sudoku']);
    expect(find.text('즐겨찾기'), findsOneWidget);
    final fav = find.byKey(const ValueKey('hub-fav-sudoku'));
    expect(find.descendant(of: fav, matching: find.byIcon(Icons.star_rounded)), findsOneWidget);
    expect(find.byKey(const ValueKey('hub-solo-sudoku')), findsNothing, reason: '아래 묶음에는 두 번 나오지 않는다');
    // 즐겨찾기 묶음이 다른 묶음보다 위에 있다
    expect(tester.getTopLeft(fav).dy, lessThan(tester.getTopLeft(find.text('혼자 놀기')).dy));

    // 다시 누르면 빠진다
    await tester.tap(find.descendant(of: fav, matching: find.byIcon(Icons.star_rounded)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.favoriteGames, isEmpty);
    expect(find.text('즐겨찾기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카드를 꾹 눌렀다가 다른 카드 위로 끌면 그 자리로 옮겨지고, 껐다 켜도 그 순서다', (tester) async {
    final settings = await pumpHub(tester);
    final before = [for (final g in allGames.where((g) => g.inSoloSection)) g.id];
    final a = find.byKey(ValueKey('hub-solo-${before[0]}')), c = find.byKey(ValueKey('hub-solo-${before[2]}'));
    final to = tester.getCenter(c);
    final g = await tester.startGesture(tester.getCenter(a));
    await tester.pump(const Duration(milliseconds: 500)); // 꾹
    expect(find.byWidgetPredicate((w) => w is GameCard && w.lifted), findsOneWidget, reason: '공중에 뜬 카드가 손가락을 따라온다');
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(Offset.lerp(tester.getCenter(a), to, i / 5)!);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    final after = [for (final id in settings.inGameOrder(allIds)) if (before.contains(id)) id];
    expect(after.sublist(0, 3), [before[1], before[2], before[0]]);
    expect(find.byWidgetPredicate((w) => w is GameCard && w.lifted), findsNothing);
    expect(tester.takeException(), isNull);

    final again = await Settings.load();
    expect([for (final id in again.inGameOrder(allIds)) if (before.contains(id)) id], after);
  });

  test('즐겨찾기 순서도 바꿀 수 있고, 순서를 정한 뒤 새로 생긴 게임은 맨 뒤에 온다', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    for (final id in ['a', 'b', 'c']) {
      s.toggleFavorite(id);
    }
    s.moveFavorite('c', 'a');
    expect(s.favoriteGames, ['c', 'a', 'b']);
    s.moveGame('y', 'x', ['x', 'y', 'z']);
    expect(s.inGameOrder(['x', 'y', 'z', 'new']), ['y', 'x', 'z', 'new']);
  });
}
