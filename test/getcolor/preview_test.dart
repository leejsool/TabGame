// 겟 컬러 화면(색 구분 무늬)을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 GETCOLOR_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/getcolor/core/getcolor_rules.dart';
import 'package:tabgame/games/getcolor/game/getcolor_controller.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_screen.dart';

void main() {
  final dir = Platform.environment['GETCOLOR_PREVIEW_DIR'];

  testWidgets('겟 컬러 색·무늬 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, List<List<int>> bottles) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      final c = GetColorController(level: GcLevel.veryHard, initial: WaterState(bottles));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: GetColorScreen(controller: c),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 1) 색마다 한 병씩 (13가지 + 빈 병 2개)
    await shoot('colors_all', const Size(430, 900), [
      for (var c = 0; c < 13; c++) [c, c, c, c],
      <int>[],
      <int>[],
    ]);

    // 2) 헷갈리기 쉬운 짝을 한 병에 번갈아 쌓은 모습
    const pairs = [
      [0, 9], // 빨강 / 분홍
      [2, 3], // 노랑 / 연두
      [3, 4], // 연두 / 초록
      [4, 5], // 초록 / 청록
      [5, 6], // 청록 / 하늘
      [7, 12], // 파랑 / 남색
      [8, 12], // 보라 / 남색
      [1, 10], // 주황 / 갈색
      [6, 11], // 하늘 / 회색
      [7, 8], // 파랑 / 보라
    ];
    await shoot('colors_pairs', const Size(430, 900), [
      for (final p in pairs) [p[0], p[1], p[0], p[1]],
      for (var i = pairs.length; i < 13; i++) <int>[],
      <int>[],
      <int>[],
    ]);
  }, skip: dir == null);
}
