import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/uttt/ui/uttt_lesson_screen.dart';

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
  final dir = Platform.environment['UTTT_PREVIEW_DIR'];

  Future<void> loadFont() async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
  }

  testWidgets('교과학습: 목록 → 모든 단원이 오류 없이 열리고 단계 슬라이더·퀴즈가 동작한다', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app(const UtttLessonScreen()));
    expect(find.text('교과학습'), findsOneWidget);
    expect(find.textContaining('프랙털이란?'), findsOneWidget);

    // 모든 단원을 차례로 연다 (첫 단원에서 "다음" 단추로 끝까지)
    await tester.tap(find.textContaining('1. 틱택토 속의 틱택토'));
    await tester.pumpAndSettle();
    for (var i = 1; i < 7; i++) {
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.textContaining('다음:'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('다음:'));
      await tester.pumpAndSettle();
    }
    // 마지막 단원: 퀴즈
    expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
    await tester.scrollUntilVisible(find.text('프랙털의 가장 큰 특징은 무엇일까요?'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('작은 부분이 전체와 닮은 모양이 되풀이된다'));
    await tester.pump();
    expect(find.text('정답! 🎉'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('교과학습 마치기'), 400, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('교과학습 마치기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('교과학습 마치기'));
    await tester.pumpAndSettle();
    expect(find.text('교과학습'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('교과학습: 프랙털 단계 슬라이더를 끝까지 올려도 그려진다', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await app(const UtttLessonScreen()));
    await tester.tap(find.textContaining('4. 궁극 틱택토는 프랙털!'));
    await tester.pumpAndSettle();
    expect(find.textContaining('단계 2 · 궁극 틱택토'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pump();
    expect(find.textContaining('모두 729칸'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('교과학습 그림 미리보기 이미지 만들기', (tester) async {
    await loadFont();
    final names = ['1. 틱택토 속의 틱택토', '2. 프랙털이란?', '3. 자연은 프랙털의 정원', '4. 궁극 틱택토는 프랙털!', '5. 두 가지 눈높이 전략', '6. 이름과 변형 규칙'];
    await tester.binding.setSurfaceSize(const Size(430, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (var i = 0; i < names.length; i++) {
      final key = GlobalKey();
      await tester.pumpWidget(await app(const UtttLessonScreen(), key: key));
      await tester.tap(find.textContaining(names[i]));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/lesson_${i + 1}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  }, skip: dir == null);
}
