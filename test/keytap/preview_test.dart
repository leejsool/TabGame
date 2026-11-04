// 건반 톡톡 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 KEYTAP_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/keytap/core/kt_songs.dart';
import 'package:tabgame/games/keytap/game/kt_race.dart';
import 'package:tabgame/games/keytap/ui/kt_menu_screen.dart';
import 'package:tabgame/games/keytap/ui/kt_play_screen.dart';
import 'package:tabgame/games/keytap/ui/kt_race_screen.dart';

import '../support/preview_kit.dart';

void main() {
  final dir = Platform.environment['KEYTAP_PREVIEW_DIR'];

  testWidgets('건반 톡톡 미리보기 이미지 만들기', (tester) async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({
      'keytap.best': '{"twinkle":[3,126],"airplane":[1,40],"endless":[0,88]}',
    });
    final settings = await Settings.load();
    settings.sound = false;
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, Widget home, {Future<void> Function()? before}) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      if (before != null) await before();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }

    const sizes = {'phone': Size(400, 860), 'tab': Size(800, 1280), 'land': Size(1280, 800)};
    final song = KtSong.byId('twinkle')!;

    for (final e in sizes.entries) {
      await shoot('menu_${e.key}', e.value, const KtMenuScreen());
      await shoot('start_${e.key}', e.value, KtPlayScreen(song: song, seed: 3));
      // 시작 블록을 누르고 조금 진행 (블록을 치며 내려가는 모습)
      await shoot('play_${e.key}', e.value, KtPlayScreen(song: song, seed: 3), before: () async {
        await _playFor(tester, 1.2);
      });
      // 아무것도 안 치고 놓쳐서 끝난 모습
      await shoot('fail_${e.key}', e.value, KtPlayScreen(song: song, seed: 3), before: () async {
        await _playFor(tester, 0.2);
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1300)));
        await tester.pump(const Duration(milliseconds: 50));
      });
      final race = KtRace(song: song, seed: 3, names: const ['나', '민준', 'CPU 1', 'CPU 2'], mySeat: 0, isHost: true, cpuSeats: const {1, 2, 3});
      await shoot('race_${e.key}', e.value, KtRaceScreen(race: race, links: const []), before: () async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await _tapNext(tester, race.run.lane(race.run.next), race.run.next + 0.5, race.run.pos);
        await tester.pump(const Duration(milliseconds: 50));
      });
    }
  }, skip: dir == null);
}

/// 판 위에서 다음 블록을 계속 치며 [seconds]초 진행한다 (첫 번째는 시작 블록).
Future<void> _playFor(WidgetTester tester, double seconds) async {
  final state = tester.state(find.byType(KtPlayScreen)) as dynamic;
  final steps = (seconds / 0.05).round();
  for (var i = 0; i < steps; i++) {
    final run = state.debugRun;
    if (run.done as bool) break;
    final visible = (run.next as int) + 0.8 < (run.pos as double) + 4;
    if (i % 3 == 0 && seconds > 0.5 && visible) await _tapNext(tester, run.lane(run.next) as int, (run.next as int) + 0.5, run.pos as double);
    if (i == 0) await _tapNext(tester, run.lane(0) as int, 0.5, run.pos as double);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [lane] 칸의 세로 좌표 [y](줄 단위)를 누른다. 판은 화면에서 맨 위 막대를 뺀 나머지다.
Future<void> _tapNext(WidgetTester tester, int lane, double y, double pos) async {
  final board = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == 'KtBoardPainter'));
  final rowH = board.height / 4;
  final dy = board.bottom - (y - pos) * rowH;
  await tester.tapAt(Offset(board.left + board.width / 4 * (lane + 0.5), dy.clamp(board.top + 2, board.bottom - 2)));
}
