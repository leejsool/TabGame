import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/rhythm/audio/rhythm_audio.dart';

/// 소리 재생기는 오류를 삼키기 때문에, 경로가 틀려도 앱에서는 그냥 조용해진다.
/// 코드에 적힌 효과음 경로가 실제 파일이고 pubspec 폴더 목록에 들어 있는지 여기서 확인한다.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final bundledDirs = RegExp(r'^\s*-\s*(assets/\S+/)\s*$', multiLine: true)
      .allMatches(pubspec)
      .map((m) => m.group(1)!)
      .toSet();

  void expectBundled(String path) {
    final file = 'assets/$path';
    expect(File(file).existsSync(), isTrue, reason: '$file 파일이 없어요');
    final dir = file.substring(0, file.lastIndexOf('/') + 1);
    expect(bundledDirs.contains(dir), isTrue, reason: 'pubspec.yaml 에 $dir 가 없어요');
  }

  test('코드에 직접 적힌 효과음 경로는 모두 파일이 있고 pubspec 에 들어 있다', () {
    final literal = RegExp(r"'(sfx/[A-Za-z0-9_/]+\.(?:wav|mp3))'");
    final found = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in literal.allMatches(f.readAsStringSync())) {
        found.add(m.group(1)!);
      }
    }
    expect(found.length, greaterThan(10));
    for (final p in found) {
      expectBundled(p);
    }
  });

  test('이름을 조합해서 부르는 효과음(요트 주사위, 건반, 리듬)도 모두 있다', () {
    for (var i = 1; i <= 9; i++) {
      expectBundled('sfx/yacht/dice_one_$i.wav');
    }
    for (var m = 55; m <= 84; m++) {
      expectBundled('sfx/keytap/n$m.wav');
    }
    expectBundled('sfx/keytap/wrong.wav');
    for (final s in Sfx.values) {
      expectBundled(s.asset);
    }
  });
}
