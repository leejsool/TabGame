// 바둑돌 옮기기 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 STONES_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/stones/core/stones_rules.dart';
import 'package:tabgame/games/stones/ui/stones_board.dart';
import 'package:tabgame/games/stones/ui/stones_menu.dart';
import 'package:tabgame/games/stones/ui/stones_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['STONES_PREVIEW_DIR'];
  testWidgets('바둑돌 옮기기 화면 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    final screens = <String, Widget>{
      'menu': const StonesMenuScreen(mode: PlayMode.vsCpu),
      'free': const StonesScreen(mode: PlayMode.local2p, puzzle: kStartBoard),
      'puzzle3': StonesScreen(mode: PlayMode.vsCpu, puzzle: kPuzzles[2], cpuSide: Side.white),
    };
    const sizes = {'phone': Size(400, 860), 'tab': Size(800, 1280), 'land': Size(1280, 800)};
    for (final s in screens.entries) {
      for (final z in sizes.entries) {
        tester.view.physicalSize = z.value;
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(theme: ThemeData(fontFamily: 'NanumGothic'), home: s.value),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        if (s.key == 'puzzle3') {
          // 빈칸 수 보기 켜고, 1행 검은 돌을 9칸으로 (정답)
          await tester.tap(find.text('빈칸 수 보기'));
          await tester.pump();
          final board = tester.getRect(find.descendant(of: find.byType(StonesBoard), matching: find.byType(CustomPaint)).first);
          final cell = board.height / 4;
          await tester.tapAt(board.topLeft + Offset(cell * 9.5, cell * 1.5));
          await tester.pump();
        }
        await savePng(tester, await captureBoundary(tester, key), '$dir/stones_${s.key}_${z.key}.png');
        expect(tester.takeException(), isNull);
      }
    }
    tester.view.reset();
  }, skip: dir == null);
}
