import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/freecell/data/freecell_storage.dart';
import 'package:tabgame/games/jigsaw/data/jigsaw_history.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/solitaire/data/solitaire_storage.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/data/sudoku_history.dart';
import 'package:tabgame/games/sudoku/ui/game_screen.dart';
import 'package:tabgame/records/favorites.dart';
import 'package:tabgame/records/records_screen.dart';

import '../support/preview_kit.dart';

Future<Widget> appWith(Widget home) async {
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true, fontFamily: 'NanumGothic'), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

SudokuRecord sudokuRecord({int seconds = 245, int at = 1760000000000, int seed = 1}) {
  final p = PuzzleGenerator.generate(Difficulty.easy, rng: Random(seed));
  return SudokuRecord(at: at, difficulty: Difficulty.easy, seconds: seconds, mistakes: 1, hints: 2, givens: p.givensString, solution: p.solutionString);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
  });

  group('즐겨찾기 저장소', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('같은 판은 한 번만 담기고, 다시 담으면 맨 앞으로 오며 기록이 새것으로 바뀐다', () async {
      final fav = SolitaireStorage.favorites;
      await fav.add(const SolitaireRecord(at: 1, deal: 100, draw: 1, seconds: 300, moves: 90));
      await fav.add(const SolitaireRecord(at: 2, deal: 200, draw: 3, seconds: 400, moves: 110));
      await fav.add(const SolitaireRecord(at: 3, deal: 100, draw: 3, seconds: 500, moves: 120)); // 같은 번호라도 뽑기 장수가 다르면 다른 판
      expect((await fav.load()).map((r) => r.at), [3, 2, 1]);
      await fav.add(const SolitaireRecord(at: 4, deal: 100, draw: 1, seconds: 250, moves: 80)); // 1번 판을 다시 담음
      final list = await fav.load();
      expect(list.map((r) => r.at), [4, 3, 2]);
      expect(list.first.seconds, 250);
      await fav.remove(const SolitaireRecord(at: 99, deal: 200, draw: 3, seconds: 0, moves: 0)); // 판이 같으면 지워진다
      expect((await fav.load()).map((r) => r.at), [4, 3]);
    });

    test('즐겨찾기는 기록이 넘쳐 오래된 기록이 지워져도 남는다', () async {
      final old = sudokuRecord(seconds: 1, at: 0, seed: 77);
      await SudokuHistory.favorites.add(old);
      await SudokuHistory.add(old);
      for (var i = 1; i < SudokuHistory.maxEntries + 5; i++) {
        await SudokuHistory.add(sudokuRecord(seconds: i + 10, at: i, seed: 2));
      }
      final history = await SudokuHistory.load();
      expect(history.any((r) => r.givens == old.givens), isFalse); // 기록에서는 밀려났지만
      final favs = await SudokuHistory.favorites.load();
      expect(favs.single.givens, old.givens); // 즐겨찾기에는 있다 (문제도 그대로)
      expect(favs.single.puzzle.givensString, old.givens);
    });

    test('같은 판을 다시 해서 더 빨리 끝내면 즐겨찾기에는 그 기록이 보인다', () async {
      final set = FavoriteSet(SolitaireStorage.favorites);
      const slow = SolitaireRecord(at: 1, deal: 7, draw: 1, seconds: 600, moves: 100);
      await SolitaireStorage.favorites.add(slow);
      await set.load();
      expect(set.has(const SolitaireRecord(at: 5, deal: 7, draw: 1, seconds: 1, moves: 1)), isTrue);
      expect(set.has(const SolitaireRecord(at: 5, deal: 8, draw: 1, seconds: 1, moves: 1)), isFalse);
      const fast = SolitaireRecord(at: 2, deal: 7, draw: 1, seconds: 420, moves: 95);
      const other = SolitaireRecord(at: 3, deal: 9, draw: 1, seconds: 10, moves: 50);
      final shown = set.shown([fast, other], (r) => r.seconds);
      expect(shown.single.seconds, 420);
      expect(set.shown([other], (r) => r.seconds).single.seconds, 600); // 새 기록이 없으면 담을 때의 기록
    });
  });

  group('기록 보드의 즐겨찾기', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('스도쿠: 별을 누르면 "즐겨찾기한 판"에 올라오고, 거기서 같은 판을 다시 풀 수 있다. 다시 누르면 빠진다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rec = sudokuRecord();
      SharedPreferences.setMockInitialValues({'sudoku.history': jsonEncode([rec.toJson()])});
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'sudoku')));
      await settle(tester, rounds: 4);
      expect(find.text('즐겨찾기한 판'), findsNothing);
      expect(find.byTooltip('즐겨찾기에 담기'), findsOneWidget);

      await tester.tap(find.byTooltip('즐겨찾기에 담기'));
      await settle(tester, rounds: 4);
      expect(find.text('즐겨찾기한 판'), findsOneWidget);
      expect(find.text('쉬움 · 04:05'), findsNWidgets(2)); // 즐겨찾기 + 완성한 판 목록
      expect(find.byTooltip('즐겨찾기 해제'), findsNWidgets(2)); // 같은 판이라 둘 다 별이 켜져 있다
      final saved = (await tester.runAsync(SudokuHistory.favorites.load))!;
      expect(saved.single.givens, rec.givens);

      // 즐겨찾기에서 다시 풀기 → 같은 문제
      await tester.tap(find.text('다시 풀기').first);
      await settle(tester, rounds: 4);
      expect(tester.widget<SudokuGameScreen>(find.byType(SudokuGameScreen)).game.puzzle.givensString, rec.givens);
      await tester.pumpWidget(const SizedBox());

      // 다시 열어서 별을 끄면 즐겨찾기에서 빠진다
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'sudoku')));
      await settle(tester, rounds: 4);
      expect(find.text('즐겨찾기한 판'), findsOneWidget); // (저장되어 있다)
      await tester.tap(find.byTooltip('즐겨찾기 해제').first);
      await settle(tester, rounds: 4);
      expect(find.text('즐겨찾기한 판'), findsNothing);
      expect(find.byTooltip('즐겨찾기에 담기'), findsOneWidget);
      expect((await tester.runAsync(SudokuHistory.favorites.load))!, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('솔리테어·프리셀: 번호가 있는 판을 즐겨찾기에 담으면 맨 위에 모이고 같은 번호로 다시 한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final game in ['solitaire', 'freecell']) {
        final history = [
          if (game == 'solitaire') ...[
            const SolitaireRecord(at: 1760000200000, deal: 4242, draw: 3, seconds: 500, moves: 120).toJson(),
            const SolitaireRecord(at: 1760000100000, deal: 77, draw: 1, seconds: 300, moves: 90).toJson(),
          ] else ...[
            const FreecellRecord(at: 1760000200000, deal: 4242, seconds: 500, moves: 120).toJson(),
            const FreecellRecord(at: 1760000100000, deal: 77, seconds: 300, moves: 90).toJson(),
          ],
        ];
        SharedPreferences.setMockInitialValues({'$game.history': jsonEncode(history)});
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(await appWith(RecordsScreen(initialGame: game)));
        await settle(tester, rounds: 5);
        expect(find.text('즐겨찾기한 판'), findsNothing, reason: game);
        expect(find.byTooltip('즐겨찾기에 담기'), findsNWidgets(2), reason: game);

        // 두 번째 판(#77)에 별을 단다
        await tester.tap(find.byTooltip('즐겨찾기에 담기').last);
        await settle(tester, rounds: 4);
        expect(find.text('즐겨찾기한 판'), findsOneWidget, reason: game);
        expect(find.textContaining('#77'), findsNWidgets(2), reason: game); // 즐겨찾기 + 목록
        expect(find.textContaining('#4242'), findsOneWidget, reason: game);
        expect(find.byTooltip('즐겨찾기 해제'), findsNWidgets(2), reason: game);
        final raw = (await tester.runAsync(() async => (await SharedPreferences.getInstance()).getString('$game.favorites')))!;
        expect((jsonDecode(raw) as List).single['deal'], 77, reason: game);
        expect(tester.takeException(), isNull, reason: game);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('직소퍼즐: 그림이 남은 퍼즐만 별을 달 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'jigsaw.history': jsonEncode([
          const JigsawRecord(at: 1760000200000, target: 24, pieces: 24, seconds: 400, source: JigsawSource('sample', 'garden')).toJson(),
          const JigsawRecord(at: 1760000100000, target: 12, pieces: 12, seconds: 200, source: JigsawSource.none).toJson(),
        ]),
      });
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'jigsaw')));
      await settle(tester, rounds: 6);
      expect(find.byTooltip('즐겨찾기에 담기'), findsOneWidget); // 그림이 없는 쪽에는 별이 없다
      await tester.tap(find.byTooltip('즐겨찾기에 담기'));
      await settle(tester, rounds: 6);
      expect(find.text('즐겨찾기한 퍼즐'), findsOneWidget);
      expect(find.text('24조각 · 06:40'), findsNWidgets(2));
      expect((await tester.runAsync(JigsawHistory.favorites.load))!.single.source.ref, 'garden');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('폰 세로·가로에서도 즐겨찾기가 있는 기록 보드가 넘치지 않는다', (tester) async {
      addTearDown(tester.view.reset);
      for (final size in const [Size(360, 640), Size(800, 500), Size(1280, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        final rec = sudokuRecord(seconds: 3725);
        SharedPreferences.setMockInitialValues({
          'sudoku.history': jsonEncode([rec.toJson()]),
          'sudoku.favorites': jsonEncode([rec.toJson()]),
          'solitaire.history': jsonEncode([const SolitaireRecord(at: 1760000200000, deal: 31999, draw: 3, seconds: 5999, moves: 999).toJson()]),
          'solitaire.favorites': jsonEncode([const SolitaireRecord(at: 1760000200000, deal: 31999, draw: 3, seconds: 5999, moves: 999).toJson()]),
        });
        for (final game in ['sudoku', 'solitaire']) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(await appWith(RecordsScreen(initialGame: game)));
          await settle(tester, rounds: 5);
          expect(find.text(game == 'sudoku' ? '즐겨찾기한 판' : '즐겨찾기한 판'), findsOneWidget, reason: '$game $size');
          expect(tester.takeException(), isNull, reason: '$game $size');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
