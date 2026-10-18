// 설정 화면의 "무늬 색깔" 부분을 PNG로 뽑아보는 도구. SETTINGS_PREVIEW_DIR 이 지정됐을 때만 실행된다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/card_look.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/hub/settings_screen.dart';

import 'support/preview_kit.dart';

void main() {
  final dir = Platform.environment['SETTINGS_PREVIEW_DIR'];
  testWidgets('설정 화면 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
        home: SettingsScreen(settings: settings),
      ),
    ));
    await tester.scrollUntilVisible(find.text('4색'), 200, scrollable: find.byType(Scrollable).first);
    for (final four in SuitPalette.values) {
      settings.suitPalette = four;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/settings_${four.name}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    // 위쪽 "카드 모양" 미리보기 카드에도 바로 반영되는지
    await tester.scrollUntilVisible(find.text('카드 모양'), -200, scrollable: find.byType(Scrollable).first);
    for (final p in SuitPalette.values) {
      settings.suitPalette = p;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/cards_${p.name}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    tester.view.reset();
  }, skip: dir == null);
}
