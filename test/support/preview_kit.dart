// 테스트·미리보기 공통 도구: 앱 글꼴 불러오기, 앱과 같은 테마, 화면을 PNG로 찍기.
//
// 글꼴을 불러오지 않으면 시험 화면의 글자·아이콘이 네모(□)로 나와서 그림으로 확인할 수가 없다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 폰, 태블릿 세로, 태블릿 가로 (탭 S9 FE). 화면 배치는 이 세 크기에서 확인한다.
const Map<String, Size> kPreviewSizes = {'phone': Size(400, 860), 'tabP': Size(800, 1280), 'tabL': Size(1280, 800)};

bool _fontsLoaded = false;

/// 앱 글꼴(나눔고딕), 머티리얼 아이콘, Lora(교과학습 수식)를 불러온다. 여러 번 불러도 한 번만 읽는다.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  final nanum = FontLoader('NanumGothic');
  for (final f in ['Regular', 'Bold', 'ExtraBold']) {
    nanum.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
  }
  await nanum.load();
  await (FontLoader('Lora')..addFont(rootBundle.load('assets/fonts/Lora-Variable.ttf'))).load();
  final icons = _materialIconsFile();
  if (icons != null) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
  _fontsLoaded = true;
}

/// Flutter SDK 안의 머티리얼 아이콘 글꼴. 시험 실행 파일(flutter_tester) 위치에서 찾는다: `bin/cache/artifacts/engine/<플랫폼>/flutter_tester`.
File? _materialIconsFile() {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  for (final name in ['materialicons-regular.otf', 'MaterialIcons-Regular.otf']) {
    final f = File('${artifacts.path}/material_fonts/$name');
    if (f.existsSync()) return f;
  }
  return null;
}

/// 앱과 같은 테마 (lib/app.dart와 맞춘다).
ThemeData previewTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7CAC), brightness: brightness),
      useMaterial3: true,
      fontFamily: 'NanumGothic',
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF6F3EE) : const Color(0xFF15181C),
    );

/// [key]가 달린 `RepaintBoundary`를 그림으로 뜬다.
Future<ui.Image> captureBoundary(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1.0)))!;
}

/// 그림을 PNG 파일로 저장한다.
Future<void> savePng(WidgetTester tester, ui.Image image, String path) async {
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// 같은 화면의 여러 크기 그림을 높이를 맞춰 한 장에 나란히 붙인다 (폰 · 태블릿 세로 · 태블릿 가로를 한눈에 보려고).
Future<ui.Image> sideBySide(WidgetTester tester, List<ui.Image> images, {double height = 640, double gap = 16}) async {
  final widths = [for (final im in images) im.width * height / im.height];
  final total = widths.fold<double>(0, (a, w) => a + w) + gap * (images.length + 1);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawRect(Rect.fromLTWH(0, 0, total, height + gap * 2), Paint()..color = const Color(0xFF888888));
  var x = gap;
  for (var i = 0; i < images.length; i++) {
    final im = images[i];
    canvas.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), Rect.fromLTWH(x, gap, widths[i], height), Paint()..filterQuality = FilterQuality.medium);
    x += widths[i] + gap;
  }
  final picture = recorder.endRecording();
  return (await tester.runAsync(() => picture.toImage(total.ceil(), (height + gap * 2).ceil())))!;
}
