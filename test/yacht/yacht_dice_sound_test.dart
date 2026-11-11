import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/yacht/ui/yacht_dice_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('소리 파일이 모두 있다 (한 개 9가지 + 여러 개 1가지)', () {
    for (var i = 1; i <= YachtDiceSound.singleVariants; i++) {
      expect(File('assets/sfx/dice_one_$i.wav').existsSync(), isTrue, reason: 'dice_one_$i.wav');
    }
    expect(File('assets/sfx/dice_multi.wav').existsSync(), isTrue);
  });

  test('3개 이하는 개수만큼 서로 다른 한 개 소리를, 4개 이상은 한 개 소리 없이 "여러 개" 소리를 쓴다', () {
    final sound = YachtDiceSound(rng: Random(1));
    for (var n = 1; n <= 3; n++) {
      for (var round = 0; round < 50; round++) {
        final picks = sound.pickSingles(n);
        expect(picks.length, n);
        expect(picks.toSet().length, n, reason: '서로 다른 소리: $picks');
        expect(picks.every((p) => p >= 0 && p < YachtDiceSound.singleVariants), isTrue);
      }
    }
    expect(sound.pickSingles(4), isEmpty);
    expect(sound.pickSingles(5), isEmpty);
    expect(sound.pickSingles(0), isEmpty);
    // 굴릴 때마다 다른 조합이 나온다 (늘 같은 소리만 나오지 않는다)
    final seen = {for (var i = 0; i < 40; i++) sound.pickSingles(1).first};
    expect(seen.length, greaterThan(3));
    // 시험 환경에서는 소리를 틀지 않지만 불러도 아무 일 없다
    sound.play(1);
    sound.play(3);
    sound.play(5);
    sound.dispose();
    sound.play(2);
  });
}
