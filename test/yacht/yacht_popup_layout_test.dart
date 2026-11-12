import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_rules.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/ui/yacht_chance_popup.dart';
import 'package:tabgame/games/yacht/ui/yacht_scale.dart';

import '../support/preview_kit.dart';

void main() {
  final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));
  final dir = Platform.environment['YACHT_PREVIEW_DIR'];

  testWidgets('확률 풀이 창: 남길 주사위가 없으면 "모두 다시"라고 하고, PC처럼 넓은 화면에서도 창이 끝까지 늘어나지 않는다', (tester) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(1900, 930);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final shot = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: previewTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showYachtChanceDetail(context,
                    advisor: advisor, cat: YachtCategory.smallStraight, dice: const [1, 1, 2, 5, 6], held: List.filled(5, false), rerollsLeft: 2),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final popup = find.byKey(const ValueKey('yacht-chance-popup'));
    expect(popup, findsOneWidget);
    expect(tester.getSize(find.descendant(of: popup, matching: find.byType(Material)).first).width, lessThanOrEqualTo(kYachtPopupMaxWidth + 60), reason: '창 폭이 화면 끝까지 늘어나지 않는다');
    final roll = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('yacht-keep-') && (w.key! as ValueKey<String>).value.endsWith('-roll'));
    final hold = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('yacht-keep-') && (w.key! as ValueKey<String>).value.endsWith('-hold'));
    expect(roll.evaluate().length + hold.evaluate().length, 5);
    if (hold.evaluate().isEmpty) expect(find.textContaining('모두 다시 굴려요'), findsOneWidget);
    expect(find.textContaining('밝게'), findsNothing);
    if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/chance_pc.png');
  });
}
