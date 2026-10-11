// 힌트 화면을 기술별로 그림(PNG)으로 뽑아보는 도구.
// 환경변수 SUDOKU_PREVIEW_DIR 가 지정됐을 때만 실행된다. (평소 테스트에서는 건너뜀)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sudoku/core/generator.dart';
import 'package:tabgame/games/sudoku/core/techniques.dart';
import 'package:tabgame/games/sudoku/game/sudoku_game.dart';
import 'package:tabgame/games/sudoku/ui/board_widget.dart';
import 'package:tabgame/games/sudoku/ui/controls.dart';

/// 각 기술이 "처음 힌트로 나오는 순간"의 게임 상태를 찾는다.
Map<Technique, SudokuGame> findScenarios(Set<Technique> wanted) {
  final rng = Random(11);
  final found = <Technique, SudokuGame>{};
  for (var attempt = 0; attempt < 300 && found.length < wanted.length; attempt++) {
    final p = PuzzleGenerator.generate(Difficulty.hard, rng: rng);
    final g = CandidateGrid.fromValues(p.givens);
    while (!g.isSolved) {
      final s = StepFinder.next(g);
      if (s == null) break;
      if (wanted.contains(s.technique) && !found.containsKey(s.technique)) {
        final auto = CandidateGrid.fromValues(g.values).cand;
        final elims = [
          for (var i = 0; i < 81; i++) g.values[i] == 0 ? auto[i] & ~g.cand[i] : 0,
        ];
        final game = SudokuGame(
          puzzle: p,
          values: List.of(g.values),
          hintElims: elims,
        )..autoNotes();
        game.requestHint();
        if (game.hint?.technique == s.technique) found[s.technique] = game;
      }
      g.apply(s);
    }
  }
  return found;
}

void main() {
  final dir = Platform.environment['SUDOKU_PREVIEW_DIR'];

  testWidgets('힌트 화면 미리보기 이미지 만들기', (tester) async {
    final loader = FontLoader('NanumGothic');
    for (final f in ['Regular', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/NanumGothic-$f.ttf'));
    }
    await loader.load();

    final wanted = {
      Technique.hiddenSingle,
      Technique.pointing,
      Technique.claiming,
      Technique.nakedPair,
      Technique.hiddenPair,
      Technique.nakedTriple,
      Technique.xWing,
      Technique.xyWing,
      Technique.xyzWing,
    };
    final scenarios = findScenarios(wanted);
    // ignore: avoid_print
    print('찾은 기술: ${scenarios.keys.map((t) => t.label).join(', ')}');
    await tester.binding.setSurfaceSize(const Size(520, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final entry in scenarios.entries) {
      final game = entry.value;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NanumGothic',
            scaffoldBackgroundColor: const Color(0xFFF6F3EE),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFFF6F3EE),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AspectRatio(aspectRatio: 1, child: SudokuBoard(game: game)),
                    const SizedBox(height: 16),
                    HintPanel(game: game, hint: game.hint!),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$dir/${entry.key.name}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  }, skip: dir == null);

  test('(미리보기 도구) 안내', () {
    if (dir == null) {
      // ignore: avoid_print
      print('SUDOKU_PREVIEW_DIR 가 없어서 미리보기 생성은 건너뜀');
    }
  });
}
