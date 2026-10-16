import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_info.dart';
import 'package:tabgame/games/quoridor/core/quoridor_ai.dart';
import 'package:tabgame/games/quoridor/core/quoridor_rules.dart';
import 'package:tabgame/games/quoridor/game/quoridor_controller.dart';

int cell(int r, int c) => r * kBoard + c;

/// 컨트롤러가 자동 이동을 마칠 때까지 기다린다.
Future<void> untilIdle(QuoridorController c) async {
  for (var i = 0; i < 400 && (c.autoPlaying || (!c.isOver && c.thinking)); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('모든 벽을 다 쓰면 자동으로 이동', () {
    test('가장 짧은 길로 한 걸음씩 가서, 먼저 닿는 사람이 이긴다 (2명)', () async {
      final c = QuoridorController(mode: PlayMode.local2p)..autoStepDelay = Duration.zero;
      c.state.wallsLeft.fillRange(0, 2, 0);
      c.start();
      expect(c.autoPlaying, isTrue);
      expect(c.humanCanAct, isFalse); // 자동으로 움직이는 동안은 직접 못 둔다
      expect(c.canUndo, isFalse);
      expect(c.canResign, isFalse);
      await untilIdle(c);
      expect(c.isOver, isTrue);
      expect(c.state.winner, isNotNull);
      expect(c.moveCount, lessThanOrEqualTo(16)); // 8칸씩인데, 마주 서면 뛰어넘어 걸음이 줄 수 있다
      // 같은 상태에서 다시 하면 결과가 똑같다 (정해진 길로만 가니까)
      final again = QuoridorController(mode: PlayMode.local2p)..autoStepDelay = Duration.zero;
      again.state.wallsLeft.fillRange(0, 2, 0);
      again.start();
      await untilIdle(again);
      expect(again.state.winner, c.state.winner);
      expect(again.moves, c.moves);
      again.dispose();
      expect(c.autoPlaying, isFalse);
      c.dispose();
    });

    test('4명도 끝까지 자동으로 가서 결과가 나온다', () async {
      final c = QuoridorController(mode: PlayMode.local2p, players: 4)..autoStepDelay = Duration.zero;
      c.state.wallsLeft.fillRange(0, 4, 0);
      c.start();
      await untilIdle(c);
      expect(c.isOver, isTrue);
      expect(c.state.winner, isNotNull);
      c.dispose();
    });

    test('마지막 벽을 세우는 수로 모두 벽이 떨어지면 그 자리에서 자동 이동이 시작된다', () async {
      final c = QuoridorController(mode: PlayMode.local2p)..autoStepDelay = Duration.zero;
      c.state.wallsLeft[0] = 1;
      c.state.wallsLeft[1] = 0;
      c.setWallMode(true);
      c.pickWall(0, 0);
      expect(c.confirmWall(), isTrue);
      expect(c.autoPlaying, isTrue);
      await untilIdle(c);
      expect(c.isOver, isTrue);
      c.dispose();
    });

    test('벽이 한 명이라도 남아 있으면 자동 이동하지 않는다', () {
      final c = QuoridorController(mode: PlayMode.local2p)..autoStepDelay = Duration.zero;
      c.state.wallsLeft[0] = 0;
      c.start();
      expect(c.autoPlaying, isFalse);
      expect(c.humanCanAct, isTrue);
      c.dispose();
    });

    test('Wi‑Fi로 하는 두 기기가 각자 자동 이동해도 판이 똑같다 (수를 주고받지 않는다)', () async {
      final a = QuoridorController(mode: PlayMode.wifi, humanSeat: 0)..autoStepDelay = Duration.zero;
      final b = QuoridorController(mode: PlayMode.wifi, humanSeat: 1)..autoStepDelay = Duration.zero;
      var sent = 0;
      a.onLocalMove = (_) => sent++;
      b.onLocalMove = (_) => sent++;
      a.state.wallsLeft.fillRange(0, 2, 0);
      b.state.wallsLeft.fillRange(0, 2, 0);
      a.start();
      b.start();
      await untilIdle(a);
      await untilIdle(b);
      expect(sent, 0); // 자동으로 간 걸음은 따로 알리지 않는다
      expect(a.isOver, isTrue);
      expect(b.isOver, isTrue);
      expect(a.state.pawn, b.state.pawn);
      expect(a.moves, b.moves);
      a.dispose();
      b.dispose();
    });

    test('CPU 대결에서도 모두 벽을 다 쓰면 CPU가 아니라 자동 이동으로 끝난다', () async {
      final c = QuoridorController(mode: PlayMode.vsCpu, players: 4, humanSeat: 0)..autoStepDelay = Duration.zero;
      c.state.wallsLeft.fillRange(0, 4, 0);
      c.start();
      expect(c.thinking, isFalse);
      await untilIdle(c);
      expect(c.isOver, isTrue);
      c.dispose();
    });

    test('벽을 쓰다가 다 떨어진 판도 끝까지 간다 (CPU끼리 벽 전쟁 뒤)', () async {
      for (final players in [2, 4]) {
        for (var seed = 0; seed < 4; seed++) {
          final c = QuoridorController(mode: PlayMode.local2p, players: players)..autoStepDelay = Duration.zero;
          final rng = Random(seed);
          // 벽을 모두 쓸 때까지: 벽이 남은 사람은 벽을 세우는 CPU 수를 고른다
          for (var i = 0; i < 200 && c.state.wallsLeft.any((w) => w > 0) && !c.isOver; i++) {
            final walls = [for (final m in c.state.allLegalMoves()) if (isWallMove(m)) m];
            final m = walls.isNotEmpty && c.state.wallsLeft[c.turn] > 0 ? walls[rng.nextInt(walls.length)] : QAi.choose(c.state, QLevel.easy, rng);
            if (isWallMove(m)) {
              c.setWallMode(true);
              c.wallOrientPick = wallOrient(m);
              c.pickWall(wallRow(m), wallCol(m));
              expect(c.confirmWall(), isTrue);
            } else {
              expect(c.tapCell(m), isTrue);
            }
            await untilIdle(c);
          }
          await untilIdle(c);
          // 벽이 모두 떨어졌거나 끝난 판이어야 한다. 자동 이동이 도중에 멈춰도 (말끼리 길을 막은 경우) 직접 둘 수 있다
          expect(c.autoPlaying, isFalse);
          if (!c.isOver) {
            expect(c.humanCanAct, isTrue, reason: '$players명 seed $seed');
          } else {
            expect(c.state.winner, isNotNull);
          }
          c.dispose();
        }
      }
    });
  });
}
