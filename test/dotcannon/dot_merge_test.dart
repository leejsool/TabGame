import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/dotcannon/core/dot_convert.dart';
import 'package:tabgame/games/dotcannon/core/dot_merge.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';

void main() {
  test('색 합치기: 앞 색 칸이 뒤 색이 되고, 앞 색은 목록에서 빠지며, 없는 색 짝은 건너뛴다', () {
    const art = DotArt(
      width: 4,
      height: 1,
      pixels: [0, 1, kDotEmpty, 2],
      colors: [Color(0xFFFF0000), Color(0xFFEE0000), Color(0xFF0000FF)],
    );
    final skipped = <String>[];
    final out = mergeDotColors(art, [('ff0000', 'EE0000'), ('123456', '0000FF')], skipped: (f, t) => skipped.add(f));
    expect([for (final c in out.colors) dotHex(c)], ['EE0000', '0000FF']);
    expect(out.pixels, [0, 0, kDotEmpty, 1]);
    expect(skipped, ['123456']);
  });
}
