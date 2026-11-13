import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/prophecy/ui/table_picker.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/hub_screen.dart';

Future<void> pumpAt(WidgetTester tester, Size size, Widget Function(Settings) home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: home(settings))));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('폰 폭에서는 게임 카드가 한 줄에 세 장씩, 태블릿에서는 더 넓게 놓인다', (tester) async {
    await pumpAt(tester, const Size(360, 780), (s) => HubScreen(settings: s));
    final cards = find.byType(GameCard);
    final a = tester.getRect(cards.at(0)), b = tester.getRect(cards.at(2)), c = tester.getRect(cards.at(3));
    expect(a.top, b.top, reason: '첫 세 카드는 같은 줄');
    expect(c.top, greaterThan(a.top), reason: '네 번째 카드는 다음 줄');
    expect(a.width, lessThan(125), reason: '카드 폭이 3분의 1쯤');
    expect(b.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);

    await pumpAt(tester, const Size(1000, 700), (s) => HubScreen(settings: s));
    final wide = find.byType(GameCard);
    expect(tester.getRect(wide.at(0)).width, greaterThan(150));
    expect(tester.getRect(wide.at(3)).top, tester.getRect(wide.at(0)).top, reason: '넓은 화면에서는 한 줄에 네 장 이상');
    expect(tester.takeException(), isNull);
  });

  testWidgets('표 크기 고르개는 좁은 폰(너비 320)에서도 8열이 화면 안에 들어온다', (tester) async {
    await pumpAt(
      tester,
      const Size(320, 600),
      (_) => Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: TablePicker(rows: 8, cols: 8, onChanged: (_, _) {}))),
    );
    final box = tester.getRect(find.descendant(of: find.byType(TablePicker), matching: find.byType(CustomPaint)).first);
    expect(box.right, lessThanOrEqualTo(320 - 16 + 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('교과학습이 있는 게임 카드에만 학사모 표시가 붙는다 (좁은 카드·넓은 카드 모두 넘침 없이)', (tester) async {
    final withLesson = {for (final g in allGames) if (g.hasLesson) g.id};
    expect(withLesson, {'ultimate_tictactoe', 'sprouts', 'dandelion', 'stones', 'park', 'prophecy', 'yacht'});
    for (final (width, compact) in const [(106.0, true), (176.0, false)]) {
      for (final g in allGames) {
        await pumpAt(
          tester,
          const Size(400, 400),
          (_) => Scaffold(body: Center(child: SizedBox(width: width, height: compact ? 110 : 140, child: GameCard(game: g, compact: compact, dense: compact, onFavorite: () {}, onTap: () {})))),
        );
        expect(find.byIcon(Icons.school_rounded), g.hasLesson ? findsOneWidget : findsNothing, reason: '${g.title} $width');
        expect(tester.takeException(), isNull, reason: '${g.title} $width');
      }
    }
  });
}
