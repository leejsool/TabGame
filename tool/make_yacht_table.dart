// 야추 "기대 점수 표"를 계산해 저장한다. 규칙을 바꾸면 다시 돌린다.
//   dart run tool/make_yacht_table.dart        (기본 규칙: assets/yacht/values.bin, 대성One Rule: assets/yacht/values_ds.bin)
//   dart run tool/make_yacht_table.dart ds     (대성One Rule 표만)
import 'dart:io';

import 'package:tabgame/games/yacht/core/yacht_daesung_values.dart';
import 'package:tabgame/games/yacht/core/yacht_values.dart';

void main(List<String> args) {
  final onlyDs = args.contains('ds');
  if (!onlyDs) {
    final watch = Stopwatch()..start();
    var seen = 0;
    final raw = buildYachtValues(onMask: (_) {
      seen++;
      if (seen % 1024 == 0) stdout.writeln('  $seen / 8191 ...');
    });
    final values = YachtValues.fromDoubles(raw);
    final file = File('assets/yacht/values.bin')..createSync(recursive: true);
    file.writeAsBytesSync(values.toBytes());
    stdout.writeln('저장: ${file.path} (${file.lengthSync()} 바이트, ${watch.elapsed.inSeconds}초)');
    stdout.writeln('처음부터 가장 좋게 했을 때의 평균 점수: ${raw[0].toStringAsFixed(2)}');
  }

  final watch = Stopwatch()..start();
  var seen = 0;
  final ds = buildDaesungValues(onMask: (_) {
    seen++;
    if (seen % 128 == 0) stdout.writeln('  (대성One) $seen / 1023 ...');
  });
  final file = File('assets/yacht/values_ds.bin')..createSync(recursive: true);
  file.writeAsBytesSync(YachtDaesungValues.fromDoubles(ds).toBytes());
  stdout.writeln('저장: ${file.path} (${file.lengthSync()} 바이트, ${watch.elapsed.inSeconds}초)');
  stdout.writeln('대성One Rule 처음부터 가장 좋게 했을 때의 평균 점수: ${ds[0].toStringAsFixed(2)}');
}
