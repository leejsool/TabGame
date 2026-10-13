// 지뢰찾기 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 MINES_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/minesweeper/core/mines_rules.dart';
import 'package:tabgame/games/minesweeper/game/mines_controller.dart';
import 'package:tabgame/games/minesweeper/ui/mines_board.dart';
import 'package:tabgame/games/minesweeper/ui/mines_painter.dart';
import 'package:tabgame/games/minesweeper/ui/mines_screen.dart';

void main() {
  final dir = Platform.environment['MINES_PREVIEW_DIR'];

  testWidgets('지뢰찾기 화면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> shoot(String name, Size size, MinesController c, {int waitMs = 600}) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: MinesScreen(controller: c),
            ),
          ),
        ),
      );
      // 컨트롤러의 시계는 실제 시간이라, 애니메이션이 진행되도록 실제로 기다린다
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: waitMs)));
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

    // 진행 중인 초급 판 (깃발 + 힌트)
    final rng = Random(4);
    final play = MinesController(level: MinesLevel.beginner, rng: rng);
    play.tap(40);
    for (var i = 0; i < play.board.size; i++) {
      if (play.board.mine[i] && i % 3 == 0) play.flag(i);
    }
    play.requestHint();
    await shoot('play', const Size(820, 1300), play, waitMs: 900);

    // 졌을 때
    final lost = MinesController(level: MinesLevel.intermediate, rng: Random(9));
    lost.tap(120);
    final mineCell = [for (var i = 0; i < lost.board.size; i++) if (lost.board.mine[i]) i].first;
    lost.tap(mineCell);
    await shoot('lost', const Size(820, 1300), lost, waitMs: 1300);

    // 이겼을 때
    final won = MinesController(level: MinesLevel.beginner, rng: Random(2));
    won.tap(0);
    while (won.status == MinesStatus.playing) {
      final safe = [for (var i = 0; i < won.board.size; i++) if (!won.board.mine[i] && won.board.marks[i] == CellMark.hidden) i];
      if (safe.isEmpty) break;
      won.tap(safe.first);
    }
    await shoot('won', const Size(820, 1300), won, waitMs: 1000);

    // 칸을 누르고 있을 때의 안내 (그 자리 / 오른쪽 / 왼쪽 / 위로 끌어 취소)
    Future<void> holdShot(String name, Size size, MinesController c, int cell, Offset drag) async {
      await tester.binding.setSurfaceSize(size);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SettingsScope(
            settings: settings,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'),
              home: MinesScreen(controller: c),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
      await tester.pump(const Duration(milliseconds: 50));
      final box = tester.getRect(find.byType(MinesBoardView));
      final layout = MinesLayout(box.size, c.board.rows, c.board.cols);
      final g = await tester.startGesture(box.topLeft + layout.rect(cell).center);
      await tester.pump(const Duration(milliseconds: 250));
      if (drag != Offset.zero) {
        await g.moveBy(drag / 2);
        await g.moveBy(drag / 2);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      await g.cancel();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final (name, drag) in [
      ('press_hold', Offset.zero),
      ('press_flag', const Offset(55, 30)),
      ('press_question', const Offset(-55, 30)),
      ('press_open', const Offset(0, -60)),
    ]) {
      final c = MinesController(level: MinesLevel.beginner, rng: Random(4));
      c.tap(40);
      final target = [for (var i = 0; i < c.board.size; i++) if (c.board.marks[i] == CellMark.hidden) i][12];
      await holdShot(name, const Size(820, 1300), c, target, drag);
    }

    // 고급: 세로 화면 / 가로 화면
    final expert = MinesController(level: MinesLevel.expert, rng: Random(1));
    expert.tap(240);
    await shoot('expert_portrait', const Size(820, 1300), expert);
    final expert2 = MinesController(level: MinesLevel.expert, rng: Random(1));
    expert2.tap(240);
    await shoot('expert_landscape', const Size(1280, 720), expert2);
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('MINES_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
