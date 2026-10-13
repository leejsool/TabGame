import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/card_look.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/game/freecell_controller.dart';
import 'package:tabgame/games/freecell/ui/freecell_screen.dart';
import 'package:tabgame/games/freecell/ui/playing_card.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';
import 'package:tabgame/games/solitaire/ui/solitaire_screen.dart';

/// 화면에 그려진 앞면 카드들이 폰용(간결)으로 그려졌는지.
Set<bool> compactFlags(WidgetTester tester) => {
      for (final p in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
        if (p.painter is PlayingCardPainter) (p.painter! as PlayingCardPainter).compact,
    };

void main() {
  tearDown(() => CardLook.layout = CardLayout.auto);

  Future<Settings> pump(WidgetTester tester, Size size, Widget Function() screen, CardLayout layout) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'cardLayout': layout.name});
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: screen()),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    return settings;
  }

  for (final (name, screen) in <(String, Widget Function())>[
    ('프리셀', () => FreecellScreen(controller: FreecellController(deal: 617, autoDelay: Duration.zero))),
    ('솔리테어', () => SolitaireScreen(controller: SolitaireController(deal: 1, autoDelay: Duration.zero))),
  ]) {
    testWidgets('$name: 카드 표시 설정을 따른다 (폰 / 태블릿, 자동·폰용·전체)', (tester) async {
      const phone = Size(360, 700), tablet = Size(900, 1300);
      final cases = <(Size, CardLayout, bool)>[
        (phone, CardLayout.auto, true),
        (phone, CardLayout.full, false),
        (tablet, CardLayout.auto, false),
        (tablet, CardLayout.phone, true),
      ];
      for (final (size, layout, expected) in cases) {
        await pump(tester, size, screen, layout);
        expect(compactFlags(tester), {expected}, reason: '$name $size ${layout.label}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('$name: 게임 도중 설정을 바꾸면 카드가 바로 다시 그려진다', (tester) async {
      final settings = await pump(tester, const Size(360, 700), screen, CardLayout.auto);
      expect(compactFlags(tester), {true});
      settings.cardLayout = CardLayout.full;
      await tester.pump(const Duration(milliseconds: 300));
      expect(compactFlags(tester), {false});
      settings.cardLayout = CardLayout.phone;
      await tester.pump(const Duration(milliseconds: 300));
      expect(compactFlags(tester), {true});
      await tester.pumpWidget(const SizedBox());
    });
  }
}
