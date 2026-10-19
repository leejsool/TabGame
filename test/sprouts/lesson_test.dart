import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_lesson_screen.dart';
import 'package:tabgame/games/sprouts/ui/sprouts_lesson_shapes.dart';

import '../support/preview_kit.dart';

Future<Widget> app(Widget home, {Key? key}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return RepaintBoundary(
    key: key,
    child: SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
    ),
  );
}

void main() {
  final dir = Platform.environment['SPROUTS_PREVIEW_DIR'];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  testWidgets('교과학습: 모든 단원이 오류 없이 열리고, 오일러 놀이터와 퀴즈가 동작한다', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app(const SproutsLessonScreen()));
    expect(find.text('교과학습'), findsOneWidget);

    await tester.tap(find.textContaining('1. 콩나물 규칙과 목숨 세기'));
    await tester.pumpAndSettle();
    for (var i = 1; i < 10; i++) {
      expect(tester.takeException(), isNull, reason: '$i번 단원');
      if (i == 3) {
        // 오일러 놀이터: 한 수 둘 때마다 양쪽이 같다
        await tester.scrollUntilVisible(find.byIcon(Icons.add_rounded), 300, scrollable: find.byType(Scrollable).first);
        for (var k = 0; k < 4; k++) {
          await tester.ensureVisible(find.byIcon(Icons.add_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add_rounded));
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(find.byKey(const ValueKey('euler-equation'))).data!;
          expect(text, contains('같아요'), reason: text);
        }
      }
      await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.textContaining('다음:'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('다음:'));
      await tester.pumpAndSettle();
    }
    // 마지막 단원: 퀴즈
    expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('전체 "목숨"'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('1개 줄어든다'));
    await tester.pump();
    expect(find.text('정답! 🎉'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그림 미리보기 이미지 만들기', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final names = ['1. 콩나물 규칙과 목숨 세기', '2. 모양이 아니라', '3. 점 + 영역', '4. 끝 모양은 벌레들', '5. 같은 네트워크일까', '6. 컵과 도넛은 같은 모양', '7. 위상수학의 세 가지', '8. 위상수학은 어디에', '9. 뫼비우스의 띠'];
    for (var i = 0; i < names.length; i++) {
      final key = GlobalKey();
      await tester.pumpWidget(await app(const SproutsLessonScreen(), key: key));
      await tester.tap(find.textContaining(names[i]));
      await tester.pumpAndSettle();
      if (i == 2) {
        for (var k = 0; k < 5; k++) {
          await tester.scrollUntilVisible(find.byIcon(Icons.add_rounded), 300, scrollable: find.byType(Scrollable).first);
          await tester.tap(find.byIcon(Icons.add_rounded));
          await tester.pump();
        }
        await tester.pump();
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/sprouts_lesson_${i + 1}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  }, skip: dir == null);

  test('복잡한 판 예시: 늘이고 비틀어도 이어진 관계는 같고, 이은 곳이 다른 판은 다르다', () {
    String link(ShapeTile t) {
      final b = t.board;
      return ([for (final c in b.curves) '${c.from}-${c.mid}-${c.to}']..sort()).join(',');
    }

    final tiles = complexTiles();
    expect(tiles.length, 6);
    final first = link(tiles.first);
    for (final t in tiles.sublist(0, 4)) {
      expect(t.same, isTrue);
      expect(link(t), first, reason: t.caption);
      expect(t.board.dots.length, 10); // 처음 점 4개 + 곡선마다 새 점 6개
    }
    // 이은 곳이 다른 판 둘은 서로 같고(돌려 봐도), 위의 판과는 다르다
    expect(link(tiles[4]), link(tiles[5]));
    expect(link(tiles[4]), isNot(first));
    expect(tiles[4].same, isFalse);
  });

  test('고리 예시: 모양이 달라도 모두 점 하나에서 나가 그 점으로 돌아온다', () {
    for (final t in loopTiles()) {
      expect(t.board.curves.length, 1, reason: t.caption);
      expect(t.board.curves.single.from, 0, reason: t.caption);
      expect(t.board.curves.single.to, 0, reason: t.caption); // 같은 점에서 나가 같은 점으로 돌아온다
      expect(t.board.dots.length, 2, reason: t.caption); // 처음 점 하나 + 고리 위의 새 점
    }
  });
}
