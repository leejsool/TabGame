// 허브 카드 배치, 예언·고블렛 아이콘, 예언 표 글씨, 표 크기 고르개를 그림(PNG)으로 뽑아보는 도구.
// 환경변수 HUB_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/prophecy/core/prophecy_examples.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_board.dart';
import 'package:tabgame/games/prophecy/ui/table_picker.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/game_icons.dart';
import 'package:tabgame/hub/hub_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['HUB_PREVIEW_DIR'];

  testWidgets('허브·아이콘·예언 표 미리보기 이미지 만들기', (tester) async {
    await loadAppFonts();
    final lora = FontLoader('Lora')..addFont(rootBundle.load('assets/fonts/Lora-Variable.ttf'));
    await lora.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();

    Future<void> shoot(String name, Size size, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: child,
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    }

    final prophecy = allGames.firstWhere((g) => g.id == 'prophecy');
    final goblet = allGames.firstWhere((g) => g.id == 'goblet_gobblers');

    await shoot('hub_phone', const Size(360, 780), HubScreen(settings: settings));
    await shoot(
      'cards_phone',
      const Size(360, 520),
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [for (final id in ['sudoku', 'prophecy', 'minesweeper', 'sprouts']) GameCard(game: allGames.firstWhere((g) => g.id == id), compact: true, onTap: () {})],
          ),
        ),
      ),
    );
    await shoot(
      'icons',
      const Size(420, 200),
      Scaffold(
        backgroundColor: const Color(0xFF8E9AD8),
        body: Center(child: Wrap(spacing: 20, children: [GameIcon(game: prophecy, size: 160), GameIcon(game: goblet, size: 160)])),
      ),
    );
    await shoot(
      'icons_small',
      const Size(200, 80),
      Scaffold(
        backgroundColor: const Color(0xFF8E9AD8),
        body: Center(child: Wrap(spacing: 20, children: [GameIcon(game: prophecy, size: 50), GameIcon(game: goblet, size: 50)])),
      ),
    );
    await shoot(
      'board',
      const Size(380, 380),
      Scaffold(body: Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: ProphBoardPainter(state: bookBoard()), size: Size.infinite))),
    );
    await shoot(
      'picker_320',
      const Size(320, 420),
      Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: TablePicker(rows: 8, cols: 8, onChanged: (_, _) {}))),
    );
  }, skip: dir == null);
}
