import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/goblet/core/goblet_ai.dart';
import 'package:tabgame/games/goblet/core/goblet_rules.dart';

/// 칸 번호 → "소유자 크기들" 로 판을 직접 꾸민다. 예: {0: [1, 2]} 는 칸 0에 빨강 크기1, 빨강 크기2.
GobbletBoard boardWith(Map<int, List<(int, int)>> pieces, {int turn = 1}) {
  final b = GobbletBoard();
  pieces.forEach((cell, list) {
    for (final (owner, size) in list) {
      b.owners[cell * 3 + size - 1] = owner;
    }
  });
  b.turn = turn;
  return b;
}

void main() {
  group('규칙', () {
    test('처음엔 빨강 차례, 대기 말은 팀·크기마다 2개, 합법수는 27개', () {
      final b = GobbletBoard();
      expect(b.turn, 1);
      for (final o in [1, 2]) {
        for (var s = 1; s <= 3; s++) {
          expect(b.reserve(o, s), 2);
        }
      }
      expect(b.legalMoves().length, 27); // 3크기 × 9칸
    });

    test('큰 말만 작은 말을 덮을 수 있다 (내 말, 상대 말 모두)', () {
      final b = boardWith({0: [(2, 2)], 1: [(1, 1)]}, turn: 1);
      final moves = b.legalMoves();
      // 칸 0(파랑 중간) 위에는 큰 말만
      expect(moves.contains(const GobbletMove.place(3, 0)), isTrue);
      expect(moves.contains(const GobbletMove.place(2, 0)), isFalse);
      expect(moves.contains(const GobbletMove.place(1, 0)), isFalse);
      // 칸 1(빨강 작은) 위에는 중간·큰 말
      expect(moves.contains(const GobbletMove.place(2, 1)), isTrue);
      expect(moves.contains(const GobbletMove.place(1, 1)), isFalse);
    });

    test('판 위의 말은 맨 위에 보이는 내 말만 옮길 수 있다', () {
      // 칸 0: 빨강 작은 위에 파랑 큰 말 → 빨강은 칸 0의 말을 못 옮김
      final b = boardWith({0: [(1, 1), (2, 3)], 4: [(1, 2)]}, turn: 1);
      final slides = b.legalMoves().where((m) => !m.isPlace).toList();
      expect(slides.every((m) => m.from == 4), isTrue);
      // 크기2 말은 빈 칸으로는 갈 수 있지만, 칸 0(큰 말 위)으로는 못 감
      expect(slides.any((m) => m.to == 0), isFalse);
      expect(slides.any((m) => m.to == 8), isTrue);
    });

    test('덮고 나서 apply/undo 가 정확히 되돌아간다', () {
      final b = boardWith({0: [(2, 1)]}, turn: 1);
      final before = List<int>.of(b.owners);
      const m = GobbletMove.place(2, 0);
      b.apply(m);
      expect(b.topOwner(0), 1);
      expect(b.topSize(0), 2);
      expect(b.owners[0 * 3 + 0], 2); // 아래 깔린 파랑 작은 말은 그대로
      expect(b.turn, 2);
      b.undo(m);
      expect(b.owners, before);
      expect(b.turn, 1);
    });

    test('가로·세로·대각선 3줄이면 승리, 덮인 말은 보이지 않아 줄에 안 센다', () {
      final b = boardWith({
        0: [(1, 3)], 1: [(1, 2)], 2: [(1, 1)],
      });
      expect(b.winnerAfter(1), 1);
      expect(b.lineOf(1), [0, 1, 2]);
      // 가운데 말을 파랑 큰 말이 덮으면 줄이 사라진다
      b.owners[1 * 3 + 2] = 2;
      expect(b.winnerAfter(1), 0);
    });

    test('말을 들어 올려 상대 줄이 드러나면 상대가 이긴다', () {
      // 파랑 줄 [0,1,2]. 칸 1은 빨강 큰 말이 덮고 있다. 빨강이 그 말을 옮기면 파랑이 이김.
      final b = boardWith({
        0: [(2, 2)], 1: [(2, 1), (1, 3)], 2: [(2, 2)],
      }, turn: 1);
      const m = GobbletMove.slide(1, 5, 3);
      expect(b.isLegal(m), isTrue);
      b.apply(m);
      expect(b.winnerAfter(1), 2);
    });

    test('들어 올린 말로 상대 줄을 다시 막으면 계속된다', () {
      // 같은 상황에서 빨강이 큰 말을 칸 0 위로 옮기면 (큰 말이 중간 말을 덮음) 줄이 막힌다
      final b = boardWith({
        0: [(2, 2)], 1: [(2, 1), (1, 3)], 2: [(2, 2)],
      }, turn: 1);
      b.apply(const GobbletMove.slide(1, 0, 3));
      expect(b.winnerAfter(1), 0);
    });

    test('들어 올려 내 줄도 만들고 상대 줄도 드러나면 상대가 이긴다', () {
      // 파랑 줄 [0,1,2] (칸 1의 파랑 말은 빨강 큰 말 밑에 깔려 있다).
      // 빨강이 그 큰 말을 칸 8로 옮기면 빨강 줄 [6,7,8]이 완성되지만, 동시에 파랑 줄이 드러난다.
      final b = boardWith({
        0: [(2, 1)], 1: [(2, 1), (1, 3)], 2: [(2, 1)],
        6: [(1, 2)], 7: [(1, 1)],
      }, turn: 1);
      b.apply(const GobbletMove.slide(1, 8, 3));
      expect(b.lineOf(1), [6, 7, 8]);
      expect(b.lineOf(2), [0, 1, 2]);
      expect(b.winnerAfter(1), 2);
    });
  });

  group('CPU', () {
    test('이길 수 있는 수가 있으면 (보통·어려움) 반드시 둔다', () {
      final b = boardWith({
        0: [(1, 3)], 1: [(1, 2)], 5: [(2, 2)], 8: [(2, 1)],
      }, turn: 1);
      for (final level in [CpuLevel.normal, CpuLevel.hard]) {
        for (var seed = 0; seed < 10; seed++) {
          final m = GobbletAi.choose(b, level, Random(seed));
          final c = b.copy()..apply(m);
          expect(c.winnerAfter(1), 1, reason: '$level $m');
        }
      }
    });

    test('상대가 이기는 걸 막을 수 있으면 (보통·어려움) 막는다', () {
      // 파랑이 [0,1] 에 줄을 만들었고 칸 2가 비어 있다. 빨강은 2번을 막아야 한다.
      final b = boardWith({
        0: [(2, 3)], 1: [(2, 3)], 4: [(1, 1)], 8: [(1, 1)],
      }, turn: 1);
      for (final level in [CpuLevel.normal, CpuLevel.hard]) {
        for (var seed = 0; seed < 10; seed++) {
          final m = GobbletAi.choose(b, level, Random(seed));
          final c = b.copy()..apply(m);
          // 막은 뒤 파랑이 곧바로 이길 수 있는 수가 남아 있으면 안 된다
          final canLose = c.legalMoves().any((mv) {
            final d = c.copy()..apply(mv);
            return d.winnerAfter(2) == 2;
          });
          expect(canLose, isFalse, reason: '$level $m');
        }
      }
    });

    test('CPU끼리 여러 판 두어도 끝까지 문제없이 진행된다', () {
      final rng = Random(3);
      for (var g = 0; g < 12; g++) {
        final b = GobbletBoard();
        var steps = 0;
        var winner = 0;
        while (steps < 80) {
          final level = b.turn == 1 ? CpuLevel.hard : CpuLevel.normal;
          final m = GobbletAi.choose(b, level, rng);
          expect(b.isLegal(m), isTrue);
          final mover = b.turn;
          b.apply(m);
          winner = b.winnerAfter(mover);
          if (winner != 0) break;
          steps++;
        }
        expect(steps < 80 || winner != 0, isTrue);
      }
    });

    test('어려움 CPU는 무작위 상대에게 지지 않는다 (먼저/나중 모두)', () {
      final rng = Random(21);
      final sw = Stopwatch()..start();
      var cpuWins = 0, cpuLosses = 0, undecided = 0;
      for (var g = 0; g < 20; g++) {
        final cpu = g.isEven ? 1 : 2;
        final b = GobbletBoard();
        var winner = 0;
        for (var steps = 0; steps < 60 && winner == 0; steps++) {
          final mover = b.turn;
          final GobbletMove m;
          if (mover == cpu) {
            m = GobbletAi.choose(b, CpuLevel.hard, rng);
          } else {
            final all = b.legalMoves();
            m = all[rng.nextInt(all.length)];
          }
          b.apply(m);
          winner = b.winnerAfter(mover);
        }
        if (winner == cpu) {
          cpuWins++;
        } else if (winner == 0) {
          undecided++;
        } else {
          cpuLosses++;
        }
      }
      // ignore: avoid_print
      print('어려움 CPU vs 무작위: 승 $cpuWins / 패 $cpuLosses / 미결 $undecided '
          '(${sw.elapsedMilliseconds}ms)');
      expect(cpuLosses, 0);
      expect(cpuWins, greaterThanOrEqualTo(17));
    });
  });
}
