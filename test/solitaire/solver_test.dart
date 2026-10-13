import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/solitaire/core/solitaire_rules.dart';
import 'package:tabgame/games/solitaire/core/solitaire_solver.dart';
import 'package:tabgame/games/solitaire/game/solitaire_controller.dart';

/// 어떤 수도 둘 수 없는 막힌 판: 0열 맨 밑에 A♣가 덮여 있고 K♦는 갈 곳이 없다.
SolState deadState() => SolState(
      [
        [0, 49], // A♣(뒤집힘), K♦
        [16], // 5♣
        [17], // 5♦
        [18], // 5♥
        [19], // 5♠
        [28], // 8♣
        [29], // 8♦
      ],
      [1, 1, 1, 1, 1, 1, 1],
      <int>[],
      <int>[],
      [0, 0, 0, 0],
      0,
    );

/// 솔버와 따로 만든 단순 탐색: 가지치기 없이 모든 상태를 본다. (이길 수 있으면 true / 못 이기면 false / 한도 초과면 null)
bool? bruteForceWins(SolState start, {int limit = 400000}) {
  String key(SolState s) =>
      '${s.tableau.map((t) => t.join(',')).join('|')}/${s.up.join(',')}/${s.stock.join(',')}/${s.waste.join(',')}/${s.found.join(',')}';
  final seen = <String>{key(start)};
  final stack = [start.copy()];
  while (stack.isNotEmpty) {
    final s = stack.removeLast();
    if (s.isWon) return true;
    for (final m in s.legalMoves()) {
      final n = s.copy()..apply(m);
      if (seen.add(key(n))) {
        if (seen.length > limit) return null;
        stack.add(n);
      }
    }
  }
  return false;
}

void main() {
  group('솔리테어 풀이기', () {
    test('막힌 판은 망했다고 판정한다', () async {
      final s = deadState();
      expect(s.legalMoves(), isEmpty);
      final r = await solveSolitaire(s);
      expect(r.verdict, SolVerdict.lost);
      expect(r.firstMove, isNull);
    });

    test('이길 수 있다고 한 판은 그 수순을 그대로 따라가면 실제로 이긴다', () async {
      var winnable = 0;
      for (var deal = 1; deal <= 25; deal++) {
        final start = SolState.deal(deal, draw: deal.isEven ? 1 : 3);
        final r = await solveSolitaire(start);
        if (r.verdict != SolVerdict.winnable) continue;
        winnable++;
        final s = start.copy();
        for (final m in r.path) {
          expect(s.isLegal(m), isTrue, reason: '판 $deal: $m');
          s.apply(m);
        }
        // 남은 카드가 모두 앞면이면 자동으로 끝까지 올라간다
        var guard = 0;
        while (!s.isWon && s.canFinishAutomatically && guard++ < 100) {
          s.apply(s.legalMoves().firstWhere((m) => m.kind == SolKind.colToFound));
        }
        expect(s.isWon, isTrue, reason: '판 $deal');
        expect(start.found.every((n) => n == 0), isTrue, reason: '원본 상태는 건드리지 않는다');
      }
      expect(winnable, greaterThanOrEqualTo(8)); // 대부분의 판은 이길 수 있다
    });

    test('한도가 너무 작으면 모른다고 답한다', () async {
      final r = await solveSolitaire(SolState.deal(617), maxNodes: 3);
      expect(r.verdict, SolVerdict.unknown);
    });

    test('중간에 취소하면 모른다고 답한다', () async {
      final r = await solveSolitaire(SolState.deal(617), cancelled: () => true, maxNodes: 1000000);
      // 취소 확인은 1500 노드마다라서, 금방 풀리는 판이면 취소 전에 끝날 수 있다
      expect(r.verdict == SolVerdict.unknown || r.verdict == SolVerdict.winnable, isTrue);
    });

    test('"망했다"는 판정은 가지치기 없는 단순 탐색과 같다', () async {
      final rng = Random(11);
      var checkedLost = 0;
      var checkedWin = 0;
      for (var i = 0; i < 60 && checkedLost < 4; i++) {
        final s = SolState.deal(1 + rng.nextInt(99999));
        // 랜덤으로 한참 진행해서 이미 꼬인 (작아진) 판을 만든다
        final steps = 150 + rng.nextInt(250);
        for (var step = 0; step < steps && !s.isWon; step++) {
          final moves = s.legalMoves();
          if (moves.isEmpty) break;
          s.apply(moves[rng.nextInt(moves.length)]);
        }
        final r = await solveSolitaire(s, maxNodes: 20000);
        if (r.verdict == SolVerdict.unknown) continue;
        final brute = bruteForceWins(s, limit: 40000);
        if (brute == null) continue;
        expect(r.verdict == SolVerdict.winnable, brute, reason: 'i=$i');
        if (brute) {
          checkedWin++;
        } else {
          checkedLost++;
        }
      }
      expect(checkedLost + checkedWin, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('솔리테어 힌트 (컨트롤러)', () {
    test('이미 망한 판이면 망했다고 알려 준다', () async {
      final c = SolitaireController(deal: 1, autoMoveEnabled: false);
      c.state = deadState();
      await c.requestHint();
      expect(c.hint, isNull);
      expect(c.hintMessage, contains('망했어요'));
      expect(c.hintThinking, isFalse);
    });

    test('이길 수 있는 판이면 합법적인 첫 수를 가리킨다', () async {
      final c = SolitaireController(deal: 1, autoMoveEnabled: false);
      await c.requestHint();
      if (c.hint != null) {
        expect(c.state.isLegal(c.hint!), isTrue);
        expect(c.hintMessage, isNotNull);
      }
      expect(c.hintThinking, isFalse);
    });

    test('힌트를 기다리는 사이에 수를 두면 낡은 답은 버린다', () async {
      final c = SolitaireController(deal: 617, autoMoveEnabled: false);
      final pending = c.requestHint();
      expect(c.hintThinking, isTrue);
      c.drawFromStock();
      await pending;
      expect(c.hintThinking, isFalse);
      expect(c.hint, isNull);
    });

    test('힌트를 닫으면 계산 결과가 나중에 도착해도 다시 뜨지 않는다', () async {
      final c = SolitaireController(deal: 617, autoMoveEnabled: false);
      final pending = c.requestHint();
      c.dismissHint();
      await pending;
      expect(c.hint, isNull);
      expect(c.hintMessage, isNull);
    });
  });
}
