// 프리셀 1~32000번 판의 난이도를 풀이기로 재서 파일로 저장하는 도구.
//
// 사용: dart run tool/rate_freecell_deals.dart [시작번호] [끝번호] [출력파일]
//   기본값: 1 32000 assets/freecell_difficulty.bin
// 결과 파일: 판 번호 N의 점수가 (N-1)번째 바이트 (0~255, 클수록 어렵다. 255 = 풀이 실패).
// 여러 코어로 나눠서 돌린다.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tabgame/games/freecell/core/freecell_rules.dart';
import 'package:tabgame/games/freecell/core/freecell_solver.dart';

Uint8List rateRange(List<int> args) {
  final from = args[0], to = args[1];
  final out = Uint8List(to - from + 1);
  for (var deal = from; deal <= to; deal++) {
    if (deal == kUnsolvableDeal) {
      out[deal - from] = 255;
      continue;
    }
    final r = FcSolver.rate(FcState.deal(deal), timeLimit: const Duration(seconds: 5));
    out[deal - from] = r.score;
  }
  return out;
}

Future<void> main(List<String> args) async {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : kMaxDeal;
  final outPath = args.length > 2 ? args[2] : 'assets/freecell_difficulty.bin';
  final workers = (Platform.numberOfProcessors - 1).clamp(1, 16);
  final total = to - from + 1;
  // 작은 덩어리로 잘라서 코어에 골고루 나눈다
  const chunk = 200;
  final tasks = <(int, int)>[];
  for (var s = from; s <= to; s += chunk) {
    tasks.add((s, (s + chunk - 1).clamp(from, to)));
  }
  final result = Uint8List(total);
  var next = 0, done = 0;
  final sw = Stopwatch()..start();
  stdout.writeln('판 $from~$to, 코어 $workers개, 덩어리 ${tasks.length}개');

  Future<void> worker() async {
    while (true) {
      if (next >= tasks.length) return;
      final t = tasks[next++];
      final bytes = await Isolate.run(() => rateRange([t.$1, t.$2]));
      result.setRange(t.$1 - from, t.$1 - from + bytes.length, bytes);
      done += bytes.length;
      if ((done ~/ chunk) % 10 == 0) {
        stdout.writeln('  $done / $total (${sw.elapsed.inMinutes}분 ${sw.elapsed.inSeconds % 60}초)');
      }
    }
  }

  await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(result);
  stdout.writeln('저장: $outPath (${result.length}바이트), 총 ${sw.elapsed.inMinutes}분');
}
