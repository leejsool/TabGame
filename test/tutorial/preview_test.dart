// 튜토리얼 화면을 그림(PNG)으로 뽑아보는 도구.
// 환경변수 TUTORIAL_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/tutorial/basic_lesson.dart';
import 'package:tabgame/games/sudoku/tutorial/basic_lesson_screen.dart';
import 'package:tabgame/games/sudoku/tutorial/practice_menu_screen.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_info.dart';
import 'package:tabgame/games/sudoku/tutorial/technique_lesson_screen.dart';
import 'package:tabgame/games/sudoku/ui/board_widget.dart';
import 'package:tabgame/tutorial/tutorial.dart';
import 'package:tabgame/tutorial/tutorial_screen.dart';

import 'preview_tutorials.dart';
import '../support/preview_kit.dart';

Future<void> _loadFonts() async {
  await loadAppFonts();
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      fontFamily: 'NanumGothic',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7CAC), brightness: b),
      scaffoldBackgroundColor:
          b == Brightness.light ? const Color(0xFFF6F3EE) : const Color(0xFF15181C),
    );

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _pumpApp(WidgetTester tester, GlobalKey key, Widget home,
    {Brightness brightness = Brightness.light}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: _theme(brightness),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// 애니메이션(자동 스크롤 등)이 끝날 때까지 프레임을 몇 번 더 그린다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final dir = Platform.environment['TUTORIAL_PREVIEW_DIR'];
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('스도쿠 기본 규칙 튜토리얼 미리보기', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await _pumpApp(tester, key, const SudokuBasicLessonScreen(firstTime: true));
    final game = tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;

    Future<void> next() async {
      await tester.tap(find.text('다음'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await _settle(tester);
    await _shot(tester, key, '$dir/basic_01_intro.png');
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_02_row.png');
    await next();
    await next();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_05_rule.png');
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_06_select.png');
    game.strokeDown(kLessonRowCell);
    game.strokeEnd();
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_06_select_done.png');
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_07_place.png');
    game.padDigit(5);
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_07_wrong.png');
    await tester.pump(const Duration(milliseconds: 1500));
    game.padDigit(9);
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_07_done.png');
    await next();
    game.padDigit(9);
    await tester.pump();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_09_cross.png');
    await tester.tap(find.text('도와줘요'));
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_09_cross_help.png');
    game.padDigit(1);
    await tester.pump();
    await next();
    // 일부러 틀리기
    game.padDigit(game.puzzle.solution[game.selected] % 9 + 1);
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_10_wrong_on_purpose.png');
    await next();
    game.erase();
    await tester.pump();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_12_notes.png');
    game.toggleNotes();
    game.padDigit(3);
    game.padDigit(9);
    await tester.pump();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_13_auto_notes.png');
    game.autoNotes();
    await tester.pump();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_14_hint.png');
    game.requestHint();
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_14_hint_open.png');
    game.applyHint();
    await tester.pump();
    await next();
    await next();
    await _settle(tester);
    await _shot(tester, key, '$dir/basic_16_finale.png');
  }, skip: dir == null);

  testWidgets('스도쿠 심화 기술 미리보기 (폰 세로)', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    for (final name in ['hiddenSingle', 'pointing', 'xWing', 'xyWing', 'skyscraper', 'xyChain', 'alsXz', 'bugPlusOne']) {
      final i = kTechniqueInfos.indexWhere((t) => t.technique.name == name);
      await _pumpApp(tester, key, SudokuTechniqueLessonScreen(index: i));
      await _settle(tester);
    await _shot(tester, key, '$dir/tech_${name}_intro.png');
      await tester.tap(find.text('직접 해 보기'));
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
    await _shot(tester, key, '$dir/tech_${name}_practice.png');
      await tester.tap(find.widgetWithText(TextButton, '힌트'));
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
    await _shot(tester, key, '$dir/tech_${name}_hint1.png');
    }
  }, skip: dir == null);

  testWidgets('스도쿠 심화 기술 미리보기 (태블릿 가로, 어두운 테마)', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    final i = kTechniqueInfos.indexWhere((t) => t.technique.name == 'nakedPair');
    await _pumpApp(tester, key, SudokuTechniqueLessonScreen(index: i), brightness: Brightness.dark);
    await _settle(tester);
    await _shot(tester, key, '$dir/tablet_nakedPair_intro.png');
    await tester.tap(find.text('직접 해 보기'));
    await tester.pump(const Duration(milliseconds: 300));
    // 메모 모드에서 칸을 고른 모습 (선택·같은 줄 강조가 녹색 계열)
    tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game.select(40);
    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    await _shot(tester, key, '$dir/tablet_nakedPair_practice.png');
    await _pumpApp(tester, key, const SudokuPracticeMenuScreen());
    await tester.pumpAndSettle();
    await _settle(tester);
    await _shot(tester, key, '$dir/tablet_practice_menu.png');
  }, skip: dir == null);

  testWidgets('다른 게임 튜토리얼 미리보기', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    for (final entry in previewTutorials().entries) {
      final GameTutorial t = entry.value;
      await _pumpApp(tester, key, TutorialScreen(tutorial: t, firstTime: true));
      // 그림 파일은 비동기로 읽히니 미리 불러 둔다
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(TutorialScreen));
        for (final name in ['c0_strike', 'c1_strike', 'c2_strike', 'c3_windup', 'c3_strike']) {
          await precacheImage(AssetImage('assets/rhythm/art/$name.png'), ctx);
        }
      });
      for (var i = 0; i < t.steps.length; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
    await _shot(tester, key, '$dir/${entry.key}_${(i + 1).toString().padLeft(2, '0')}.png');
        if (i < t.steps.length - 1) {
          await tester.tap(find.text('다음'));
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
    }
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('TUTORIAL_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
