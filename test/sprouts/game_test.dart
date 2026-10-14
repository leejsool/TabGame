import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/sprouts/core/sprouts_ai.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_geometry.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/game/sprouts_controller.dart';

/// 컨트롤러에서 [move]를 사람이 그은 것처럼 둔다.
bool draw(SproutsController c, SproutsMove m) => c.tryStroke(m.path);

void main() {
  group('CPU 수 고르기', () {
    test('모든 난이도가 합법적인 수를 고르고, 판을 끝까지 둘 수 있다', () {
      for (final level in SproutsLevel.values) {
        final rng = Random(level.index + 7);
        final b = SproutsBoard.initial(3, rng);
        var moves = 0;
        while (true) {
          final m = chooseMove(b, level, rng, budget: const Duration(milliseconds: 600));
          if (m == null) break;
          expect(m.result.ok, isTrue);
          b.apply(m.s, m.e, m.result, moves % 2);
          moves++;
          expect(moves, lessThanOrEqualTo(8), reason: '${level.label}: 점 3개 판은 8수 안에 끝나야 해요');
        }
        expect(hasMove(b), isFalse);
        expect(moves, greaterThanOrEqualTo(6), reason: level.label);
      }
    });

    test('상대가 막히는 수가 있으면 그 수를 둔다 (보통·어려움)', () {
      // 점 두 개, 한쪽을 고리로 막아 두고 한 수만 남긴 판을 만든다: 마지막 한 수를 두면 끝난다
      final rng = Random(3);
      final b = SproutsBoard.initial(2, rng);
      // 거의 끝난 판을 만들 때까지 무작위로 둔다
      while (b.totalLives > 2) {
        final ms = findMoves(b);
        if (ms.isEmpty) break;
        final m = ms[rng.nextInt(ms.length)];
        b.apply(m.s, m.e, m.result, 0);
      }
      for (final level in [SproutsLevel.normal, SproutsLevel.hard]) {
        final m = chooseMove(b, level, Random(1), budget: const Duration(milliseconds: 800));
        if (m == null) continue; // 이미 끝난 판
        final nb = b.copy()..apply(m.s, m.e, m.result, 0);
        // 가능한 수들 가운데 상대를 막는 수가 있었다면 그것을 골랐어야 한다
        final winning = findMoves(b).any((c) => !hasMove(b.copy()..apply(c.s, c.e, c.result, 0)));
        if (winning) expect(hasMove(nb), isFalse, reason: level.label);
      }
    });
  });

  group('컨트롤러 (둘이서)', () {
    SproutsController two() => SproutsController(mode: PlayMode.local2p, dotCount: 3, rng: Random(5));

    test('곡선을 그으면 차례가 바뀌고 새 점이 생긴다. 안 되는 선은 이유를 알려 준다', () {
      final c = two();
      expect(c.turn, 0);
      // 점 아닌 곳에서 시작
      expect(c.tryStroke([const P(5, 5), const P(30, 30)]), isFalse);
      expect(c.message, contains('점'));
      expect(c.turn, 0);

      final m = findMoves(c.board).firstWhere((m) => !m.isLoop);
      final livesBefore = c.livesLeft;
      expect(draw(c, m), isTrue);
      expect(c.turn, 1);
      expect(c.moveCount, 1);
      expect(c.board.dots.length, 4);
      expect(c.livesLeft, livesBefore - 1);
      expect(c.message, isNull);
      c.dispose();
    });

    test('끝까지 두면 마지막으로 둔 사람이 이긴다', () {
      final c = two();
      var last = -1;
      var guard = 0;
      while (!c.isOver && guard++ < 20) {
        final ms = findMoves(c.board);
        expect(ms, isNotEmpty);
        last = c.turn;
        expect(draw(c, ms.first), isTrue);
      }
      expect(c.isOver, isTrue);
      expect(c.winner, last);
      expect(c.moveCount, inInclusiveRange(6, 8));
      // 끝난 뒤에는 더 못 둔다
      expect(c.tryStroke([const P(0, 0), const P(1, 1)]), isFalse);
      c.dispose();
    });

    test('되돌리기는 한 수씩, 기권은 한 수 둔 뒤에만 되고 상대가 이긴다', () {
      final c = two();
      expect(c.canUndo, isFalse);
      expect(c.canResign, isFalse);
      draw(c, findMoves(c.board).first);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.moveCount, 0);
      expect(c.turn, 0);
      expect(c.board.dots.length, 3);
      draw(c, findMoves(c.board).first);
      expect(c.turn, 1);
      expect(c.resign(), isTrue); // 지금 차례인 플레이어 2가 기권
      expect(c.isOver, isTrue);
      expect(c.resigned, isTrue);
      expect(c.winner, 0);
      c.dispose();
    });

    test('힌트는 합법적인 곡선을 잠깐 보여 주고, 곧바로 그대로 그으면 된다', () {
      final c = two();
      expect(c.showHint(), isTrue);
      final hint = c.hintPath!;
      expect(c.tryStroke(hint), isTrue);
      expect(c.hintPath, isNull);
      c.dispose();
    });
  });

  group('컨트롤러 (CPU 대결)', () {
    test('사람이 두면 CPU가 응답하고, CPU가 생각하는 동안에는 둘 수 없다', () async {
      final c = SproutsController(mode: PlayMode.vsCpu, dotCount: 3, level: SproutsLevel.easy, rng: Random(9));
      draw(c, findMoves(c.board).first);
      expect(c.thinking, isTrue);
      expect(c.humanCanAct, isFalse);
      for (var i = 0; i < 100 && (c.thinking || c.turn != c.humanSide) && !c.isOver; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(c.moveCount, greaterThanOrEqualTo(2));
      expect(c.isOver || c.turn == c.humanSide, isTrue);
      c.dispose();
    });

    test('CPU가 먼저인 판은 start()로 CPU가 첫 수를 둔다', () async {
      final c = SproutsController(mode: PlayMode.vsCpu, dotCount: 3, humanSide: 1, level: SproutsLevel.easy, rng: Random(2));
      c.start();
      for (var i = 0; i < 100 && c.moveCount == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(c.moveCount, 1);
      expect(c.turn, 1); // 이제 사람(나중) 차례
      expect(c.humanCanAct, isTrue);
      c.dispose();
    });

    test('CPU 대결 되돌리기는 내 수와 CPU의 응답을 함께 되돌린다', () async {
      final c = SproutsController(mode: PlayMode.vsCpu, dotCount: 3, level: SproutsLevel.easy, rng: Random(4));
      draw(c, findMoves(c.board).first);
      for (var i = 0; i < 100 && c.thinking; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(c.moveCount, 2);
      c.undo();
      expect(c.moveCount, 0);
      expect(c.turn, 0);
      c.dispose();
    });
  });
}
