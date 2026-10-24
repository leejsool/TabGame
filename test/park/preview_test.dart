// 공원 길찾기·바둑돌 옮기기(폰 가로) 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 PARK_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/park/core/park_rules.dart';
import 'package:tabgame/games/park/ui/park_board.dart';
import 'package:tabgame/games/park/ui/park_lesson_screen.dart';
import 'package:tabgame/games/park/ui/park_screen.dart';
import 'package:tabgame/games/stones/core/stones_rules.dart';
import 'package:tabgame/games/stones/ui/stones_screen.dart';

import '../support/preview_kit.dart';

Offset _pt(WidgetTester tester, int n, int r, int c) {
  final rect = tester.getRect(find.byType(ParkBoard).first);
  final gap = rect.shortestSide / (n + 1.24);
  final origin = rect.topLeft + Offset((rect.width - gap * n) / 2, (rect.height - gap * n) / 2);
  return origin + Offset(c * gap, r * gap);
}

Future<void> _draw(WidgetTester tester, int n, List<Walk> steps, {bool lift = true}) async {
  var (r, c) = (0, 0);
  final g = await tester.startGesture(_pt(tester, n, 0, 0));
  for (final s in steps) {
    final from = _pt(tester, n, r, c);
    s == Walk.right ? c++ : r++;
    for (var k = 1; k <= 6; k++) {
      await g.moveTo(Offset.lerp(from, _pt(tester, n, r, c), k / 6)!);
    }
  }
  if (lift) await g.up();
  await tester.pump();
}

void main() {
  final dir = Platform.environment['PARK_PREVIEW_DIR'];
  testWidgets('공원 길찾기 미리보기', (tester) async {
    await loadAppFonts();
    Directory(dir!).createSync(recursive: true);
    const r = Walk.right, d = Walk.down;
    const sizes = {'phone': Size(400, 860), 'tab': Size(800, 1280), 'land': Size(1280, 800)};
    for (final z in sizes.entries) {
      tester.view.physicalSize = z.value;
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(theme: ThemeData(fontFamily: 'NanumGothic'), home: const ParkScreen())));
      await tester.tap(find.text('3×3 공원'));
      await tester.pump();
      for (final p in const [
        [r, d, d, r, r, d],
        [d, r, r, d, d, r],
        [r, d, d, d, r, r],
      ]) {
        await _draw(tester, 3, p);
      }
      await _draw(tester, 3, const [r, d, d, r, r, d]); // 이미 찾은 길
      await savePng(tester, await captureBoundary(tester, key), '$dir/park_${z.key}.png');
      expect(tester.takeException(), isNull);
    }
    // 바둑돌 옮기기: 폰 가로
    tester.view.physicalSize = const Size(860, 400);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(theme: ThemeData(fontFamily: 'NanumGothic'), home: StonesScreen(mode: PlayMode.vsCpu, puzzle: kPuzzles[0], cpuSide: Side.black)),
    ));
    await tester.pump();
    await savePng(tester, await captureBoundary(tester, key), '$dir/stones_phone_land.png');
    // 교과학습 단원 (긴 화면 한 장씩)
    tester.view.physicalSize = const Size(400, 2600);
    for (final unit in ['2. 같은 것이 있는 순열', '3. 공원의 최단경로 수', '4. 덧셈으로 세기', '5. 조건에 맞는 길 세기', '6. 퀴즈로 확인하기']) {
      final k = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: k, child: MaterialApp(theme: ThemeData(fontFamily: 'NanumGothic'), home: const ParkLessonScreen())));
      await tester.tap(find.textContaining(unit));
      await tester.pumpAndSettle();
      await savePng(tester, await captureBoundary(tester, k), '$dir/park_lesson_${unit.substring(0, 1)}.png');
      expect(tester.takeException(), isNull);
    }
    tester.view.reset();
  }, skip: dir == null);
}
