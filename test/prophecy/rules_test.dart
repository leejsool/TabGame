import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/prophecy/core/prophecy_ai.dart';
import 'package:tabgame/games/prophecy/core/prophecy_rules.dart';

/// 책의 그림(4행 × 5열): 0 = 먼저 쓰는 쪽(분홍), 1 = 나중에 쓰는 쪽. X = -1.
ProphState bookBoard() {
  const x = kCross;
  final cells = [
    5, 4, 2, 3, x, //
    2, 5, 4, 1, 3,
    3, x, x, 4, 2,
    4, 2, 3, 5, 1,
  ];
  // 4는 모두 분홍(먼저 쓴 쪽), 나머지는 청록: 점수가 12 : 19가 된다
  final owners = [for (final v in cells) v == x ? 1 : (v == 4 || v == 2 || v == 1 ? 0 : 1)];
  return ProphState.fromCells(4, 5, cells, owners);
}

void main() {
  group('규칙', () {
    test('숫자는 1부터 가장 긴 줄의 칸 수까지, X는 언제나', () {
      final s = ProphState(4, 6);
      expect(s.maxNumber, 6);
      expect(s.canPlay(0, 6), isTrue);
      expect(s.canPlay(0, 7), isFalse);
      expect(s.canPlay(0, 0), isFalse);
      expect(s.canPlay(0, kCross), isTrue);
      expect(ProphState(8, 5).maxNumber, 8);
    });

    test('같은 행이나 열에는 같은 숫자를 두 번 쓸 수 없다 (X는 몇 번이든)', () {
      final s = ProphState(4, 5);
      s.play(0, 4); // 0행 0열에 4
      expect(s.canPlay(1, 4), isFalse); // 같은 행
      expect(s.canPlay(5, 4), isFalse); // 같은 열
      expect(s.canPlay(6, 4), isTrue); // 다른 행·열
      expect(s.legalNumbers(1), isNot(contains(4)));
      s.play(1, kCross);
      s.play(2, kCross);
      expect(s.cells[1], kCross);
      expect(s.cells[2], kCross);
    });

    test('차례는 번갈아 가고, 쓴 사람이 기록된다', () {
      final s = ProphState(4, 4);
      expect(s.turn, 0);
      s.play(0, 1);
      expect(s.turn, 1);
      s.play(1, kCross);
      expect(s.owners[0], 0);
      expect(s.owners[1], 1);
      expect(s.turn, 0);
      expect(s.turns, 2);
    });

    test('어떤 숫자도 쓸 수 없는 칸은 저절로 X가 되고, 차례로 세지 않는다', () {
      // 4×4: 같은 행과 열에 1·2·3·4를 모두 써서 한 칸을 막는다.
      final s = ProphState(4, 4);
      // 칸 (0,0)을 막으려면 0행과 0열에 1~4가 있어야 한다: 0행에 1,2 (열 1,2) / 0열에 3,4 (행 1,2)
      s.play(1, 1); // (0,1)=1
      s.play(2, 2); // (0,2)=2
      s.play(4, 3); // (1,0)=3
      expect(s.cells[0], kBlank);
      final turnsBefore = s.turns;
      final crossed = s.play(8, 4); // (2,0)=4 → (0,0)은 1,2,3,4가 모두 막힘
      expect(crossed, [0]);
      expect(s.cells[0], kCross);
      expect(s.owners[0], kNoOwner);
      expect(s.turns, turnsBefore + 1); // 저절로 생긴 X는 차례로 안 센다
      expect(s.turn, (turnsBefore + 1) % 2);
    });

    test('판이 가득 차면 끝난다', () {
      final s = ProphState(4, 4);
      playRandomly(s, Random(3));
      expect(s.isOver, isTrue);
      expect(s.blanks, 0);
      expect(s.cells.every((c) => c != kBlank), isTrue);
    });
  });

  group('세기와 점수', () {
    test('책의 그림: 행·열 숫자 개수와 점수', () {
      final s = bookBoard();
      expect([for (var r = 0; r < 4; r++) s.rowCount(r)], [4, 5, 3, 5]);
      expect([for (var c = 0; c < 5; c++) s.colCount(c)], [4, 3, 3, 4, 3]);
      final hits = s.hits();
      // 행으로 맞은 것: 4(1행) 5(2행) 3(3행) 5(4행)
      expect([for (final h in hits) if (h.byRow) h.number], [4, 5, 3, 5]);
      // 열로 맞은 것: 3(5열, 2행) 4(4열, 3행) 4(1열, 4행) 3(3열, 4행)
      expect([for (final h in hits) if (h.byCol) h.number]..sort(), [3, 3, 4, 4]);
      expect(s.scores(), [12, 19]);
      expect(s.winner, 1);
      final parts = s.scoreParts();
      expect(parts.rowPts[0] + parts.colPts[0], 12);
      expect(parts.rowPts[1] + parts.colPts[1], 19);
    });

    test('한 숫자가 행과 열에서 모두 맞으면 두 번 득점한다', () {
      // 4×4, 0행: [2, 1, X, X]는 숫자 2개, 0열: [2, X, 1, 3]은 숫자 3개 → (0,0)의 2는 행에서만
      // 0행 [3,1,2,X]: 숫자 3개 / 0열 [3,2,1,X]: 숫자 3개 → (0,0)의 3은 행과 열 모두 → 6점
      const x = kCross;
      final cells = [
        3, 1, 2, x, //
        2, x, x, x,
        1, x, x, x,
        x, x, x, x,
      ];
      final s = ProphState.fromCells(4, 4, cells, [for (final v in cells) v == x ? 1 : 0]);
      final h = s.hits().firstWhere((h) => h.cell == 0);
      expect(h.byRow, isTrue);
      expect(h.byCol, isTrue);
      expect(h.points, 6);
    });

    test('아무도 맞히지 못한 줄은 점수가 없다', () {
      const x = kCross;
      final cells = [
        1, 2, x, x, //
        x, x, x, x,
        x, x, x, x,
        x, x, x, x,
      ];
      final s = ProphState.fromCells(4, 4, cells, [for (final v in cells) v == x ? 1 : 0]);
      // 0행은 숫자 2개 → 2(0행 1열)가 맞음. 1은 틀림. 열은 모두 숫자 1개 이하 → 1(0열)은 열에서 맞음
      expect(s.scores(), [2 + 1, 0]);
    });

    test('수 목록으로 다시 만들면 같은 판이 된다', () {
      final rng = Random(5);
      final s = ProphState(5, 6);
      final moves = <int>[];
      while (!s.isOver) {
        final ms = s.legalMoves();
        final m = ms[rng.nextInt(ms.length)];
        moves.add(m);
        s.play(moveCell(m), moveValue(m));
      }
      final t = ProphState.fromMoves(5, 6, moves);
      expect(t.cells, s.cells);
      expect(t.owners, s.owners);
      expect(t.scores(), s.scores());
    });

    test('무작위로 여러 판 두어도 규칙이 지켜진다: 같은 줄에 같은 숫자 없음, 점수는 줄 길이 이하', () {
      for (final (rows, cols) in const [(4, 4), (4, 7), (8, 8), (6, 5)]) {
        for (var seed = 0; seed < 25; seed++) {
          final s = ProphState(rows, cols);
          playRandomly(s, Random(seed));
          for (var r = 0; r < rows; r++) {
            final nums = [for (var c = 0; c < cols; c++) if (s.cells[r * cols + c] > 0) s.cells[r * cols + c]];
            expect(nums.toSet().length, nums.length, reason: '$rows×$cols seed=$seed 행$r');
          }
          for (var c = 0; c < cols; c++) {
            final nums = [for (var r = 0; r < rows; r++) if (s.cells[r * cols + c] > 0) s.cells[r * cols + c]];
            expect(nums.toSet().length, nums.length, reason: '$rows×$cols seed=$seed 열$c');
          }
          final sc = s.scores();
          expect(sc[0] + sc[1], lessThanOrEqualTo(2 * (rows * cols) * 8));
        }
      }
    });
  });

  group('CPU', () {
    test('모든 난이도가 항상 규칙에 맞는 수를 둔다', () {
      final rng = Random(2);
      for (final level in ProphLevel.values) {
        final s = ProphState(5, 5);
        while (!s.isOver) {
          final m = ProphAi.choose(s, level, rng);
          expect(s.canPlay(moveCell(m), moveValue(m)), isTrue, reason: '${level.label} ${s.turns}수');
          s.play(moveCell(m), moveValue(m));
        }
      }
    });

    test('어려움 CPU는 무작위로 두는 상대보다 대체로 점수가 높다 (먼저/나중)', () {
      final rng = Random(4);
      var wins = 0, losses = 0, diff = 0;
      const games = 16;
      for (var g = 0; g < games; g++) {
        final cpuSide = g.isEven ? 0 : 1;
        final s = ProphState(5, 5);
        while (!s.isOver) {
          if (s.turn == cpuSide) {
            final m = ProphAi.choose(s, ProphLevel.hard, rng);
            s.play(moveCell(m), moveValue(m));
          } else {
            final ms = s.legalMoves();
            final m = ms[rng.nextInt(ms.length)];
            s.play(moveCell(m), moveValue(m));
          }
        }
        final sc = s.scores();
        diff += sc[cpuSide] - sc[1 - cpuSide];
        if (s.winner == cpuSide) wins++;
        if (s.winner == 1 - cpuSide) losses++;
      }
      // ignore: avoid_print
      print('어려움 vs 무작위(5×5): 승 $wins / 패 $losses / 평균 점수차 ${(diff / games).toStringAsFixed(1)}');
      expect(wins, greaterThan(losses));
      expect(diff, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)), tags: 'slow');
  });
}
