import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/card_look.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/hub/settings_screen.dart';

void main() {
  testWidgets('설정의 카드 뒷면 고르는 곳은 처음에 접혀 있고, 눌러서 펼치면 모양들이 나온다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SettingsScope(settings: settings, child: MaterialApp(home: SettingsScreen(settings: settings))));
    await tester.pump();

    final section = find.byKey(const ValueKey('card-back-section'));
    await tester.scrollUntilVisible(section, 200, scrollable: find.byType(Scrollable).first);
    // 접혀 있다: 지금 고른 모양의 이름만 보이고, 뒷면 카드들은 없다
    expect(find.text(settings.cardBackStyle.label), findsOneWidget);
    for (final style in CardBackStyle.values) {
      expect(find.byKey(ValueKey('card-back-style-${style.name}')), findsNothing);
    }

    // 펼친다
    await tester.tap(find.text('카드 뒷면'));
    await tester.pumpAndSettle();
    for (final style in CardBackStyle.values) {
      expect(find.byKey(ValueKey('card-back-style-${style.name}'), skipOffstage: false), findsOneWidget, reason: style.name);
    }

    // 다른 모양을 고르면 접었을 때 보이는 이름도 바뀐다
    final other = CardBackStyle.values.firstWhere((s) => s != settings.cardBackStyle);
    final tile = find.byKey(ValueKey('card-back-style-${other.name}'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(settings.cardBackStyle, other);

    // 다시 접는다
    await tester.tap(find.text('카드 뒷면'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('card-back-style-${other.name}')), findsNothing);
    expect(find.text(other.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
