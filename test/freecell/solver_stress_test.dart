// 풀이기 스트레스 테스트: 환경변수 FC_STRESS 가 있을 때만 실행된다 (오래 걸림).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/core/freecell_solver.dart';

void main() {
  final on = Platform.environment['FC_STRESS'] != null;
  test('풀이기: 300판 스트레스', () {
    var solved = 0, failed = 0;
    var maxMs = 0, totalMs = 0, longest = 0;
    final failures = <int>[];
    for (var deal = 1; deal <= 300; deal++) {
      final sw = Stopwatch()..start();
      final sol = FcSolver.solve(FcState.deal(deal));
      final ms = sw.elapsedMilliseconds;
      totalMs += ms;
      if (ms > maxMs) maxMs = ms;
      if (sol == null) {
        failed++;
        failures.add(deal);
        continue;
      }
      final s = FcState.deal(deal);
      for (final m in sol) {
        expect(s.isLegal(m), isTrue, reason: '#$deal $m');
        s.apply(m);
      }
      expect(s.isWon, isTrue, reason: '#$deal');
      solved++;
      if (sol.length > longest) longest = sol.length;
    }
    // ignore: avoid_print
    print('풀이 $solved / 실패 $failed $failures, 평균 ${totalMs ~/ 300}ms, 최대 ${maxMs}ms, 가장 긴 풀이 $longest 수');
    expect(solved, greaterThan(290));
  }, skip: !on, timeout: const Timeout(Duration(minutes: 8)));
}
