// 고른 아이콘(icon_designs.dart 의 [appIcon])을 실제 앱·웹 아이콘 파일로 만든다. 그림을 고치면 다시 돌린다.
//
// 실행 (사용자 폴더가 한글인 PC는 TEMP/TMP 를 영문 경로로 먼저 지정):
//   flutter test tool/app_icon/apply_app_icon_test.dart
// 만드는 파일:
//   android/app/src/main/res/mipmap-*/ic_launcher.png, ic_launcher_foreground.png (적응형 아이콘 앞 그림)
//   같은 폴더의 ic_launcher_dev.png, ic_launcher_dev_foreground.png ('개발' 띠가 붙은 개발용 앱 아이콘)
//   web/favicon.png, web/icons/Icon-192/512.png, Icon-maskable-192/512.png
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/preview_kit.dart';
import 'icon_designs.dart';

const String _res = 'android/app/src/main/res';
const Map<String, double> _density = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4};

void main() {
  testWidgets('앱·웹 아이콘 파일 만들기', (tester) async {
    await loadAppFonts();

    Future<void> save(String path, int px, {double zoom = 1, double corner = 0, bool dev = false}) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.scale(px.toDouble());
      if (corner > 0) c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 1, 1), Radius.circular(corner)));
      // 그림을 가운데 기준으로 줄인다 (잘려 나가는 바깥쪽은 배경색으로 채워진다).
      c.translate(0.5, 0.5);
      c.scale(zoom);
      c.translate(-0.5, -0.5);
      appIcon.paint(c);
      if (dev) _devBand(c);
      final image = (await tester.runAsync(() => rec.endRecording().toImage(px, px)))!;
      await savePng(tester, image, path);
    }

    for (final e in _density.entries) {
      final dir = '$_res/mipmap-${e.key}';
      final legacy = (48 * e.value).round(), layer = (108 * e.value).round();
      for (final dev in [false, true]) {
        final name = dev ? 'ic_launcher_dev' : 'ic_launcher';
        // 옛 안드로이드용: 모서리가 둥근 네모.
        await save('$dir/$name.png', legacy, corner: 0.16, dev: dev);
        // 적응형 아이콘: 108 가운데 72만 보이므로 그림을 72/108 로 줄여 넣는다.
        await save('$dir/${name}_foreground.png', layer, zoom: 72 / 108, dev: dev);
      }
    }

    await save('web/favicon.png', 48, corner: 0.16);
    await save('web/icons/Icon-192.png', 192, corner: 0.16);
    await save('web/icons/Icon-512.png', 512, corner: 0.16);
    // 마스크용: 기기가 동그라미 등으로 자르므로 꽉 채우고 그림을 조금 줄인다.
    await save('web/icons/Icon-maskable-192.png', 192, zoom: 0.86);
    await save('web/icons/Icon-maskable-512.png', 512, zoom: 0.86);
  });
}

/// 개발용 앱 아이콘 아래쪽의 빨간 '개발' 띠.
void _devBand(Canvas c) {
  c.drawRect(const Rect.fromLTRB(-1, 0.66, 2, 2), Paint()..color = const Color(0xFFE5484D));
  final tp = TextPainter(
    text: const TextSpan(
      text: '개발',
      style: TextStyle(fontFamily: 'Pretendard', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  c.save();
  c.translate(0.5, 0.79);
  c.scale(0.01);
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  c.restore();
}
