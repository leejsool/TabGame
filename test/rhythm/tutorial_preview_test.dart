// 리듬 검사단 튜토리얼 그림을 PNG로 뽑아보는 도구. RHYTHM_TUTORIAL_PREVIEW_DIR 이 지정됐을 때만 실행된다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/tutorial/rhythm_tutorial.dart';

void main() {
  final dir = Platform.environment['RHYTHM_TUTORIAL_PREVIEW_DIR'];
  testWidgets('튜토리얼 그림 미리보기', (tester) async {
    Directory(dir!).createSync(recursive: true);
    final key = GlobalKey();
    final t = rhythmTutorial();
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    for (var i = 0; i < t.steps.length; i++) {
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Builder(builder: (context) => Center(child: SizedBox(width: 380, height: 380, child: t.steps[i].art!(context, t.color)))),
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/step_$i.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    tester.view.reset();
  }, skip: dir == null);
}
