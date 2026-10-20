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

  test('칸 칠하기: 칸을 있는 색·새 색·빈 칸으로 바꾸고, 안 쓰이게 된 색은 뺀다', () {
    const art = DotArt(
      width: 2,
      height: 2,
      pixels: [0, 1, 1, 2],
      colors: [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)],
    );
    final skipped = <String>[];
    final out = paintDotCells(
      art,
      {'0,0': '00ff00', '1,1': '.', '5,0': 'FF0000', '0,1': '123456', '1,0': 'zz'},
      skipped: (c, _) => skipped.add(c),
    );
    expect([for (final c in out.colors) dotHex(c)], ['00FF00', '123456'], reason: '그림에 없던 123456은 새 색으로 들어간다');
    expect(out.pixels, [0, 0, 1, kDotEmpty]);
    expect(skipped, ['5,0', '1,0']);
  });
}
