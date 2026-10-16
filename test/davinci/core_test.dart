import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/davinci/core/davinci_ai.dart';
import 'package:tabgame/games/davinci/core/davinci_rules.dart';

int b(int n) => dvTile(0, n);
int w(int n) => dvTile(1, n);

/// 정해 둔 줄로 시작하는 2명 판 (더미는 비워 두고 필요하면 채운다).
DvState fixed(List<int> row0, List<int> row1, {List<int> black = const [], List<int> white = const []}) {
  final s = DvState.deal(2, 1);
  s.rows[0]
    ..clear()
    ..addAll(row0);
  s.rows[1]
    ..clear()
    ..addAll(row1);
  s.blackPool
    ..clear()
    ..addAll(black);
  s.whitePool
    ..clear()
    ..addAll(white);
  s.revealed.clear();
  s.turn = 0;
  s.phase = DvPhase.draw;
  s.drawn = null;
  s.winner = null;
  s.phase = s.drawableColors.isEmpty ? DvPhase.guess : DvPhase.draw;
  return s;
}

void main() {
  group('패 나누기', () {
    test('26장이 겹치지 않고, 2명 4장·3~4명 3장씩, 줄은 순서대로 놓인다', () {
      for (final players in [2, 3, 4]) {
        final s = DvState.deal(players, 7);
        final all = [for (final r in s.rows) ...r, ...s.blackPool, ...s.whitePool];
        expect(all.toSet().length, kDvTiles);
        expect(all.length, kDvTiles);
        for (final r in s.rows) {
          expect(r.length, players == 2 ? 4 : 3);
          final plain = [for (final t in r) if (!dvIsJoker(t)) t];
          for (var i = 1; i < plain.length; i++) {
            expect(dvCompare(plain[i - 1], plain[i]), lessThan(0));
          }
        }
        expect(s.blackPool.every((t) => dvColor(t) == 0), isTrue);
        expect(s.whitePool.every((t) => dvColor(t) == 1), isTrue);
      }
      expect(DvState.deal(3, 5).rows, DvState.deal(3, 5).rows); // 같은 씨앗이면 같은 패
    });

    test('같은 숫자는 검정이 앞, 조커는 순서에 끼지 않는다', () {
      expect(dvCompare(b(5), w(5)), lessThan(0));
      expect(dvCompare(w(4), b(5)), lessThan(0));
      expect(dvNumber(24), -1);
      expect(dvColor(25), 1);
    });
  });

  group('한 차례', () {
    test('뽑은 타일은 순서에 맞는 자리에 끼워지고, 맞히면 공개되어 계속하거나 멈춘다', () {
      final s = fixed([b(1), b(6), w(9)], [b(2), w(7), b(10)], black: [b(4)], white: [w(3)]);
      expect(s.phase, DvPhase.draw);
      expect(s.isLegal(DvMove.drawMove(0)), isTrue);
      s.apply(DvMove.drawMove(0)); // 검정 4
      expect(s.rows[0], [b(1), b(4), b(6), w(9)]);
      expect(s.drawn, b(4));
      expect(s.phase, DvPhase.guess);
      // 상대의 숨은 타일 맞히기
      s.apply(DvMove.guess(1, 1, 7)); // 흰 7 맞힘
      expect(s.isRevealed(w(7)), isTrue);
      expect(s.phase, DvPhase.decide);
      expect(s.lastGuess!.correct, isTrue);
      // 멈추면 내 뽑은 타일은 숨은 채로 차례가 넘어간다
      s.apply(DvMove.stop);
      expect(s.turn, 1);
      expect(s.isRevealed(b(4)), isFalse);
      expect(s.phase, DvPhase.draw);
    });

    test('틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어간다', () {
      final s = fixed([b(1), b(6), w(9)], [b(2), w(7), b(10)], black: [b(4)]);
      s.apply(DvMove.drawMove(0));
      s.apply(DvMove.guess(1, 0, 11)); // 틀림 (검정 2)
      expect(s.lastGuess!.correct, isFalse);
      expect(s.isRevealed(b(4)), isTrue);
      expect(s.isRevealed(b(2)), isFalse);
      expect(s.turn, 1);
    });

    test('맞힌 뒤에도 계속 맞히다가 틀리면 그때 뽑은 타일이 공개된다', () {
      final s = fixed([b(1), b(6), w(9)], [b(2), w(7), b(10)], white: [w(3)]);
      s.apply(DvMove.drawMove(1));
      s.apply(DvMove.guess(1, 0, 2));
      expect(s.phase, DvPhase.decide);
      s.apply(DvMove.guess(1, 1, 5)); // 틀림
      expect(s.isRevealed(w(3)), isTrue);
      expect(s.turn, 1);
    });

    test('공개된 타일·자기 자신·탈락한 사람은 맞힐 수 없고, 숫자 범위도 지켜야 한다', () {
      final s = fixed([b(1), b(6), w(9)], [b(2), w(7), b(10)], black: [b(4)]);
      s.apply(DvMove.drawMove(0));
      expect(s.isLegal(DvMove.guess(0, 0, 3)), isFalse); // 나
      expect(s.isLegal(DvMove.guess(1, 5, 3)), isFalse); // 없는 자리
      expect(s.isLegal(DvMove.guess(1, 0, 13)), isFalse);
      expect(s.isLegal(DvMove.guess(1, 0, kJokerGuess)), isTrue);
      s.revealed.add(b(2));
      expect(s.isLegal(DvMove.guess(1, 0, 2)), isFalse); // 이미 공개
    });

    test('뽑은 조커는 내가 고른 자리에 놓인다', () {
      final s = fixed([b(1), b(6)], [b(2), w(7)], black: [24]);
      s.apply(DvMove.drawMove(0));
      expect(s.phase, DvPhase.placeJoker);
      expect(s.pendingJoker, 24);
      expect(s.isLegal(DvMove.placeJoker(3)), isFalse);
      s.apply(DvMove.placeJoker(1));
      expect(s.rows[0], [b(1), 24, b(6)]);
      expect(s.phase, DvPhase.guess);
      // 조커 맞히기
      s.rows[1][0] = 25;
      s.apply(DvMove.guess(1, 0, kJokerGuess));
      expect(s.lastGuess!.correct, isTrue);
    });

    test('더미가 비면 뽑지 않고 바로 맞히고, 틀리면 내 숨은 타일 하나를 직접 공개한다', () {
      final s = fixed([b(1), b(6), w(9)], [b(2), w(7), b(10)]);
      expect(s.phase, DvPhase.guess);
      s.apply(DvMove.guess(1, 0, 5)); // 틀림 (뽑은 타일이 없다)
      expect(s.phase, DvPhase.reveal);
      expect(s.turn, 0);
      expect(s.isLegal(DvMove.reveal(1)), isTrue);
      s.apply(DvMove.reveal(1));
      expect(s.isRevealed(b(6)), isTrue);
      expect(s.turn, 1);
    });
  });

  group('탈락과 승리', () {
    test('숨은 타일이 모두 공개되면 탈락하고, 마지막 한 사람이 이긴다', () {
      final s = fixed([b(1), b(6)], [b(2), w(7)], black: [b(4)]);
      s.revealed.add(b(2));
      s.apply(DvMove.drawMove(0));
      s.apply(DvMove.guess(1, 1, 7)); // 마지막 숨은 타일을 맞힘
      expect(s.isOut(1), isTrue);
      expect(s.winner, 0);
      expect(s.isOver, isTrue);
      expect(s.isLegal(DvMove.stop), isFalse);
    });

    test('틀려서 내 마지막 숨은 타일이 공개되면 내가 탈락한다 (2명이면 상대가 이긴다)', () {
      final s = fixed([b(1)], [b(2), w(7)], black: [b(4)]);
      s.rows[0]
        ..clear()
        ..add(b(1));
      s.revealed.add(b(1));
      s.rows[0].insert(0, b(0)); // 숨은 타일은 b(0) 하나
      s.apply(DvMove.drawMove(0)); // 검정 4가 끼워진다
      s.revealed.add(b(0)); // (이제 방금 뽑은 타일만 숨어 있다고 가정)
      s.apply(DvMove.guess(1, 0, 9)); // 틀림 → 뽑은 타일 공개 → 전부 공개
      expect(s.isOut(0), isTrue);
      expect(s.winner, 1);
    });

    test('3명 이상이면 탈락한 사람은 건너뛰고 차례가 돈다', () {
      final s = DvState.deal(3, 2);
      s.blackPool.clear();
      s.whitePool.clear();
      s.phase = DvPhase.guess;
      s.revealed.addAll(s.rows[1]); // 1번 탈락
      s.apply(DvMove.guess(2, 0, 11)); // 틀림 (뽑은 타일이 없어서 내 타일 하나를 직접 공개한다)
      expect(s.phase, DvPhase.reveal);
      s.apply(DvMove.reveal(0));
      expect(s.turn, 2); // 탈락한 1번을 건너뛴다
    });
  });

  group('후보와 CPU', () {
    test('후보: 내 타일과 공개된 타일은 빼고, 양옆 공개된 타일의 순서에 맞는 숫자만 남긴다', () {
      final s = fixed([b(3), w(5), b(9)], [b(1), b(4), b(8), w(10)]);
      s.revealed.addAll([b(1), b(8)]);
      // 1번 줄의 두 번째(검정 4): 왼쪽 공개 검정1, 오른쪽 공개 검정8 사이 + 내 b3은 제외
      final c = s.candidates(0, 1, 1);
      expect(c.contains(4), isTrue);
      expect(c.contains(3), isFalse); // 내가 가진 검정 3
      expect(c.contains(0), isFalse); // 왼쪽 검정1보다 작다
      expect(c.contains(9), isFalse); // 내가 가진 검정 9 (그리고 오른쪽 검정8보다 크다)
      expect(c.contains(10), isFalse); // 오른쪽 검정8보다 크다
      expect(c.contains(kJokerGuess), isTrue); // 조커는 어디든 가능
    });

    test('CPU는 항상 둘 수 있는 수를 고르고, 끝까지 두면 승자가 나온다', () {
      for (final players in [2, 3, 4]) {
        for (final level in DvLevel.values) {
          for (var seed = 0; seed < 3; seed++) {
            final s = DvState.deal(players, seed * 10 + players);
            final rng = Random(seed);
            var steps = 0;
            while (!s.isOver && steps < 2000) {
              steps++;
              final m = DvAi.choose(s, level, rng);
              expect(s.isLegal(m), isTrue, reason: '$players명 $level seed $seed step $steps $m ${s.phase}');
              s.apply(m);
            }
            expect(s.isOver, isTrue, reason: '$players명 $level seed $seed 끝나지 않았어요');
            expect(s.winner, isNotNull);
          }
        }
      }
    });

    test('확률: 숫자를 줄 순서에 맞춰 세어서, 가능한 숫자들의 확률 합이 1이고 실제 숫자가 후보에 들어 있다', () {
      for (var g = 0; g < 60; g++) {
        final s = DvState.deal(2 + g % 3, g);
        final rng = Random(g);
        var steps = 0;
        while (!s.isOver && steps++ < 400) {
          for (var viewer = 0; viewer < s.players; viewer++) {
            for (var seat = 0; seat < s.players; seat++) {
              if (seat == viewer) continue;
              final m = DvAi.rowMarginals(s, viewer, seat);
              for (var i = 0; i < s.rows[seat].length; i++) {
                final t = s.rows[seat][i];
                if (s.isRevealed(t)) {
                  expect(m[i], isNull);
                  continue;
                }
                final probs = m[i]!;
                expect(probs.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-6));
                expect(probs.containsKey(dvIsJoker(t) ? kJokerGuess : dvNumber(t)), isTrue, reason: 'g$g');
              }
            }
          }
          s.apply(DvAi.choose(s, DvLevel.values[rng.nextInt(3)], rng));
        }
      }
    });

    test('확률: 양옆이 공개된 칸은 사이의 숫자만 남는다', () {
      // 1번 줄: 검정2(공개), 검정3(숨음), 검정4(공개) — 내 줄에는 이 숫자들이 없다
      final s = fixed([w(0), w(11)], [b(2), b(3), b(4)]);
      s.revealed.addAll([b(2), b(4)]);
      final m = DvAi.rowMarginals(s, 0, 1)[1]!;
      expect(m[3], greaterThan(0.4));
      // 검정 2보다 크고 4보다 작은 검정은 3뿐 (흰색 타일은 색이 달라서 이 칸에 올 수 없다). 조커만 예외로 남는다.
      expect(m.keys.where((k) => k != kJokerGuess && k != 3), isEmpty, reason: '$m');
    });

    test('CPU가 후보 안에서 맞히면 맞히는 쪽이 더 이긴다 (보통이 쉬움보다 낫다)', () {
      var normalWins = 0;
      const games = 30;
      for (var g = 0; g < games; g++) {
        final s = DvState.deal(2, 100 + g);
        final rng = Random(g);
        final normalSeat = g % 2;
        var steps = 0;
        while (!s.isOver && steps < 3000) {
          steps++;
          s.apply(DvAi.choose(s, s.turn == normalSeat ? DvLevel.normal : DvLevel.easy, rng));
        }
        if (s.winner == normalSeat) normalWins++;
      }
      expect(normalWins, greaterThan(games ~/ 2));
    });
  });
}
