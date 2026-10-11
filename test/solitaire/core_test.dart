import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/solitaire/core/solitaire_rules.dart';

/// 모든 카드가 정확히 한 곳에 있는지 확인한다.
void expectConserved(SolState s) {
  final all = <int>[
    for (final t in s.tableau) ...t,
    ...s.stock,
    ...s.waste,
    for (var suit = 0; suit < 4; suit++)
      for (var r = 0; r < s.found[suit]; r++) r * 4 + suit,
  ];
  expect(all.length, 52);
  expect(all.toSet().length, 52);
  for (var i = 0; i < 7; i++) {
    expect(s.up[i], inInclusiveRange(s.tableau[i].isEmpty ? 0 : 1, s.tableau[i].length), reason: 'col $i');
  }
}

String dump(SolState s) => [
      s.tableau.map((t) => t.join(',')).join('|'),
      s.up.join(','),
      s.stock.join(','),
      s.waste.join(','),
      s.found.join(','),
      s.fan,
    ].join(' / ');

void main() {
  group('판 만들기', () {
    test('열은 1~7장, 맨 위만 앞면, 나머지 24장은 더미', () {
      final s = SolState.deal(1);
      expectConserved(s);
      expect([for (final t in s.tableau) t.length], [1, 2, 3, 4, 5, 6, 7]);
      expect(s.up, [1, 1, 1, 1, 1, 1, 1]);
      expect(s.stock.length, 24);
      expect(s.waste, isEmpty);
      expect(s.faceDownCount, 21);
    });

    test('같은 번호는 같은 판, 다른 번호는 다른 판', () {
      expect(dump(SolState.deal(617)), dump(SolState.deal(617)));
      expect(dump(SolState.deal(617)), isNot(dump(SolState.deal(618))));
    });

    test('수 코드 왕복', () {
      for (final m in [
        SolMove.draw,
        SolMove.recycle,
        const SolMove(SolKind.colToCol, from: 6, to: 0, count: 13),
        const SolMove(SolKind.foundToCol, from: 3, to: 6),
        const SolMove(SolKind.wasteToCol, to: 4),
      ]) {
        expect(SolMove.fromCode(m.code), m);
      }
    });
  });

  group('규칙', () {
    SolState empty({int draw = 1}) => SolState(
          List.generate(7, (_) => <int>[]),
          List.filled(7, 0),
          [],
          [],
          List.filled(4, 0),
          0,
          draw: draw,
        );

    test('열에는 다른 색 + 숫자가 하나 작은 카드만, 빈 열에는 K만', () {
      final s = empty();
      s.tableau[0].add(6 * 4 + 0); // 클로버 7 (검정)
      s.up[0] = 1;
      expect(s.canPlaceOnCol(5 * 4 + 1, 0), isTrue); // 다이아 6
      expect(s.canPlaceOnCol(5 * 4 + 3, 0), isFalse); // 스페이드 6 (같은 색)
      expect(s.canPlaceOnCol(4 * 4 + 1, 0), isFalse); // 숫자가 맞지 않음
      expect(s.canPlaceOnCol(12 * 4 + 2, 1), isTrue); // 빈 열에 K
      expect(s.canPlaceOnCol(11 * 4 + 2, 1), isFalse); // 빈 열에 Q
    });

    test('완성 칸에는 A부터 같은 무늬 순서로', () {
      final s = empty();
      expect(s.canPlaceOnFound(0 * 4 + 2), isTrue);
      expect(s.canPlaceOnFound(1 * 4 + 2), isFalse);
      s.found[2] = 1;
      expect(s.canPlaceOnFound(1 * 4 + 2), isTrue);
    });

    test('뒤집힌 카드 위에는 놓을 수 없다', () {
      final s = empty();
      s.tableau[0].addAll([6 * 4 + 0]);
      s.up[0] = 0;
      expect(s.canPlaceOnCol(5 * 4 + 1, 0), isFalse);
    });

    test('옮기고 나면 아래 카드가 저절로 앞면이 된다', () {
      final s = empty();
      s.tableau[0].addAll([30, 6 * 4 + 0]);
      s.up[0] = 1;
      s.tableau[1].addAll([7 * 4 + 1]); // 다이아 8
      s.up[1] = 1;
      s.apply(const SolMove(SolKind.colToCol, from: 0, to: 1));
      expect(s.tableau[1].last, 6 * 4 + 0);
      expect(s.up[0], 1);
      expect(s.tableau[0], [30]);
      expect(s.up[1], 2);
    });

    test('뽑기: 1장/3장, 더미가 비면 다시 넘기기', () {
      final s = SolState.deal(5, draw: 3);
      final top3 = s.stock.reversed.take(3).toList();
      s.apply(SolMove.draw);
      expect(s.waste, top3);
      expect(s.fan, 3);
      expect(s.stock.length, 21);
      for (var i = 0; i < 7; i++) {
        s.apply(SolMove.draw);
      }
      expect(s.stock, isEmpty);
      expect(s.waste.length, 24);
      expect(s.legalMoves().contains(SolMove.recycle), isTrue);
      final order = List<int>.of(s.waste);
      s.apply(SolMove.recycle);
      expect(s.waste, isEmpty);
      expect(s.stock.length, 24);
      s.apply(SolMove.draw);
      expect(s.waste, order.take(3).toList()); // 처음과 같은 순서로 다시 나온다
    });

    test('버린 카드를 완성 칸에 올리면 펼친 장수(fan)가 줄어든다', () {
      final s = empty(draw: 3);
      s.waste.addAll([20, 9, 0 * 4 + 0]); // 맨 위가 클로버 A
      s.fan = 3;
      s.apply(const SolMove(SolKind.wasteToFound));
      expect(s.waste, [20, 9]);
      expect(s.fan, 2);
      expect(s.found[0], 1);
    });

    test('A는 완성 칸으로, 완성 칸에서 열로 내릴 수도 있다', () {
      final s = empty();
      s.waste.add(0 * 4 + 1); // 다이아 A
      s.fan = 1;
      s.apply(const SolMove(SolKind.wasteToFound));
      expect(s.found[1], 1);
      expect(s.waste, isEmpty);
      expect(s.fan, 0);
    });

    test('안전하게 올릴 카드: A/2는 항상, 3부터는 반대 색 앞 숫자가 올라가 있을 때', () {
      final s = empty();
      expect(s.isSafeForFound(0 * 4 + 0), isTrue);
      s.found[0] = 1;
      expect(s.isSafeForFound(1 * 4 + 0), isTrue); // 클로버 2
      s.found[0] = 2;
      expect(s.isSafeForFound(2 * 4 + 0), isFalse); // 클로버 3: 빨강 2들이 아직
      s.found[1] = 2;
      s.found[2] = 2;
      expect(s.isSafeForFound(2 * 4 + 0), isTrue);
    });

    test('모든 카드가 앞면이고 더미가 비면 자동으로 끝낼 수 있다', () {
      final s = empty();
      s.tableau[0].addAll([12 * 4 + 0, 11 * 4 + 1]);
      s.up[0] = 2;
      expect(s.canFinishAutomatically, isTrue);
      s.stock.add(3);
      expect(s.canFinishAutomatically, isFalse);
    });

    test('이긴 판', () {
      final s = empty();
      expect(s.isWon, isFalse);
      s.found.fillRange(0, 4, 13);
      expect(s.isWon, isTrue);
    });

    test('막힘: 더미를 넘겨도 둘 수 있는 수가 없으면 막힘', () {
      final s = empty();
      s.tableau[0].add(2 * 4 + 0); // 클로버 3
      s.up[0] = 1;
      s.tableau[1].add(4 * 4 + 1); // 다이아 5
      s.up[1] = 1;
      expect(s.isStuck, isTrue);
      s.stock.add(1 * 4 + 1); // 다이아 2 → 클로버 3 위에 둘 수 있다
      expect(s.isStuck, isFalse);
    });
  });

  group('무작위 플레이', () {
    test('아무 합법 수나 두어도 카드는 늘 52장이고, 복사본은 독립적이다', () {
      final rng = Random(7);
      for (var game = 0; game < 40; game++) {
        final s = SolState.deal(1 + rng.nextInt(99999), draw: game.isEven ? 1 : 3);
        for (var step = 0; step < 300 && !s.isWon; step++) {
          final before = s.copy();
          final before0 = dump(before);
          final moves = s.legalMoves();
          if (moves.isEmpty) break;
          final m = moves[rng.nextInt(moves.length)];
          expect(s.isLegal(m), isTrue);
          s.apply(m);
          expectConserved(s);
          expect(dump(before), before0); // 복사본은 그대로
        }
      }
    });

    test('힌트는 늘 합법적인 수이거나 null', () {
      final rng = Random(3);
      for (var game = 0; game < 30; game++) {
        final s = SolState.deal(1 + rng.nextInt(99999));
        for (var step = 0; step < 150; step++) {
          final h = s.hint();
          if (h == null) break;
          expect(s.isLegal(h), isTrue, reason: '$h');
          final moves = s.legalMoves();
          s.apply(rng.nextInt(3) == 0 ? h : moves[rng.nextInt(moves.length)]);
        }
      }
    });

    test('힌트만 따라가도 쉬운 판은 상당 부분 풀린다 (힌트가 엉뚱하지 않다)', () {
      var progressed = 0;
      for (var deal = 1; deal <= 30; deal++) {
        final s = SolState.deal(deal);
        for (var step = 0; step < 400 && !s.isWon; step++) {
          final h = s.hint();
          if (h == null) break;
          s.apply(h);
        }
        if (s.found.fold<int>(0, (a, b) => a + b) >= 8) progressed++;
      }
      expect(progressed, greaterThanOrEqualTo(8));
    });
  });
}
