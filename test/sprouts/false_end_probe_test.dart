// 조사용(평소에는 건너뜀): 무작위로 끝까지 둔 판 가운데 "위상적으로는 둘 수 있는 수가 남았는데 수 찾기가 못 찾고 끝난 판"을 센다.
// 사용: $env:SPROUTS_PROBE='1'; powershell -File tool/test.ps1 test/sprouts/false_end_probe_test.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/sprouts/core/sprouts_board.dart';
import 'package:tabgame/games/sprouts/core/sprouts_faces.dart';
import 'package:tabgame/games/sprouts/core/sprouts_planner.dart';
import 'package:tabgame/games/sprouts/core/sprouts_relax.dart' show boardIsPlanar;

void main() {
  final probe = Platform.environment['SPROUTS_PROBE'] != null;
  test('거짓 종료 세기', () {
    var falseEnds = 0, games = 0;
    final report = StringBuffer();
    for (final n in [2, 3, 4, 5, 6]) {
      for (var seed = 1; seed <= 100; seed++) {
        final rng = Random(seed * 31 + n);
        final b = SproutsBoard.initial(n, rng);
        var moves = 0;
        while (true) {
          final ms = findMoves(b);
          if (ms.isEmpty) break;
          final m = ms[rng.nextInt(ms.length)];
          final hadLayout = m.result.layout != null;
          final loop = m.s == m.e;
          b.apply(m.s, m.e, m.result, moves % 2);
          moves++;
          if (!boardIsPlanar(b)) {
            report.writeln('  (layout=$hadLayout loop=$loop s=${m.s} e=${m.e})');
            falseEnds += 1000;
            report.writeln('n=$n seed=$seed moves=$moves 선이 서로 가로질렀어요');
            break;
          }
        }
        games++;
        if (analyzeRegions(b).hasMove(b)) {
          falseEnds++;
          report.writeln('n=$n seed=$seed moves=$moves lives=${[for (final d in b.dots) d.lives]} pairs=${analyzeRegions(b).allPairs(b)}');
        }
      }
    }
    // ignore: avoid_print
    print('games=$games falseEnds=$falseEnds\n$report');
  }, skip: !probe, timeout: const Timeout(Duration(minutes: 30)));
}
