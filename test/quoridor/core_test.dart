import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/quoridor/core/quoridor_ai.dart';
import 'package:tabgame/games/quoridor/core/quoridor_rules.dart';

int cell(int r, int c) => r * kBoard + c;

void main() {
  group('처음 모습', () {
    test('2명: 아래·위 가운데, 벽 10개씩', () {
      final s = QState.start(2);
      expect(s.pawn, [cell(8, 4), cell(0, 4)]);
      expect(s.wallsLeft, [10, 10]);
      expect(s.distance(0), 8);
      expect(s.distance(1), 8);
    });

    test('4명: 아래·왼쪽·위·오른쪽, 벽 5개씩, 모두 8걸음', () {
      final s = QState.start(4);
      expect(s.pawn, [cell(8, 4), cell(4, 0), cell(0, 4), cell(4, 8)]);
      expect(s.wallsLeft, [5, 5, 5, 5]);
      for (var p = 0; p < 4; p++) {
        expect(s.distance(p), 8, reason: '$p');
      }
      expect(reachedGoal(4, 0, cell(0, 0)), isTrue);
      expect(reachedGoal(4, 1, cell(0, 8)), isTrue);
      expect(reachedGoal(4, 2, cell(8, 3)), isTrue);
      expect(reachedGoal(4, 3, cell(2, 0)), isTrue);
      expect(reachedGoal(4, 3, cell(2, 8)), isFalse);
    });
  });

  group('말 움직이기', () {
    test('한 칸씩, 벽에 막히면 못 간다', () {
      final s = QState.start(2);
      expect(s.legalPawnMoves()..sort(), [cell(7, 4), cell(8, 3), cell(8, 5)]);
      s.apply(wallMove(0, 7, 4)); // 7행과 8행 사이, 4~5열
      expect(s.hWallAt(7, 4), isTrue);
      expect(s.blockedBetween(cell(8, 4), cell(7, 4)), isTrue);
      expect(s.blockedBetween(cell(8, 5), cell(7, 5)), isTrue);
      expect(s.blockedBetween(cell(8, 3), cell(7, 3)), isFalse);
      expect(s.legalPawnMoves(0)..sort(), [cell(8, 3), cell(8, 5)]);
    });

    test('마주 선 말은 뛰어넘고, 뒤가 막히면 옆으로 비껴 간다', () {
      final s = QState.start(2);
      s.pawn[0] = cell(4, 4);
      s.pawn[1] = cell(3, 4);
      expect(s.legalPawnMoves(0)..sort(), [cell(2, 4), cell(4, 3), cell(4, 5), cell(5, 4)]);
      s.h[2 * kAnchors + 4] = true; // 2행과 3행 사이, 4~5열: 말 뒤를 막는다
      expect(s.legalPawnMoves(0)..sort(), [cell(3, 3), cell(3, 5), cell(4, 3), cell(4, 5), cell(5, 4)]);
      s.v[3 * kAnchors + 4] = true; // 4열과 5열 사이, 3~4행: 오른쪽 옆을 막는다
      expect(s.legalPawnMoves(0).contains(cell(3, 5)), isFalse);
      expect(s.legalPawnMoves(0).contains(cell(3, 3)), isTrue);
    });

    test('판 끝에서는 말 뒤가 없으니 옆으로 비껴 간다', () {
      final s = QState.start(2);
      s.pawn[0] = cell(1, 4);
      s.pawn[1] = cell(0, 4);
      expect(s.legalPawnMoves(0)..sort(), [cell(0, 3), cell(0, 5), cell(1, 3), cell(1, 5), cell(2, 4)]);
    });

    test('4명: 뒤에 또 말이 있으면 옆으로 비껴 간다', () {
      final s = QState.start(4);
      s.pawn[0] = cell(4, 4);
      s.pawn[1] = cell(3, 4);
      s.pawn[2] = cell(2, 4);
      expect(s.legalPawnMoves(0)..sort(), [cell(3, 3), cell(3, 5), cell(4, 3), cell(4, 5), cell(5, 4)]);
    });

    test('도착 줄에 닿으면 끝나고, 차례는 한 바퀴 돈다', () {
      final s = QState.start(4);
      expect(s.turn, 0);
      s.apply(cell(7, 4));
      expect(s.turn, 1);
      s.apply(cell(4, 1));
      s.apply(cell(1, 4));
      s.apply(cell(4, 7));
      expect(s.turn, 0);
      s.pawn[0] = cell(1, 2);
      s.apply(cell(0, 2));
      expect(s.winner, 0);
      expect(s.isOver, isTrue);
      expect(s.isLegal(cell(1, 2)), isFalse); // 끝난 판
    });
  });

  group('벽 세우기', () {
    test('겹치거나 십자로 엇갈리면 안 된다', () {
      final s = QState.start(2);
      s.apply(wallMove(0, 3, 3));
      expect(s.canPlaceWall(0, 3, 3), isFalse); // 같은 자리
      expect(s.canPlaceWall(1, 3, 3), isFalse); // 십자
      expect(s.canPlaceWall(0, 3, 4), isFalse); // 가로로 겹침
      expect(s.canPlaceWall(0, 3, 2), isFalse);
      expect(s.canPlaceWall(0, 3, 5), isTrue); // 이어 붙이기는 된다
      expect(s.canPlaceWall(1, 2, 3), isTrue);
      expect(s.canPlaceWall(1, 3, 4), isTrue);
      s.apply(wallMove(1, 0, 0));
      expect(s.canPlaceWall(1, 1, 0), isFalse); // 세로로 겹침
      expect(s.canPlaceWall(1, 0, 0), isFalse);
      expect(s.canPlaceWall(0, 0, 0), isFalse);
      expect(s.canPlaceWall(0, 8, 0), isFalse); // 판 밖
      expect(s.canPlaceWall(1, 0, 8), isFalse);
    });

    test('모든 길을 막는 벽은 안 된다', () {
      final s = QState.start(2);
      s.pawn[1] = cell(0, 0);
      s.h[0] = true; // 0행 아래 (0~1열)
      expect(s.distance(1), greaterThan(0));
      expect(s.canPlaceWall(1, 0, 0), isFalse); // 오른쪽까지 막으면 갇힌다
      expect(s.canPlaceWall(1, 1, 0), isTrue);
    });

    test('벽이 떨어지면 못 세운다', () {
      final s = QState.start(4);
      s.wallsLeft[0] = 0;
      expect(s.canPlaceWall(0, 0, 0), isFalse);
      expect(s.isLegal(wallMove(0, 0, 0)), isFalse);
      s.wallsLeft[0] = 1;
      expect(s.isLegal(wallMove(0, 0, 0)), isTrue);
      s.apply(wallMove(0, 0, 0));
      expect(s.wallsLeft[0], 0);
    });

    test('수를 처음부터 다시 두면 같은 상태가 된다', () {
      final s = QState.start(4);
      final rng = Random(4);
      final moves = <int>[];
      for (var i = 0; i < 30 && !s.isOver; i++) {
        final ms = s.allLegalMoves();
        final m = ms[rng.nextInt(ms.length)];
        moves.add(m);
        s.apply(m);
      }
      final t = QState.fromMoves(4, moves);
      expect(t.pawn, s.pawn);
      expect(t.wallsLeft, s.wallsLeft);
      expect(t.h, s.h);
      expect(t.v, s.v);
      expect(t.turn, s.turn);
    });
  });

  group('CPU', () {
    test('모든 난이도가 둘 수 있는 수를 고른다 (2명·4명)', () {
      for (final players in [2, 4]) {
        for (final level in QLevel.values) {
          final s = QState.start(players);
          final rng = Random(players * 7 + level.index);
          for (var i = 0; i < 40 && !s.isOver; i++) {
            final m = QAi.choose(s, level, rng);
            expect(s.isLegal(m), isTrue, reason: '$players $level $i');
            s.apply(m);
          }
        }
      }
    });

    test('CPU끼리 끝까지 두면 이기는 사람이 나온다 (모든 길이 항상 열려 있다)', () {
      for (final (players, level) in [(2, QLevel.easy), (2, QLevel.normal), (2, QLevel.hard), (4, QLevel.easy), (4, QLevel.normal), (4, QLevel.hard)]) {
        for (var seed = 0; seed < 3; seed++) {
          final s = QState.start(players);
          final rng = Random(seed);
          var turns = 0;
          while (!s.isOver && turns < 600) {
            turns++;
            s.apply(QAi.choose(s, level, rng));
            for (var p = 0; p < players; p++) {
              expect(s.distance(p), greaterThanOrEqualTo(0), reason: '$players $level seed $seed turn $turns');
            }
          }
          expect(s.isOver, isTrue, reason: '$players명 $level seed $seed 끝나지 않았어요');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('보통은 쉬움보다 잘 둔다 (2명, 여러 판)', () {
      var normalWins = 0;
      const games = 12;
      for (var g = 0; g < games; g++) {
        final s = QState.start(2);
        final rng = Random(g);
        final normalSeat = g % 2;
        var turns = 0;
        while (!s.isOver && turns < 400) {
          turns++;
          s.apply(QAi.choose(s, s.turn == normalSeat ? QLevel.normal : QLevel.easy, rng));
        }
        if (s.winner == normalSeat) normalWins++;
      }
      expect(normalWins, greaterThanOrEqualTo(games * 2 ~/ 3));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
