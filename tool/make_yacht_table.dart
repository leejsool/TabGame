// 야추 "기대 점수 표"(assets/yacht/values.bin)를 계산해 저장한다. 규칙을 바꾸면 다시 돌린다.
//   dart run tool/make_yacht_table.dart
import 'dart:io';

import 'package:tabgame/games/yacht/core/yacht_values.dart';

void main() {
  final watch = Stopwatch()..start();
  var seen = 0;
  final raw = buildYachtValues(onMask: (_) {
    seen++;
    if (seen % 512 == 0) stdout.writeln('  $seen / 4095 ...');
  });
  final values = YachtValues.fromDoubles(raw);
  final file = File('assets/yacht/values.bin')..createSync(recursive: true);
  file.writeAsBytesSync(values.toBytes());
  stdout.writeln('저장: ${file.path} (${file.lengthSync()} 바이트, ${watch.elapsed.inSeconds}초)');
  stdout.writeln('처음부터 가장 좋게 했을 때의 평균 점수: ${raw[0].toStringAsFixed(2)}');
}
