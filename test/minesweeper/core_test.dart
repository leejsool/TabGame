import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/minesweeper/core/mines_rules.dart';
import 'package:tabgame/games/minesweeper/core/mines_solver.dart';

MinesBoard custom(int rows, int cols, List<int> mines) {
  final b = MinesBoard(rows, cols, mines.length)..setMines(mines);
  return b;
}

void main() {
  group('판 만들기', () {
    test('난이도별 크기와 지뢰 수', () {
      expect((MinesLevel.beginner.rows, MinesLevel.beginner.cols, MinesLevel.beginner.mines), (9, 9, 10));
      expect((MinesLevel.intermediate.rows, MinesLevel.intermediate.cols, MinesLevel.intermediate.mines), (16, 16, 40));
      expect((MinesLevel.expert.rows, MinesLevel.expert.cols, MinesLevel.expert.mines), (16, 30, 99));
    });

    test('첫 칸과 그 이웃에는 지뢰가 없고, 지뢰 수는 정확하다', () {
      final rng = Random(1);
      for (final level in MinesLevel.values) {
        for (var t = 0; t < 30; t++) {
          final b = MinesBoard.forLevel(level);
          final first = rng.nextInt(b.size);
          b.placeMines(first, rng);
          expect(b.mine.where((m) => m).length, level.mines);
          expect(b.mine[first], isFalse);
          for (final n in b.neighbors(first)) {
            expect(b.mine[n], isFalse, reason: '${level.label} first=$first');
          }
        }
      }
    });

    test('주변 숫자가 정확하다', () {
      final b = custom(3, 3, [0, 2]);
      expect(b.adj[1], 2);
      expect(b.adj[4], 2);
      expect(b.adj[3], 1);
      expect(b.adj[8], 0);
    });

    test('모서리/가장자리 이웃 수', () {
      final b = MinesBoard(5, 7, 0);
      expect(b.neighbors(0).length, 3);
      expect(b.neighbors(3).length, 5);
      expect(b.neighbors(b.index(2, 3)).length, 8);
    });
  });

  group('열기', () {
    test('0인 칸을 열면 주변이 연쇄로 열리고, 거리 순서로 알려준다', () {
      // 5x5, 오른쪽 아래 구석에만 지뢰
      final b = custom(5, 5, [24]);
      final opened = b.reveal(0);
      expect(opened.first, (0, 0));
      expect(b.revealedCount, 24); // 지뢰 칸만 빼고 모두
      expect(b.isWon, isTrue);
      // 거리는 늘어나는 순서
      for (var i = 1; i < opened.length; i++) {
        expect(opened[i].$2, greaterThanOrEqualTo(opened[i - 1].$2));
      }
    });

    test('숫자 칸은 그 칸만 열린다', () {
      final b = custom(3, 3, [4]);
      final opened = b.reveal(0);
      expect(opened.length, 1);
      expect(b.revealedCount, 1);
    });

    test('지뢰를 밟으면 터진다', () {
      final b = custom(3, 3, [4]);
      b.reveal(4);
      expect(b.isLost, isTrue);
      expect(b.explodedCell, 4);
      expect(b.isWon, isFalse);
    });

    test('깃발이 꽂힌 칸은 열리지 않고, 연쇄로도 열리지 않는다', () {
      final b = custom(1, 5, [4]);
      b.toggleFlag(2);
      expect(b.reveal(2), isEmpty);
      b.reveal(0); // 0 0 0.. 연쇄: 깃발 칸에서 멈춘다
      expect(b.marks[2], CellMark.flagged);
      expect(b.marks[1], CellMark.revealed);
      expect(b.marks[3], CellMark.hidden);
    });

    test('물음표는 지뢰 수에 안 들어가고, 열 수 있고, 연쇄로도 열린다', () {
      final b = custom(1, 5, [4]);
      expect(b.toggleQuestion(2), isTrue);
      expect(b.marks[2], CellMark.question);
      expect(b.minesLeft, 1);
      b.reveal(0); // 연쇄가 물음표 칸도 연다
      expect(b.marks[2], CellMark.revealed);
      expect(b.marks[3], CellMark.revealed);
      expect(b.toggleQuestion(2), isFalse); // 열린 칸에는 못 단다
    });

    test('깃발 ↔ 물음표 바꾸기와 떼기', () {
      final b = custom(3, 3, [0, 1]);
      b.toggleFlag(0);
      expect(b.flagCount, 1);
      b.toggleQuestion(0); // 깃발이 물음표로
      expect(b.marks[0], CellMark.question);
      expect(b.flagCount, 0);
      b.toggleFlag(0); // 물음표가 깃발로
      expect(b.marks[0], CellMark.flagged);
      expect(b.flagCount, 1);
      b.toggleFlag(0);
      expect(b.marks[0], CellMark.hidden);
      b.toggleQuestion(0);
      b.toggleQuestion(0);
      expect(b.marks[0], CellMark.hidden);
    });

    test('코드: 물음표 칸도 한꺼번에 열린다', () {
      final b = custom(1, 3, [0]);
      b.reveal(1); // 숫자 1
      b.toggleFlag(0);
      b.toggleQuestion(2);
      expect(b.chord(1).map((e) => e.$1), [2]);
      expect(b.marks[2], CellMark.revealed);
    });

    test('깃발 토글과 남은 지뢰 수', () {
      final b = custom(3, 3, [0, 1]);
      expect(b.minesLeft, 2);
      b.toggleFlag(0);
      expect(b.minesLeft, 1);
      b.toggleFlag(0);
      expect(b.minesLeft, 2);
      b.reveal(8);
      expect(b.toggleFlag(8), isFalse); // 열린 칸에는 못 꽂는다
    });
  });

  group('한꺼번에 열기(코드)', () {
    test('깃발 수가 숫자와 같으면 나머지 칸이 열린다', () {
      // 위 줄에 지뢰 하나, 가운데 숫자 칸을 열어 둔 상태
      final b = custom(3, 3, [0]);
      b.reveal(4); // 숫자 1
      expect(b.chord(4), isEmpty); // 깃발이 아직 없다
      b.toggleFlag(0);
      final opened = b.chord(4);
      expect(opened, isNotEmpty);
      expect(b.isWon, isTrue);
    });

    test('깃발을 잘못 꽂고 코드하면 지뢰를 밟는다', () {
      final b = custom(3, 3, [0]);
      b.reveal(4);
      b.toggleFlag(1); // 틀린 깃발
      b.chord(4);
      expect(b.isLost, isTrue);
      expect(b.explodedCell, 0);
    });

    test('깃발 수가 숫자와 다르면 아무 일도 없다', () {
      final b = custom(3, 3, [0, 2]);
      b.reveal(4); // 숫자 2
      b.toggleFlag(0);
      expect(b.chord(4), isEmpty);
    });
  });

  group('승리/복사', () {
    test('지뢰가 아닌 칸을 모두 열면 이긴다. 이기면 남은 지뢰에 깃발을 모두 꽂는다', () {
      final b = custom(2, 2, [3]);
      b.reveal(0);
      b.reveal(1);
      expect(b.isWon, isFalse);
      b.reveal(2);
      expect(b.isWon, isTrue);
      b.flagAllMines();
      expect(b.marks[3], CellMark.flagged);
      expect(b.minesLeft, 0);
    });

    test('copy는 독립적이다', () {
      final b = custom(3, 3, [4]);
      final c = b.copy();
      b.reveal(0);
      expect(c.revealedCount, 0);
      expect(c.mine[4], isTrue);
    });
  });

  group('힌트', () {
    test('숫자 하나로 확정되는 지뢰', () {
      // 1 x
      final b = custom(1, 3, [2]);
      b.reveal(0); // 0칸? adj=0 → 연쇄로 1도 열림 (1칸 옆이 지뢰)
      expect(b.marks[1], CellMark.revealed);
      final h = MinesSolver.findHint(b)!;
      expect(h.kind, HintKind.mine);
      expect(h.targets, [2]);
      expect(h.reasons, [1]);
    });

    test('깃발로 숫자가 채워졌으면 나머지는 안전', () {
      final b = custom(3, 3, [0]);
      b.reveal(4);
      b.toggleFlag(0);
      final h = MinesSolver.findHint(b)!;
      expect(h.kind, HintKind.safe);
      expect(h.targets.contains(0), isFalse);
      expect(h.targets.toSet(), {1, 2, 3, 5, 6, 7, 8});
    });

    test('두 숫자를 비교하는 규칙 (1-2 패턴)', () {
      // 열린 줄 아래에서  1 2 ... 형태를 만든다.
      //  숫자:   [1][2]    ← 위 줄
      //  위 칸의 후보: 아래 줄
      // 지뢰는 아래 줄 3칸 중 2번째와 3번째
      final b = MinesBoard(2, 3, 2)..setMines([4, 5]);
      b.marks[0] = CellMark.revealed; // adj=1 (이웃 4)
      b.marks[1] = CellMark.revealed; // adj=2 (이웃 4,5)
      b.marks[2] = CellMark.revealed; // adj=2 (이웃 4,5)
      b.revealedCount = 3;
      // 0번: 후보 {3,4}  need 1 (adj=1: 이웃 3,4,1 → 4가 지뢰... adj 계산 확인)
      expect(b.adj[0], 1);
      final h = MinesSolver.findHint(b);
      expect(h, isNotNull);
      // 힌트가 알려주는 칸은 실제 정답과 일치해야 한다
      for (final t in h!.targets) {
        expect(b.mine[t], h.kind == HintKind.mine, reason: '$t');
      }
    });

    test('힌트를 따라가면 틀린 안내가 한 번도 나오지 않는다 (무작위 판 많이)', () {
      final rng = Random(11);
      var solvedSome = 0;
      for (var game = 0; game < 120; game++) {
        final level = MinesLevel.values[game % 3];
        final b = MinesBoard.forLevel(level);
        final first = rng.nextInt(b.size);
        b.placeMines(first, rng);
        b.reveal(first);
        for (var step = 0; step < 2000 && !b.isWon && !b.isLost; step++) {
          final h = MinesSolver.findHint(b);
          if (h == null) break;
          for (final t in h.targets) {
            expect(b.mine[t], h.kind == HintKind.mine, reason: 'game $game step $step target $t');
          }
          if (h.kind == HintKind.safe) {
            for (final t in h.targets) {
              b.reveal(t);
            }
          } else {
            for (final t in h.targets) {
              if (b.marks[t] == CellMark.hidden) b.toggleFlag(t);
            }
          }
        }
        expect(b.isLost, isFalse, reason: 'game $game');
        if (b.isWon) solvedSome++;
      }
      expect(solvedSome, greaterThan(20)); // 초급 판은 힌트만으로도 자주 끝까지 풀린다
    });
  });
}
