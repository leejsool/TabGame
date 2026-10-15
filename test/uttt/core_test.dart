import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/uttt/core/uttt_ai.dart';
import 'package:tabgame/games/uttt/core/uttt_rules.dart';

int mv(int board, int cell) => board * 9 + cell;

/// 합법인 수만 순서대로 둔다 (잘못된 수가 있으면 테스트가 실패하게).
UttState play(List<int> moves) {
  final s = UttState();
  for (final m in moves) {
    expect(s.isLegal(m), isTrue, reason: '불법 수 ${m ~/ 9}판 ${m % 9}칸');
    s.apply(m);
  }
  return s;
}

void main() {
  group('규칙', () {
    test('처음엔 81칸 모두 둘 수 있고, X가 먼저다', () {
      final s = UttState();
      expect(s.legalMoves().length, 81);
      expect(s.turn, kX);
      expect(s.next, -1);
    });

    test('내가 둔 칸의 위치가 상대가 둘 작은 판이 된다', () {
      final s = play([mv(4, 2)]); // X: 가운데 판의 오른쪽 위 칸
      expect(s.next, 2);
      expect(s.turn, kO);
      final moves = s.legalMoves();
      expect(moves.length, 9);
      expect(moves.every((m) => m ~/ 9 == 2), isTrue);
      // 다른 판은 둘 수 없다
      expect(s.isLegal(mv(0, 0)), isFalse);
      expect(s.isLegal(mv(2, 0)), isTrue);
    });

    test('이미 찬 칸에는 못 둔다', () {
      final s = play([mv(4, 2), mv(2, 4)]);
      expect(s.isLegal(mv(4, 2)), isFalse);
      expect(s.next, 4);
      expect(s.isLegal(mv(4, 2)), isFalse); // 4판의 2칸은 이미 X
      expect(s.isLegal(mv(4, 3)), isTrue);
    });

    test('작은 판에서 한 줄을 만들면 그 판을 차지한다', () {
      // X가 0판의 0,1,2 칸을 차지하도록 (상대는 다른 판에 두게 유도)
      final s = play([
        mv(0, 0), // X → 상대는 0판
        mv(0, 3), // O → X는 3판
        mv(3, 0), // X → O는 0판
        mv(0, 4), // O → X는 4판
        mv(4, 1), // X → O는 1판
        mv(1, 0), // O → X는 0판
        mv(0, 1), // X → 0판에 0,1 (O는 1판)
        mv(1, 1), // O → X는 1판
        mv(1, 2), // X → O는 2판
        mv(2, 0), // O → X는 0판
        mv(0, 2), // X → 0,1,2 한 줄!
      ]);
      expect(s.boardOwner(0), 1);
      expect(s.bigX & 1, 1);
      // X가 둔 칸은 2 → 다음 판 2
      expect(s.next, 2);
      expect(s.turn, kO);
    });

    test('보내진 판이 이미 끝났으면 아무 판에나 둘 수 있다', () {
      final s = UttState();
      // 0판을 X가 차지한 상태를 직접 만든다: X가 0,1,2 칸 (O는 다른 곳)
      s.cellsX[0] = 0x7;
      s.bigX = 1;
      s.next = -1;
      s.turn = kO;
      // O가 0번 칸(→ 0판으로 보냄)에 둔다: 다른 판의 0칸
      s.apply(mv(5, 0));
      expect(s.boardOpen(0), isFalse);
      expect(s.next, -1); // 0판이 끝났으니 자유
      final moves = s.legalMoves();
      expect(moves.every((m) => m ~/ 9 != 0), isTrue); // 끝난 판에는 둘 수 없다
      expect(moves.map((m) => m ~/ 9).toSet().length, 8); // 나머지 8판 모두 가능
    });

    test('작은 판이 가득 차면 무승부 판으로 닫힌다', () {
      final s = UttState();
      // 0판을 줄 없이 가득 채운다: X 0,1,5,6,7 / O 2,3,4,8
      s.cellsX[0] = (1 << 0) | (1 << 1) | (1 << 5) | (1 << 6) | (1 << 7);
      s.cellsO[0] = (1 << 2) | (1 << 3) | (1 << 8);
      expect(hasLine(s.cellsX[0]), isFalse);
      s.turn = kO;
      s.apply(mv(0, 4)); // 마지막 빈 칸 (4)
      expect(s.bigDraw & 1, 1);
      expect(s.boardOwner(0), 3);
      expect(s.boardOpen(0), isFalse);
    });

    test('큰 판에서 차지한 판 세 개가 한 줄이면 이긴다', () {
      final s = UttState();
      s.bigX = 0x3; // 0, 1판 차지
      s.cellsX[2] = 0x3; // 2판에 X가 0,1 → 2칸에 두면 이 판도 차지
      s.turn = kX;
      s.next = 2;
      s.apply(mv(2, 2));
      expect(s.outcome, Outcome.xWins);
      expect(s.isOver, isTrue);
      expect(s.winningLine, [0, 1, 2]);
      expect(s.legalMoves(), isEmpty);
      expect(s.isLegal(mv(3, 0)), isFalse);
    });

    test('모든 작은 판이 끝났는데 큰 줄이 없으면 무승부', () {
      final s = UttState();
      // X: 0,2,3,7 O: 1,5,6,8 (큰 줄 없음), 4판만 남김
      s.bigX = (1 << 0) | (1 << 2) | (1 << 3) | (1 << 7);
      s.bigO = (1 << 1) | (1 << 5) | (1 << 6) | (1 << 8);
      s.cellsX[4] = 0x3; // 4판에서 X가 0,1
      s.turn = kX;
      s.next = 4;
      // 4판을 무승부로 닫는다: 남은 칸을 줄 없이 채워 보자
      s.cellsX[4] = (1 << 0) | (1 << 1) | (1 << 5) | (1 << 6) | (1 << 7);
      s.cellsO[4] = (1 << 2) | (1 << 3) | (1 << 8);
      s.turn = kO;
      s.apply(mv(4, 4));
      expect(s.outcome, Outcome.draw);
    });

    test('apply / undo 가 정확히 서로 되돌린다 (무작위 대국 반복)', () {
      final rng = Random(7);
      for (var game = 0; game < 200; game++) {
        final s = UttState();
        final played = <int>[];
        final snapshots = <String>[];
        String sig(UttState x) =>
            '${x.cellsX.join(',')}|${x.cellsO.join(',')}|${x.bigX},${x.bigO},${x.bigDraw}|${x.turn},${x.next},${x.moveCount},${x.outcome.index}';
        while (!s.isOver) {
          final moves = s.legalMoves();
          expect(moves, isNotEmpty);
          snapshots.add(sig(s));
          final m = moves[rng.nextInt(moves.length)];
          expect(s.isLegal(m), isTrue);
          s.apply(m);
          played.add(m);
        }
        expect(played.length, lessThanOrEqualTo(81));
        // 끝까지 되돌린다
        while (played.isNotEmpty) {
          s.undo(played.removeLast());
          expect(sig(s), snapshots.removeLast());
        }
      }
    });

    test('isLegal 은 legalMoves 와 항상 일치한다', () {
      final rng = Random(3);
      final s = UttState();
      while (!s.isOver) {
        final legal = s.legalMoves().toSet();
        for (var m = 0; m < 81; m++) {
          expect(s.isLegal(m), legal.contains(m), reason: '수 $m');
        }
        s.apply(legal.elementAt(rng.nextInt(legal.length)));
      }
    });

    test('fromMoves 와 copy', () {
      final moves = [mv(4, 2), mv(2, 4), mv(4, 3), mv(3, 3)];
      final a = UttState.fromMoves(moves);
      final b = a.copy();
      expect(b.cellsX, a.cellsX);
      expect(b.next, a.next);
      b.apply(b.legalMoves().first);
      expect(a.moveCount, 4); // 복사본을 바꿔도 원본은 그대로
      expect(b.moveCount, 5);
    });
  });

  group('CPU', () {
    test('한 수로 이길 수 있으면 (보통·어려움) 반드시 이긴다', () {
      // X가 큰 판 0,1을 차지했고, 2판에서 한 줄만 만들면 이긴다. 2판에는 X가 0,1에 있다.
      for (final level in [UttLevel.normal, UttLevel.hard]) {
        for (var seed = 0; seed < 5; seed++) {
          final s = UttState();
          s.bigX = 0x3;
          s.cellsX[2] = 0x3;
          s.cellsO[2] = (1 << 3) | (1 << 4);
          s.turn = kX;
          s.next = 2;
          final m = UttAi.choose(s, level, Random(seed));
          expect(m, mv(2, 2), reason: '$level');
        }
      }
    });

    test('상대가 한 수로 이기는 걸 막을 수 있으면 (어려움) 막는다', () {
      // O가 큰 판 0,1을 차지했고, 2판에서 O가 0,1에 있다. X는 2판의 2칸을 막아야 한다.
      final s = UttState();
      s.bigO = 0x3;
      s.cellsO[2] = 0x3;
      s.cellsX[2] = (1 << 3) | (1 << 4);
      s.turn = kX;
      s.next = 2;
      for (var seed = 0; seed < 5; seed++) {
        final m = UttAi.choose(s, UttLevel.hard, Random(seed));
        // 2칸을 막거나, (5칸으로) 같은 판에서 직접 한 줄을 완성해 판을 차지해도 위협은 사라진다.
        // 어느 쪽이든 O가 곧바로 이기는 수가 남아 있으면 안 된다.
        final after = s.copy()..apply(m);
        final oWinsNow = after.legalMoves().any((o) {
          final t = after.copy()..apply(o);
          return t.outcome == Outcome.oWins;
        });
        expect(oWinsNow, isFalse, reason: '수 ${m ~/ 9}판 ${m % 9}칸');
        expect([mv(2, 2), mv(2, 5)], contains(m));
      }
    });

    test('CPU가 둔 수는 항상 합법이고, 보드를 바꾸지 않는다', () {
      final rng = Random(11);
      for (final level in UttLevel.values) {
        final s = UttState();
        var guard = 0;
        while (!s.isOver && guard++ < 90) {
          final before = s.copy();
          final m = UttAi.choose(s, level, rng);
          expect(s.isLegal(m), isTrue, reason: '$level');
          expect(s.cellsX, before.cellsX);
          expect(s.cellsO, before.cellsO);
          expect(s.next, before.next);
          s.apply(m);
        }
        expect(s.isOver, isTrue);
      }
    }, tags: 'slow');

    /// [a]가 X, [b]가 O로 한 판 두고 결과를 돌려준다.
    Outcome duel(UttLevel? a, UttLevel? b, Random rng) {
      final s = UttState();
      var guard = 0;
      while (!s.isOver && guard++ < 90) {
        final level = s.turn == kX ? a : b;
        final m = level == null
            ? (() {
                final all = s.legalMoves();
                return all[rng.nextInt(all.length)];
              })()
            : UttAi.choose(s, level, rng);
        s.apply(m);
      }
      return s.outcome;
    }

    test('어려움 CPU는 무작위 상대에게 거의 지지 않는다 (먼저/나중)', () {
      final rng = Random(5);
      final sw = Stopwatch()..start();
      var wins = 0, losses = 0;
      const n = 12;
      for (var g = 0; g < n; g++) {
        final cpuIsX = g.isEven;
        final o = cpuIsX ? duel(UttLevel.hard, null, rng) : duel(null, UttLevel.hard, rng);
        if ((o == Outcome.xWins && cpuIsX) || (o == Outcome.oWins && !cpuIsX)) wins++;
        if ((o == Outcome.oWins && cpuIsX) || (o == Outcome.xWins && !cpuIsX)) losses++;
      }
      // ignore: avoid_print
      print('어려움 vs 무작위: 승 $wins / 패 $losses / 무 ${n - wins - losses} (${sw.elapsedMilliseconds}ms)');
      expect(wins, greaterThanOrEqualTo(11));
      expect(losses, 0);
    }, timeout: const Timeout(Duration(minutes: 4)), tags: 'slow');

    test('난이도 순서: 어려움 ≥ 보통 ≥ 쉬움 (서로 겨루기)', () {
      final rng = Random(9);
      int score(UttLevel strong, UttLevel weak) {
        var pts = 0;
        const n = 6;
        for (var g = 0; g < n; g++) {
          final strongIsX = g.isEven;
          final o = strongIsX ? duel(strong, weak, rng) : duel(weak, strong, rng);
          final strongWon = (o == Outcome.xWins && strongIsX) || (o == Outcome.oWins && !strongIsX);
          final weakWon = (o == Outcome.xWins && !strongIsX) || (o == Outcome.oWins && strongIsX);
          if (strongWon) pts += 2;
          if (o == Outcome.draw) pts += 1;
          if (weakWon) pts += 0;
        }
        return pts;
      }

      final normalVsEasy = score(UttLevel.normal, UttLevel.easy);
      final hardVsNormal = score(UttLevel.hard, UttLevel.normal);
      // ignore: avoid_print
      print('보통 vs 쉬움 점수 $normalVsEasy/12, 어려움 vs 보통 점수 $hardVsNormal/12');
      expect(normalVsEasy, greaterThan(6)); // 이긴 판이 더 많다
      expect(hardVsNormal, greaterThanOrEqualTo(6)); // 적어도 밀리지 않는다
    }, timeout: const Timeout(Duration(minutes: 6)), tags: 'slow');
  });
}
