import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/prophecy/core/prophecy_ai.dart';
import 'package:tabgame/games/prophecy/core/prophecy_examples.dart';
import 'package:tabgame/games/prophecy/core/prophecy_lessons.dart';
import 'package:tabgame/games/prophecy/core/prophecy_rules.dart';
import 'package:tabgame/games/prophecy/data/prophecy_history.dart';
import 'package:tabgame/games/prophecy/game/prophecy_controller.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_board.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_lesson_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_lesson_widgets.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_records_tab.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_screen.dart';
import 'package:tabgame/games/prophecy/ui/prophecy_setup_screen.dart';
import 'package:tabgame/games/prophecy/ui/table_picker.dart';

import '../support/preview_kit.dart';

Future<Widget> app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// 표 화면 좌표: 칸 [cell]의 가운데.
Offset cellCenter(WidgetTester tester, ProphecyController c, int cell) {
  final rect = tester.getRect(find.byType(ProphBoard));
  final layout = ProphLayout(rect.size, c.rows, c.cols, maxCell: prophMaxCell(tester.element(find.byType(ProphBoard))));
  return rect.topLeft + layout.cellRect(cell).center;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('예시 판과 교과학습 계산', () {
    test('안내 그림: 같은 숫자 두 번은 안 되고, 마지막 숫자를 쓰면 막힌 칸이 저절로 X가 된다', () {
      final rep = repeatBoard();
      expect(rep.canPlay(kRepeatCell, 4), isFalse);
      expect(rep.canPlay(kRepeatCell, 2), isTrue);

      final before = deadCellBefore();
      expect(before.cells[0], kBlank);
      expect(before.canPlay(8, 4), isTrue);
      final after = before.copy()..play(8, 4);
      expect(after.cells[0], kCross);
      expect(after.owners[0], kNoOwner);
      expect(deadCellAfter().cells[0], kCross);
    });

    test('책의 표는 12 : 19점이고, 행 4개와 열 4개에서 맞았다', () {
      final s = bookBoard();
      expect(s.scores(), [12, 19]);
      expect(s.hits().where((h) => h.byRow).length, 4);
      expect(s.hits().where((h) => h.byCol).length, 4);
    });

    test('폰 노이만의 수: 0={}, 1={{}}, 2={{}, {{}}}, 중괄호 쌍은 2의 n제곱', () {
      expect(vonNeumann(0), '{}');
      expect(vonNeumann(1), '{{}}');
      expect(vonNeumann(2), '{{}, {{}}}');
      expect(vonNeumann(3), '{{}, {{}}, {{}, {{}}}}');
      for (var n = 0; n <= 5; n++) {
        expect(braceCount(n), pow(2, n), reason: 'n=$n');
      }
    });

    test('자기 설명 표: 칸이 3개까지는 답이 없고, 4칸부터 답이 있다 (2·3·2·1, 3·1·3·1)', () {
      for (var k = 1; k <= 3; k++) {
        expect(selfDescribingTables(k), isEmpty, reason: '칸 $k개');
      }
      final four = selfDescribingTables(4);
      expect(four, containsAll([[2, 3, 2, 1], [3, 1, 3, 1]]));
      expect(four.length, 2);
      expect(selfDescribing([1, 2, 3, 4], [2, 3, 2, 1]), isTrue);
      expect(selfDescribing([1, 2, 3, 4], [1, 1, 1, 1]), isFalse);
      expect(selfDescribingTables(5), isNotEmpty);
    });

    test('자기 글자 수를 세는 문장은 정말 열여덟 글자, 베리의 문장은 스물다섯 글자 미만이다', () {
      expect(letterCount(kSelfCountingSentence), 18);
      expect(kSelfCountingSentence, contains('열여덟'));
      expect(letterCount(kBerryPhrase), 24); // "스물다섯 글자 미만"으로 정의했다 (모순의 핵심)
      expect(letterCount(kBerryPhrase), lessThan(25));
      expect(kBerryPhrase, '스물다섯 글자 미만으로 정의할 수 없는 가장 작은 양의 정수');
    });

    test('샐로스의 팬그램은 문장이 말한 알파벳 개수가 실제와 모두 같다', () {
      const claimed = [4, 1, 2, 1, 30, 6, 5, 7, 11, 1, 1, 2, 2, 18, 15, 2, 1, 5, 27, 18, 2, 7, 8, 2, 3, 1];
      expect(letterTally(kSallowsPangram).values.toList(), claimed);
      expect(letterTally(kSallowsPangram).values.every((v) => v > 0), isTrue);
    });

    test('샐로스의 "바보" 문장은 알파벳·쉼표·어포스트로피·하이픈·느낌표 개수를 모두 정확히 말한다', () {
      const claimed = {
        'a': 10, 'b': 3, 'c': 4, 'd': 4, 'e': 46, 'f': 16, 'g': 4, 'h': 13, 'i': 15, 'k': 2, 'l': 9, 'm': 4,
        'n': 25, 'o': 24, 'p': 5, 'r': 16, 's': 41, 't': 37, 'u': 10, 'v': 8, 'w': 8, 'x': 4, 'y': 11,
        ',': 27, '’': 23, '-': 7, '!': 1,
      };
      expect(charTally(kSallowsFoolSentence, claimed.keys), claimed);
      // 문장에 안 나오는 알파벳은 정말 하나도 없다.
      expect(charTally(kSallowsFoolSentence, ['j', 'q', 'z']).values, everyElement(0));
    });

    test('맛보기 노트의 줄 [4, X, ?, 3]: 무엇을 써도 2는 맞을 수 없고, 1이나 2를 쓰면 3이 맞는다', () {
      for (final v in [1, 2]) {
        final o = rowOutcome([4, kCross, v, 3]);
        expect(o.count, 3);
        expect(o.correct, [3]);
      }
      final x = rowOutcome([4, kCross, kCross, 3]);
      expect(x.count, 2);
      expect(x.correct, isEmpty);
    });
  });

  group('표 크기 고르개', () {
    testWidgets('누르거나 끌면 그 칸까지 행×열이 정해지고, 4×4보다 작게는 안 된다', (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var rows = 5, cols = 5;
      await tester.pumpWidget(await app(StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Center(child: TablePicker(rows: rows, cols: cols, onChanged: (r, c) => setState(() {
            rows = r;
            cols = c;
          }))),
        ),
      )));
      expect(find.text('5행 × 5열  ·  칸 25개'), findsOneWidget);
      final grid = tester.getRect(find.byType(CustomPaint).last);
      // 격자 왼쪽 위(번호 칸 22px 뒤)에서 한 칸의 크기: 위젯 폭에서 계산
      final side = grid.width;
      final cell = (side - 22) / kMaxSide;
      Offset at(int r, int c) => grid.topLeft + Offset(22 + (c - 0.5) * cell, 22 + (r - 0.5) * cell);

      await tester.tapAt(at(7, 6)); // 7행 6열
      await tester.pump();
      expect((rows, cols), (7, 6));
      expect(find.text('7행 × 6열  ·  칸 42개'), findsOneWidget);

      await tester.tapAt(at(2, 1)); // 너무 작으면 4×4로
      await tester.pump();
      expect((rows, cols), (4, 4));

      // 끌어서 8×8까지
      final g = await tester.startGesture(at(4, 4));
      await g.moveTo(at(6, 7));
      await g.moveTo(at(8, 8));
      await g.up();
      await tester.pump();
      expect((rows, cols), (8, 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('게임 화면', () {
    testWidgets('칸을 누르고 숫자를 쓰면 차례가 넘어가고, 같은 줄에 있는 숫자는 숫자판에서 막힌다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = ProphecyController(mode: PlayMode.local2p, rows: 4, cols: 5);
      await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
      await settle(tester, rounds: 2);
      expect(find.textContaining('플레이어 1 차례'), findsWidgets);
      expect(find.textContaining('빈칸을 눌러'), findsWidgets);

      // 0번 칸을 눌러 4를 쓴다
      await tester.tapAt(cellCenter(tester, c, 0));
      await tester.pump();
      expect(c.selected, 0);
      expect(find.textContaining('1행 1열에 쓸 숫자나 X를 고르세요'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '4'));
      await tester.pump();
      expect(c.state.cells[0], 4);
      expect(c.state.owners[0], 0);
      expect(c.state.turn, 1);
      expect(c.selected, -1);
      expect(find.textContaining('플레이어 2 차례'), findsWidgets);

      // 같은 행의 다음 칸에서는 4가 막힌다 (줄이 그어진 숫자 버튼은 눌러도 안 써진다)
      await tester.tapAt(cellCenter(tester, c, 1));
      await tester.pump();
      final four = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '4'));
      expect(four.onPressed, isNull);
      expect(find.text('5'), findsWidgets); // 가장 긴 줄(5칸)까지의 숫자가 있다
      await tester.tap(find.widgetWithText(FilledButton, 'X'));
      await tester.pump();
      expect(c.state.cells[1], kCross);
      expect(c.moveCount, 2);

      // 되돌리기 → 방금 쓴 X가 사라지고 다시 플레이어 2 차례
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      expect(c.state.cells[1], kBlank);
      expect(c.moveCount, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('끝까지 두면 점수가 나오고 기록이 남는다 (동그라미와 화살표가 그려진다)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = ProphecyController(mode: PlayMode.local2p, rows: 4, cols: 4);
      await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
      await settle(tester, rounds: 2);
      final rng = Random(3);
      while (!c.isOver) {
        final ms = c.state.legalMoves();
        final m = ms[rng.nextInt(ms.length)];
        c.select(moveCell(m));
        expect(c.write(moveValue(m)), isTrue);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000)); // 점수 표시가 차례로 나타난다
      final sc = c.state.scores();
      expect(find.text('${sc[0]}점'), findsWidgets);
      expect(find.text('${sc[1]}점'), findsWidgets);
      expect(find.text('한 판 더'), findsOneWidget);
      expect(find.textContaining('좌우 화살표는 행'), findsOneWidget);
      final h = await tester.runAsync(ProphHistory.load);
      expect(h!.length, 1);
      expect(h.single.score0, sc[0]);
      expect(h.single.score1, sc[1]);
      expect(h.single.rows, 4);
      expect(h.single.winner, c.state.winner);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('한 판 더'));
      await tester.pump();
      expect(c.moveCount, 0);
      expect(c.isOver, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CPU 대결: 사람이 쓰면 CPU가 이어서 쓴다 (쉬움·보통·어려움 모두 규칙대로)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final level in ProphLevel.values) {
        final c = ProphecyController(mode: PlayMode.vsCpu, rows: 4, cols: 4, humanSide: 0, level: level)..cpuStageDelay = const Duration(milliseconds: 20);
        await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
        await settle(tester, rounds: 2);
        c.select(5);
        expect(c.write(2), isTrue);
        expect(c.thinking, isTrue);
        expect(c.humanCanAct, isFalse);
        await settle(tester, rounds: 30);
        expect(c.thinking, isFalse, reason: level.label);
        expect(c.moveCount, 2, reason: level.label);
        expect(c.state.owners[moveCell(c.moves.last)], 1);
        expect(c.humanCanAct, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('CPU 차례: 칸을 고르고 → 기다렸다가 → 숫자를 고르고 → 기다렸다가 → 쓰고 내 차례가 된다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = ProphecyController(mode: PlayMode.vsCpu, rows: 4, cols: 4, humanSide: 0, level: ProphLevel.easy)..cpuStageDelay = const Duration(milliseconds: 150);
      await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
      await settle(tester, rounds: 2);
      c.select(5);
      c.write(2);
      final seen = <String>[];
      c.addListener(() {
        if (c.cpuCell >= 0) seen.add(c.cpuValue == null ? 'cell' : 'value');
      });
      // 생각이 끝나면 칸만 먼저 골라 두고, 한참 뒤에야 숫자를 고르고, 또 뒤에 쓴다
      for (var i = 0; i < 80 && c.cpuCell < 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(c.cpuCell, greaterThanOrEqualTo(0));
      expect(c.cpuValue, isNull);
      expect(c.moveCount, 1); // 아직 쓰지 않았다
      expect(c.humanCanAct, isFalse);
      expect(find.textContaining('칸을 골랐어요'), findsOneWidget);
      for (var i = 0; i < 80 && c.cpuValue == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(c.cpuValue, isNotNull);
      expect(c.moveCount, 1);
      await tester.pump();
      expect(find.textContaining('를 써요').evaluate().length + find.textContaining('을(를) 써요').evaluate().length, greaterThan(0));
      await settle(tester, rounds: 12);
      expect(c.moveCount, 2);
      expect(c.cpuCell, -1);
      expect(c.humanCanAct, isTrue);
      expect(seen.first, 'cell');
      expect(seen.contains('value'), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CPU가 먼저 쓰는 판이면 열자마자 CPU가 쓴다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = ProphecyController(mode: PlayMode.vsCpu, rows: 4, cols: 4, humanSide: 1, level: ProphLevel.easy)..cpuStageDelay = const Duration(milliseconds: 20);
      await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
      await settle(tester, rounds: 30);
      expect(c.moveCount, 1);
      expect(c.state.owners[moveCell(c.moves.first)], 0);
      expect(c.humanCanAct, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (name, size) in const [
      ('폰 세로', Size(360, 740)),
      ('작은 가로', Size(740, 360)),
      ('태블릿 가로', Size(1280, 800)),
    ]) {
      testWidgets('8×8 표도 넘침 없이 그려진다 ($name)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final c = ProphecyController(mode: PlayMode.local2p, rows: 8, cols: 8);
        await tester.pumpWidget(await app(ProphecyScreen(controller: c)));
        await settle(tester, rounds: 2);
        c.select(10);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('설정 화면', () {
    testWidgets('크기를 고르고 시작하면 그 크기의 판이 열린다 (CPU 대결은 쓰는 순서와 난이도도)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const ProphecySetupScreen(mode: PlayMode.vsCpu)));
      await settle(tester, rounds: 2);
      expect(find.text('표의 크기'), findsOneWidget);
      expect(find.text('5행 × 5열  ·  칸 25개'), findsOneWidget);
      expect(find.text('먼저 쓰기'), findsOneWidget);
      await tester.tap(find.text('어려움'));
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await settle(tester, rounds: 4);
      final screen = tester.widget<ProphecyScreen>(find.byType(ProphecyScreen));
      expect((screen.rows, screen.cols, screen.humanSide, screen.level), (5, 5, 0, ProphLevel.hard));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('둘이서는 크기만 고른다', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const ProphecySetupScreen(mode: PlayMode.local2p)));
      await settle(tester, rounds: 2);
      expect(find.text('CPU 난이도'), findsNothing);
      expect(find.text('튜토리얼 보기'), findsOneWidget);
      expect(find.text('교과학습'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('기록 탭', () {
    testWidgets('전적과 최근 결과가 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final page = await app(const Scaffold(body: ProphecyRecordsTab()));
      await tester.runAsync(() async {
        await ProphHistory.add(const ProphRecord(
          at: 1760000000000,
          vsCpu: true,
          rows: 5,
          cols: 5,
          score0: 20,
          score1: 12,
          winner: 0,
          moves: 25,
          level: ProphLevel.hard,
          human: 0,
        ));
        await ProphHistory.add(const ProphRecord(
          at: 1760000100000,
          vsCpu: false,
          rows: 4,
          cols: 6,
          score0: 9,
          score1: 9,
          winner: null,
          moves: 24,
        ));
      });
      await tester.pumpWidget(page);
      await settle(tester, rounds: 6);
      expect(find.textContaining('이겼어요 · CPU 어려움'), findsOneWidget);
      expect(find.text('무승부'), findsWidgets);
      expect(find.textContaining('표 5×5'), findsOneWidget);
      expect(find.textContaining('20 : 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('교과학습 화면', () {
    Future<void> pumpLesson(WidgetTester tester, {double width = 430}) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await app(const ProphecyLessonScreen()));
      await tester.pump();
    }

    testWidgets('모든 단원이 오류 없이 열린다', (tester) async {
      await pumpLesson(tester);
      expect(find.text('교과학습'), findsOneWidget);
      await tester.tap(find.textContaining('1. 예언 한눈에 보기'));
      await tester.pumpAndSettle();
      for (var i = 1; i < 12; i++) {
        expect(tester.takeException(), isNull, reason: '$i번째 단원');
        await tester.scrollUntilVisible(find.textContaining('다음:'), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.textContaining('다음:'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('다음:'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('퀴즈로 확인하기'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    Future<void> openUnit(WidgetTester tester, String title) async {
      await tester.scrollUntilVisible(find.textContaining(title), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.textContaining(title));
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('맛보기 노트: 2를 쓰면 3이 맞고, X를 쓰면 아무도 못 맞힌다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '3. 맛보기 노트');
      await tapVisible(tester, find.text('2 쓰기'));
      expect(find.textContaining('2를 쓰는 순간 숫자가 3개가 되어'), findsWidgets);
      expect(find.textContaining('이 행의 숫자: 3개'), findsOneWidget);
      await tapVisible(tester, find.text('X 쓰기'));
      expect(find.textContaining('맞은 예언은 하나도 없어요'), findsOneWidget);
      expect(find.textContaining('이 행의 숫자: 2개'), findsOneWidget);
    });

    testWidgets('자기 설명 표: 정답 보기로 4칸 표가 맞춰진다, 3칸 표는 답이 없다고 알려 준다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      await tapVisible(tester, find.text('정답 보기'));
      expect(find.textContaining('성공!'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '3'));
      await tapVisible(tester, find.text('정답 보기'));
      expect(find.text('칸이 3개일 때는 답이 없어요'), findsOneWidget);
      await tester.tap(find.text('알겠어요'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('좁은 폰 화면(너비 320)에서도 표의 칸 수 5를 누를 수 있고 넘침이 없다', (tester) async {
      await pumpLesson(tester, width: 320);
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      final five = find.widgetWithText(ChoiceChip, '5');
      await tester.scrollUntilVisible(five, 300, scrollable: find.byType(Scrollable).first);
      final right = tester.getTopRight(five).dx;
      expect(right, lessThanOrEqualTo(320));
      await tester.tap(five);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(five).selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('칸이 하나뿐인 표: 1을 쓰면 1이 2번, 2를 쓰면 1이 1번이라 둘 다 틀린 표로 보인다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      await tester.scrollUntilVisible(find.text('아래 줄에 1을 쓰면'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('아래 줄에 1을 쓰면'), findsOneWidget);
      expect(find.text('아래 줄에 2를 쓰면'), findsOneWidget);
      expect(find.text('표 전체에서 숫자 1은 2번'), findsOneWidget);
      expect(find.text('표 전체에서 숫자 1은 1번'), findsOneWidget);
      expect(find.text('그런데 아래 줄은 "1번"'), findsOneWidget);
      expect(find.text('그런데 아래 줄은 "2번"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('러셀·이발사·정지 문제 장치가 모두 모순을 보여 준다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '8. 러셀의 역설과 이발사');
      await tapVisible(tester, find.text('이발사가 스스로 깎는다'));
      expect(find.textContaining('자기 규칙을 어겨요'), findsOneWidget);
      await tapVisible(tester, find.text('다른 사람이 깎아 준다'));
      expect(find.textContaining('또 모순!'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openUnit(tester, '10. 괴델과 튜링');
      await tapVisible(tester, find.text('"멈춘다"'));
      expect(find.textContaining('H의 예언이 틀렸어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('자기 설명 표(화살표 표): 처음에는 실제 5·1·1·1번, 화살표로 고치고 처음으로 되돌릴 수 있다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('self-table')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('실제 5번'), findsOneWidget);
      expect(find.text('실제 1번'), findsNWidgets(3));
      expect(tester.widget<Text>(find.byKey(const ValueKey('self-count-0'))).data, '1');
      // 첫 칸의 위 화살표를 누르면 1 → 2
      await tester.tap(find.byKey(const ValueKey('self-up-0')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('self-count-0'))).data, '2');
      expect(find.text('실제 4번'), findsOneWidget); // 1은 위 줄 하나 + 아래 줄 셋
      // 아래 화살표로 다시 1
      await tester.tap(find.byKey(const ValueKey('self-down-0')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('self-count-0'))).data, '1');
      // 1보다 작게는 안 내려간다
      await tester.tap(find.byKey(const ValueKey('self-down-0')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const ValueKey('self-count-0'))).data, '1');
      // 정답을 보여 준 뒤 '처음으로'
      await tapVisible(tester, find.text('정답 보기'));
      expect(find.textContaining('성공!'), findsOneWidget);
      await tapVisible(tester, find.text('처음으로'));
      expect(find.textContaining('성공!'), findsNothing);
      expect(find.text('실제 5번'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('글상자: 문장을 고치면 알파벳 개수가 바로 바뀌고, 처음 문장으로 되돌릴 수 있다', (tester) async {
      await pumpLesson(tester);
      tester.view.physicalSize = const Size(430, 3200); // 글상자와 개수 칩이 한 화면에 다 들어오게
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      final field = find.byKey(const ValueKey('editable-sentence'));
      expect(find.text('A 4').first, findsOneWidget); // 샐로스의 팬그램: A 네 개
      await tester.enterText(field.first, 'aaa banana');
      await tester.pump();
      expect(find.text('A 6 (원래 4)').first, findsOneWidget);
      expect(find.text('B 1'), findsWidgets);
      expect(find.textContaining('달라진 글자가'), findsWidgets);
      // 글자를 새로 더해도 바로 바뀐다
      await tester.enterText(field.first, 'aaa banana a');
      await tester.pump();
      expect(find.text('A 7 (원래 4)').first, findsOneWidget);
      // 지우면 모두 0이 된다
      await tester.tap(find.byKey(const ValueKey('editable-clear')).first);
      await tester.pump();
      expect(find.text('A 0 (원래 4)').first, findsOneWidget);
      // 처음 문장으로
      await tester.tap(find.byKey(const ValueKey('editable-reset')).first);
      await tester.pump();
      expect(find.text('A 4').first, findsOneWidget);
      expect(find.textContaining('처음 문장 그대로예요').first, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('한국어 자기 설명 문장도 고칠 수 있고 글자 수가 달라지면 틀렸다고 알려 준다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '4. 자기 자신을 설명하는 표');
      final count = find.byKey(const ValueKey('editable-count'));
      await tester.scrollUntilVisible(count, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('공백을 빼고 센 글자 수: 18'), findsOneWidget);
      expect(find.textContaining('같아요!'), findsWidgets);
      final field = find.byKey(const ValueKey('editable-sentence')).last;
      await tester.enterText(field, '이 문장은 공백을 빼면 모두 열여덟 글자예요 정말로');
      await tester.pump();
      expect(find.textContaining('공백을 빼고 센 글자 수: 21'), findsOneWidget);
      expect(find.textContaining('맞지 않아요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('더 많은 역설들: 베리의 역설은 스물다섯 글자 미만, 커리의 역설은 한 단계씩 따라갈 수 있다', (tester) async {
      await pumpLesson(tester);
      await openUnit(tester, '9. 더 많은 역설들');
      final berryTitle = find.textContaining('스물다섯 글자 미만으로 정의할 수 없는 가장 작은 양의 정수');
      await tester.scrollUntilVisible(berryTitle, 300, scrollable: find.byType(Scrollable).first);
      expect(berryTitle, findsOneWidget);
      final berryBox = find.ancestor(of: berryTitle, matching: find.byType(LessonReveal));
      await tapVisible(tester, find.descendant(of: berryBox, matching: find.text('답 보기'))); // 베리
      expect(find.textContaining('공백을 빼면 24글자예요'), findsOneWidget);
      // 커리
      final next = find.byKey(const ValueKey('curry-next'));
      await tester.scrollUntilVisible(next, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('curry-step-0')), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('curry-step-$i')), findsOneWidget, reason: '${i + 1}단계');
      }
      expect(find.textContaining('증명해 버렸어요'), findsOneWidget);
      // 결론 문장을 바꾸면 처음부터 다시
      await tester.ensureVisible(find.byKey(const ValueKey('curry-claim-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('curry-claim-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('curry-step-0')), findsNothing);
      expect(find.textContaining('1 + 1 = 3이다'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
