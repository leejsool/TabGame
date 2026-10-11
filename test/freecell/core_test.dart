import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/core/freecell_solver.dart';

FcState state(List<List<String>> cols, {List<String> cells = const [], List<int>? found}) {
  int parse(String s) {
    final rank = s.substring(0, s.length - 1);
    final r = rank == 'A'
        ? 0
        : rank == 'T' || rank == '10'
            ? 9
            : rank == 'J'
                ? 10
                : rank == 'Q'
                    ? 11
                    : rank == 'K'
                        ? 12
                        : int.parse(rank) - 1;
    return r * 4 + kSuitLetters.indexOf(s[s.length - 1]);
  }

  final c = [for (final col in cols) [for (final s in col) parse(s)]];
  while (c.length < 8) {
    c.add([]);
  }
  final cl = [for (final s in cells) parse(s)];
  while (cl.length < 4) {
    cl.add(-1);
  }
  return FcState(c, cl, found ?? [0, 0, 0, 0]);
}

void main() {
  group('판 만들기', () {
    test('52장이 한 장씩, 4열은 7장·4열은 6장', () {
      for (final n in [1, 2, 617, 11982, 32000]) {
        final s = FcState.deal(n);
        final all = [for (final c in s.columns) ...c];
        expect(all.toSet().length, 52, reason: '#$n');
        expect(s.columns.map((c) => c.length), [7, 7, 7, 7, 6, 6, 6, 6]);
        expect(s.freeCells, 4);
      }
    });

    test('같은 번호는 늘 같은 판, 다른 번호는 다른 판', () {
      expect(FcState.deal(5).key, FcState.deal(5).key);
      expect(FcState.deal(5).key == FcState.deal(6).key, isFalse);
    });

    test('마이크로소프트 프리셀 1번 판의 첫 줄(처음 깔린 카드)과 같다', () {
      // 1번 판의 첫 줄: JD 2D 9H JC 5D 7H 7C 5H
      final s = FcState.deal(1);
      expect([for (final c in s.columns) cardLabel(c.first)],
          ['JD', '2D', '9H', 'JC', '5D', '7H', '7C', '5H']);
    });
  });

  group('규칙', () {
    test('색이 다르고 계급이 하나 낮은 카드만 열에 올릴 수 있다', () {
      final s = state([
        ['9S'], // 검정 9
        ['8H'], // 빨강 8 → 9S에 올릴 수 있다
        ['8C'], // 검정 8 → 9S에 올릴 수 없다 (색이 같음)
        ['7D'], // 빨강 7 → 9S에 올릴 수 없다 (계급 차이)
      ]);
      expect(s.isLegal(const FcMove(Place.column, 1, Place.column, 0)), isTrue);
      expect(s.isLegal(const FcMove(Place.column, 2, Place.column, 0)), isFalse);
      expect(s.isLegal(const FcMove(Place.column, 3, Place.column, 0)), isFalse);
    });

    test('빈 열에는 아무 카드나, 프리셀은 한 칸에 한 장', () {
      final s = state([['KS'], ['3H']]);
      expect(s.isLegal(const FcMove(Place.column, 1, Place.column, 2)), isTrue); // 빈 열
      expect(s.isLegal(const FcMove(Place.column, 1, Place.cell, 0)), isTrue);
      s.apply(const FcMove(Place.column, 1, Place.cell, 0));
      expect(s.cells[0], 2 * 4 + 2); // 3H = 계급 인덱스 2, 하트(2)
      expect(s.isLegal(const FcMove(Place.column, 0, Place.cell, 0)), isFalse); // 찬 칸
      expect(s.isLegal(const FcMove(Place.column, 0, Place.cell, 1)), isTrue);
    });

    test('완성 칸에는 A부터 같은 무늬로 차례로', () {
      final s = state([['2H'], ['AH'], ['AS']]);
      expect(s.isLegal(const FcMove(Place.column, 0, Place.foundation, 2)), isFalse); // 2H는 아직
      expect(s.isLegal(const FcMove(Place.column, 1, Place.foundation, 2)), isTrue);
      expect(s.isLegal(const FcMove(Place.column, 1, Place.foundation, 3)), isFalse); // 무늬 칸이 다름
      s.apply(const FcMove(Place.column, 1, Place.foundation, 2));
      expect(s.found[2], 1);
      expect(s.isLegal(const FcMove(Place.column, 0, Place.foundation, 2)), isTrue); // 이제 2H 가능
    });

    test('여러 장 옮기기 한도: (빈 프리셀+1) × 2^(빈 열)', () {
      // 빈 프리셀 4, 빈 열 0 → 5장까지
      final s = state([
        ['QH', 'JS', 'TH', '9S', '8H', '7S'], // 이어진 6장 줄
        ['KC'], // QH를 받을 수 있는 검정 K
        ['QD'], // JS를 받을 수 있는 빨강 Q
        ['2C'], ['2D'], ['2H'], ['2S'], ['3C'],
      ]);
      expect(s.emptyColumns, 0);
      expect(s.freeCells, 4);
      expect(s.maxMovable(toEmptyColumn: false), 5);
      expect(s.runLength(0), 6);
      expect(s.isLegal(const FcMove(Place.column, 0, Place.column, 2, 5)), isTrue); // 5장 → QD 위
      expect(s.isLegal(const FcMove(Place.column, 0, Place.column, 1, 6)), isFalse); // 6장은 한도 초과
      s.apply(const FcMove(Place.column, 3, Place.cell, 0));
      // 프리셀을 하나 쓰면 빈 프리셀 3(→ 4장), 대신 열 하나가 비어서 ×2 → 8장
      expect(s.maxMovable(toEmptyColumn: false), (3 + 1) * (1 << 1));
      // 빈 열로 옮길 때는 그 빈 열은 한도 계산에 넣지 않는다
      expect(s.maxMovable(toEmptyColumn: true), (3 + 1) * (1 << 0));
    });

    test('여러 장 줄을 옮길 수 있는 만큼만 옮긴다', () {
      final s = state([
        ['9S', '8H', '7S', '6H'], // 이어진 4장 줄
        ['TD'], // 이 위에 9S 줄을 올린다
      ]);
      // 빈 프리셀 4, 빈 열 6 → 한도는 아주 크다. 프리셀을 채우고 열을 채워 한도를 줄여 본다.
      final t = state([
        ['9S', '8H', '7S', '6H'],
        ['TD'],
        ['KS'], ['KH'], ['QS'], ['QC'], ['JS'], ['JC'],
      ], cells: ['AC', '2C', '3C']); // 프리셀 3칸 사용, 빈 열 0
      expect(t.freeCells, 1);
      expect(t.emptyColumns, 0);
      expect(t.maxMovable(toEmptyColumn: false), 2);
      expect(t.isLegal(const FcMove(Place.column, 0, Place.column, 1, 2)), isFalse); // 7S,6H → TD 안 맞음
      expect(s.runLength(0), 4);
      // 줄 4장을 TD에 올리려면 9S부터 4장: 한도는 충분(프리셀 4,빈 열 6)
      expect(s.isLegal(const FcMove(Place.column, 0, Place.column, 1, 4)), isTrue);
      expect(t.isLegal(const FcMove(Place.column, 0, Place.column, 1, 4)), isFalse); // 한도 2 < 4
    });

    test('안전한 자동 올리기: 에이스·2는 항상, 그 외는 반대 색 앞 계급이 올라간 뒤', () {
      final s = state([['AS', '2S'], ['AH']]);
      // 맨 위: 2S(= 아직 AS가 아래에 있어 못 올림), AH는 가능
      expect(s.safeAutoMove(), const FcMove(Place.column, 1, Place.foundation, 2));

      // 3S: 빨강(하트·다이아) 2가 완성 칸에 없으면 안전하지 않다
      final u = state([['3S']], found: [0, 0, 0, 2]); // 스페이드 A,2 올라감
      expect(u.canFoundation(2 * 4 + 3), isTrue);
      expect(u.safeAutoMove(), isNull);
      final v = state([['3S']], found: [0, 2, 2, 2]); // 다이아·하트도 2까지
      expect(v.safeAutoMove(), const FcMove(Place.column, 0, Place.foundation, 3));
    });

    test('자동 완성 조건: 모든 열이 위로 갈수록 작아질 때', () {
      expect(state([['KS', 'QH', '3C'], ['JD']]).canFinishAutomatically, isTrue);
      expect(state([['3C', 'QH']]).canFinishAutomatically, isFalse); // 3C가 QH 밑에 깔림
    });

    test('FcMove 부호 변환', () {
      const moves = [
        FcMove(Place.column, 7, Place.column, 0, 13),
        FcMove(Place.cell, 3, Place.foundation, 2),
        FcMove(Place.column, 0, Place.cell, 3),
        FcMove(Place.cell, 0, Place.column, 6),
      ];
      for (final m in moves) {
        expect(FcMove.fromCode(m.code), m);
        expect(FcMove.fromCode(m.code).count, m.count);
      }
    });

    test('합법수 목록은 모두 isLegal 이고, 적용해도 52장이 유지된다', () {
      final s = FcState.deal(3);
      for (var step = 0; step < 40; step++) {
        final moves = s.legalMoves();
        if (moves.isEmpty) break;
        for (final m in moves) {
          expect(s.isLegal(m), isTrue, reason: '$m');
        }
        s.apply(moves[step % moves.length]);
        final total = s.columns.fold<int>(0, (a, c) => a + c.length) +
            (4 - s.freeCells) +
            s.foundationTotal;
        expect(total, 52);
      }
    });
  });

  group('풀이기', () {
    // 풀이기가 낸 수 순서를 실제로 적용해서 끝까지 풀리는지 확인한다.
    void verifySolution(int deal, List<FcMove> solution) {
      final s = FcState.deal(deal);
      for (final m in solution) {
        expect(s.isLegal(m), isTrue, reason: '#$deal 불법 수 $m');
        s.apply(m);
      }
      expect(s.isWon, isTrue, reason: '#$deal 풀이가 끝나지 않음');
    }

    test('여러 판을 풀어낸다 (풀이를 직접 적용해 검증)', () {
      var solved = 0;
      var nodesSlow = 0;
      final sw = Stopwatch()..start();
      const deals = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20];
      for (final d in deals) {
        final t = Stopwatch()..start();
        final sol = FcSolver.solve(FcState.deal(d));
        if (sol != null) {
          verifySolution(d, sol);
          solved++;
        }
        if (t.elapsedMilliseconds > 3000) nodesSlow++;
      }
      // ignore: avoid_print
      print('프리셀 풀이기: ${deals.length}판 중 $solved판 해결, 3초 넘게 걸린 판 $nodesSlow, '
          '총 ${sw.elapsedMilliseconds}ms');
      expect(solved, greaterThanOrEqualTo(deals.length - 1));
    });

    test('풀이 도중 상태에서도 이어서 풀 수 있다 (힌트용)', () {
      final s = FcState.deal(2);
      final sol = FcSolver.solve(s)!;
      // 풀이의 앞부분을 적용한 뒤 다시 풀어도 끝까지 풀린다
      for (var i = 0; i < 8 && i < sol.length; i++) {
        s.apply(sol[i]);
      }
      final rest = FcSolver.solve(s);
      expect(rest, isNotNull);
      for (final m in rest!) {
        expect(s.isLegal(m), isTrue);
        s.apply(m);
      }
      expect(s.isWon, isTrue);
    });

    test('이미 풀린 판은 빈 풀이, 풀 수 없는 막힌 판은 null', () {
      final won = FcState([for (var i = 0; i < 8; i++) <int>[]], [-1, -1, -1, -1], [13, 13, 13, 13]);
      expect(FcSolver.solve(won), isEmpty);
      // 프리셀 4칸이 모두 K로 가득 차고, 열마다 움직일 수 없는 카드만 있는 막힌 상태
      final stuck = state([
        ['AS', '2D'], ['AD', '2S'], ['AH', '2C'], ['AC', '2H'],
        ['3S', '5D'], ['3D', '5S'], ['3H', '5C'], ['3C', '5H'],
      ], cells: ['KS', 'KD', 'KH', 'KC']);
      expect(stuck.legalMoves().length, lessThan(100));
      expect(FcSolver.solve(stuck, maxNodes: 20000, timeLimit: const Duration(seconds: 2)), isNull);
    });
  });
}
