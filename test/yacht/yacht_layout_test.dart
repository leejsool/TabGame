import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/yacht/core/yacht_advisor.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';
import 'package:tabgame/games/yacht/game/yacht_controller.dart';
import 'package:tabgame/games/yacht/ui/yacht_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final advisor = YachtAdvisor(YachtValues.fromBytes(File('assets/yacht/values.bin').readAsBytesSync()));
  final dir = Platform.environment['YACHT_PREVIEW_DIR'];

  // PC 브라우저처럼 넓고 높이도 넉넉한 화면은 점수판을 한 장으로, 핸드폰 가로처럼 낮은 화면만 둘로 나눈다.
  // 어느 쪽이든 족보 이름이 점수 칸으로 삐져나오지 않는다.
  for (final (name, size, split) in const [('pc', Size(1900, 930), false), ('phone_land', Size(860, 400), true)]) {
    testWidgets('점수판 배치: $name', (tester) async {
      await loadAppFonts();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final shot = GlobalKey();
      final c = YachtController(mode: PlayMode.local2p, players: 2, advisor: advisor, rng: Random(1), cpuSeats: const [1], turnSeconds: 60);
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: RepaintBoundary(
          key: shot,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: previewTheme(Brightness.light), home: YachtScreen(mode: c.mode, players: 2, controller: c)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('나'), split ? findsNWidgets(2) : findsOneWidget, reason: split ? '둘로 나뉜다' : '한 장');
      // 가장 긴 이름이 내 점수 칸 앞에서 끝난다
      for (final label in const ['라지 스트레이트', '스몰 스트레이트']) {
        final text = tester.getRect(find.text(label));
        final cell = tester.getRect(find.byKey(const ValueKey('yacht-cell-0-largeStraight')));
        expect(text.right, lessThanOrEqualTo(cell.left + 0.5), reason: '$label 글자가 점수 칸으로 넘친다');
      }
      if (dir != null) await savePng(tester, await captureBoundary(tester, shot), '$dir/layout_$name.png');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
